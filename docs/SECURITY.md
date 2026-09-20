# Forgejo iOS security and deployment boundary

This document is the security contract for the native Forgejo deployment on
the tested jailbroken iPad. It describes the boundary that this port can
actually validate; it is not a claim that iOS 12 or a jailbreak provides the
same isolation as a supported server operating system.

## Qualified target

The evidence in this document is limited to:

```text
Forgejo 15.0.9
Go runtime go1.26.7-a7
iPad4,4 / Apple A7 / iOS 12.5.7 / Darwin 18.7.0
rootful Amethyst jailbreak
```

The project-owned launcher is
[`scripts/ios/run-forgejo.sh`](../scripts/ios/run-forgejo.sh). It is a
jailbreak-compatible process wrapper, not a replacement for Forgejo
authentication, authorization, TLS, or repository permission checks.

## Security model and jailbreak boundary

The tested deployment is rootful. The filesystem has a writable `/var`
runtime area, and the rootful jailbreak exposes `/amethyst`; the tested
device does not use the rootless `/var/jb` layout. Runtime paths in the
examples are therefore device-specific and must not be copied to a rootless
jailbreak without a new test.

The operator must provide all of the following:

- a dedicated runtime directory owned by the account that runs Forgejo;
- owner-only permissions on the runtime, configuration, database, repository,
  log, backup, key, and launcher-state paths;
- the physical iOS arm64 executable built for iOS 12 and accepted by the
  device's code-signing policy;
- device-side `ldid` signing. The tested rootful path uses the
  `com.apple.private.security.no-container` entitlement and does not claim
  that an unsigned or differently signed copy will launch;
- a stable `HOME`, `PATH`, Git executable, SQLite, shell, and OpenSSH
  environment for any enabled Forgejo feature that invokes them.

The jailbreak removes normal iOS application-container assumptions. Anyone
with root/jailbreak shell access, filesystem access, or a copy of the device
backup can potentially read or alter the instance. The Unix account boundary
is useful against ordinary other users only when the jailbreak and device
permissions remain trusted. It is not a protection against root, a malicious
jailbreak package, a compromised SSH account, or physical extraction.

Persistent boot through the managed rootful LaunchDaemon is an opt-in,
device-gated service mode. It is distinct from an arbitrary launchd hook or tweak: the installer
owns only `/Library/LaunchDaemons/com.forgejo.ios.plist`, runs the configured
non-root account, supplies a fixed environment, and has a reversible unload and
uninstall path. `sudo -n id` must succeed before that system plist is touched.
Manual launcher operation remains available for disposable runtimes and for
device validation before enabling persistence.

## Filesystem permissions

Use a dedicated tree, for example:

```text
runtime/                    700
runtime/custom/conf/        700
runtime/custom/conf/app.ini 600
runtime/data/               700
runtime/repositories/       700
runtime/logs/               700
backup/<timestamp>/         700
```

The managed LaunchDaemon plist is the exception to the owner-only runtime
tree: launchd requires the system file at `/Library/LaunchDaemons` to be mode
`644`. Its referenced logs remain below the mode-`700` runtime `logs/` tree and
are mode `600`.

Regular files in these trees must have no group/other bits. The following are
explicitly mode `600`: `app.ini`, SQLite databases and sidecars, SSH/private
key files, `authorized_keys`, token/secret material, launcher state, logs,
and backup `metadata.txt`, `manifest.sha256`, and `payload.tar`. Owner-only
executables such as the Forgejo binary and Git hooks may be mode `700`.

The launcher now sets `umask 077`, restricts the dedicated service tree before
starting Forgejo, and restricts an explicit `--config` file to mode `600`.
It preserves owner execute bits, so this does not disable Forgejo, Git, or
hooks for the service account. The launcher state files are still written
atomically and remain mode `600`.

[`scripts/ios/audit-security.sh`](../scripts/ios/audit-security.sh) is a
read-only check for this contract. It fails on a missing required directory,
a directory that is not `700`, any group/other file permission, or a
sensitive file that is not `600`. It can also scan logs, provenance, and CI
artifact paths for private-key and common credential material without printing
matching file contents.

