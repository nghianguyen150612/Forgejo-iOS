#!/bin/sh
# Forgejo iOS lifecycle engine; install.sh is the checksum-pinned curl bootstrap.
set -eu
umask 077
PATH=/usr/local/bin:/usr/bin:/bin:/usr/sbin:/sbin
export PATH

say() { printf '%s\n' "$*"; }
die() { say "ERROR: $*" >&2; exit 1; }
hash() { sha256sum "$1" | awk '{print $1}'; }
field() { awk -F= -v key="$2" '$1 == key {print substr($0,index($0,"=")+1)}' "$1"; }
ask() { printf '%s: ' "$1" >/dev/tty; IFS= read -r answer </dev/tty || die 'A terminal is required; use an explicit command for unattended operation.'; }
safe_path() {
    case "$1" in /*) ;; *) die 'Use an absolute dedicated installation path.';; esac
    case "$1" in *[!a-zA-Z0-9_./-]*|*/../*|*/./*|*/..|*/.|*//*|*/) die 'Unsafe installation path.';; esac
    case "$1" in /|/var|/var/lib|/tmp|/usr|/usr/local|/usr/local/bin|/home|/var/mobile) die 'Refusing a broad installation path.';; esac
    case "${1##*/}" in forgejo-ios|forgejo-ios-*|runtime) ;; *) die 'Use a dedicated root named forgejo-ios, forgejo-ios-<name>, or runtime.';; esac
}
init() {
    self=$(cd "$(dirname "$0")" && pwd)/$(basename "$0")
    case "$self" in */bin/manager.sh) default_root=${self%/bin/manager.sh};; *) default_root=/var/lib/forgejo-ios;; esac
    root=${FORGEJO_IOS_ROOT:-$default_root}
    safe_path "$root"
    bin=$root/bin/forgejo
    config=$root/custom/conf/app.ini
    state=$root/install-state
    pidfile=$root/run/forgejo.pid
    link=/usr/local/bin/forgejo-ios
    release=${FORGEJO_IOS_RELEASE:-v1.0.0-ios}
    case "$release" in ''|*[!a-zA-Z0-9._-]*|.*) die 'Invalid release tag.';; esac
    stage='' lock_owned=0 active=0 previous='' was_running=0
    trap cleanup 0
    trap 'exit 130' INT
    trap 'exit 143' TERM HUP
}
check_paths() {
    # iOS /var itself is a system symlink. Reject symlinks below the chosen root
    # and every installer-owned entry; never traverse user content recursively.
    probe=$root
    while [ "$probe" != / ] && [ "$probe" != /var ]; do
        [ ! -L "$probe" ] || die 'Symlink in installation path.'
        probe=$(dirname "$probe")
    done
    for item in bin custom custom/conf data repositories logs backup run install-state custom/conf/app.ini bin/forgejo bin/manager.sh bin/forgejo-ios run/forgejo.pid logs/service.log; do
        [ ! -L "$root/$item" ] || die 'Symlink at a managed path; manual review required.'
    done
    if [ -d "$root/bin" ]; then
        [ "$(owner "$root/bin")" = "$(id -u)" ] || die 'Installer binaries must belong to the managing user.'
    fi
    if [ -d "$root" ]; then
        [ "$(owner "$root")" = "$(id -u)" ] || die 'Installation root belongs to another manager.'
        case "$(mode "$root")" in 700|711|750|751|755) ;; *) die 'Installation root permissions are unsafe; review manually.';; esac
    fi
    if [ -d "$root/bin" ]; then
        case "$(mode "$root/bin")" in 700|711|750|751|755) ;; *) die 'Binary directory permissions are unsafe; review manually.';; esac
    fi
}
owner() {
    if stat_value=$(stat -c '%u' "$1" 2>/dev/null); then say "$stat_value"; else stat -f '%u' "$1"; fi
}
mode() {
    if stat_value=$(stat -c '%a' "$1" 2>/dev/null); then say "$stat_value"; else stat -f '%Lp' "$1"; fi
}
check_device() {
    [ "$(uname -s)" = Darwin ] || die 'A physical jailbroken iOS device is required.'
    [ "$(sysctl -n hw.cputype)" = 16777228 ] || die 'arm64 is required.'
    [ "$(sysctl -n hw.machine)" = iPad4,4 ] || die 'Only iPad4,4 is qualified.'
    [ "$(sw_vers -productVersion)" = 12.5.7 ] || die 'Only iOS 12.5.7 is qualified.'
    [ ! -d /var/jb ] || die 'Rootless jailbreak layouts are not qualified.'
    for tool in ldid sha256sum curl sqlite3 git nohup ps stat; do
        command -v "$tool" >/dev/null || die "Required tool missing: $tool"
    done
    if [ "$(id -u)" != 0 ]; then
        [ "$root" != /var/lib/forgejo-ios ] || die 'Use sudo for the default installation.'
        say 'User-owned installation: root access not verified.'
    fi
}
choose_user() {
    if [ -f "$config" ]; then
        run_user=$(ini '' RUN_USER)
    elif [ "$(id -u)" = 0 ]; then
        run_user=${FORGEJO_IOS_USER:-${SUDO_USER:-mobile}}
    else
        run_user=$(id -un)
    fi
    case "$run_user" in ''|root|*[!a-zA-Z0-9_-]*) die 'Select an existing non-root service account with FORGEJO_IOS_USER.';; esac
    run_uid=$(id -u "$run_user") || die 'Service account does not exist.'
    [ "$run_uid" != 0 ] || die 'Forgejo must not run as root.'
    if [ -f "$config" ]; then
        [ "$(owner "$config")" = "$run_uid" ] || die 'Config owner must match RUN_USER; review ownership manually.'
    fi
    if [ "$(id -u)" != 0 ]; then
        [ "$run_uid" = "$(id -u)" ] || die 'Cannot manage another user without root.'
    else
        command -v sudo >/dev/null || die 'sudo is required to drop service privileges.'
    fi
}
as_user() {
    if [ "$(id -u)" = 0 ]; then
        sudo -H -u "$run_user" env -i PATH="$PATH" USER="$run_user" LOGNAME="$run_user" HOME="$root/data" GOMAXPROCS=1 "$@"
    else
        env -i PATH="$PATH" USER="$run_user" LOGNAME="$run_user" HOME="$root/data" GOMAXPROCS=1 "$@"
    fi
}
ini() {
    # Only selected non-secret fields are read. Never source app.ini or state.
    awk -v section="$1" -v key="$2" '
      /^[[:space:]]*[;#]/ {next}
      /^[[:space:]]*\[/ {s=$0; sub(/^[[:space:]]*\[/,"",s); sub(/\].*$/,"",s); next}
      s==section && index($0,"=") {k=substr($0,1,index($0,"=")-1); gsub(/^[ \t]+|[ \t]+$/,"",k);
        if (k==key) {v=substr($0,index($0,"=")+1); gsub(/^[ \t]+|[ \t\r]+$/,"",v); print v}}' "$config"
}
check_config() {
    [ -f "$config" ] || die 'Config missing; repair never resets configuration.'
    [ "$(ini '' WORK_PATH)" = "$root" ] &&
    [ "$(ini server APP_DATA_PATH)" = "$root/data" ] &&
    [ "$(ini repository ROOT)" = "$root/repositories" ] &&
    [ "$(ini database DB_TYPE)" = sqlite3 ] &&
    [ "$(ini database PATH)" = "$root/data/forgejo.db" ] &&
    [ "$(ini server HTTP_ADDR)" = 127.0.0.1 ] &&
    [ "$(ini log ROOT_PATH)" = "$root/logs" ] &&
    [ "$(ini server DISABLE_SSH)" = true ] &&
    [ "$(ini server START_SSH_SERVER)" = false ] || die 'Config paths, SQLite, SSH, or loopback policy differ; manual review required.'
    port=$(ini server HTTP_PORT)
    case "$port" in ''|*[!0-9]*|0*) die 'Invalid HTTP port.';; esac
    [ "$port" -ge 1024 ] && [ "$port" -le 65535 ] || die 'Use an unprivileged HTTP port.'
    protocol=$(ini server PROTOCOL)
    [ -z "$protocol" ] || [ "$protocol" = http ] || die 'Only loopback HTTP is supported.'
    url=http://127.0.0.1:$port/api/healthz
}
permissions() {
    chmod 711 "$root"
    chmod 755 "$root/bin"
    chmod 700 "$root/backup"
    for item in custom custom/conf data repositories logs run; do
        if [ "$(id -u)" = 0 ]; then chown -h "$run_user" "$root/$item"; fi
        as_user chmod 700 "$root/$item"
    done
    if [ -f "$config" ]; then
        as_user chmod 600 "$config"
    fi
}
layout() {
    mkdir -p "$root/bin" "$root/custom/conf" "$root/data" "$root/repositories" "$root/logs" "$root/backup" "$root/run"
    permissions
}
lock() {
    if [ ! -d "$root" ]; then mkdir -p "$root"; chmod 711 "$root"; fi
    mkdir "$root/.installer-lock" 2>/dev/null || die 'Another operation or an interrupted transaction holds .installer-lock; inspect before removing it.'
    lock_owned=1
}
service_pid() {
    pid=
    [ -f "$pidfile" ] || return 1
    pid=$(cat "$pidfile")
    case "$pid" in ''|*[!0-9]*) die 'Invalid service PID file.';; esac
    [ "$pid" -gt 1 ] || die 'Unsafe service PID.'
    kill -0 "$pid" 2>/dev/null || return 1
    case "$(ps -p "$pid" -o stat= 2>/dev/null || :)" in Z*) return 1;; esac
    command_line=$(ps -p "$pid" -o command= 2>/dev/null || :)
    case "$command_line" in "$bin web --config $config --work-path $root") ;; *) die 'PID belongs to an unexpected process; refusing to signal it.';; esac
    process_uid=$(ps -p "$pid" -o uid= | tr -d ' ')
    [ "$process_uid" = "$run_uid" ] || die 'Service PID owner mismatch.'
}
stop_service() {
    if service_pid; then
        kill -TERM "$pid" || return 1
        tries=0
        while kill -0 "$pid" 2>/dev/null; do
            # A zombie has already closed files and listeners.
            case "$(ps -p "$pid" -o stat= 2>/dev/null || :)" in Z*) break;; esac
            tries=$((tries + 1))
            [ "$tries" -le 30 ] || { say 'Shutdown timed out; no SIGKILL sent.' >&2; return 1; }
            sleep 1
        done
    fi
    rm -f "$pidfile"
}
http_status() { curl --noproxy '*' --connect-timeout 2 --max-time 3 -s -o /dev/null -w '%{http_code}' "$url" 2>/dev/null || :; }
start_service() {
    if service_pid; then return 0; fi
    # Refuse to attribute a pre-existing listener or unmanaged process to this start.
    if ps -axo command= | awk -v binary="$bin" '$1 == binary {found=1} END {exit !found}'; then
        say 'Untracked Forgejo process; inspect it before restarting.' >&2; return 1
    fi
    [ "$(http_status)" = 000 ] || { say 'HTTP port is already occupied.' >&2; return 1; }
    rm -f "$pidfile"
    # shellcheck disable=SC2016
    if [ "$(id -u)" = 0 ]; then
        nohup sudo -H -u "$run_user" env -i PATH="$PATH" USER="$run_user" LOGNAME="$run_user" HOME="$root/data" GOMAXPROCS=1 \
            /bin/sh -c 'umask 077; exec >>"$1/logs/service.log" 2>&1; printf "%s\n" "$$" >"$1/run/forgejo.pid"; exec "$1/bin/forgejo" web --config "$1/custom/conf/app.ini" --work-path "$1"' sh "$root" \
            </dev/null >/dev/null 2>&1 &
    else
        nohup env -i PATH="$PATH" USER="$run_user" LOGNAME="$run_user" HOME="$root/data" GOMAXPROCS=1 \
            /bin/sh -c 'umask 077; exec >>"$1/logs/service.log" 2>&1; printf "%s\n" "$$" >"$1/run/forgejo.pid"; exec "$1/bin/forgejo" web --config "$1/custom/conf/app.ini" --work-path "$1"' sh "$root" \
            </dev/null >/dev/null 2>&1 &
    fi
    tries=0
    while [ "$tries" -lt 60 ]; do
        sleep 1
        tries=$((tries + 1))
        if [ -f "$pidfile" ]; then
            service_pid || return 1
            if [ "$(http_status)" = 200 ]; then
                sleep 1
                service_pid && [ "$(http_status)" = 200 ] && return 0
            fi
        fi
    done
    return 1
}
fetch() {
    curl --proto '=https' --proto-redir '=https' -fsSL --connect-timeout 20 --max-time 600 --retry 2 "$1" -o "$2"
}
download() {
    if [ -n "${FORGEJO_IOS_BUNDLE:-}" ]; then
        # Explicit offline mode, still subject to the same release checksum gate.
        cp "$FORGEJO_IOS_BUNDLE/forgejo-ios" "$stage/forgejo-ios"
        cp "$FORGEJO_IOS_BUNDLE/SHA256SUMS" "$stage/release-sums"
    else
        base=https://github.com/nghianguyen150612/forgejo-ios/releases/download/$release
        fetch "$base/SHA256SUMS" "$stage/release-sums" || die 'Release checksums unavailable. No installed files were replaced.'
        fetch "$base/forgejo-ios" "$stage/forgejo-ios" || die 'Release binary unavailable. No installed files were replaced.'
    fi
    # Ignore other release assets; accept exactly one strict, path-free binary entry.
    awk '$2=="forgejo-ios" || $2=="*forgejo-ios" {if(NF!=2 || length($1)!=64 || $1~/[^0-9a-fA-F]/) exit 1; count++; print tolower($1) "  forgejo-ios"}
         END {if(count!=1) exit 1}' "$stage/release-sums" >"$stage/SHA256SUMS" || die 'Malformed or duplicate binary checksum.'
    (cd "$stage" && sha256sum -c SHA256SUMS) || die 'Checksum mismatch; installation refused.'
    [ -s "$stage/forgejo-ios" ] || die 'Empty release binary.'
    # The frozen release must be the A7 artifact, never the generic iOS build.
    qualify_artifact
}
qualify_artifact() {
    [ "$(hash "$stage/forgejo-ios")" = 19dd23e3a78d13e1beb18a1e475d7b1a2c75959a0718d958905a0a540400218a ] || die 'Artifact is outside the qualified v1.0.0 A7 release. A new qualification cycle is required.'
}
sign_binary() {
    cat >"$stage/entitlements.plist" <<'PLIST'
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0"><dict><key>com.apple.private.security.no-container</key><true/></dict></plist>
PLIST
    ldid -S"$stage/entitlements.plist" "$stage/forgejo-ios" >"$stage/sign.log" 2>&1 || die 'Device signing failed.'
    chmod 755 "$stage/forgejo-ios"
    # Run version as the service user, never execute the release as root.
    chmod 711 "$stage"
    version_text=$(as_user "$stage/forgejo-ios" --version 2>/dev/null) || die 'Signed binary cannot execute.'
    version=$(printf '%s\n' "$version_text" | sed -n 's/^forgejo version \([0-9][0-9.]*\).*$/\1/p')
    [ "$version" = 15.0.9 ] || die 'Only qualified Forgejo 15.0.9 rebuilds may be installed; database migrations are not reversible by binary rollback.'
}
write_config() {
    [ ! -e "$config" ] || return 0
    port=${FORGEJO_IOS_PORT:-3000}
    case "$port" in ''|*[!0-9]*|0*) die 'Invalid port.';; esac
    [ "$port" -ge 1024 ] && [ "$port" -le 65535 ] || die 'Invalid port range.'
    cat >"$stage/app.ini" <<EOF
