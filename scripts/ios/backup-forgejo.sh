#!/usr/bin/env bash

set -euo pipefail
IFS=$'\n\t'
umask 077

usage() {
	cat >&2 <<'USAGE'
usage:
  backup-forgejo.sh backup --source-root RUNTIME_ROOT --output BACKUP_DIR [options]
  backup-forgejo.sh verify BACKUP_DIR
  backup-forgejo.sh restore BACKUP_DIR --destination RUNTIME_ROOT

backup options:
  --binary PATH       read Forgejo version/runtime provenance beside PATH
  --pid-file PATH     service PID file (default: RUNTIME_ROOT/forgejo.pid)
  --allow-running     use SQLite online backup when the service PID is live;
                      full crash-consistent backup still requires a stop

The backup command never overwrites an existing backup or runtime. It writes
an atomic backup set containing metadata.txt, manifest.sha256, and payload.tar.
USAGE
	exit 2
}

fail() {
	printf 'Forgejo backup: %s\n' "$1" >&2
	exit 1
}

command_required() {
	command -v "$1" >/dev/null 2>&1 || fail "required command is unavailable: $1"
}

timestamp() {
	date -u '+%Y-%m-%dT%H:%M:%SZ' 2>/dev/null || date
}

absolute_path() {
	case "$1" in
		/*) printf '%s\n' "$1" ;;
		*) printf '%s/%s\n' "$(pwd)" "$1" ;;
	esac
}

file_mode() {
	local path="$1"
	local mode
	mode="$(stat -c '%a' "$path" 2>/dev/null || true)"
	if [[ -z "$mode" ]]; then
		mode="$(stat -f '%Lp' "$path" 2>/dev/null || true)"
	fi
	printf '%s\n' "${mode:-unknown}"
}

sha256_stdin() {
	if command -v sha256sum >/dev/null 2>&1; then
		sha256sum | awk '{print $1}'
		return 0
	fi
	if command -v shasum >/dev/null 2>&1; then
		shasum -a 256 | awk '{print $1}'
		return 0
	fi
	fail 'neither sha256sum nor shasum is available'
}

sha256_file() {
	local path="$1"
	if command -v sha256sum >/dev/null 2>&1; then
		sha256sum "$path" | awk '{print $1}'
		return 0
	fi
	if command -v shasum >/dev/null 2>&1; then
		shasum -a 256 "$path" | awk '{print $1}'
		return 0
	fi
	fail 'neither sha256sum nor shasum is available'
}

metadata_value() {
	local file="$1"
	local key="$2"
	awk -F= -v key="$key" '$1 == key { sub(/^[^=]*=/, ""); print; exit }' "$file"
}

build_info_path() {
	local binary_path="$1"
	local candidate
	local binary_dir

	if [[ -n "${FORGEJO_IOS_BUILD_INFO:-}" && -r "$FORGEJO_IOS_BUILD_INFO" ]]; then
		printf '%s\n' "$FORGEJO_IOS_BUILD_INFO"
		return 0
	fi
	if [[ -z "$binary_path" ]]; then
		return 0
	fi
	binary_dir="$(cd -- "$(dirname -- "$binary_path")" && pwd)"
	for candidate in \
		"$binary_dir/forgejo-ios-a7-build-info.txt" \
		"$binary_dir/forgejo-ios-build-info.txt" \
		"${binary_path}-build-info.txt" \
		"build/ios/go1.26.7-a7/provenance.env"; do
		if [[ -r "$candidate" ]]; then
			printf '%s\n' "$candidate"
			return 0
		fi
	done
	return 0
}

provenance_value() {
	local binary_path="$1"
	local key="$2"
	local info_path
	info_path="$(build_info_path "$binary_path")"
	if [[ -n "$info_path" ]]; then
		metadata_value "$info_path" "$key"
	fi
}

is_live_pid() {
	local pid_file="$1"
	local pid
	[[ -r "$pid_file" ]] || return 1
	pid="$(sed -n '1p' "$pid_file" 2>/dev/null || true)"
	[[ "$pid" =~ ^[0-9]+$ && "$pid" -gt 1 ]] || return 1
	kill -0 "$pid" 2>/dev/null || return 1
	if command -v ps >/dev/null 2>&1; then
		[[ -n "$(ps -p "$pid" -o pid= 2>/dev/null | tr -d '[:space:]')" ]] || return 1
	fi
	printf '%s\n' "$pid"
}

sqlite_integrity() {
	local database="$1"
	local result
	result="$(sqlite3 "$database" 'PRAGMA integrity_check;' 2>/dev/null)" || \
		fail "SQLite integrity_check could not open $database"
	result="$(printf '%s' "$result" | tr -d '[:space:]')"
	[[ "$result" == 'ok' ]] || fail 'SQLite PRAGMA integrity_check did not return ok'
}

sqlite_online_backup() {
	local source_database="$1"
	local destination_database="$2"
	local escaped_destination

	escaped_destination="${destination_database//\'/\'\'}"
	sqlite3 "$source_database" ".backup '$escaped_destination'" >/dev/null 2>&1 || \
		fail 'SQLite online backup failed'
}

repo_inventory() {
	local repositories_root="$1"
	local inventory_path="$2"
	local repository
	local relative
	local head_ref
	local refs
	local history
	local refs_digest
	local history_digest
	local commit_count
	local repository_count=0

	: >"$inventory_path"
	while IFS= read -r repository; do
		[[ -n "$repository" ]] || continue
		relative="${repository#"$repositories_root/"}"
		git -C "$repository" fsck --full >/dev/null 2>&1 || \
			fail "git fsck --full failed for repository $relative"
		head_ref="$(git -C "$repository" symbolic-ref -q HEAD 2>/dev/null || cat "$repository/HEAD" 2>/dev/null || true)"
		refs="$(git -C "$repository" show-ref 2>/dev/null || true)"
		history="$(git -C "$repository" rev-list --all --objects 2>/dev/null || true)"
		refs_digest="$(printf 'HEAD=%s\nREFS\n%s\n' "$head_ref" "$refs" | sha256_stdin)"
		history_digest="$(printf '%s\n' "$history" | sha256_stdin)"
		commit_count="$(git -C "$repository" rev-list --all --count 2>/dev/null || printf '0')"
		printf '%s\t%s\t%s\t%s\n' \
			"$relative" "$refs_digest" "$history_digest" "$commit_count" >>"$inventory_path"
		repository_count=$((repository_count + 1))
	done < <(find "$repositories_root" -type d -name '*.git' -print | LC_ALL=C sort)

	printf '%s\n' "$repository_count"
}

validate_tar_entries() {
	local archive="$1"
	local entry
	local listing="$2"

	tar -tf "$archive" >"$listing" 2>/dev/null || fail 'cannot list backup payload'
	while IFS= read -r entry; do
		[[ -n "$entry" ]] || continue
		case "$entry" in
			/*|../*|*/../*|*/..) fail 'backup payload contains a traversal path' ;;
			custom/conf|custom/conf/*|data|data/*|repositories|repositories/*) ;;
			*) fail "backup payload contains an unexpected path: $entry" ;;
		esac
	done <"$listing"
}

verify_manifest() {
	local payload_root="$1"
	local manifest="$2"
	local line
	local expected
	local relative
	local actual

	while IFS= read -r line || [[ -n "$line" ]]; do
		[[ -n "$line" ]] || continue
		expected="${line%%  *}"
		relative="${line#*  }"
		[[ "$expected" =~ ^[0-9a-fA-F]{64}$ && "$relative" != "$line" ]] || \
			fail 'backup manifest has an invalid entry'
		case "$relative" in
			/*|../*|*/../*|*/..) fail 'backup manifest contains a traversal path' ;;
		esac
		[[ -f "$payload_root/$relative" ]] || fail "backup manifest file is missing: $relative"
		actual="$(sha256_file "$payload_root/$relative")"
		[[ "$actual" == "$expected" ]] || fail "backup manifest checksum mismatch: $relative"
	done <"$manifest"
}

