#!/usr/bin/env bash

set -euo pipefail

script_dir="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
repo_root="$(cd -- "$script_dir/../.." && pwd)"
output_path="${1:-$repo_root/build/ios/native-c-probe}"

if [[ "$output_path" != /* ]]; then
	output_path="$repo_root/$output_path"
fi

mkdir -p "$(dirname -- "$output_path")"
cd "$repo_root"

command -v xcrun >/dev/null 2>&1 || {
	printf 'iOS native C probe: xcrun is unavailable; run from an active Xcode environment\n' >&2
	exit 1
}

sdk_path="$(xcrun --sdk iphoneos --show-sdk-path)"
clang_path="$(xcrun --sdk iphoneos --find clang)"

[[ -d "$sdk_path" ]] || {
	printf 'iOS native C probe: iphoneos SDK path does not exist: %s\n' "$sdk_path" >&2
	exit 1
}
[[ -x "$clang_path" ]] || {
	printf 'iOS native C probe: clang is not executable: %s\n' "$clang_path" >&2
	exit 1
}

"$clang_path" \
	-arch arm64 \
	-target arm64-apple-ios12.0 \
	-isysroot "$sdk_path" \
	-mios-version-min=12.0 \
	-O2 \
	-Wall \
	-Wextra \
	-o "$output_path" \
	 tools/ios-runtime-probes/native-c/main.c

printf 'iOS native C probe built: %s\n' "$output_path"
