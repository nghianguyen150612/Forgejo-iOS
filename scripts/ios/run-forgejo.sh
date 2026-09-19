#!/usr/bin/env bash

set -euo pipefail

if [[ "$#" -lt 1 ]]; then
	printf 'usage: run-forgejo.sh FORGEJO_BINARY [ARG...]\n' >&2
	exit 2
fi

binary_path="$1"
shift

if [[ ! -x "$binary_path" ]]; then
	printf 'Forgejo iOS launcher: binary is not executable: %s\n' "$binary_path" >&2
	exit 1
fi

machine="${FORGEJO_IOS_DEVICE_MODEL:-}"
if [[ -z "$machine" ]] && command -v sysctl >/dev/null 2>&1; then
	machine="$(sysctl -n hw.machine 2>/dev/null || true)"
fi

darwin_release="${FORGEJO_IOS_DARWIN_RELEASE:-}"
if [[ -z "$darwin_release" ]]; then
	darwin_release="$(uname -r 2>/dev/null || true)"
fi

policy='preserve-explicit'
if [[ -z "${GOMAXPROCS:-}" ]]; then
	case "$machine:$darwin_release" in
		iPad4,4:18.*|iPad4,5:18.*|iPad4,6:18.*)
			export GOMAXPROCS=1
			policy='a7-ios12-default'
			;;
		*)
			policy='no-default-for-unvalidated-target'
			;;
	esac
fi

printf 'Forgejo iOS launcher: machine=%s darwin=%s policy=%s GOMAXPROCS=%s\n' \
	"${machine:-unknown}" \
	"${darwin_release:-unknown}" \
	"$policy" \
	"${GOMAXPROCS:-unset}" >&2

exec "$binary_path" "$@"