APP_NAME = Forgejo iOS
RUN_USER = $run_user
RUN_MODE = prod
WORK_PATH = $root
[server]
APP_DATA_PATH = $root/data
DOMAIN = 127.0.0.1
HTTP_ADDR = 127.0.0.1
HTTP_PORT = $port
ROOT_URL = http://127.0.0.1:$port/
DISABLE_SSH = true
START_SSH_SERVER = false
[database]
DB_TYPE = sqlite3
PATH = $root/data/forgejo.db
[repository]
ROOT = $root/repositories
[log]
MODE = file
ROOT_PATH = $root/logs
EOF
    if [ "$(id -u)" = 0 ]; then chown "$run_user" "$stage/app.ini"; fi
    chmod 600 "$stage/app.ini"
    mv "$stage/app.ini" "$config"
}
snapshot() {
    previous=$(mktemp -d "$root/backup/transaction.XXXXXX")
    for item in forgejo manager.sh forgejo-ios; do
        if [ -f "$root/bin/$item" ]; then cp -p "$root/bin/$item" "$previous/$item"; fi
    done
    if [ -f "$state" ]; then cp -p "$state" "$previous/install-state"; fi
    if service_pid; then was_running=1; else was_running=0; fi
    printf '%s\n' "$was_running" >"$previous/was-running"
    for item in . bin custom custom/conf data repositories logs backup run; do
        printf '%s %s %s\n' "$item" "$(owner "$root/$item")" "$(mode "$root/$item")"
    done >"$previous/permissions"
    if [ -f "$config" ]; then printf 'custom/conf/app.ini %s %s\n' "$(owner "$config")" "$(mode "$config")" >>"$previous/permissions"; fi
    say "Recovery snapshot: $previous"
}
restore_snapshot() {
    stop_service || return 1
    for item in forgejo manager.sh forgejo-ios; do
        if [ -f "$previous/$item" ]; then
            cp -p "$previous/$item" "$root/bin/.$item.restore" || return 1
            mv -f "$root/bin/.$item.restore" "$root/bin/$item" || return 1
        else
            rm -f "$root/bin/$item" || return 1
        fi
    done
    if [ -f "$previous/install-state" ]; then
        cp -p "$previous/install-state" "$root/.state.restore" && mv -f "$root/.state.restore" "$state" || return 1
    else
        rm -f "$state" || return 1
    fi
    while read -r item saved_uid saved_mode; do
        if [ "$(id -u)" = 0 ]; then chown "$saved_uid" "$root/$item" || return 1; fi
        chmod "$saved_mode" "$root/$item" || return 1
    done <"$previous/permissions"
    if [ "$was_running" = 1 ]; then start_service || return 1; fi
}
cleanup() {
    result=$?
    trap - 0 INT TERM HUP
    if [ "$active" = 1 ]; then
        say 'Transaction failed; restoring binary, launcher, state, permissions, and prior running/stopped state.' >&2
        if restore_snapshot; then say 'Rollback PASS' >&2; else say "Rollback INCOMPLETE: preserve $previous and inspect the service manually." >&2; result=1; fi
    fi
    if [ -n "$stage" ] && [ -d "$stage" ]; then rm -rf "$stage"; fi
    if [ "$lock_owned" = 1 ]; then rmdir "$root/.installer-lock" || result=1; fi
    exit "$result"
}
install_update() {
    check_device
    check_paths
    choose_user
    if [ "$action" = update ]; then
        [ -f "$state" ] && [ -x "$bin" ] || die 'No managed installation; use install or repair.'
        [ "$(field "$state" VERSION)" = 15.0.9 ] || die 'Cross-version update refused.'
        [ "$(hash "$bin")" = "$(field "$state" BINARY_SHA256)" ] || die 'Installed binary checksum differs; investigate before updating.'
        check_config
    else
        [ ! -e "$bin" ] && [ ! -e "$state" ] || die 'Already installed; use update.'
        if [ -f "$config" ]; then check_config; fi
    fi
    lock
    # Staging shares the destination filesystem so rename is atomic.
    stage=$(mktemp -d "$root/.stage.XXXXXX")
    download
    sign_binary
    # Existing directory and config permissions are captured before changing them.
    for item in bin custom custom/conf data repositories logs backup run; do mkdir -p "$root/$item"; done
    snapshot
    active=1
    stop_service || die 'Could not stop current service.'
    layout
    write_config
    check_config
    cp "$self" "$stage/manager.sh"
    chmod 755 "$stage/manager.sh"
    mv -f "$stage/forgejo-ios" "$bin"
    mv -f "$stage/manager.sh" "$root/bin/manager.sh"
    printf '#!/bin/sh\nexec /bin/sh "%s/bin/manager.sh" "$@"\n' "$root" >"$stage/command"
    chmod 755 "$stage/command"
    mv -f "$stage/command" "$root/bin/forgejo-ios"
    start_service || die 'New binary did not become healthy.'
    printf 'VERSION=%s\nRELEASE=%s\nINSTALL_TIME=%s\nBINARY_SHA256=%s\n' "$version" "$release" "$(date -u '+%Y-%m-%dT%H:%M:%SZ')" "$(hash "$bin")" >"$stage/install-state"
    chmod 600 "$stage/install-state"
    mv -f "$stage/install-state" "$state"
    if [ "$root" = /var/lib/forgejo-ios ]; then
        mkdir -p /usr/local/bin
        if [ -e "$link" ] || [ -L "$link" ]; then
            [ -L "$link" ] && [ "$(readlink "$link")" = "$root/bin/forgejo-ios" ] || die 'Command path is occupied; refusing to overwrite it.'
        else
            ln -s "$root/bin/forgejo-ios" "$link"
        fi
    fi
    active=0
    say "$action PASS: http://127.0.0.1:$port/ (complete first-run setup locally)."
    say "Command: $root/bin/forgejo-ios"
}
verify() {
    check_paths; choose_user; check_config
    [ -x "$bin" ] && [ -f "$state" ] || die 'Installation is incomplete.'
    [ "$(hash "$bin")" = "$(field "$state" BINARY_SHA256)" ] || die 'Installed binary checksum mismatch.'
    [ "$(awk -F= '{print $1}' "$state" | sort | tr '\n' ' ')" = 'BINARY_SHA256 INSTALL_TIME RELEASE VERSION ' ] || die 'Invalid state fields.'
    [ "$(mode "$config")" = 600 ] || die 'Config permissions must be 600.'
    [ "$(owner "$config")" = "$run_uid" ] || die 'Config owner mismatch.'
    if [ -f "$root/data/forgejo.db" ]; then
        [ "$(as_user sqlite3 -readonly "$root/data/forgejo.db" 'PRAGMA integrity_check;' 2>/dev/null)" = ok ] || die 'SQLite integrity failed; details withheld.'
    else
        say 'SQLite: not initialized (finish first-run setup).'
    fi
    service_pid || die 'Service is stopped.'
    [ "$(http_status)" = 200 ] || die 'HTTP health check failed.'
    say 'Verify PASS: installed checksum, config permissions, SQLite (if initialized), owned PID, HTTP 200.'
}
diagnostics() {
    check_paths
    say 'Forgejo iOS'
    say ''
    say "Device: $(sysctl -n hw.machine 2>/dev/null || say unknown)"
    cpu=$(sysctl -n hw.cputype 2>/dev/null || uname -m)
    case "$cpu" in 16777228) say 'Architecture: arm64';; *) say 'Architecture: unqualified / unknown';; esac
    say "iOS: $(sw_vers -productVersion 2>/dev/null || say unknown)"
    say "Jailbreak: rootful tools; installer UID $(id -u) (distribution not automatically identified)"
    say ''; say 'Binary:'
    if [ -f "$state" ]; then
        # Only fixed validated tokens are displayed, never arbitrary state text.
        case "$(field "$state" VERSION)" in 15.0.9) say 'Version: 15.0.9';; *) say 'Version: unknown';; esac
        if [ -f "$bin" ] && [ "$(hash "$bin")" = "$(field "$state" BINARY_SHA256)" ]; then say 'Checksum: OK'; else say 'Checksum: MISMATCH / missing'; fi
    else say 'Version: unknown'; say 'Checksum: no install-state'; fi
    say ''; say 'Runtime:'
    if [ -x "$bin" ] && [ -f "$config" ] && [ -f "$state" ] && [ "$(hash "$bin")" = "$(field "$state" BINARY_SHA256)" ]; then
        if (choose_user) >/dev/null 2>&1; then
            choose_user
            runtime=$(as_user "$bin" --version 2>/dev/null | sed -n 's/.*\(go1\.[0-9][0-9]*\.[0-9][0-9]*\).*/\1/p' || :)
            say "Go version: ${runtime:-unknown} (qualified release uses A7 patch)"
        else say 'Go version: unavailable'; fi
    else say 'Go version: unavailable'; fi
    say ''; say 'Config:'
    if (check_config) >/dev/null 2>&1; then
        say 'OK'; check_config
    else say 'NEEDS REVIEW (values withheld)'; url=; port=unknown; fi
    say ''; say 'Database:'
    if [ -f "$root/data/forgejo.db" ]; then
        if (choose_user; [ "$(as_user sqlite3 -readonly "$root/data/forgejo.db" 'PRAGMA integrity_check;' 2>/dev/null)" = ok ]) >/dev/null 2>&1; then
            say 'SQLite integrity: OK'
        else say 'SQLite integrity: FAILED / unavailable (details withheld)'; fi
    else say 'SQLite integrity: not initialized'; fi
    say ''; say 'Service:'
    if (choose_user; service_pid) >/dev/null 2>&1; then choose_user; service_pid; say "Running PID: $pid"; else say 'Running PID: stopped / unverified'; fi
    say "Port: $port"
    say "HTTP status: $(if [ -n "$url" ]; then http_status; else say unknown; fi)"
    say ''; say 'Storage:'
    for item in data repositories; do
        size=$(du -sk "$root/$item" 2>/dev/null | awk '{print $1}' || :)
        case "$item" in data) say "Data: ${size:-unknown} KiB";; repositories) say "Repositories: ${size:-unknown} KiB";; esac
    done
    say "Free space: $(df -Pk "$root" 2>/dev/null | awk 'NR==2 {print $4}') KiB"
}
repair() {
    check_device; check_paths; choose_user; check_config; lock
    layout
    if [ ! -f "$bin" ]; then
        [ -f "$state" ] || die 'No state for authenticating a backup; manual recovery required.'
        wanted=$(field "$state" BINARY_SHA256)
        found=
        for candidate in "$root"/backup/transaction.*/forgejo; do
            [ -f "$candidate" ] && [ ! -L "$candidate" ] || continue
            if [ "$(hash "$candidate")" = "$wanted" ]; then found=$candidate; break; fi
        done
        [ -n "$found" ] || die 'No backup matching install-state; nothing restored.'
        cp -p "$found" "$root/bin/.repair"
        mv "$root/bin/.repair" "$bin"
    fi
    [ -f "$state" ] && [ "$(hash "$bin")" = "$(field "$state" BINARY_SHA256)" ] || die 'Binary mismatch; repair will not execute it.'
    chmod 755 "$bin"
    if ! stop_service || ! start_service; then die 'Restart failed; data and config retained.'; fi
    say 'Repair PASS; no database, config content, or data was changed by repair.'
}
uninstall() {
    check_paths; choose_user; lock
    [ -f "$state" ] || [ -f "$root/bin/manager.sh" ] || die 'No managed installation; refusing deletion.'
    stop_service || die 'Could not stop service; uninstall refused.'
    if [ "$root" = /var/lib/forgejo-ios ] && [ -L "$link" ] && [ "$(readlink "$link")" = "$root/bin/forgejo-ios" ]; then rm "$link"; fi
    rm -f "$bin" "$root/bin/manager.sh" "$root/bin/forgejo-ios" "$state" "$pidfile"
    rm -rf "$root/logs"
    say 'Uninstall PASS. Data, repositories, configuration, and recovery backups retained.'
    if [ "${purge:-0}" = 1 ]; then
        ask 'Type DELETE FORGEJO DATA to delete data, repositories, configuration, and backups'
        [ "$answer" = 'DELETE FORGEJO DATA' ] || die 'Data deletion cancelled; retained files are unchanged.'
        rm -rf "$root/data" "$root/repositories" "$root/custom" "$root/backup"
        say 'Data, repositories, configuration, and backups deleted; recovery requires an external backup.'
    fi
}
menu() {
    while :; do
        printf '\nForgejo iOS\n1. Install Forgejo\n2. Update Forgejo\n3. Verify installation\n4. Diagnostics\n5. Repair\n6. Uninstall\n7. Exit\n'
        ask 'Choose 1-7'
        case "$answer" in
            1) selected=install;; 2) selected=update;; 3) selected=verify;; 4) selected=diagnostics;; 5) selected=repair;; 6) selected=uninstall;; 7) return;; *) continue;;
        esac
        # A fresh shell keeps errexit and transaction traps effective after failure.
        /bin/sh "$self" "$selected" || say 'Operation failed; review the message above.'
    done
}
main() {
    init
    action=${1:-menu}; purge=0
    [ "$#" -le 2 ] || die 'Too many arguments.'
    if [ "$#" = 2 ]; then [ "$action:$2" = uninstall:--purge ] || die 'Only uninstall accepts --purge.'; purge=1; fi
    case "$action" in
        menu) menu;; install|update) install_update;; verify) verify;; diagnostics) diagnostics;; repair) repair;; uninstall) uninstall;;
        start|stop|restart)
            check_paths; choose_user; check_config; lock
            if [ "$action" != stop ]; then
                [ -f "$state" ] && [ -f "$bin" ] && [ "$(hash "$bin")" = "$(field "$state" BINARY_SHA256)" ] || die 'Installed checksum mismatch; startup refused.'
            fi
            case "$action" in start) start_service;; stop) stop_service;; restart) stop_service && start_service;; esac;;
        *) die 'Usage: forgejo-ios [install|update|verify|diagnostics|repair|uninstall [--purge]|start|stop|restart]' ;;
    esac
}