verify_backup() {
	local backup_dir="$1"
	local payload="$backup_dir/payload.tar"
	local metadata="$backup_dir/metadata.txt"
	local manifest="$backup_dir/manifest.sha256"
	local expected_checksum
	local actual_checksum
	local verify_root
	local listing
	local expected_count
	local actual_count
	local inventory

	[[ -d "$backup_dir" ]] || fail "backup directory does not exist: $backup_dir"
	[[ -f "$payload" && -f "$metadata" && -f "$manifest" ]] || \
		fail 'backup set is incomplete; expected payload.tar, metadata.txt, and manifest.sha256'
	chmod 700 "$backup_dir" 2>/dev/null || true
	[[ "$(file_mode "$payload")" == '600' ]] || fail 'payload.tar must be mode 600'
	[[ "$(file_mode "$metadata")" == '600' ]] || fail 'metadata.txt must be mode 600'
	[[ "$(file_mode "$manifest")" == '600' ]] || fail 'manifest.sha256 must be mode 600'
	expected_checksum="$(metadata_value "$metadata" BACKUP_CHECKSUM_SHA256)"
	[[ "$expected_checksum" =~ ^[0-9a-fA-F]{64}$ ]] || fail 'backup metadata has no valid checksum'
	actual_checksum="$(sha256_file "$payload")"
	[[ "$actual_checksum" == "$expected_checksum" ]] || fail 'backup payload checksum mismatch'

	verify_root="$(mktemp -d "${TMPDIR:-/tmp}/forgejo-backup-verify.XXXXXX")"
	listing="$verify_root/tar.list"
	trap 'rm -rf "$verify_root"' RETURN
	validate_tar_entries "$payload" "$listing"
	tar -xf "$payload" -C "$verify_root" || fail 'cannot extract backup payload for verification'
	verify_manifest "$verify_root" "$manifest"
	[[ -d "$verify_root/custom/conf" && -d "$verify_root/data" && -d "$verify_root/repositories" ]] || \
		fail 'backup payload is missing a mandatory runtime directory'
	command_required sqlite3
	sqlite_integrity "$verify_root/data/forgejo.db"
	inventory="$verify_root/repository-inventory.tsv"
	actual_count="$(repo_inventory "$verify_root/repositories" "$inventory")"
	expected_count="$(metadata_value "$metadata" REPOSITORY_COUNT)"
	[[ "$actual_count" == "$expected_count" ]] || fail 'backup repository count does not match metadata'
	rm -rf "$verify_root"
	trap - RETURN
	printf 'Forgejo backup verified\n'
	printf '  backup=%s\n' "$backup_dir"
	printf '  checksum=%s\n' "$actual_checksum"
	printf '  repositories=%s\n' "$actual_count"
	printf '  database=ok\n'
}

