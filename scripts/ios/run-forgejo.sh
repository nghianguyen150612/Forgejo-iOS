#!/usr/bin/env bash

set -euo pipefail

usage() {
	cat >&2 <<'USAGE'
usage:
  run-forgejo.sh FORGEJO_BINARY [ARG...]
  run-forgejo.sh start [FORGEJO_BINARY] [ARG...]
  run-forgejo.sh stop [FORGEJO_BINARY]
  run-forgejo.sh restart [FORGEJO_BINARY] [ARG...]
  run-forgejo.sh status [FORGEJO_BINARY] [PID]

The binary may be omitted for lifecycle commands when FORGEJO_IOS_BINARY,
FORGEJO_IOS_SERVICE_DIR, or a prior forgejo.binary state file is configured.
USAGE
	exit 2
}

script_path="$(cd -- "$(dirname -- "$0")" && pwd)/$(basename -- "$0")"
mode='run'
binary_path=''
pid_override="${FORGEJO_IOS_PID:-}"
configured_binary="${FORGEJO_IOS_BINARY:-}"

if [[ "$#" -lt 1 ]]; then
	usage
fi

case "$1" in
	start|stop|restart|status|run)
		mode="$1"
		shift
		;;
esac

case "$mode" in
	run)
		[[ "$#" -ge 1 ]] || usage
		binary_path="$1"
		shift
		;;
	start|restart)
		if [[ "$#" -gt 0 && "$1" != --* && ( -z "$configured_binary" || "$1" == "$configured_binary" ) ]]; then
			binary_path="$1"
			shift
		fi
		;;
	stop)
		[[ "$#" -le 1 ]] || usage
		if [[ "$#" -eq 1 ]]; then
			binary_path="$1"
		fi
		shift || true
		;;
	status)
		[[ "$#" -le 2 ]] || usage
		if [[ "$#" -ge 1 ]]; then
			binary_path="$1"
			shift
		fi
		if [[ "$#" -eq 1 ]]; then
			pid_override="$1"
			shift
		fi
		;;
esac

if [[ -z "$binary_path" ]]; then
	binary_path="${FORGEJO_IOS_BINARY:-}"
fi

machine="${FORGEJO_IOS_DEVICE_MODEL:-}"
if [[ -z "$machine" ]] && command -v sysctl >/dev/null 2>&1; then
	machine="$(sysctl -n hw.machine 2>/dev/null || true)"
fi

darwin_release="${FORGEJO_IOS_DARWIN_RELEASE:-}"
if [[ -z "$darwin_release" ]]; then
	darwin_release="$(uname -r 2>/dev/null || true)"
fi

requested_gomaxprocs="${GOMAXPROCS:-}"
effective_gomaxprocs="$requested_gomaxprocs"
policy='preserve-explicit'
if [[ -z "$requested_gomaxprocs" ]]; then
	case "$machine:$darwin_release" in
		iPad4,4:18.*|iPad4,5:18.*|iPad4,6:18.*)
			effective_gomaxprocs=1
			policy='a7-ios12-default'
			;;
		*)
			effective_gomaxprocs='unset'
			policy='no-default-for-unvalidated-target'
			;;
	esac
fi