Do not use a shared group-readable runtime, a web-served backup directory, or
a runtime path writable by an unrelated account. Do not put passwords or
tokens in launcher arguments: `forgejo.args` is protected, but process
arguments and shell history can still be observable to a privileged user. The
managed plist intentionally contains no credential environment variables.

## Network exposure modes

The upstream Forgejo source default for `HTTP_ADDR` is `0.0.0.0`. That is not
a safe iOS deployment default. The iOS configuration must set an explicit
address, and the deployment audit must inspect the effective listener.

### Local only (recommended default)

Use:

```ini
[server]
HTTP_ADDR = 127.0.0.1
DISABLE_SSH = true
START_SSH_SERVER = false
```

The P10 device validation observed HTTP 200 on the iPad loopback address and
no wildcard Forgejo listener. A loopback listener is not reachable through
Wi-Fi, LAN, or the device's Tailscale interface. This is the recommended
default when the instance is used locally or through a same-device proxy.

### Tailscale

For an intentionally reachable private service, bind Forgejo to the device's
current Tailscale address, for example `100.x.y.z`, rather than to
`0.0.0.0`, `::`, or `*`. Apply Tailscale ACLs and device identity controls
outside Forgejo, and re-check the address after a Tailscale/interface change.
The P10 validation used an explicit address-specific bind and observed only
that address and port in `netstat`; it did not qualify a public internet
exposure, Wi-Fi firewall policy, or a permanent address.

### Reverse proxy

Keep Forgejo on `127.0.0.1` and place a separately managed reverse proxy on
the device or on a trusted network hop. The proxy owns TLS, certificate
renewal, external access control, request limits, and access-log review.
Forward only to the loopback Forgejo port and keep the proxy's configuration
and keys under the same owner-only permission contract. The proxy is outside
this repository's iOS validation boundary.

For every mode, inspect the process-specific listener with `netstat` (or the
device equivalent) and record the raw address before following any URL. A
listener such as `*.PORT`, `0.0.0.0.PORT`, or `[::].PORT` is an unintended
wildcard exposure for the local-only deployment.

## Secrets and logs

Forgejo configuration and its database are confidential. Depending on enabled
features they can contain password hashes, session material, access-token
metadata, webhook/OAuth secrets, SSH keys, and repository contents. The
complete runtime cannot be made public merely because the web listener is
loopback-bound.

The launcher does not intentionally write password, access-token, or private
key values to `launcher.log` or `runtime.log`. `forgejo.log` is application
output and must be reviewed after enabling extensions, mail, OAuth, Actions,
or other features that may log request/configuration details. The provenance
writer records build identity and hashes only; it must not receive a secret
environment variable or a private path as a build field.

The P13 source/CI audit checks the source tree and generated build/provenance
surface for private-key material and common token formats. This is a finite
leak check, not a proof that an arbitrary Forgejo extension cannot log a
secret. Rotate any credential that has appeared in a log, command line,
artifact, or unencrypted backup.

## Authentication and API tokens

Use Forgejo's existing authentication and authorization behavior. P13 does
not rewrite login, logout, password hashing, session creation, or API-token
semantics. Disposable validation covers:

1. creation of a temporary administrator account with a generated password;
2. web login, authenticated session access, logout, and unauthenticated
   access after logout;
3. a temporary API token accepted by an authenticated API request and rejected
   when absent or invalid;
4. database inspection that the password is represented by a password hash,
   and the API token is represented by its stored hash/salt metadata rather
   than a plaintext token column;
5. removal of the disposable runtime, account, token, cookie jar, and working
   data after the test.

Test credentials are held only in the bounded test process and temporary
owner-only files where a client requires them. They are not committed,
copied into documentation, or retained as a deployment credential.

## Git and repository access

Git access is authorized by the same Forgejo user/repository permissions as
the web/API surface. The P13 disposable test must demonstrate all of the
following without changing a real repository:

- a private repository is visible to its owner but not to an anonymous or
  invalid credential;
- unauthenticated Git discovery/clone is rejected;
- authenticated clone and push succeed;
- a repository hook executes with owner-only permissions; and
- `git fsck --full` remains clean before backup and after restore.

The recommended iOS profile keeps both built-in and external SSH services
disabled and uses HTTP Git through a loopback or explicitly scoped private
network path. If SSH is enabled later, separately protect host keys,
authorized keys, `known_hosts`, identity files, the SSH listener, and the
external `git-upload-pack`/`git-receive-pack` path.

## Backup confidentiality

The P12 backup workflow in
[`scripts/ios/backup-forgejo.sh`](../scripts/ios/backup-forgejo.sh) is a
filesystem copy and integrity-verification tool, not an encryption tool. It
refuses a live service by default, validates SQLite integrity and Git history,
and refuses to package a runtime whose dedicated tree is not owner-only. It
does not print database rows, configuration values, repository contents, or
credential values.

Each backup directory is mode `700`; `metadata.txt`, `manifest.sha256`, and
`payload.tar` are mode `600`. The payload is still confidential because it
contains the complete configured data and repository set. Store it outside a
web root, restrict the backup account, transfer it over an authenticated
encrypted channel, and encrypt it at rest with an operator-controlled tool
such as a platform-supported age/GPG workflow. Keep encryption keys separate
from the backup device. Do not add an encryption implementation to this iOS
port without a separate design and validation boundary.

A restore must target a new empty owner-only runtime. Review absolute paths,
`ROOT_URL`, bind address, and enabled services before starting it. Do not run
two Forgejo processes against one SQLite database or repository tree.

## iOS limitations

- Only the rootful A7/iOS 12 target above is qualified. Rootless jailbreaks,
  other jailbreaks, later iOS releases, other A7 devices, and non-A7 arm64
  devices require new signing, filesystem, runtime, and network tests.
- iOS 12 is an obsolete platform. TLS roots, ciphers, system libraries,
  package availability, and third-party jailbreak components may be stale.
- The device is not a hardened server. There is no claim of sandboxing,
  secure enclave storage for Forgejo secrets, background execution guarantees,
  thermal/battery qualification, or protection from a root-capable jailbreak
  process.
- Tailscale ACLs, reverse-proxy TLS, SSH hardening, Wi-Fi filtering, and
  physical-device security are deployment responsibilities outside Forgejo.
- The bounded P13 resource check is a short RSS/CPU/startup observation. It is
  not a long soak, capacity limit, battery-life measurement, or denial-of-
  service guarantee.

## Security validation record

The final P13 report records the exact device paths, listener tuples, mode
counts, disposable authentication/Git results, backup checksum/permission
results, bounded RSS/CPU timings, Linux build result, iOS CI result, and the
host/GitHub/iPad commit SHAs. Existing P10/P12 evidence remains historical
where explicitly labelled; it is not silently reused as a P13 result.

## Release-candidate handoff

Prompt 014 does not change this security boundary. The release candidate is
the source commit plus the generated `forgejo-ios`, `build-info.txt`, and
`SHA256SUMS` bundle described in [`RELEASE.md`](../RELEASE.md). The CI
signature is an ad-hoc physical-iOS signature; a device-side working copy is
re-signed with the installed `ldid` and the no-container entitlement, so its
checksum is expected to differ from the host artifact checksum.

Before installation, verify the checksum and inspect the provenance file.
After installation, re-check the entitlements, owner-only modes, effective
listener address, Forgejo version, runtime version, SQLite integrity, and
launcher stop behavior. The P14 evidence used a new disposable runtime and
did not touch the existing device service or real user data. Do not treat the
release-candidate checksum as a backup confidentiality control or as evidence
for a different device, jailbreak, iOS release, or automatic startup mode.

The P14 source audit covered the production source and the `scripts/`,
`docs/`, and `.github/` release surfaces for private-key and common
credential-like material. Existing upstream test fixtures outside those
release surfaces are not deployment credentials and are not included in the
artifact bundle.