backup_command() {
	local source_root=''
	local output_dir=''
	local binary_path=''
	local pid_file=''
	local allow_running=0
	local option
	local source_database
	local live_pid=''
	local database_mode='stopped-files'
	local backup_id
	local output_parent
	local output_base
	local work_dir=''
	local payload_root
	local pre_inventory
	local post_inventory
	local repository_count
	local payload_checksum
	local timestamp_value
	local source_db_mode
	local source_db_wal='absent'
	local source_db_shm='absent'
	local payload_db_files='data/forgejo.db'
	local attachments_state='absent'
	local generated_state='absent'
	local generated_dir
	local generated_list=''
	local metadata_path
	local manifest_path
	local files_list
	local backup_status=0
	local file_path
	local relative
	local sidecar_list='data/forgejo.db'
	local info_path
	local forgejo_version
	local git_commit
	local runtime_version
	local stale

	while [[ "$#" -gt 0 ]]; do
		option="$1"
		shift
		case "$option" in
			--source-root|--source)
				[[ "$#" -gt 0 ]] || usage
				source_root="$1"
				shift
				;;
			--output)
				[[ "$#" -gt 0 ]] || usage
				output_dir="$1"
				shift
				;;
			--binary)
				[[ "$#" -gt 0 ]] || usage
				binary_path="$1"
				shift
				;;
			--pid-file)
				[[ "$#" -gt 0 ]] || usage
				pid_file="$1"
				shift
				;;
			--allow-running)
				allow_running=1
				;;
			*)
				usage
				;;
		esac
	done

	[[ -n "$source_root" && -n "$output_dir" ]] || usage
	command_required tar
	command_required find
	command_required git
	command_required sqlite3
	[[ -d "$source_root" ]] || fail "source runtime does not exist: $source_root"
	source_root="$(cd -- "$source_root" && pwd)"
	output_dir="$(absolute_path "$output_dir")"
	output_parent="$(dirname -- "$output_dir")"
	output_base="$(basename -- "$output_dir")"
	[[ "$output_base" != '.' && "$output_base" != '/' && -n "$output_base" ]] || fail 'backup output has an invalid basename'
	if [[ "$output_dir/" == "$source_root/"* || "$output_dir" == "$source_root" ]]; then
		fail 'backup output must be outside the source runtime'
	fi
	if [[ -e "$output_dir" || -L "$output_dir" ]]; then
		fail "refusing to overwrite existing backup: $output_dir"
	fi
	mkdir -p "$output_parent"

	for stale in "$output_parent/.${output_base}.partial."*; do
		if [[ -e "$stale" || -L "$stale" ]]; then
			fail "stale temporary backup exists; remove it manually after inspection: $stale"
		fi
	done

	[[ -d "$source_root/custom/conf" ]] || fail 'mandatory directory is missing: custom/conf'
	[[ -f "$source_root/custom/conf/app.ini" ]] || fail 'mandatory configuration is missing: custom/conf/app.ini'
	[[ -d "$source_root/data" ]] || fail 'mandatory directory is missing: data'
	[[ -d "$source_root/repositories" ]] || fail 'mandatory directory is missing: repositories'
	source_database="$source_root/data/forgejo.db"
	[[ -f "$source_database" ]] || fail 'mandatory database is missing: data/forgejo.db'

	if [[ -z "$pid_file" ]]; then
		pid_file="${FORGEJO_IOS_PID_FILE:-$source_root/forgejo.pid}"
	fi
	pid_file="$(absolute_path "$pid_file")"
	if live_pid="$(is_live_pid "$pid_file")"; then
		if [[ "$allow_running" -ne 1 ]]; then
			fail "Forgejo appears to be running (PID $live_pid); stop it before backup or use --allow-running"
		fi
		database_mode='sqlite-online-backup'
	fi

	sqlite_integrity "$source_database"
	if [[ -e "$source_database-wal" ]]; then
		source_db_wal='present'
		sidecar_list="$sidecar_list,data/forgejo.db-wal"
	fi
	if [[ -e "$source_database-shm" ]]; then
		source_db_shm='present'
		sidecar_list="$sidecar_list,data/forgejo.db-shm"
	fi
	if [[ -d "$source_root/data/attachments" ]]; then
		attachments_state='present'
	fi
	for generated_dir in indexers queues sessions tmp; do
		if [[ -d "$source_root/data/$generated_dir" ]]; then
			generated_state='present'
			generated_list="${generated_list}${generated_list:+,}data/$generated_dir"
		fi
	done

	backup_id="$output_base"
	output_parent="$(cd -- "$output_parent" && pwd)"
	work_dir="$(mktemp -d "$output_parent/.${output_base}.partial.XXXXXX")"
	trap 'backup_status=$?; if [[ -n "${work_dir:-}" && -d "$work_dir" ]]; then rm -rf "$work_dir"; fi; exit "$backup_status"' EXIT
	trap 'exit 130' INT TERM
	payload_root="$work_dir/payload-root"
	mkdir -p "$payload_root"

	pre_inventory="$work_dir/repository-before.tsv"
	post_inventory="$work_dir/repository-after.tsv"
	repository_count="$(repo_inventory "$source_root/repositories" "$pre_inventory")"

	# tar preserves the mode bits, directory structure, and symbolic links without
	# printing file names or file contents to the operator's log.
	tar -cf - -C "$source_root" custom/conf data repositories | tar -xf - -C "$payload_root"
	if [[ "$database_mode" == 'sqlite-online-backup' ]]; then
		sqlite_online_backup "$source_database" "$work_dir/forgejo.db.online"
		mv "$work_dir/forgejo.db.online" "$payload_root/data/forgejo.db"
		rm -f "$payload_root/data/forgejo.db-wal" "$payload_root/data/forgejo.db-shm"
		payload_db_files='data/forgejo.db'
	else
		payload_db_files="$sidecar_list"
	fi
	sqlite_integrity "$payload_root/data/forgejo.db"
	repo_inventory "$payload_root/repositories" "$post_inventory" >/dev/null
	cmp -s "$pre_inventory" "$post_inventory" || \
		fail 'repository refs or commit history changed during backup'

	tar -cf "$work_dir/payload.tar" -C "$payload_root" custom/conf data repositories
	validate_tar_entries "$work_dir/payload.tar" "$work_dir/tar.list"
	payload_checksum="$(sha256_file "$work_dir/payload.tar")"

	metadata_path="$work_dir/metadata.txt"
	manifest_path="$work_dir/manifest.sha256"
	files_list="$work_dir/files.list"
	find "$payload_root/custom/conf" "$payload_root/data" "$payload_root/repositories" \
		-type f -print | LC_ALL=C sort >"$files_list"
	: >"$manifest_path"
	while IFS= read -r file_path; do
		[[ -n "$file_path" ]] || continue
		relative="${file_path#"$payload_root/"}"
		printf '%s  %s\n' "$(sha256_file "$file_path")" "$relative" >>"$manifest_path"
	done <"$files_list"

	info_path="$(build_info_path "$binary_path")"
	forgejo_version="${FORGEJO_IOS_VERSION:-}"
	[[ -n "$forgejo_version" ]] || forgejo_version="$(provenance_value "$binary_path" FORGEJO_VERSION)"
	[[ -n "$forgejo_version" ]] || forgejo_version='unknown'
	git_commit="${FORGEJO_IOS_GIT_COMMIT:-}"
	[[ -n "$git_commit" ]] || git_commit="$(provenance_value "$binary_path" GIT_COMMIT)"
	[[ -n "$git_commit" ]] || git_commit="$(provenance_value "$binary_path" 'Git commit')"
	[[ -n "$git_commit" ]] || git_commit='unknown'
	runtime_version="${FORGEJO_IOS_RUNTIME_VERSION:-}"
	[[ -n "$runtime_version" ]] || runtime_version="$(provenance_value "$binary_path" GO_RUNTIME)"
	[[ -n "$runtime_version" ]] || runtime_version="$(provenance_value "$binary_path" P7_RUNTIME)"
	[[ -n "$runtime_version" ]] || runtime_version='unknown'
	timestamp_value="$(timestamp)"
	source_db_mode="$database_mode"

	{
		printf 'FORMAT_VERSION=1\n'
		printf 'BACKUP_ID=%s\n' "$backup_id"
		printf 'TIMESTAMP_UTC=%s\n' "$timestamp_value"
		printf 'FORGEJO_VERSION=%s\n' "$forgejo_version"
		printf 'GIT_COMMIT=%s\n' "$git_commit"
		printf 'RUNTIME=%s\n' "$runtime_version"
		printf 'SOURCE_LAYOUT=custom/conf,data,repositories\n'
		printf 'DATABASE_RELATIVE=data/forgejo.db\n'
		printf 'DATABASE_MODE=%s\n' "$source_db_mode"
		printf 'DATABASE_INTEGRITY=ok\n'
		printf 'SOURCE_DATABASE_FILES=%s\n' "$sidecar_list"
		printf 'SOURCE_DATABASE_WAL=%s\n' "$source_db_wal"
		printf 'SOURCE_DATABASE_SHM=%s\n' "$source_db_shm"
		printf 'PAYLOAD_DATABASE_FILES=%s\n' "$payload_db_files"
		printf 'ATTACHMENTS_STATE=%s\n' "$attachments_state"
		printf 'GENERATED_DATA_STATE=%s\n' "$generated_state"
		printf 'GENERATED_DATA_PATHS=%s\n' "${generated_list:-none}"
		printf 'REPOSITORY_COUNT=%s\n' "$repository_count"
		printf 'PAYLOAD_FILE=payload.tar\n'
		printf 'BACKUP_CHECKSUM_SHA256=%s\n' "$payload_checksum"
		printf 'BACKUP_CHECKSUM_SCOPE=payload.tar\n'
		printf 'SECRETS_IN_METADATA=none\n'
		if [[ -n "$info_path" ]]; then
			printf 'BUILD_INFO_SOURCE=provided\n'
		else
			printf 'BUILD_INFO_SOURCE=unavailable\n'
		fi
	} >"$metadata_path"

	chmod 600 "$metadata_path" "$manifest_path" "$work_dir/payload.tar"
	chmod 700 "$work_dir"
	rm -rf "$payload_root" "$pre_inventory" "$post_inventory" "$files_list" "$work_dir/tar.list"
	mv "$work_dir" "$output_dir"
	work_dir=''
	trap - EXIT INT TERM
	printf 'Forgejo backup complete\n'
	printf '  backup=%s\n' "$output_dir"
	printf '  database=%s integrity=ok\n' "$source_db_mode"
	printf '  repositories=%s\n' "$repository_count"
	printf '  checksum=%s\n' "$payload_checksum"
}