if [[ -n "$binary_path" && "$binary_path" == */* ]]; then
	binary_path="$(cd -- "$(dirname -- "$binary_path")" && pwd)/$(basename -- "$binary_path")"
elif [[ -n "$binary_path" ]]; then
	binary_path="$(command -v -- "$binary_path" 2>/dev/null || true)"
fi

service_dir="${FORGEJO_IOS_SERVICE_DIR:-}"
if [[ -z "$service_dir" && -n "$binary_path" ]]; then
	service_dir="$(dirname -- "$binary_path")"
fi
if [[ -z "$service_dir" && -n "${FORGEJO_IOS_PID_FILE:-}" ]]; then
	service_dir="$(dirname -- "$FORGEJO_IOS_PID_FILE")"
fi

if [[ -z "$service_dir" && "$mode" != run ]]; then
	printf '%s\n' 'Forgejo iOS lifecycle: set FORGEJO_IOS_SERVICE_DIR or FORGEJO_IOS_BINARY when the binary is omitted' >&2
	exit 2
fi

if [[ -z "$service_dir" ]]; then
	service_dir='.'
fi

pid_file="${FORGEJO_IOS_PID_FILE:-$service_dir/forgejo.pid}"
log_dir="${FORGEJO_IOS_LOG_DIR:-$service_dir/logs}"
launcher_log="$log_dir/launcher.log"
runtime_log="$log_dir/runtime.log"
forgejo_log="$log_dir/forgejo.log"
binary_state_file="$service_dir/forgejo.binary"
args_state_file="$service_dir/forgejo.args"
lock_dir="$pid_file.lock"
lock_owned=0

timestamp() {
	date -u '+%Y-%m-%dT%H:%M:%SZ' 2>/dev/null || date
}

log_launcher() {
	local message="$1"
	if [[ -n "${launcher_log:-}" && -d "${log_dir:-}" ]]; then
		printf '%s %s\n' "$(timestamp)" "$message" >>"$launcher_log"
	fi
}

log_runtime() {
	local event="$1"
	local pid="$2"
	local runtime="$3"
	local version="$4"
	if [[ -d "${log_dir:-}" ]]; then
		printf '%s event=%s pid=%s runtime=%s forgejo=%s binary=%s\n' \
			"$(timestamp)" "$event" "$pid" "$runtime" "$version" "$binary_path" >>"$runtime_log"
	fi
}

fail() {
	local message="$1"
	log_launcher "level=error $message"
	printf 'Forgejo iOS lifecycle: %s\n' "$message" >&2
	exit 1
}

metadata_value() {
	local key="$1"
	local build_info="${FORGEJO_IOS_BUILD_INFO:-}"
	if [[ -z "$build_info" && -n "$binary_path" ]]; then
		local binary_dir
		binary_dir="$(dirname -- "$binary_path")"
		for candidate in \
			"$binary_dir/forgejo-ios-build-info.txt" \
			"$binary_dir/forgejo-ios-a7-build-info.txt" \
			"${binary_path}-build-info.txt" \
			"build/ios/go1.26.7-a7/provenance.env"; do
			if [[ -r "$candidate" ]]; then
				build_info="$candidate"
				break
			fi
		done
	fi
	if [[ -n "$build_info" && -r "$build_info" ]]; then
		awk -F= -v key="$key" '$1 == key { sub(/^[^=]*=/, ""); print; exit }' "$build_info"
	fi
}

runtime_version() {
	local value="${FORGEJO_IOS_RUNTIME_VERSION:-}"
	if [[ -z "$value" ]]; then value="$(metadata_value P7_RUNTIME)"; fi
	if [[ -z "$value" ]]; then value="$(metadata_value GO_RUNTIME)"; fi
	[[ -n "$value" ]] || value='unknown'
	printf '%s\n' "$value"
}

forgejo_version() {
	local value="${FORGEJO_IOS_VERSION:-}"
	if [[ -z "$value" ]]; then value="$(metadata_value FORGEJO_VERSION)"; fi
	[[ -n "$value" ]] || value='unknown'
	printf '%s\n' "$value"
}

build_tags() {
	local value
	value="$(metadata_value BUILD_TAGS)"
	printf '%s\n' "$value"
}

normalize_pid_file() {
	local value
	value="$(sed -n '1p' "$pid_file" 2>/dev/null || true)"
	if [[ ! "$value" =~ ^[0-9]+$ || "$value" -le 1 ]]; then
		return 2
	fi
	pid_value="$value"
	return 0
}

process_line() {
	local pid="$1"
	ps -p "$pid" -o pid=,rss=,pcpu=,etime=,state= 2>/dev/null | sed -n '1p'
}

process_args() {
	local pid="$1"
	local value
	value="$(ps -p "$pid" -o args= 2>/dev/null || true)"
	if [[ -z "$value" ]]; then
		value="$(ps -p "$pid" -o command= 2>/dev/null || true)"
	fi
	printf '%s\n' "$value"
}

process_alive() {
	local pid="$1"
	local line
	local process_state
	[[ "$pid" =~ ^[0-9]+$ && "$pid" -gt 1 ]] || return 1
	kill -0 "$pid" 2>/dev/null || return 1
	line="$(process_line "$pid")"
	[[ -n "$line" ]] || return 1
	read -r _process_pid _process_rss _process_cpu _process_elapsed process_state <<<"$line"
	[[ "$process_state" != Z* ]]
}

process_matches_binary() {
	local pid="$1"
	local args
	local binary_name
	args="$(process_args "$pid")"
	binary_name="$(basename -- "$binary_path")"
	[[ -n "$args" ]] || return 1
	if [[ "$binary_path" == */* ]]; then
		[[ "$args" == *"$binary_path"* ]]
	else
		[[ " $args " == *"/$binary_name "* || " $args " == *" $binary_name "* ]]
	fi
}

