#!/usr/bin/env bash

set -euo pipefail

usage() {
	cat >&2 <<'EOF'
usage: run-device-runtime-probes.sh SSH_TARGET ARTIFACT_DIR REMOTE_DIR

SSH_TARGET is the existing SSH target for the jailbroken iOS device.
ARTIFACT_DIR contains the final CI probes, SHA256SUMS, and build-info.txt.
REMOTE_DIR is a new, dedicated device directory; it must not already exist.
EOF
}

[[ $# -eq 3 ]] || {
	usage
	exit 2
}

device="$1"
artifact_dir="$2"
remote_dir="$3"

[[ "$remote_dir" == /* && "$remote_dir" != *[[:space:]]* ]] || {
	printf 'device runtime probes: REMOTE_DIR must be an absolute path without whitespace: %s\n' "$remote_dir" >&2
	exit 2
}

command -v ssh >/dev/null 2>&1 || {
	printf 'device runtime probes: ssh is unavailable\n' >&2
	exit 1
}
command -v scp >/dev/null 2>&1 || {
	printf 'device runtime probes: scp is unavailable\n' >&2
	exit 1
}
command -v sha256sum >/dev/null 2>&1 || {
	printf 'device runtime probes: sha256sum is unavailable\n' >&2
	exit 1
}

script_dir="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
repo_root="$(cd -- "$script_dir/../.." && pwd)"

if [[ "$artifact_dir" != /* ]]; then
	artifact_dir="$repo_root/$artifact_dir"
fi
artifact_dir="$(cd -- "$artifact_dir" && pwd)"

probes=(
	native-c-probe
	go120-probe
	go120-cgo-probe
	go126-probe
	go126-cgo-probe
)

for required in SHA256SUMS build-info.txt; do
	[[ -f "$artifact_dir/$required" ]] || {
		printf 'device runtime probes: missing %s in %s\n' "$required" "$artifact_dir" >&2
		exit 1
	}
done

for probe in "${probes[@]}"; do
	[[ -f "$artifact_dir/$probe" ]] || {
		printf 'device runtime probes: missing %s in %s\n' "$probe" "$artifact_dir" >&2
		exit 1
	}
done

(cd "$artifact_dir" && sha256sum -c SHA256SUMS)

ssh "$device" /usr/bin/bash -s -- "$remote_dir" <<'REMOTE'
set -euo pipefail
remote_dir="$1"

test ! -e "$remote_dir" || {
	printf 'device runtime probes: refusing existing remote directory: %s\n' "$remote_dir" >&2
	exit 1
}

mkdir "$remote_dir"
test -x /usr/bin/ldid || {
	printf 'device runtime probes: /usr/bin/ldid is unavailable\n' >&2
	exit 1
}
test -x /usr/bin/sha256sum || {
	printf 'device runtime probes: /usr/bin/sha256sum is unavailable\n' >&2
	exit 1
}
REMOTE

scp \
	"$artifact_dir/SHA256SUMS" \
	"$artifact_dir/build-info.txt" \
	"$artifact_dir/native-c-probe" \
	"$artifact_dir/go120-probe" \
	"$artifact_dir/go120-cgo-probe" \
	"$artifact_dir/go126-probe" \
	"$artifact_dir/go126-cgo-probe" \
	"$repo_root/scripts/ios/device-entitlements-no-container.plist" \
	"$device:$remote_dir/"

ssh "$device" /usr/bin/bash -s -- "$remote_dir" <<'REMOTE'
set +e
remote_dir="$1"
cd "$remote_dir" || exit 1

printf '%s\n' '--- device artifact verification ---'
/usr/bin/sha256sum -c SHA256SUMS
verify_status=$?
printf 'CHECKSUM_STATUS=%s\n' "$verify_status"
[[ "$verify_status" -eq 0 ]] || exit "$verify_status"

printf '%s\n' '--- device signing metadata ---'
printf 'ENTITLEMENT_FIXTURE_SHA256='
/usr/bin/sha256sum device-entitlements-no-container.plist | /usr/bin/awk '{print $1}'
printf '%s\n' 'LDID_VERSION:'
/usr/bin/ldid 2>&1 | sed -n '1p'

: > device-runtime-results.txt
for probe in native-c-probe go120-probe go120-cgo-probe go126-probe go126-cgo-probe; do
	chmod 755 "$probe"
	/usr/bin/bash -c '"$1"; status=$?; exit "$status"' device-run "./$probe" >"original-$probe.stdout" 2>"original-$probe.stderr"
	original_status=$?
	accepted="accepted-$probe"
	cp "$probe" "$accepted"
	/usr/bin/ldid -Sdevice-entitlements-no-container.plist "$accepted" >"$accepted.sign.stdout" 2>"$accepted.sign.stderr"
	sign_status=$?
	/usr/bin/bash -c '"$1"; status=$?; exit "$status"' device-run "./$accepted" >"$accepted.stdout" 2>"$accepted.stderr"
	accepted_status=$?
	{
		printf 'PROBE=%s\n' "$probe"
		printf 'ORIGINAL_EXIT=%s\n' "$original_status"
		printf 'ORIGINAL_STDOUT='; tr '\n' '|' <"original-$probe.stdout"; printf '\n'
		printf 'ORIGINAL_STDERR='; tr '\n' '|' <"original-$probe.stderr"; printf '\n'
		printf 'SIGN_EXIT=%s\n' "$sign_status"
		printf 'ACCEPTED_EXIT=%s\n' "$accepted_status"
		printf 'ACCEPTED_STDOUT='; tr '\n' '|' <"$accepted.stdout"; printf '\n'
		printf 'ACCEPTED_STDERR='; tr '\n' '|' <"$accepted.stderr"; printf '\n'
		printf 'ACCEPTED_SHA256='; /usr/bin/sha256sum "$accepted" | /usr/bin/awk '{print $1}'
		printf '%s\n' 'ACCEPTED_SIGNATURE:'
		/usr/bin/ldid -h "$accepted" 2>&1 | /usr/bin/grep -E 'CodeDirectory|CDHash|Entitlements'
		printf '%s\n' '---'
	} | tee -a device-runtime-results.txt
done

exit 0
REMOTE

scp "$device:$remote_dir/device-runtime-results.txt" "$artifact_dir/"
printf 'device runtime probe results: %s\n' "$artifact_dir/device-runtime-results.txt"
