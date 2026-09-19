#!/usr/bin/env bash

set -euo pipefail

usage() {
	cat >&2 <<'EOF'
usage: build-forgejo.sh OUTPUT_PATH [TAGS]

Builds the Forgejo root package through the upstream Makefile backend target.
The output path must be a generated artifact path, normally under build/ios.
EOF
}

[[ $# -ge 1 && $# -le 2 ]] || {
	usage
	exit 2
}

script_dir="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
repo_root="$(cd -- "$script_dir/../.." && pwd)"
output_path="$1"
tags="${2:-bindata timetzdata sqlite sqlite_unlock_notify}"

if [[ "$output_path" != /* ]]; then
	output_path="$repo_root/$output_path"
fi

[[ "${GOOS:-ios}" == 'ios' ]] || {
	printf 'Forgejo iOS build: GOOS must be ios\n' >&2
	exit 1
}
[[ "${GOARCH:-arm64}" == 'arm64' ]] || {
	printf 'Forgejo iOS build: GOARCH must be arm64\n' >&2
	exit 1
}
[[ "${CGO_ENABLED:-1}" == '1' ]] || {
	printf 'Forgejo iOS build: CGO_ENABLED must be 1\n' >&2
	exit 1
}
[[ "${IOS_DEPLOYMENT_TARGET:-12.0}" == '12.0' ]] || {
	printf 'Forgejo iOS build: IOS_DEPLOYMENT_TARGET must be 12.0\n' >&2
	exit 1
}

command -v xcrun >/dev/null 2>&1 || {
	printf 'Forgejo iOS build: xcrun is unavailable\n' >&2
	exit 1
}
command -v make >/dev/null 2>&1 || {
	printf 'Forgejo iOS build: make is unavailable\n' >&2
	exit 1
}
command -v go >/dev/null 2>&1 || {
	printf 'Forgejo iOS build: go is unavailable\n' >&2
	exit 1
}

wrapper="$repo_root/scripts/ios/clang-wrapper"
[[ -x "$wrapper" ]] || {
	printf 'Forgejo iOS build: compiler wrapper is not executable: %s\n' "$wrapper" >&2
	exit 1
}

go_bin="$(go env GOROOT)/bin/go"
[[ -x "$go_bin" ]] || {
	printf 'Forgejo iOS build: Go toolchain executable is unavailable: %s\n' "$go_bin" >&2
	exit 1
}

sdk_path="$(xcrun --sdk iphoneos --show-sdk-path)"
clang_path="$(xcrun --sdk iphoneos --find clang)"
[[ -d "$sdk_path" ]] || {
	printf 'Forgejo iOS build: iphoneos SDK path does not exist: %s\n' "$sdk_path" >&2
	exit 1
}
[[ -x "$clang_path" ]] || {
	printf 'Forgejo iOS build: clang is not executable: %s\n' "$clang_path" >&2
	exit 1
}

mkdir -p "$(dirname -- "$output_path")"
cd "$repo_root"

forgejo_version="${FORGEJO_VERSION:-}"
if [[ -z "$forgejo_version" ]]; then
	forgejo_version="$(make --no-print-directory -s show-version-full TAGS="$tags")"
fi
[[ "$forgejo_version" =~ ^[0-9]+\.[0-9]+\.[0-9]+([-.+]|$) ]] || {
	printf 'Forgejo iOS build: Make produced an invalid semantic version: %s\n' "$forgejo_version" >&2
	printf 'Forgejo iOS build: fetch the repository tags before building\n' >&2
	exit 1
}
forgejo_version_api="${FORGEJO_VERSION_API:-$forgejo_version}"
[[ "$forgejo_version_api" =~ ^[0-9]+\.[0-9]+\.[0-9]+([-.+]|$) ]] || {
	printf 'Forgejo iOS build: invalid API version: %s\n' "$forgejo_version_api" >&2
	exit 1
}
make_version="$(make --version | sed -n '1p')"
extra_go_flags="${EXTRA_GOFLAGS:--buildvcs=false}"
ldflags="-linkmode external -s -w"
ldflags+=" -X \"main.ReleaseVersion=$forgejo_version\""
ldflags+=" -X \"main.MakeVersion=$make_version\""
ldflags+=" -X \"main.Version=$forgejo_version\""
ldflags+=" -X \"main.Tags=$tags\""
ldflags+=" -X \"main.ForgejoVersion=$forgejo_version_api\""

cgo_cflags="${CGO_CFLAGS:-} -DSQLITE_MAX_VARIABLE_NUMBER=32766"

export GOOS=ios
export GOARCH=arm64
export CGO_ENABLED=1
export GOTOOLCHAIN=local
export IOS_DEPLOYMENT_TARGET=12.0
export CC="$wrapper"

make --no-print-directory \
	GO="$go_bin" \
	CC="$wrapper" \
	CGO_CFLAGS="$cgo_cflags" \
	LDFLAGS="$ldflags" \
	FORGEJO_VERSION="$forgejo_version" \
	FORGEJO_VERSION_API="$forgejo_version_api" \
	RELEASE_VERSION="$forgejo_version" \
	EXTRA_GOFLAGS="$extra_go_flags" \
	TAGS="$tags" \
	EXECUTABLE="$output_path" \
	backend

printf 'Forgejo iOS build complete\n'
printf '  output=%s\n' "$output_path"
printf '  tags=%s\n' "$tags"
printf '  version=%s\n' "$forgejo_version"
printf '  api_version=%s\n' "$forgejo_version_api"
printf '  extra_go_flags=%s\n' "$extra_go_flags"
printf '  sdk=%s\n' "$sdk_path"
printf '  clang=%s\n' "$clang_path"