find_existing_pid() {
	local line
	local candidate
	local args
	local binary_name
	binary_name="$(basename -- "$binary_path")"
	while IFS= read -r line; do
		line="${line#"${line%%[![:space:]]*}"}"
		candidate="${line%% *}"
		[[ "$candidate" =~ ^[0-9]+$ ]] || continue
		[[ "$candidate" != "$$" && "$candidate" != "${PPID:-}" ]] || continue
		args="${line#* }"
		[[ "$args" == *run-forgejo.sh* ]] && continue
		if [[ "$binary_path" == */* && "$args" == *"$binary_path"* ]] || \
			[[ "$binary_path" != */* && ( " $args " == *"/$binary_name "* || " $args " == *" $binary_name "* ) ]]; then
			printf '%s\n' "$candidate"
			return 0
		fi
	done < <(ps -axo pid=,args= 2>/dev/null || true)
	return 1
}

atomic_write() {
	local path="$1"
	local contents="$2"
	local parent
	local tmp
	parent="$(dirname -- "$path")"
	tmp="$(mktemp "$parent/.$(basename -- "$path").tmp.XXXXXX")" || fail "cannot create temporary state file for $path"
	if ! printf '%s\n' "$contents" >"$tmp"; then
		rm -f -- "$tmp"
		fail "cannot write temporary state file for $path"
	fi
	chmod 600 "$tmp"
	if ! mv -f -- "$tmp" "$path"; then
		rm -f -- "$tmp"
		fail "cannot install state file $path"
	fi
}

load_state_binary() {
	if [[ -z "$binary_path" && -r "$binary_state_file" ]]; then
		binary_path="$(sed -n '1p' "$binary_state_file")"
	fi
}

load_saved_args() {
	local value
	if [[ ! -r "$args_state_file" ]]; then
		return 0
	fi
	while IFS= read -r value || [[ -n "$value" ]]; do
		forgejo_args+=("$value")
	done <"$args_state_file"
}

acquire_lock() {
	local attempt=1
	local owner
	while [[ "$attempt" -le 5 ]]; do
		if mkdir -- "$lock_dir" 2>/dev/null; then
			printf '%s\n' "$$" >"$lock_dir/owner"
			lock_owned=1
			return 0
		fi
		owner="$(sed -n '1p' "$lock_dir/owner" 2>/dev/null || true)"
		if [[ "$owner" =~ ^[0-9]+$ ]] && kill -0 "$owner" 2>/dev/null; then
			fail "another lifecycle operation is in progress PID $owner"
		fi
		rm -f -- "$lock_dir/owner"
		rmdir -- "$lock_dir" 2>/dev/null || true
		sleep 0.1
		attempt=$((attempt + 1))
	done
	fail "cannot acquire lifecycle lock $lock_dir"
}

release_lock() {
	if [[ "$lock_owned" -eq 1 ]]; then
		rm -f -- "$lock_dir/owner"
		rmdir -- "$lock_dir" 2>/dev/null || true
		lock_owned=0
	fi
}