fixture_step() {
    # Test-only entry: always creates/uses a private mktemp sandbox, never the
    # default install root. No production command accepts these substitutions.
    case "${2:-}" in /tmp/forgejo-lifecycle-test.??????) ;; *) die 'Invalid fixture sandbox.';; esac
    [ -d "$2" ] && [ ! -L "$2" ] && [ "$(owner "$2")" = "$(id -u)" ] && [ "$(mode "$2")" = 700 ] || die 'Unsafe fixture sandbox.'
    FORGEJO_IOS_ROOT=$2/runtime
    FORGEJO_IOS_BUNDLE=$2/bundle
    export FORGEJO_IOS_ROOT FORGEJO_IOS_BUNDLE
    check_device() { :; }
    qualify_artifact() { :; }
    choose_user() { run_user=$(id -un); run_uid=$(id -u); }
    sign_binary() { version=15.0.9; chmod 755 "$stage/forgejo-ios"; }
    service_pid() { [ -f "$root/run/fixture-running" ]; }
    stop_service() { rm -f "$root/run/fixture-running"; }
    start_service() {
        if [ -f "$root/data/fail-once" ]; then rm "$root/data/fail-once"; return 1; fi
        touch "$root/run/fixture-running"
    }
    http_status() { say 200; }
    as_user() { "$@"; }
    main "$1"
}
self_test() {
    test_root=$(mktemp -d /tmp/forgejo-lifecycle-test.XXXXXX)
    trap 'rm -rf "$test_root"' 0
    trap 'exit 130' INT
    trap 'exit 143' TERM HUP
    test_engine=$(cd "$(dirname "$0")" && pwd)/$(basename "$0")
    mkdir "$test_root/bundle"
    printf 'release-one\n' >"$test_root/bundle/forgejo-ios"
    (cd "$test_root/bundle" && sha256sum forgejo-ios >SHA256SUMS)
    /bin/sh "$test_engine" --fixture-step install "$test_root"
    test_runtime=$test_root/runtime
    printf 'retained data\n' >"$test_runtime/data/sentinel"
    printf 'retained repository\n' >"$test_runtime/repositories/sentinel"
    cp "$test_runtime/custom/conf/app.ini" "$test_root/config-before"
    /bin/sh "$test_engine" --fixture-step verify "$test_root"
    printf 'release-two\n' >"$test_root/bundle/forgejo-ios"
    (cd "$test_root/bundle" && sha256sum forgejo-ios >SHA256SUMS)
    /bin/sh "$test_engine" --fixture-step update "$test_root"
    cmp "$test_root/bundle/forgejo-ios" "$test_runtime/bin/forgejo"
    cp -p "$test_runtime/install-state" "$test_root/state-before"
    cp -p "$test_runtime/bin/forgejo" "$test_root/binary-before"
    cp -p "$test_runtime/bin/manager.sh" "$test_root/manager-before"
    chmod 751 "$test_runtime/bin/forgejo"
    chmod 750 "$test_runtime/repositories"
    printf 'release-three\n' >"$test_root/bundle/forgejo-ios"
    (cd "$test_root/bundle" && sha256sum forgejo-ios >SHA256SUMS)
    touch "$test_runtime/data/fail-once"
    if /bin/sh "$test_engine" --fixture-step update "$test_root"; then die 'Expected startup failure.'; fi
    cmp "$test_root/binary-before" "$test_runtime/bin/forgejo"
    cmp "$test_root/manager-before" "$test_runtime/bin/manager.sh"
    cmp "$test_root/state-before" "$test_runtime/install-state"
    [ "$(mode "$test_runtime/bin/forgejo")" = 751 ]
    [ "$(mode "$test_runtime/repositories")" = 750 ]
    [ -f "$test_runtime/run/fixture-running" ]
    say 'PASS: rollback restores binary, manager, state, permissions, running service'
    rm "$test_runtime/run/fixture-running"
    touch "$test_runtime/data/fail-once"
    if /bin/sh "$test_engine" --fixture-step update "$test_root"; then die 'Expected stopped-service update failure.'; fi
    [ ! -f "$test_runtime/run/fixture-running" ]
    say 'PASS: rollback preserves stopped service'
    printf 'corruption\n' >>"$test_root/bundle/forgejo-ios"
    if /bin/sh "$test_engine" --fixture-step update "$test_root"; then die 'Expected checksum refusal.'; fi
    cmp "$test_root/binary-before" "$test_runtime/bin/forgejo"
    cmp "$test_root/state-before" "$test_runtime/install-state"
    say 'PASS: checksum failure refuses replacement'
    rm "$test_runtime/bin/forgejo"
    /bin/sh "$test_engine" --fixture-step repair "$test_root"
    cmp "$test_root/binary-before" "$test_runtime/bin/forgejo"
    /bin/sh "$test_engine" --fixture-step uninstall "$test_root"
    [ ! -e "$test_runtime/bin/forgejo" ] && [ ! -e "$test_runtime/bin/manager.sh" ]
    [ ! -e "$test_runtime/install-state" ] && [ ! -e "$test_runtime/logs" ]
    cmp "$test_root/config-before" "$test_runtime/custom/conf/app.ini"
    [ "$(cat "$test_runtime/data/sentinel")" = 'retained data' ]
    [ "$(cat "$test_runtime/repositories/sentinel")" = 'retained repository' ]
    say 'PASS: uninstall and data/config/repository preservation'
    ln -s "$test_root/bundle" "$test_runtime/bin/forgejo"
    if /bin/sh "$test_engine" --fixture-step install "$test_root"; then die 'Expected symlink refusal.'; fi
    say 'PASS: managed symlink refusal'
    say 'All lifecycle fixtures PASS (mock signing/process/HTTP, not iOS runtime evidence).'
}

case "${1:-}" in
    --self-test) self_test;;
    --fixture-step) shift; fixture_step "$@";;
    *) main "$@";;
esac
