#!/usr/bin/env bash

set -euo pipefail

binary_path="${1:?usage: inspect-forgejo-binary.sh BINARY INSPECTION_FILE}"
inspection_path="${2:?usage: inspect-forgejo-binary.sh BINARY INSPECTION_FILE}"

fail() {
	printf 'Forgejo iOS binary inspection: %s\n' "$*" >&2
	exit 1
}

[[ -f "$binary_path" ]] || fail "binary does not exist: $binary_path"
file_output="$(file "$binary_path")"
[[ "$file_output" == *'Mach-O 64-bit'* && "$file_output" == *'arm64'* && "$file_output" == *'executable'* ]] || fail "not a physical arm64 Mach-O: $file_output"
[[ "$file_output" != *'simulator'* ]] || fail "simulator binary rejected: $file_output"

header_output="$(otool -hv "$binary_path")"
load_commands="$(otool -l "$binary_path")"
linked_libraries="$(otool -L "$binary_path")"

if grep -q 'cmd LC_BUILD_VERSION' <<<"$load_commands"; then
	version_block="$(awk '
		/cmd LC_BUILD_VERSION/ { capture=1; lines=0 }
		capture { print; lines++ }
		capture && lines >= 8 { capture=0 }
	' <<<"$load_commands")"
	grep -Eq 'platform[[:space:]]+(IOS|2)([[:space:]]|$)' <<<"$version_block" || fail 'LC_BUILD_VERSION is not physical iOS platform 2'
	grep -Eq 'minos[[:space:]]+12\.0([[:space:]]|$)' <<<"$version_block" || fail 'minimum OS is not iOS 12.0'
elif grep -q 'cmd LC_VERSION_MIN_IPHONEOS' <<<"$load_commands"; then
	version_block="$(awk '
		/cmd LC_VERSION_MIN_IPHONEOS/ { capture=1; lines=0 }
		capture { print; lines++ }
		capture && lines >= 6 { capture=0 }
	' <<<"$load_commands")"
	grep -Eq 'version[[:space:]]+12\.0([[:space:]]|$)' <<<"$version_block" || fail 'minimum OS is not iOS 12.0'
else
	fail 'no physical iPhoneOS deployment load command found'
fi

if grep -Eiq 'IOSSIMULATOR|IPHONESIMULATOR|platform[[:space:]]+(SIMULATOR|7)([[:space:]]|$)|iphonesimulator' <<<"$version_block"; then
	fail 'simulator deployment metadata found'
fi
if grep -Eiq '/(opt/homebrew|usr/local|opt/local)/.*\.dylib' <<<"$linked_libraries"; then
	fail 'host-local dynamic library dependency found'
fi

raw_size="$(wc -c <"$binary_path" | tr -d ' ')"
mkdir -p "$(dirname -- "$inspection_path")"
{
	printf 'STATUS=BUILT_AND_INSPECTED\n'
	printf 'PATH=%s\n' "$binary_path"
	printf 'RAW_SIZE=%s\n' "$raw_size"
	printf 'FILE=%s\n' "$file_output"
	printf '%s\n' 'MACHO_HEADER:'
	printf '%s\n' "$header_output"
	printf '%s\n' 'IPHONEOS_DEPLOYMENT:'
	printf '%s\n' "$version_block"
	printf '%s\n' 'LINKED_LIBRARIES:'
	printf '%s\n' "$linked_libraries"
} >"$inspection_path"

printf 'Forgejo iOS binary inspected: %s\n' "$binary_path"
