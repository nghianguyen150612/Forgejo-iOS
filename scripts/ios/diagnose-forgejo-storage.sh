#!/bin/sh
# Read-only Forgejo data/storage diagnostic for jailbroken iOS/iPadOS.

usage() {
    printf '%s\n' "Usage: $0 [FORGEJO_DATA_DIR]" >&2
    printf '%s\n' '  The directory is read only; default is $FORGEJO_IOS_DATA_DIR or /var/mobile/Library/Forgejo.' >&2
}

if [ "$#" -gt 1 ]; then
    usage
    exit 2
fi

root=${1-${FORGEJO_IOS_DATA_DIR-/var/mobile/Library/Forgejo}}
if [ ! -d "$root" ]; then
    printf 'Storage: unavailable (directory does not exist: %s)\n' "$root"
    exit 0
fi

printf 'Forgejo storage (read-only snapshot)\nRoot: %s\n' "$root"

if command -v du >/dev/null 2>&1; then
    total=$(du -sk "$root" 2>/dev/null | awk 'NR == 1 { print $1 }')
    if [ -n "$total" ]; then
        printf 'Total: %s KB\n' "$total"
    else
        printf '%s\n' 'Total: unavailable (du could not read the directory)'
    fi
    for component in data custom repositories log logs; do
        if [ -e "$root/$component" ]; then
            size=$(du -sk "$root/$component" 2>/dev/null | awk 'NR == 1 { print $1 }')
            if [ -n "$size" ]; then
                printf '%s: %s KB\n' "$component" "$size"
            else
                printf '%s: unavailable\n' "$component"
            fi
        fi
    done
else
    printf '%s\n' 'Total: unavailable (du is not installed)'
fi

if command -v df >/dev/null 2>&1; then
    filesystem=$(df -k "$root" 2>/dev/null | awk 'NR == 2 { print $4 }')
    if [ -n "$filesystem" ]; then
        printf 'Filesystem available: %s KB\n' "$filesystem"
    else
        printf '%s\n' 'Filesystem available: unavailable (df could not read the filesystem)'
    fi
else
    printf '%s\n' 'Filesystem available: unavailable (df is not installed)'
fi

printf '%s\n' 'Note: sizes depend on du block units and may include logs, repositories, WAL/SHM, and other files.'
