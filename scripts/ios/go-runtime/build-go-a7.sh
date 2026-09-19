#!/usr/bin/env bash
set -euo pipefail
script_dir="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
repo_root="$(cd -- "$script_dir/../../.." && pwd)"
build_root="${1:-$repo_root/build/ios/go1.26.7-a7}"
if [[ "$build_root" != /* ]]; then
	build_root="$repo_root/$build_root"
fi
case "$build_root" in
	"$repo_root/build/ios"/*) ;;
	*)
		printf 'Go A7 toolchain: refusing build root outside build/ios: %s\n' "$build_root" >&2
		exit 2
		;;
esac
source_version='go1.26.7'
source_url='https://go.dev/dl/go1.26.7.src.tar.gz'
source_archive_sha256='0ed24eac755105085b89fe9cabc2742b91a0ad7b94b59d3ad364918ebc8956ad'
asm_arm64_sha256='c2d54a06306c90a1d6ab666101c563056578a84c9b11f50575874af9c54b2133'
stubs_sha256='0572c8b87cdbd975e8fddc5e8e84240d6397445589641035f0ce95e6676ee90e'
version_sha256='89f723ad27054a2ccc7c22f2a974886f3077f64623a231297fcea2e74a73a782'
patch_path="$script_dir/go1.26.7-a7-procyield.patch"
download_dir="$build_root/download"
archive_path="$download_dir/${source_version}.src.tar.gz"
goroot_path="$build_root/goroot"
provenance_path="$build_root/provenance.env"
fail() {
	printf 'Go A7 toolchain: %s\n' "$*" >&2
	exit 1
}
hash_file() {
	local path="$1"
	if command -v shasum >/dev/null 2>&1; then
		shasum -a 256 "$path" | awk '{print $1}'
	elif command -v sha256sum >/dev/null 2>&1; then
		sha256sum "$path" | awk '{print $1}'
	else
		fail 'neither shasum nor sha256sum is available'
	fi
}
verify_hash() {
	local expected="$1"
	local path="$2"
	local actual
	actual="$(hash_file "$path")"
	[[ "$actual" == "$expected" ]] || fail "SHA-256 mismatch for $path: expected $expected, got $actual"
	printf 'verified sha256=%s path=%s\n' "$actual" "$path"
}
[[ -f "$patch_path" ]] || fail "missing runtime patch: $patch_path"
[[ -f "$repo_root/go.mod" ]] || fail "repository root is not Forgejo: $repo_root"
mkdir -p "$download_dir"
if [[ ! -f "$archive_path" ]]; then
	command -v curl >/dev/null 2>&1 || fail 'curl is required to download the official Go source'
	curl -fL --retry 3 --connect-timeout 15 --max-time 300 -o "$archive_path" "$source_url"
fi
verify_hash "$source_archive_sha256" "$archive_path"
# Recreate only generated source/toolchain directories. Prompt evidence under build/ios remains untouched.
if [[ -e "$goroot_path" ]]; then
	rm -rf -- "$goroot_path"
fi
mkdir -p "$goroot_path"
tar -xzf "$archive_path" -C "$goroot_path" --strip-components=1
version_value="$(sed -n '1p' "$goroot_path/VERSION")"
[[ "$version_value" == "$source_version" ]] || fail "source VERSION is $version_value, expected $source_version"
verify_hash "$asm_arm64_sha256" "$goroot_path/src/runtime/asm_arm64.s"
verify_hash "$stubs_sha256" "$goroot_path/src/runtime/stubs.go"
verify_hash "$version_sha256" "$goroot_path/VERSION"
patch_sha256="$(hash_file "$patch_path")"
goroot_relative="${goroot_path#"$repo_root"/}"
[[ "$goroot_relative" != "$goroot_path" && "$goroot_relative" != *'..'* ]] || fail 'generated GOROOT is not safely below the repository root'
git -C "$repo_root" apply --check --unidiff-zero --directory="$goroot_relative" "$patch_path" || fail 'the version-specific runtime patch does not apply cleanly'
git -C "$repo_root" apply --unidiff-zero --directory="$goroot_relative" "$patch_path"
procyield_source="$goroot_path/src/runtime/asm_arm64.s"
procyield_count="$(awk '/^TEXT runtime·procyieldAsm\(SB\)/ { n++ } END { print n + 0 }' "$procyield_source")"
[[ "$procyield_count" == '1' ]] || fail 'expected exactly one runtime.procyieldAsm definition after patch'
ios_branch="$(awk '
/^TEXT runtime·procyieldAsm\(SB\)/ { in_fn=1 }
in_fn && /^#ifdef GOOS_ios$/ { in_ios=1; next }
in_ios && /^#else$/ { exit }
in_ios { print }
' "$procyield_source")"
generic_branch="$(awk '
/^TEXT runtime·procyieldAsm\(SB\)/ { in_fn=1 }
in_fn && /^#else$/ && !in_generic { in_generic=1; next }
in_generic && /^#endif$/ { exit }
in_generic { print }
' "$procyield_source")"
[[ "$ios_branch" == *'YIELD'* && "$ios_branch" == *'SUBW'* && "$ios_branch" == *'CBNZ'* ]] || fail 'iOS procyield branch is not the expected bounded YIELD loop'
[[ "$ios_branch" != *'CNTVCT_EL0'* ]] || fail 'CNTVCT_EL0 remains in the selected iOS procyield branch'
[[ "$generic_branch" == *'CNTVCT_EL0'* ]] || fail 'stock non-iOS procyield branch was not retained'
bootstrap_go="${GO_BOOTSTRAP:-go}"
command -v "$bootstrap_go" >/dev/null 2>&1 || fail "bootstrap Go is unavailable: $bootstrap_go"
bootstrap_version="$("$bootstrap_go" version)"
bootstrap_goroot="$("$bootstrap_go" env GOROOT)"
[[ -d "$bootstrap_goroot" ]] || fail "bootstrap GOROOT does not exist: $bootstrap_goroot"
host_os="$(uname -s | tr '[:upper:]' '[:lower:]')"
host_arch="$(uname -m)"
printf '%s\n' 'building isolated Go toolchain; bootstrap variables are host-local'
(
	cd "$goroot_path/src"
	unset GOOS GOARCH CGO_ENABLED GOFLAGS GOTOOLCHAIN GOENV
	GOROOT_BOOTSTRAP="$bootstrap_goroot" ./make.bash
)
toolchain_go="$goroot_path/bin/go"
[[ -x "$toolchain_go" ]] || fail "toolchain build did not produce $toolchain_go"
toolchain_version="$("$toolchain_go" version)"
[[ "$toolchain_version" == *"$source_version"* ]] || fail "built toolchain reports unexpected version: $toolchain_version"
mkdir -p "$build_root"
{
	printf 'P7_RUNTIME=go1.26.7-a7\n'
	printf 'SOURCE_VERSION=%s\n' "$source_version"
	printf 'SOURCE_URL=%s\n' "$source_url"
	printf 'SOURCE_ARCHIVE_SHA256=%s\n' "$source_archive_sha256"
	printf 'ASM_ARM64_SHA256=%s\n' "$asm_arm64_sha256"
	printf 'STUBS_SHA256=%s\n' "$stubs_sha256"
	printf 'VERSION_SHA256=%s\n' "$version_sha256"
	printf 'PATCH_SHA256=%s\n' "$patch_sha256"
	printf 'BOOTSTRAP_GO_VERSION=%s\n' "$bootstrap_version"
	printf 'HOST_OS=%s\n' "$host_os"
	printf 'HOST_ARCH=%s\n' "$host_arch"
	printf 'GOROOT=%s\n' "$goroot_path"
	printf 'GO_VERSION=%s\n' "$toolchain_version"
	printf 'PATCH_SCOPE=GOOS_ios GOARCH_arm64 runtime.procyieldAsm\n'
	printf 'PATCH_IMPLEMENTATION=bounded YIELD SUBW CBNZ loop; stock timer path retained outside GOOS_ios\n'
} >"$provenance_path"
printf 'Go A7 toolchain built: %s\n' "$toolchain_version"
printf 'GOROOT=%s\n' "$goroot_path"
printf 'PROVENANCE=%s\n' "$provenance_path"
