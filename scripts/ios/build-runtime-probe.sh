#!/usr/bin/env bash

set -euo pipefail

script_dir="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
repo_root="$(cd -- "$script_dir/../.." && pwd)"
output_path="${1:-$repo_root/build/ios/runtime-probe}"
source_path="${2:-tools/ios-runtime-probes/go/main.go}"

if [[ "$output_path" != /* ]]; then
	output_path="$repo_root/$output_path"
fi
if [[ "$source_path" != /* ]]; then
	source_path="$repo_root/$source_path"
fi

[[ -f "$source_path" ]] || {
	printf 'iOS runtime probe: source file does not exist: %s\n' "$source_path" >&2
	exit 1
}

wrapper="$repo_root/scripts/ios/clang-wrapper"
[[ -x "$wrapper" ]] || {
	printf 'iOS runtime probe: compiler wrapper is not executable: %s\n' "$wrapper" >&2
	exit 1
}

mkdir -p "$(dirname -- "$output_path")"
cd "$repo_root"

export GOOS=ios
export GOARCH=arm64
export CGO_ENABLED=1
export GO111MODULE=off
export IOS_DEPLOYMENT_TARGET="${IOS_DEPLOYMENT_TARGET:-12.0}"
export CC="$wrapper"

go build \
	-trimpath \
	-buildvcs=false \
	-buildmode=exe \
	-ldflags=-linkmode=external \
	-o "$output_path" \
	"$source_path"

printf 'iOS runtime probe built: %s\n' "$output_path"