restore_command() {
	local backup_dir="$1"
	local destination=''
	local option
	local parent
	local base
	local work_dir=''
	local stale
	local restore_status=0
	local payload="$backup_dir/payload.tar"
	local listing

	shift
	while [[ "$#" -gt 0 ]]; do
		option="$1"
		shift
		case "$option" in
			--destination|--destination-root)
				[[ "$#" -gt 0 ]] || usage
				destination="$1"
				shift
				;;
			*)
				usage
				;;
		esac
	done
	[[ -n "$destination" ]] || usage
	backup_dir="$(absolute_path "$backup_dir")"
	destination="$(absolute_path "$destination")"
	verify_backup "$backup_dir" >/dev/null
	[[ ! -e "$destination" && ! -L "$destination" ]] || \
		fail "refusing to overwrite existing runtime: $destination"
	parent="$(dirname -- "$destination")"
	base="$(basename -- "$destination")"
	mkdir -p "$parent"
	for stale in "$parent/.${base}.restore.partial."*; do
		if [[ -e "$stale" || -L "$stale" ]]; then
			fail "stale temporary restore exists; remove it manually after inspection: $stale"
		fi
	done
	work_dir="$(mktemp -d "$parent/.${base}.restore.partial.XXXXXX")"
	trap 'restore_status=$?; if [[ -n "${work_dir:-}" && -d "$work_dir" ]]; then rm -rf "$work_dir"; fi; exit "$restore_status"' EXIT
	trap 'exit 130' INT TERM
	listing="$work_dir/tar.list"
	validate_tar_entries "$payload" "$listing"
	tar -xf "$payload" -C "$work_dir"
	rm -f "$listing"
	chmod 700 "$work_dir"
	mv "$work_dir" "$destination"
	work_dir=''
	trap - EXIT INT TERM
	printf 'Forgejo restore complete\n'
	printf '  runtime=%s\n' "$destination"
	printf '  database=verified\n'
}

[[ "$#" -ge 1 ]] || usage
command="$1"
shift
case "$command" in
	backup)
		backup_command "$@"
		;;
	verify)
		[[ "$#" -eq 1 ]] || usage
		verify_backup "$(absolute_path "$1")"
		;;
	restore)
		[[ "$#" -ge 1 ]] || usage
	restore_command "$@"
		;;
	*)
		usage
		;;
esac