prepare_service_dirs() {
	if ! mkdir -p -- "$service_dir" "$log_dir"; then
		fail "cannot create service directory $service_dir or log directory $log_dir"
	fi
	chmod 700 "$service_dir" "$log_dir" 2>/dev/null || true
	: >>"$launcher_log" || fail "cannot write launcher log $launcher_log"
	: >>"$runtime_log" || fail "cannot write runtime log $runtime_log"
	: >>"$forgejo_log" || fail "cannot write Forgejo log $forgejo_log"
	chmod 600 "$launcher_log" "$runtime_log" "$forgejo_log" 2>/dev/null || true
}

start_service() {
	local existing_pid
	local pid
	local ready=0
	local i
	local runtime
	local version
	local args_contents=''
	forgejo_args=("$@")
	if [[ "$#" -eq 0 ]]; then
		load_saved_args
	fi
	prepare_service_dirs
	acquire_lock
	trap release_lock EXIT

	if [[ -e "$pid_file" ]]; then
		if ! normalize_pid_file; then
			fail "invalid PID file $pid_file; refusing to remove it"
		fi
		if process_alive "$pid_value"; then
			if process_matches_binary "$pid_value"; then
				log_launcher "level=info event=duplicate pid=$pid_value"
				printf 'Forgejo already running PID %s\n' "$pid_value" >&2
				exit 1
			fi
			fail "PID file $pid_file belongs to another process PID $pid_value; refusing to signal it"
		fi
		log_launcher "level=info event=remove-stale-pid pid=$pid_value"
		rm -f -- "$pid_file"
	fi

	if existing_pid="$(find_existing_pid)"; then
		log_launcher "level=info event=duplicate pid=$existing_pid source=process-scan"
		printf 'Forgejo already running PID %s\n' "$existing_pid" >&2
		exit 1
	fi

	atomic_write "$binary_state_file" "$binary_path"
	if [[ "${#forgejo_args[@]}" -gt 0 ]]; then
		for arg in "${forgejo_args[@]}"; do
			args_contents+="$arg"$'\n'
		done
		atomic_write "$args_state_file" "${args_contents%$'\n'}"
	fi

	log_launcher "level=info event=start binary=$binary_path"
	if command -v nohup >/dev/null 2>&1; then
		FORGEJO_IOS_LAUNCHER_LOG="$launcher_log" \
			FORGEJO_IOS_RUNTIME_LOG="$runtime_log" \
			nohup "$script_path" run "$binary_path" "${forgejo_args[@]}" \
				>>"$forgejo_log" 2>&1 < /dev/null &
	else
		FORGEJO_IOS_LAUNCHER_LOG="$launcher_log" \
			FORGEJO_IOS_RUNTIME_LOG="$runtime_log" \
			"$script_path" run "$binary_path" "${forgejo_args[@]}" \
				>>"$forgejo_log" 2>&1 < /dev/null &
	fi
	pid=$!
	i=1
	while [[ "$i" -le 50 ]]; do
		if kill -0 "$pid" 2>/dev/null; then
			ready=1
			break
		fi
		sleep 0.1
		i=$((i + 1))
	done
	if [[ "$ready" -ne 1 ]]; then
		log_launcher "level=error event=start-failed pid=$pid"
		fail "Forgejo exited before PID $pid could be recorded; inspect $forgejo_log"
	fi

	atomic_write "$pid_file" "$pid"
	runtime="$(runtime_version)"
	version="$(forgejo_version)"
	log_runtime 'start' "$pid" "$runtime" "$version"
	log_launcher "level=info event=started pid=$pid runtime=$runtime"
	printf 'Forgejo started PID %s\n' "$pid"
	release_lock
	trap - EXIT
}

