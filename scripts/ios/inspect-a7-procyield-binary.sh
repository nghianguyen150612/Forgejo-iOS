#!/usr/bin/env bash

set -euo pipefail

binary_path="${1:?usage: inspect-a7-procyield-binary.sh BINARY OUTPUT_FILE}"
output_path="${2:?usage: inspect-a7-procyield-binary.sh BINARY OUTPUT_FILE}"

fail() {
	printf 'A7 runtime binary inspection: %s\n' "$*" >&2
	exit 1
}

[[ -f "$binary_path" ]] || fail "binary does not exist: $binary_path"
command -v file >/dev/null 2>&1 || fail 'file is unavailable'
command -v otool >/dev/null 2>&1 || fail 'otool is unavailable'
command -v perl >/dev/null 2>&1 || fail 'perl is unavailable'

file_output="$(file "$binary_path")"
[[ "$file_output" == *'Mach-O 64-bit'* && "$file_output" == *'arm64'* && "$file_output" == *'executable'* ]] || {
	fail "not a physical arm64 Mach-O: $file_output"
}

load_commands="$(otool -l "$binary_path")"
text_addr_hex="$(awk '
	$1 == "sectname" && $2 == "__text" { in_text=1; next }
	in_text && $1 == "addr" { print $2; exit }
' <<<"$load_commands")"
text_size_hex="$(awk '
	$1 == "sectname" && $2 == "__text" { in_text=1; next }
	in_text && $1 == "size" { print $2; exit }
' <<<"$load_commands")"
text_file_offset="$(awk '
	$1 == "sectname" && $2 == "__text" { in_text=1; next }
	in_text && $1 == "offset" { print $2; exit }
' <<<"$load_commands")"

[[ -n "$text_addr_hex" && -n "$text_size_hex" && -n "$text_file_offset" ]] || {
	fail 'could not locate __text section metadata'
}

# Exact little-endian bytes emitted by the GOOS_ios procyieldAsm fallback:
# MOVWU 8(RSP), R0; CBZ R0, done; YIELD; SUBW $1, R0, R0;
# CBNZ R0, loop; RET.
match_offsets="$(perl -0777 -ne '
	my $needle = pack("C*",
		0xe0, 0x0b, 0x40, 0xb9,
		0x80, 0x00, 0x00, 0xb4,
		0x3f, 0x20, 0x03, 0xd5,
		0x00, 0x04, 0x00, 0x51,
		0xc0, 0xff, 0xff, 0xb5,
		0xc0, 0x03, 0x5f, 0xd6,
	);
	my $start = 0;
	while (1) {
		my $offset = index($_, $needle, $start);
		last if $offset < 0;
		print "$offset\n";
		$start = $offset + 1;
	}
' "$binary_path")"
match_count="$(printf '%s\n' "$match_offsets" | awk 'NF { count++ } END { print count + 0 }')"
[[ "$match_count" == '1' ]] || fail "expected one exact fallback body in __text, found $match_count"
match_offset="$match_offsets"

text_addr=$((text_addr_hex))
text_size=$((text_size_hex))
text_end=$((text_file_offset + text_size))
match_end=$((match_offset + 24))
(( match_offset >= text_file_offset && match_end <= text_end )) || {
	fail "fallback body is outside __text: file_offset=$match_offset text=$text_file_offset..$text_end"
}

virtual_address=$((text_addr + match_offset - text_file_offset))
mkdir -p "$(dirname -- "$output_path")"
{
	printf 'STATUS=BUILT_AND_INSPECTED\n'
	printf 'PATH=%s\n' "$binary_path"
	printf 'FILE=%s\n' "$file_output"
	printf 'TEXT_FILE_OFFSET=%s\n' "$text_file_offset"
	printf 'TEXT_VM_ADDRESS=%s\n' "$text_addr_hex"
	printf 'FALLBACK_FILE_OFFSET=%s\n' "$match_offset"
	printf 'FALLBACK_VM_ADDRESS=0x%x\n' "$virtual_address"
	printf 'FALLBACK_BYTES=MOVWU,CBZ,YIELD,SUBW,CBNZ,RET\n'
	printf 'CNTVCT_EL0=absent from selected fallback body\n'
	printf 'INSPECTION=unique exact little-endian fallback signature in final stripped __text\n'
} >"$output_path"

printf 'A7 fallback runtime body inspected in final binary: %s (0x%x)\n' "$binary_path" "$virtual_address"
