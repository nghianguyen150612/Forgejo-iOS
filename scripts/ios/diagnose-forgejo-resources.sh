#!/bin/sh
# Read-only Forgejo process resource diagnostic for jailbroken iOS/iPadOS.

usage() {
    printf '%s\n' "Usage: $0 [PID]" >&2
    printf '%s\n' '  PID is optional; without it, the first process named forgejo is inspected.' >&2
}

if [ "$#" -gt 1 ]; then
    usage
    exit 2
fi

pid=${1-}
if [ -n "$pid" ]; then
    case $pid in
        *[!0-9]* )
            printf 'RAM/CPU: unavailable (PID must be numeric: %s)\n' "$pid"
            exit 0
            ;;
    esac
else
    if ! command -v ps >/dev/null 2>&1; then
        printf '%s\n' 'RAM/CPU: unavailable (ps is not installed)'
        exit 0
    fi
    pid=$(ps -axo pid=,comm= 2>/dev/null | awk '$2 ~ /(^|\/)forgejo$/ { print $1; exit }')
    if [ -z "$pid" ]; then
        printf '%s\n' 'RAM/CPU: unavailable (Forgejo process was not found)'
        exit 0
    fi
fi

if ! command -v ps >/dev/null 2>&1; then
    printf '%s\n' 'RAM/CPU: unavailable (ps is not installed)'
    exit 0
fi

if ! details=$(ps -p "$pid" -o pid= -o rss= -o %cpu= -o comm= 2>/dev/null); then
    printf 'RAM/CPU: unavailable (process %s could not be queried)\n' "$pid"
    exit 0
fi

if [ -z "$details" ]; then
    printf 'RAM/CPU: unavailable (process %s is not running)\n' "$pid"
    exit 0
fi

printf '%s\n' 'Forgejo process resources (read-only snapshot)'
printf 'PID: %s\n' "$pid"
printf '%s\n' "$details" | awk '{
    printf "RSS: %s KB\nCPU: %s%%\nCommand: %s\n", $2, $3, $4
}'
printf '%s\n' 'Note: RSS and CPU are process-local ps values; CPU is not whole-device usage.'