stop_service() {
	local pid
	local timeout_value
	local i
	local runtime
	local version
	if [[ ! -e "$pid_file" ]]; then
		printf '%s\n' 'Forgejo not running (no PID file)'
		return 0
	fi
	if ! normalize_pid_file; then
		fail "invalid PID file $pid_file; refusing to remove it"
	fi
	pid="$pid_value"
	prepare_service_dirs
	acquire_lock
	trap release_lock EXIT
	if ! process_alive "$pid"; then
		log_launcher "level=info event=remove-stale-pid pid=$pid"
		rm -f -- "$pid_file"
		log_runtime 'stale-pid-removed' "$pid" "$(runtime_version)" "$(forgejo_version)"
		printf 'Forgejo stopped (removed stale PID %s)\n' "$pid"
		release_lock
		trap - EXIT
		return 0
	fi
	if ! process_matches_binary "$pid"; then
		fail "PID file $pid_file belongs to another process PID $pid; refusing to signal it"
	fi

	runtime="$(runtime_version)"
	version="$(forgejo_version)"
	log_launcher "level=info event=stop-signal pid=$pid"
	log_runtime 'stop-signal' "$pid" "$runtime" "$version"
	if ! kill -TERM "$pid" 2>/dev/null; then
		fail "SIGTERM could not be delivered to Forgejo PID $pid"
	fi
	timeout_value="${FORGEJO_IOS_STOP_TIMEOUT:-30}"
	if [[ ! "$timeout_value" =~ ^[0-9]+$ || "$timeout_value" -lt 1 ]]; then
		fail "FORGEJO_IOS_STOP_TIMEOUT must be a positive integer"
	fi
	i=1
	while [[ "$i" -le "$timeout_value" ]]; do
		if ! process_alive "$pid"; then
			break
		fi
		sleep 1
		i=$((i + 1))
	done
	if process_alive "$pid"; then
		log_launcher "level=error event=stop-timeout pid=$pid timeout=$timeout_value"
		fail "Forgejo PID $pid did not exit after SIGTERM within ${timeout_value}s; PID file retained"
	fi
	rm -f -- "$pid_file"
	log_runtime 'stop' "$pid" "$runtime" "$version"
	log_launcher "level=info event=stopped pid=$pid"
	printf 'Forgejo stopped PID %s\n' "$pid"
	release_lock
	trap - EXIT
}

