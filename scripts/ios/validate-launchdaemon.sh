#!/bin/sh
# Validate the generated Forgejo iOS LaunchDaemon configuration without
# loading it into the host or device launchd.
set -eu

die() {
    printf 'ERROR: %s\n' "$*" >&2
    exit 1
}

validate() {
    [ "$#" = 1 ] || die 'usage: validate-launchdaemon.sh PLIST'
    if [ ! -f "$1" ] || [ -L "$1" ]; then
        die 'plist must be a regular file'
    fi
    python3 - "$1" <<'PY'
import os
import plistlib
import re
import stat
import sys

path = sys.argv[1]
try:
    with open(path, "rb") as stream:
        plist = plistlib.load(stream)
except Exception as exc:
    raise SystemExit(f"plist parse failed: {exc}")

if not isinstance(plist, dict):
    raise SystemExit("plist root is not a dictionary")

required = (
    "ProgramArguments",
    "RunAtLoad",
    "KeepAlive",
    "WorkingDirectory",
    "EnvironmentVariables",
    "StandardOutPath",
    "StandardErrorPath",
)
missing = [key for key in required if key not in plist]
if missing:
    raise SystemExit("missing required keys: " + ", ".join(missing))

if plist.get("Label") != "com.forgejo.ios":
    raise SystemExit("unexpected LaunchDaemon label")
if plist.get("RunAtLoad") is not True or plist.get("KeepAlive") is not True:
    raise SystemExit("RunAtLoad and KeepAlive must both be true")

arguments = plist["ProgramArguments"]
if not isinstance(arguments, list) or len(arguments) != 2 or arguments[1] != "service-run":
    raise SystemExit("ProgramArguments must invoke the service-run launcher")
if not isinstance(arguments[0], str) or not arguments[0].endswith("/bin/forgejo-ios"):
    raise SystemExit("ProgramArguments does not point to the managed launcher")

environment = plist["EnvironmentVariables"]
if not isinstance(environment, dict) or environment.get("GOMAXPROCS") != "1":
    raise SystemExit("EnvironmentVariables must include GOMAXPROCS=1")
for key in ("PATH", "HOME", "GOMAXPROCS"):
    if key not in environment:
        raise SystemExit(f"EnvironmentVariables missing {key}")

for key in ("WorkingDirectory", "StandardOutPath", "StandardErrorPath"):
    if not isinstance(plist[key], str) or not plist[key].startswith("/"):
        raise SystemExit(f"{key} must be an absolute path")

def strings(value):
    if isinstance(value, str):
        yield value
    elif isinstance(value, dict):
        for item in value.values():
            yield from strings(item)
    elif isinstance(value, list):
        for item in value:
            yield from strings(item)

joined = "\n".join(strings(plist))
if re.search(r"password|token|private\s+key|BEGIN (RSA|OPENSSH|EC|DSA|PRIVATE) KEY", joined, re.I):
    raise SystemExit("plist contains credential-like material")

mode = stat.S_IMODE(os.stat(path, follow_symlinks=False).st_mode)
if mode != 0o644:
    raise SystemExit(f"plist mode is {mode:o}, expected 644")

print("LaunchDaemon plist validation PASS")
PY
}

self_test() {
    test_root=$(mktemp -d /tmp/forgejo-launchdaemon-test.XXXXXX)
    trap 'rm -rf "$test_root"' 0
    trap 'exit 130' INT
    cat >"$test_root/com.forgejo.ios.plist" <<'PLIST'
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0"><dict>
<key>Label</key><string>com.forgejo.ios</string>
<key>UserName</key><string>mobile</string>
<key>ProgramArguments</key><array><string>/var/lib/forgejo-ios/bin/forgejo-ios</string><string>service-run</string></array>
<key>RunAtLoad</key><true/>
<key>KeepAlive</key><true/>
<key>WorkingDirectory</key><string>/var/lib/forgejo-ios</string>
<key>EnvironmentVariables</key><dict>
<key>PATH</key><string>/usr/local/bin:/usr/bin:/bin:/usr/sbin:/sbin</string>
<key>HOME</key><string>/var/lib/forgejo-ios/data</string>
<key>GOMAXPROCS</key><string>1</string>
</dict>
<key>StandardOutPath</key><string>/var/lib/forgejo-ios/logs/forgejo.log</string>
<key>StandardErrorPath</key><string>/var/lib/forgejo-ios/logs/launcher.log</string>
</dict></plist>
PLIST
    chmod 644 "$test_root/com.forgejo.ios.plist"
    validate "$test_root/com.forgejo.ios.plist"
    printf '%s\n' 'LaunchDaemon validator self-test PASS'
}

case "${1:-}" in
    --self-test) self_test;;
    *) validate "$@";;
esac
