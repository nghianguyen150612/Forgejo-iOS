#!/usr/bin/env bash

set -euo pipefail
IFS=$'\n\t'
umask 077

usage() {
	cat >&2 <<'USAGE'
usage:
  audit-security.sh RUNTIME_ROOT [BACKUP_ROOT ...]
  audit-security.sh --scan-only PATH [...]

The runtime and backup roots must be dedicated owner-only trees. The audit is
read-only: it reports insecure modes and secret-like material without changing
the supplied paths.
USAGE
	exit 2
}

fail() {
	printf 'Forgejo security audit: %s\n' "$1" >&2
	exit 1
}

command_required() {
	command -v "$1" >/dev/null 2>&1 || fail "required command is unavailable: $1"
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

owner_only() {
	local mode="$1"
	local numeric

	[[ "$mode" =~ ^[0-7]+$ ]] || return 1
	numeric=$((8#$mode))
	(( (numeric & 077) == 0 ))
}

require_directory_mode() {
	local path="$1"
	local mode

	[[ -d "$path" ]] || fail "required directory is missing: $path"
	mode="$(file_mode "$path")"
	[[ "$mode" == '700' ]] || fail "directory is not mode 700: $path (mode $mode)"
}

audit_tree_modes() {
	local root="$1"
	local path
	local mode

	[[ -d "$root" ]] || fail "audit root does not exist: $root"
	while IFS= read -r -d '' path; do
		mode="$(file_mode "$path")"
		[[ "$mode" == '700' ]] || fail "directory is not mode 700: $path (mode $mode)"
	done < <(find "$root" -type d -print0)
	while IFS= read -r -d '' path; do
		mode="$(file_mode "$path")"
		owner_only "$mode" || fail "file has group/other permissions: $path (mode $mode)"
	done < <(find "$root" -type f -print0)
}

audit_sensitive_files() {
	local root="$1"
	local path
	local mode
	local base

	while IFS= read -r -d '' path; do
		base="${path##*/}"
		case "$base" in
			app.ini|forgejo.db|forgejo.db-*|*.key|*.pem|authorized_keys|\
			*token*|*secret*|*password*|metadata.txt|manifest.sha256|payload.tar|\
			forgejo.pid|forgejo.binary|forgejo.args|*.log)
				mode="$(file_mode "$path")"
				[[ "$mode" == '600' ]] || fail "sensitive file is not mode 600: $path (mode $mode)"
				;;
		esac
	done < <(find "$root" -type f -print0)
}

scan_without_secrets() {
	local path
	local candidate
	local matches
	local pattern='BEGIN (RSA|OPENSSH|EC|DSA|PRIVATE) KEY|gh[pousr]_[A-Za-z0-9_]{20,}|glpat-[A-Za-z0-9_-]{20,}|github_pat_[A-Za-z0-9_]{20,}|xox[baprs]-[A-Za-z0-9-]{20,}|AKIA[0-9A-Z]{16}|Bearer[[:space:]]+[A-Za-z0-9._~+/=-]{20,}|(token|secret|password)[=:][[:space:]]*[A-Za-z0-9._~+/=-]{24,}'

	for path in "$@"; do
		[[ -e "$path" ]] || fail "secret-scan path does not exist: $path"
		matches=''
		if command -v rg >/dev/null 2>&1; then
			matches="$(rg -Il --hidden --no-messages \
				-g '!*.db' -g '!*.db-*' -g '!*.tar' \
				-e "$pattern" \
				-- "$path" || true)"
		else
			command_required find
			command_required grep
			if [[ -d "$path" ]]; then
				while IFS= read -r -d '' candidate; do
					case "$candidate" in
						*.db|*.db-*|*.tar)
							continue
							;;
					esac
					if grep -EIl "$pattern" "$candidate" >/dev/null 2>&1; then
						matches+="$candidate"$'\n'
					fi
				 done < <(find "$path" -type f -print0)
			else
				case "$path" in
					*.db|*.db-*|*.tar)
						continue
						;;
				 esac
				if grep -EIl "$pattern" "$path" >/dev/null 2>&1; then
					matches="$path"
				fi
			fi
		fi
		if [[ -n "$matches" ]]; then
			printf '%s\n' "$matches" >&2
			fail "secret-like material found under $path"
		fi
	done
}

audit_root() {
	local root="$1"
	local required

	root="$(cd -- "$root" && pwd)"
	require_directory_mode "$root"
	for required in \
		custom/conf data repositories logs backup runtime \
		runtime/custom/conf runtime/data runtime/repositories runtime/logs runtime/backup; do
		if [[ -e "$root/$required" ]]; then
			[[ -d "$root/$required" ]] || fail "security path is not a directory: $root/$required"
			require_directory_mode "$root/$required"
		fi
	done
	audit_tree_modes "$root"
	audit_sensitive_files "$root"
	printf 'Forgejo security audit passed: %s\n' "$root"
}

[[ "$#" -ge 1 ]] || usage
if [[ "$1" == '--scan-only' ]]; then
	shift
	[[ "$#" -ge 1 ]] || usage
	scan_without_secrets "$@"
	printf 'Forgejo secret scan passed: %s path(s)\n' "$#"
	exit 0
fi

command_required find
command_required stat
for root in "$@"; do
	audit_root "$root"
done