status_service() {
	local build_info="${FORGEJO_IOS_BUILD_INFO:-}"
	local runtime
	local patch_sha
	local git_commit
	local version
	local tags
	local version_output=''
	local sqlite='unknown'
	local git_path
	local git_version
	local pid=''
	local state='not-requested'
	local rss='n/a'
	local cpu='n/a'
	local elapsed='n/a'
	local process_state='n/a'
	local threads='n/a'
	local file_descriptors='n/a'
	local pid_file_state='absent'
	local ps_line=''

	runtime="$(runtime_version)"
	patch_sha="$(metadata_value PATCH_SHA256)"
	if [[ -z "$patch_sha" ]]; then patch_sha="$(metadata_value RUNTIME_PATCH_SHA256)"; fi
	git_commit="$(metadata_value 'Git commit')"
	if [[ -z "$git_commit" ]]; then git_commit="$(metadata_value GIT_COMMIT)"; fi
	version="$(forgejo_version)"
	tags="$(build_tags)"
	if [[ -z "$runtime" ]]; then runtime='unknown'; fi
	if [[ -z "$patch_sha" ]]; then patch_sha='unknown'; fi
	if [[ -z "$git_commit" ]]; then git_commit='unknown'; fi
	if [[ -z "$version" ]]; then version='unknown'; fi

	if [[ -n "$binary_path" && -x "$binary_path" && -z "$tags" && -z "${FORGEJO_IOS_SKIP_BINARY_PROBE:-}" ]]; then
		version_output="$($binary_path --version 2>&1 || true)"
	fi
	if [[ "$version" == 'unknown' ]]; then
		version="$(printf '%s\n' "$version_output" | awk '/forgejo version/ { print; exit }')"
		[[ -n "$version" ]] || version='unknown'
	fi
	if [[ "$tags" == *sqlite* || "$version_output" == *sqlite* ]]; then
		sqlite='enabled'
	fi

	git_path="$(command -v git 2>/dev/null || true)"
	if [[ -n "$git_path" ]]; then
		git_version="$($git_path --version 2>&1 || true)"
	else
		git_version='unavailable'
	fi

	if [[ -n "$pid_override" ]]; then
		pid="$pid_override"
	elif [[ -r "$pid_file" ]]; then
		pid_file_state='present'
		if normalize_pid_file; then
			pid="$pid_value"
		else
			pid_file_state='invalid'
		fi
	fi
	if [[ -n "$pid" && "$pid" =~ ^[0-9]+$ ]]; then
		if process_alive "$pid"; then
			ps_line="$(process_line "$pid")"
			read -r _ps_pid rss cpu elapsed process_state <<<"$ps_line"
			state="running pid=$pid state=$process_state elapsed=$elapsed"
			threads="$(ps -M "$pid" 2>/dev/null | tail -n +2 | wc -l | tr -d ' ')"
			if command -v lsof >/dev/null 2>&1; then
				file_descriptors="$(lsof -p "$pid" 2>/dev/null | tail -n +2 | wc -l | tr -d ' ')"
			else
				file_descriptors='unavailable (lsof not installed)'
			fi
		else
			state="not-running pid=$pid"
		fi
	elif [[ "$pid_file_state" == 'invalid' ]]; then
		state="invalid-pid-file file=$pid_file"
	elif [[ "$pid_file_state" == 'present' ]]; then
		state='not-running (invalid PID)'
	fi

	printf '%s\n' 'Forgejo iOS status'
	printf 'Service directory: %s\n' "$service_dir"
	printf 'PID file: %s (%s)\n' "$pid_file" "$pid_file_state"
	printf 'Log directory: %s\n' "$log_dir"
	printf 'Runtime: %s\n' "$runtime"
	printf 'Device: %s\n' "${machine:-unknown}"
	printf 'Darwin: %s\n' "${darwin_release:-unknown}"
	printf 'Scheduler: GOMAXPROCS=%s\n' "$effective_gomaxprocs"
	printf 'Policy: %s\n' "$policy"
	printf 'Forgejo: %s\n' "$version"
	printf 'SQLite: %s\n' "$sqlite"
	printf 'Git: %s (%s)\n' "${git_path:-unavailable}" "$git_version"
	printf 'Build commit: %s\n' "$git_commit"
	printf 'Runtime patch SHA256: %s\n' "$patch_sha"
	printf 'Provenance: %s\n' "${build_info:-unavailable}"
	printf 'Process: %s\n' "$state"
	printf 'RSS_KB: %s\n' "$rss"
	printf 'CPU_PERCENT: %s\n' "$cpu"
	printf 'Threads: %s\n' "$threads"
	printf 'FDs: %s\n' "$file_descriptors"
}

if [[ "$mode" == 'run' ]]; then
	if [[ ! -x "$binary_path" ]]; then
		printf 'Forgejo iOS launcher: binary is not executable: %s\n' "$binary_path" >&2
		exit 2
	fi
	if [[ -z "$requested_gomaxprocs" && "$policy" == 'a7-ios12-default' ]]; then
		export GOMAXPROCS="$effective_gomaxprocs"
	fi
	launcher_message="machine=${machine:-unknown} darwin=${darwin_release:-unknown} policy=$policy GOMAXPROCS=${GOMAXPROCS:-unset}"
	if [[ -n "${FORGEJO_IOS_LAUNCHER_LOG:-}" ]]; then
		printf '%s level=info event=exec %s\n' "$(timestamp)" "$launcher_message" >>"$FORGEJO_IOS_LAUNCHER_LOG"
	fi
	printf 'Forgejo iOS launcher: %s\n' "$launcher_message" >&2
	exec "$binary_path" "$@"
fi

load_state_binary
if [[ "$mode" == 'start' || "$mode" == 'restart' ]]; then
	[[ -n "$binary_path" && -x "$binary_path" ]] || fail "binary is not executable: ${binary_path:-unset}"
elif [[ "$mode" == 'status' && -n "$binary_path" && ! -x "$binary_path" ]]; then
	printf 'Forgejo iOS launcher: binary is not executable: %s\n' "$binary_path" >&2
	exit 2
fi

case "$mode" in
	start)
	start_service "$@"
	;;
	stop)
	stop_service
	;;
	restart)
	stop_service
	start_service "$@"
	;;
	status)
	status_service
	;;
	*)
		usage
		;;
esac
