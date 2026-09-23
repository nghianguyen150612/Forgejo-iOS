#!/bin/sh
# Pipe-safe bootstrap. The engine is checksum-pinned independently of the branch.
set -eu
umask 077
PATH=/usr/local/bin:/usr/bin:/bin:/usr/sbin:/sbin
export PATH
engine_sha=07be4647926d8393fd1b7b5156172394ba059f90427b5df38a452479ac7b0173
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
