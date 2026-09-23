#!/bin/sh
# Pipe-safe bootstrap. The engine is checksum-pinned independently of the branch.
set -eu
umask 077
PATH=/usr/local/bin:/usr/bin:/bin:/usr/sbin:/sbin
export PATH
engine_sha=387d0c6c8cb5856f722eaaa3b1ad8adaa9ebad7063f0dc62855c0da3bf5c3542
engine_url=https://raw.githubusercontent.com/nghianguyen150612/Forgejo-iOS/iOS/scripts/ios/install-forgejo.sh
command -v curl >/dev/null || { printf '%s\n' 'curl is required' >&2; exit 1; }
command -v sha256sum >/dev/null || { printf '%s\n' 'sha256sum is required' >&2; exit 1; }
work=$(mktemp -d /tmp/forgejo-installer.XXXXXX)
trap 'rm -f "$work/manager.sh" "$work/SHA256SUMS"; rmdir "$work"' 0
trap 'exit 130' INT
trap 'exit 143' TERM HUP
curl --proto '=https' --proto-redir '=https' -fsSL --connect-timeout 20 --max-time 120 "$engine_url" -o "$work/manager.sh"
printf '%s  manager.sh\n' "$engine_sha" >"$work/SHA256SUMS"
(cd "$work" && sha256sum -c SHA256SUMS) || exit 1
/bin/sh "$work/manager.sh" "$@"
