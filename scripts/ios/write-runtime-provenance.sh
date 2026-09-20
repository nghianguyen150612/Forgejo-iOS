#!/usr/bin/env bash

set -euo pipefail

if [[ "$#" -lt 2 || "$#" -gt 3 ]]; then
	cat >&2 <<'USAGE'
usage: write-runtime-provenance.sh FORGEJO_BINARY OUTPUT_FILE [TARGET_DEVICE_CLASS]
USAGE
	exit 2
fi

binary_path="$1"
output_path="$2"
target_device_class="${3:-${FORGEJO_IOS_TARGET_CLASS:-a7-ios12}}"

if [[ ! -x "$binary_path" ]]; then
	printf 'runtime provenance: binary is not executable: %s\n' "$binary_path" >&2
	exit 1
fi

binary_dir="$(cd -- "$(dirname -- "$binary_path")" && pwd)"
build_info="${FORGEJO_IOS_BUILD_INFO:-}"
if [[ -z "$build_info" ]]; then
	for candidate in \
		"$binary_dir/forgejo-ios-a7-build-info.txt" \
		"$binary_dir/forgejo-ios-build-info.txt" \
		"${binary_path}-build-info.txt" \
		"build/ios/go1.26.7-a7/provenance.env"; do
		if [[ -r "$candidate" ]]; then
			build_info="$candidate"
			break
		fi
	done
fi

metadata_value() {
	local key="$1"
	if [[ -n "$build_info" && -r "$build_info" ]]; then
		awk -F= -v key="$key" '$1 == key { sub(/^[^=]*=/, ""); print; exit }' "$build_info"
	fi
}

forgejo_version="${FORGEJO_IOS_VERSION:-unknown}"
git_commit="${FORGEJO_IOS_GIT_COMMIT:-$(metadata_value 'Git commit')}"
if [[ -z "$git_commit" && -d .git ]]; then
	git_commit="$(git rev-parse HEAD 2>/dev/null || true)"
fi
runtime="$(metadata_value P7_RUNTIME)"
patch_sha="$(metadata_value PATCH_SHA256)"
build_tags="${FORGEJO_IOS_BUILD_TAGS:-bindata timetzdata sqlite sqlite_unlock_notify}"

[[ -n "$git_commit" ]] || git_commit='unknown'
[[ -n "$runtime" ]] || runtime='unknown'
[[ -n "$patch_sha" ]] || patch_sha='unknown'

output_dir="$(dirname -- "$output_path")"
mkdir -p "$output_dir"
tmp_path="$(mktemp "$output_path.tmp.XXXXXX")"
trap 'rm -f "$tmp_path"' EXIT

{
	printf 'FORMAT_VERSION=1\n'
	printf 'FORGEJO_VERSION=%s\n' "$forgejo_version"
	printf 'GIT_COMMIT=%s\n' "$git_commit"
	printf 'GO_RUNTIME=%s\n' "$runtime"
	printf 'RUNTIME_PATCH_SHA256=%s\n' "$patch_sha"
	printf 'BUILD_TAGS=%s\n' "$build_tags"
	printf 'TARGET_GOOS=ios\n'
	printf 'TARGET_GOARCH=arm64\n'
	printf 'TARGET_DEVICE_CLASS=%s\n' "$target_device_class"
	printf 'RUNTIME_PATCH_SCOPE=GOOS_ios GOARCH_arm64 runtime.procyieldAsm\n'
} >"$tmp_path"

mv "$tmp_path" "$output_path"
trap - EXIT
printf 'runtime provenance written: %s\n' "$output_path"
