#!/usr/bin/env bash

set -euo pipefail

probe_dir="${1:?usage: inspect-runtime-probes.sh PROBE_DIR INSPECTION_FILE PROBE...}"
inspection_path="${2:?usage: inspect-runtime-probes.sh PROBE_DIR INSPECTION_FILE PROBE...}"
shift 2

mkdir -p "$(dirname -- "$inspection_path")"
: >"$inspection_path"

fail() {
	printf 'iOS runtime probe inspection: %s\n' "$*" >&2
	exit 1
}

for probe_name in "$@"; do
	probe_path="$probe_dir/$probe_name"

	if [[ ! -f "$probe_path" ]]; then
		{
			printf '===== %s =====\n' "$probe_name"
			printf 'STATUS=MISSING\n\n'
		} >>"$inspection_path"
		continue
	fi

	file_output="$(file "$probe_path")"
	[[ "$file_output" == *'Mach-O 64-bit executable arm64'* ]] || {
		fail "$probe_name is not a physical arm64 Mach-O: $file_output"
	}
	[[ "$file_output" != *'simulator'* ]] || fail "$probe_name is a simulator binary: $file_output"

	header_output="$(otool -hv "$probe_path")"
	load_commands="$(otool -l "$probe_path")"
	linked_libraries="$(otool -L "$probe_path")"

	if grep -q 'cmd LC_BUILD_VERSION' <<<"$load_commands"; then
		version_block="$(awk '
			/cmd LC_BUILD_VERSION/ { capture=1; lines=0 }
			capture { print; lines++ }
			capture && lines >= 8 { capture=0 }
		' <<<"$load_commands")"
		grep -Eq 'platform[[:space:]]+(IOS|2)([[:space:]]|$)' <<<"$version_block" || {
			fail "$probe_name does not declare physical iOS platform 2"
		}
		grep -Eq 'minos[[:space:]]+12\.0([[:space:]]|$)' <<<"$version_block" || {
			fail "$probe_name does not declare iOS minimum 12.0"
		}
	elif grep -q 'cmd LC_VERSION_MIN_IPHONEOS' <<<"$load_commands"; then
		version_block="$(awk '
			/cmd LC_VERSION_MIN_IPHONEOS/ { capture=1; lines=0 }
			capture { print; lines++ }
			capture && lines >= 6 { capture=0 }
		' <<<"$load_commands")"
		grep -Eq 'version[[:space:]]+12\.0([[:space:]]|$)' <<<"$version_block" || {
			fail "$probe_name does not declare iOS minimum 12.0"
		}
	else
		fail "$probe_name has no physical iPhoneOS deployment load command"
	fi

	if grep -Eiq 'IOSSIMULATOR|IPHONESIMULATOR|platform[[:space:]]+(SIMULATOR|7)([[:space:]]|$)|iphonesimulator' <<<"$version_block"; then
		fail "$probe_name contains simulator deployment metadata"
	fi
	if grep -Eq '/(opt/homebrew|usr/local)/.*\.dylib' <<<"$linked_libraries"; then
		fail "$probe_name contains a host dynamic library dependency"
	fi

	codesign --force --sign - --timestamp=none "$probe_path" >/dev/null
	codesign_output="$(codesign --display --verbose=4 "$probe_path" 2>&1)"
	codesign --verify --verbose=4 "$probe_path" >/dev/null 2>&1 || {
		fail "$probe_name failed ad-hoc signature verification"
	}

	{
		printf '===== %s =====\n' "$probe_name"
		printf 'STATUS=BUILT_AND_INSPECTED\n'
		printf 'FILE=%s\n' "$file_output"
		printf '%s\n' 'MACHO_HEADER:'
		printf '%s\n' "$header_output"
		printf '%s\n' 'IPHONEOS_DEPLOYMENT:'
		printf '%s\n' "$version_block"
		printf '%s\n' 'LINKED_LIBRARIES:'
		printf '%s\n' "$linked_libraries"
		printf '%s\n' 'CODE_SIGNATURE:'
		printf '%s\n' "$codesign_output"
		printf '\n'
	} >>"$inspection_path"
done
