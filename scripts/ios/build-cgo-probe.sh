#!/usr/bin/env bash

set -euo pipefail

script_dir="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
repo_root="$(cd -- "$script_dir/../.." && pwd)"
output_path="${1:-$repo_root/build/ios/ios-cgo-probe}"

if [[ "$output_path" != /* ]]; then
	output_path="$repo_root/$output_path"
fi

wrapper="$repo_root/scripts/ios/clang-wrapper"
[[ -x "$wrapper" ]] || {
	printf 'iOS CGO probe: compiler wrapper is not executable: %s\n' "$wrapper" >&2
	exit 1
}

mkdir -p "$(dirname -- "$output_path")"
cd "$repo_root"

export GOOS=ios
export GOARCH=arm64
export CGO_ENABLED=1
export IOS_DEPLOYMENT_TARGET="${IOS_DEPLOYMENT_TARGET:-12.0}"
export CC="$wrapper"

go build \
	-mod=readonly \
	-trimpath \
	-buildvcs=false \
	-buildmode=exe \
	-ldflags=-linkmode=external \
	-o "$output_path" \
	./tools/ios-cgo-probe

printf 'iOS CGO probe built: %s\n' "$output_path"
