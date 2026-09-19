# Forgejo iOS port baseline and portability audit

Audit date: 2026-09-19

This document freezes the Prompt 001 reference point and records the source,
build, and device evidence collected before any iOS compatibility patching.
Prompt 001 made no production-source changes. Findings marked `SOURCE VERIFIED`
come from this checkout and its declared build files. Findings marked
`RUNTIME VERIFIED` were observed by executing a build or a device probe.
Unverified device behavior remains `UNRESOLVED` until a native arm64 build can
run on the target.

## Frozen upstream baseline

- Upstream project: Forgejo, `https://codeberg.org/forgejo/forgejo.git`
- Selected stable v15 LTS tag: `v15.0.9`
- Baseline commit: `19b9b9d216bbfb501c18514bd1a8c980246ca3f7`
- Baseline commit date: `2026-09-17T07:11:47+02:00`
- The available normal stable tags were `v15.0.9` through `v15.0.0`.
  `v15.0.0-dev` was excluded as a development tag.
- `ios` and `origin/ios` were already exactly at the selected tag. The
  `v15.0.9...ios` revision count was `0 0`, so no branch realignment or force
  push was needed.
- `main` remains unchanged at its existing upstream reference
  `1649d43c4e9373f3aee6fdea6b19041d0e177a25`.
- `origin` is the GitHub repository
  `https://github.com/nghianguyen150612/forgejo-ios.git`.
- `upstream` is the official Codeberg repository
  `https://codeberg.org/forgejo/forgejo.git`.
- `git fetch upstream --prune --tags` and `git fetch origin --prune` both
  completed successfully.
- The only pre-existing worktree item was the untracked user file
  `docs/ios-port.md`. It was inspected and intentionally preserved outside
  this Prompt 001 commit. No existing iOS-specific history was found.

## Target and deployment assumptions

- OS: jailbroken iOS/iPadOS
- Architecture: arm64
- Initial minimum target: iOS 12.5.7
- Initial test hardware: iPad mini 2, Apple A7
- Jailbreak model: rootful
- Primary database: SQLite
- Deployment model: native server process on the device, without containers
- Divergence rule: reuse portable upstream code first, then a genuinely
  compatible Darwin implementation, then a narrowly scoped iOS build-tagged
  implementation, and only lastly a shared-code change or subsystem rewrite.

The configured Tailscale path also provided a read-only device check during the
audit. The active peer named `ipad-server` reported `Darwin 18.7.0`,
`iPad4,4`, `arm64`, and user `nghianguyen`; this matches the intended iPad mini
2 target. The device has Git 2.39.1, `/usr/bin/git-upload-pack`,
`/usr/bin/git-receive-pack`, Bash, sh, and OpenSSH. No Forgejo checkout existed
in the device user's home at discovery time. Existing `Synveil` and other
unrelated files must not be overwritten.

## Host toolchain and declared requirements

The following versions and locations were observed on the Linux development
machine. The shell startup warning
`/home/nghianguyen/.zshenv:.:1: no such file or directory: /tmp/synveil-p98d-cargo/env`
was emitted by the host shell before commands; it
was not a Forgejo build error.

| Tool | Observed location | Observed version or relevant state |
| --- | --- | --- |
| Go | `/usr/bin/go` | `go1.27.1-X:nodwarf5 linux/amd64` |
| Go root | `/usr/lib/go` | `GOROOT=/usr/lib/go` |
| Go workspace | `/home/nghianguyen/go` | `GOPATH=/home/nghianguyen/go` |
| Go module | `/mnt/Projects/forgejo-ios/go.mod` | `GOMOD` for this checkout |
| C compiler | `/usr/bin/cc` | GCC 16.2.1 |
| Clang | `/usr/bin/clang` | Clang 22.1.8, target `x86_64-pc-linux-gnu` |
| Node | `/usr/bin/node` | `v26.8.2` |
| npm | `/usr/bin/npm` | `12.0.2` |
| Git | `/usr/bin/git` | `2.55.0` |
| Make | `/usr/bin/make` | GNU Make 4.4.1 (reported by the built binary) |
| Bash | `/usr/bin/bash` | available on the host |

Repository-declared requirements and build facts:

- `go.mod` declares `go 1.26.0` and `toolchain go1.26.7`.
- `package.json` declares Node `>=20.0.0`; `.node-version` pins the project
  development choice to `24.14.1`. The host Node is newer than both declared
  minimums and differs from the pin.
- The Makefile's normal `build` target is `frontend` plus `backend`. The
  backend target runs `go generate` with `CGO_ENABLED=0`, then builds the root
  executable with the requested `TAGS`.
- The normal project SQLite build uses the tags `bindata timetzdata` plus
  `sqlite sqlite_unlock_notify`. The tested control build used all four tags.
- The `static-executable` target uses external static linking and
  `netgo osusergo`; this is a Linux-oriented release target, not an iPhoneOS
  target.
- `release-darwin` uses xgo for
  `darwin-10.12/amd64,darwin-10.12/arm64`. It does not declare an iOS or
  iPhoneOS SDK target.
- `go tool dist list` includes `ios/amd64` and `ios/arm64`, but that only means
  the Go toolchain has an iOS target. It does not supply an Apple SDK, C
  compiler, or linker.
- The host has no `xcrun`, `xcodebuild`, `xcode-select`, or `ld64`, and no
  iPhoneOS SDK was found. LLVM tools are present, but the installed host
  linker/toolchain is not an Apple iPhoneOS toolchain.
- Docker build definitions install Linux/musl cross tools and a Linux runtime
  image containing Git, SQLite, OpenSSH, and Linux PAM. They are useful for
  identifying upstream assumptions but cannot be used as an iOS build path.

## Linux control build

Command run:

```text
make build TAGS='bindata timetzdata sqlite sqlite_unlock_notify'
```

Result: `RUNTIME VERIFIED`, exit status 0.

The build ran the repository's frontend/backend mechanism, completed the Go
generation step, and produced the ignored host artifact `gitea`. The artifact
was an x86-64 Linux ELF, and `./gitea --version` reported:

```text
forgejo version 15.0.9+gitea-1.22.0 (release name 15.0.9+gitea-1.22.0) built with GNU Make 4.4.1, go1.27.1-X:nodwarf5 : bindata, timetzdata, sqlite, sqlite_unlock_notify
```

No source or tracked generated file was changed by this control build. This is
the control result for separating host/toolchain failures from iOS failures.

## Initial iOS compile probes

The probes intentionally omitted the `sqlite` tags where possible so that the
first platform/toolchain failure would not be hidden by SQLite.

### CGO-disabled root executable

Command:

```text
timeout 180s env GOOS=ios GOARCH=arm64 CGO_ENABLED=0 go build -tags='bindata timetzdata' -o /tmp/forgejo-ios-pure-go-root-probe .
```

Result: `RUNTIME VERIFIED`, exit status 1, no artifact. The Go tool reported:

```text
ios/arm64 requires external (cgo) linking, but cgo is not enabled
```

The same failure was confirmed for explicit executable/archive build modes.
This is not a Forgejo package error: the root `main` executable cannot enter a
usable pure-Go final link path for this Go iOS target. A future probe must use
an Apple-compatible CGO toolchain before source-level compiler failures can be
classified.

### CGO-enabled root executable with the host compiler

Command:

```text
timeout 180s env GOOS=ios GOARCH=arm64 CGO_ENABLED=1 go build -tags='bindata timetzdata' -o /tmp/forgejo-ios-cgo-probe .
```

Result: `RUNTIME VERIFIED`, exit status 1, no artifact. The first relevant
errors came from `runtime/cgo`'s `gcc_arm64.S`: host GCC attempted to assemble
ARM64 Apple/iOS assembly as a native Linux assembly dialect (`stp`, `ldp`,
`blr`, and related instructions were rejected). This is a host
cross-toolchain failure, not evidence that Forgejo source itself is
incompatible. The probe also confirms that the first iOS build gate is
CGO/runtime/linker setup, before SQLite or Forgejo application code can be
evaluated.

## Portability audit

The following register is the actionable blocker index. The detailed sections
below retain the source evidence and the boundaries of each finding.

| ID | Location / package | Why it fails or may fail | Compile or runtime | Probable strategy | Dependency and recommended order |
| --- | --- | --- | --- | --- | --- |
| A | `Makefile`, `release-darwin`, Docker/build workflows | No iPhoneOS SDK, deployment target, or device linker path is declared; the root iOS executable requires external CGO linking. | Compile/build | Add the smallest reproducible iPhoneOS toolchain entry point after the external toolchain is proven. | First blocker; required by every later source probe. |
| B | `modules/user/user.go`, `modules/util/path.go`, generic standard-library imports | `os/user.Current()` and environment-derived home paths may not match the jailbreak; generic Unix selection is not proof of iOS behavior. | Compile and runtime | Prefer existing `osusergo`/fallback behavior; add a narrow iOS case only for a demonstrated failure. | After A, before service launch. |
| C | `*_unix.go` platform files; no Forgejo `_darwin.go` or `_ios.go` files | Unix code uses signals, process attributes, fd inheritance, sockets, and `x/sys/unix` APIs that may differ on iOS. | Compile and runtime | Compile the selected files with the Apple toolchain, then reuse or narrowly specialize them. | After A; feeds D/E/J. |
| D | `modules/process/*`, `modules/graceful/*`, `cmd/*` signal handlers | `Setpgid`, negative-PID `SIGTERM`/`SIGKILL`, signal set, `os.StartProcess`, and inherited listener fds need iOS behavior proof. | Compile and runtime | Validate ordinary shutdown/cancellation first; defer or gate graceful restart if device behavior requires it. | After A/C; before Git and hooks. |
| E | `modules/util/file_unix.go`, temp/storage paths, hooks, Unix sockets | Umask/chmod, temp roots, rename/remove, executable bits, socket permissions, and SQLite WAL locks may differ on the device filesystem. | Runtime primarily | Probe real writable roots and modes; preserve upstream APIs and change only confirmed semantics. | After A/C; required by G/H/I. |
| F | Go `runtime/cgo`, `github.com/mattn/go-sqlite3` | Host GCC is not an arm64 iPhoneOS assembler/linker and no SDK is installed. | Compile/link | Supply an Apple-targeting compiler, SDK, Mach-O linker, and reproducible flags. | First hard external dependency; Prompt 002. |
| G | `modules/setting/database_sqlite.go`, go-sqlite3 C files | SQLite is CGO-only; unlock-notify uses exported Go callbacks; `libsqlite3` paths are macOS/Linux, not iPhoneOS. | Compile, link, and runtime | Start with bundled SQLite, validate WAL/locking, then decide on unlock-notify; do not assume system SQLite. | After F; before core runtime. |
| H | `modules/git/git.go`, `command.go`, `repo.go`, `cmd/serv.go`, hooks | Forgejo requires external Git, helper commands, shell hooks, cwd/env/pipes, credentials, timeouts, and maintenance. | Runtime, with compile through `os/exec` | Keep integration; prove native Git and each operation on-device before changing code. | After D/E/G; central product blocker. |
| I | `modules/ssh/*`, `modules/git/repo.go`, `cmd/serv.go` | Built-in SSH spawns the Forgejo executable; external Git SSH needs OpenSSH, keys, known-hosts, and child-process status. | Runtime | Retain built-in SSH option; verify both built-in and external paths separately. | After D/E/H; optional for initial HTTP-only bring-up. |
| J | `cmd/web.go`, `modules/graceful/net_unix.go`, `modules/hostmatcher/http.go` | TCP/Unix listeners, `RawConn`, IPv4/IPv6, TLS, HTTP/2, DNS, and inherited listeners need device validation. | Compile and runtime | Reuse Go net/http and TLS; run narrow listener/security probes, not an Apple networking rewrite. | Compile after A/C; runtime after G. |
| K | `modules/queue`, cron/task/indexer services, Bleve/mmap | Goroutines are portable, but A7 memory/CPU, mmap, queue shutdown, and background execution may be limiting. | Runtime/performance | Start with reduced workers/indexers and measure before changing queue semantics. | After core server/G; later device prompts. |
| L | PAM, systemd, sendmail, external markup, remote services | Optional features assume Linux PAM/systemd or arbitrary external binaries. | Build-tag and runtime | Leave PAM/systemd/sendmail/renderers disabled or explicitly provisioned; retain portable SMTP/remote clients. | After core success; not Prompt 002. |
| M | Jailbroken iPad runtime as a whole | Launch, entitlements, CGO callbacks, signals, filesystem, networking, battery/background policy, and crash recovery cannot be proved on Linux. | Runtime only | Use finite, isolated, checksum-recorded device probes with cleanup and no unrelated worktree changes. | Every artifact prompt; final acceptance gate. |

### A. Build system and cross-compilation

| Location | Finding and effect | Classification and order |
| --- | --- | --- |
| `Makefile:build`, `backend`, `generate-go`, `static-executable` | Normal build assumes a host or Linux release environment. `generate-go` forces CGO off, while the final iOS main executable currently requires external CGO linking. | Build blocker; establish an explicit iPhoneOS toolchain/probe first. |
| `Makefile:release-darwin` | Only macOS Darwin targets are declared; there is no `ios`/`iphoneos` target, SDK selection, minimum iOS version, or Mach-O device linker configuration. | A1 build-system work, dependent on the Apple SDK/toolchain. |
| `Dockerfile*`, `.forgejo/workflows/*` | Build and runtime definitions install Linux Git, PAM, OpenSSH, and SQLite packages. They are not portable deployment instructions for iOS. | A1 documentation/build boundary; do not copy Linux package assumptions to iOS. |
| `go.mod`, `package.json`, `.node-version` | Go and frontend requirements are declared and satisfied by the host for the control build. They do not describe a cross C toolchain. | Not a current source blocker; preserve upstream requirements. |

Recommended strategy: add the smallest possible iOS build entry point only
after a separately validated arm64 iPhoneOS C compiler, SDK, and linker are
available. Keep the upstream `build` target and `main` branch unchanged.

### B. Pure-Go OS compatibility

- `runtime.GOOS` has only two relevant production uses found in the audit:
  `modules/git/git.go` uses it for a Linux-specific old-Git hint, and
  `modules/metrics/collector.go` reports the platform in metrics. Neither is
  an iOS implementation.
- `modules/user/user.go` calls `os/user.Current()` and falls back to `USER`
  or `USERNAME`. A jailed or nonstandard iOS user database may make the first
  call fail or return semantics unlike Linux. The fallback should be retained
  and verified with the device user; `osusergo` is already used by the static
  upstream build path and should be evaluated before adding an iOS fork.
- `modules/util/path.go` deliberately uses `$HOME` rather than
  `user.Current().HomeDir`. This is a useful deployment hook on a jailbreak,
  but every service launch path must provide a stable writable `HOME`.
- Standard Go HTTP, TLS, goroutine, context, JSON, and database/sql code has
  no direct iOS-specific source condition in Forgejo and is the preferred
  reuse path. Compilation and runtime validation remain pending because the
  initial root probe stops at the external-linking gate.
- Forgejo has no production `_darwin.go` or `_ios.go` files. The only
  platform-named production files found are `_unix.go`, `_linux.go`, and
  build-tag variants. Darwin selection therefore frequently falls through to
  generic Unix code and must not be treated as proof of iOS compatibility.

### C. Darwin/iOS platform implementation

The following generic Unix files are selected for non-Linux Unix targets and
are the first implementation review set:

```text
modules/graceful/manager_unix.go
modules/graceful/net_unix.go
modules/graceful/restart_unix.go
modules/process/graceful_cancel_unix.go
modules/process/manager_unix.go
modules/util/file_unix.go
routers/private/manager_unix.go
```

They use Unix signals, process attributes, file descriptors, Unix sockets,
`syscall`, and `golang.org/x/sys/unix`. The correct next step is to compile
each affected package with an Apple toolchain and then probe the behavior on
the jailbreak; adding a broad `ios` abstraction before those results would
create unnecessary divergence.

### D. Processes, signals, and syscalls

| Location | Finding | Effect and probable strategy |
| --- | --- | --- |
| `modules/process/manager_unix.go` | `SetupCancellableCommand` sets `SysProcAttr.Setpgid=true`. | Compile support and process-group behavior must be confirmed on Go's iOS target; runtime test with Git, hooks, and timeouts. |
| `modules/process/graceful_cancel.go` | Generic non-Linux cancellation sends `SIGTERM` and then `SIGKILL` to `-cmd.Process.Pid`, polling signal 0. | iOS/Darwin uses this fallback because `graceful_cancel_linux.go` is excluded. Process-group creation, negative-PID signaling, and permissions are runtime blockers. |
| `modules/process/graceful_cancel_linux.go` | Linux-only pidfd implementation is excluded on iOS. | No port needed initially; validate the generic fallback before considering a narrow implementation. |
| `modules/graceful/manager_unix.go`, `cmd/cmd.go`, `cmd/forgejo/forgejo.go` | Signal handlers use `SIGHUP`, `SIGUSR1`, `SIGUSR2`, `SIGINT`, `SIGTERM`, and `SIGTSTP`. | Some signals are supervisor-oriented. Disable or narrow only after device behavior is observed; normal SIGTERM/SIGINT shutdown is the first required case. |
| `modules/graceful/restart_unix.go` | Graceful restart inherits listener file descriptors, calls `exec.LookPath(os.Args[0])`, and starts a replacement with `os.StartProcess`. | Verify executable lookup, fd inheritance, `SetUnlinkOnClose`, and replacement process behavior. A supported iOS deployment may initially need graceful restart disabled, but that is a later product decision. |
| `cmd/serv.go`, `modules/ssh/ssh.go`, `services/mailer/mailer.go`, `modules/markup/external/external.go` | External commands all use context cancellation and the shared process setup. | One process compatibility fix can affect Git, SSH, hooks, mail, and optional renderers; test the shared behavior before per-subsystem changes. |

### E. Filesystem, permissions, locking, and temporary paths

- `modules/util/file_unix.go` calls `unix.Umask` during initialization and
  restores it, then applies the effective mode with `os.Chmod`.
- `modules/graceful/net_unix.go` removes and creates Unix sockets and applies
  `setting.UnixSocketPermission` with `os.Chmod` for absolute paths.
- Configuration, dumps, SSH authorized keys, repository hooks, local storage,
  and temporary files explicitly use modes such as `0600`, executable bits,
  or `os.ModePerm`. Relevant paths include `cmd/dump.go`,
  `modules/setting/config_provider.go`,
  `models/asymkey/ssh_key_authorized_keys.go`,
  `modules/repository/hooks.go`, and `modules/storage/local.go`.
- Git credentials and many repository operations use `os.CreateTemp` or
  `os.MkdirTemp`, frequently under `os.TempDir()`. The device's writable temp
  path, cleanup behavior, permissions, and free space must be tested.
- No production Go calls to `os.Chown`, `os.Lchown`, or direct Unix `flock`
  were found in the targeted audit. This reduces one porting surface, but does
  not remove Git lock files or SQLite WAL/database locking from runtime scope.
- Hardcoded special-device paths found in production behavior are primarily
  `/dev/null` for disabling Git hooks and `/dev/stdin` as a documented Git
  possibility. No production `/proc/...` or `/sys/...` dependency was found
  in the targeted search. `/dev` and permission behavior still need a device
  probe; rootful jailbreak access is not a substitute for verifying the
  actual filesystem layout.

Classification: likely runtime blocker rather than a first compile blocker.
First validate a writable application data root, repository root, temp root,
SQLite WAL files, Unix sockets, mode changes, rename/remove, and concurrent
repository operations. Do not add permission emulation speculatively.

### F. CGO toolchain

The current SQLite dependency and the Go iOS executable path both require
CGO/external linking. The host's native GCC cannot assemble the iOS runtime,
and no Apple SDK or device linker is installed.

The eventual toolchain must provide, at minimum:

1. an arm64 iPhoneOS-targeting C compiler with the selected minimum iOS
   deployment version;
2. iPhoneOS SDK headers and libraries;
3. an Apple-compatible Mach-O linker or a proven LLVM alternative configured
   for iPhoneOS;
4. Go external linking support for `GOOS=ios GOARCH=arm64 CGO_ENABLED=1`;
5. reproducible CFLAGS/LDFLAGS for the chosen SQLite strategy; and
6. a way to transfer and launch the resulting device executable for a probe.

This is the first hard dependency for Prompt 002. The exact flags must come
from the installed SDK/toolchain rather than being guessed in the repository.

### G. SQLite

Forgejo's SQLite path is build-tagged:

- `modules/setting/database_sqlite.go` has `//go:build sqlite` and
  blank-imports `github.com/mattn/go-sqlite3`.
- `go.mod` pins `github.com/mattn/go-sqlite3 v1.14.50`.
- The normal project SQLite build uses the default bundled SQLite C source,
  not a dynamically discovered system library. `sqlite3.go` is
  `//go:build cgo` and embeds `sqlite3-binding.h`; `sqlite3_other.go`
  supplies non-Windows C flags and only adds Linux-specific `-ldl`/pthread
  flags.
- The alternative `libsqlite3` tag uses `<sqlite3.h>` and platform-specific
  library paths. Its Darwin entries are macOS Homebrew paths, not iPhoneOS
  SDK paths, so it is not an iOS solution as-is.
- The production test/release tag also enables `sqlite_unlock_notify`.
  `sqlite3_opt_unlock_notify.go` is CGO code with exported Go callbacks and C
  wait/notification behavior. It must be validated with iPhoneOS cgo before
  being retained for the device build.
- With `CGO_ENABLED=0`, the dependency deliberately registers a stub that
  returns `go-sqlite3 requires cgo to work`; a CGO-disabled Forgejo binary is
  therefore not a usable SQLite fallback.
- Forgejo constructs a file DSN with busy timeout, immediate transactions,
  optional journal mode, and read/write/create mode in
  `modules/setting/database.go`. The selected SQLite strategy must test these
  options, WAL files, concurrent workers, interrupted writes, and device
  storage behavior.

Probable order: first build the default embedded SQLite with the device C
toolchain; then run the existing SQLite test/build subset; then decide whether
`sqlite_unlock_notify` is safe and useful on the target. Do not switch to the
iOS system SQLite library merely because it is present until headers, symbols,
deployment availability, and link behavior are verified.

### H. Git executable integration

Git is a required runtime dependency, not a replaceable implementation detail
of this port. Central paths are:

- `modules/git/git.go`: `exec.LookPath`, absolute executable selection, Git
  version check, `GitExecutable`, `HasSSHExecutable`, global Git environment,
  and configuration initialization. The minimum supported Git version is
  `2.34.1`.
- `modules/git/command.go`: `exec.CommandContext`, working directory,
  environment construction, `HOME`, `GNUPGHOME`, `GIT_NO_REPLACE_OBJECTS`,
  `LC_ALL=C`, `GIT_TERMINAL_PROMPT=0`, stdin/stdout/stderr pipes, process
  cancellation, and the default command timeout (360 seconds).
- `modules/git/repo.go`: repository initialization, clone, fetch, push,
  temporary bundles, SSH command setup, `core.hooksPath=/dev/null` for
  disabled hooks, and cleanup.
- `modules/git/git.go` and `modules/git/repo_commitgraph.go`: fsck,
  commit-graph maintenance, update-server-info, and other maintenance commands.
- `cmd/serv.go`: SSH Git service dispatch to `git-upload-pack`,
  `git-receive-pack`, or `git <subcommand>`, with repository-root cwd and
  Forgejo environment variables.
- `modules/repository/hooks.go` and `cmd/hook.go`: hook generation,
  executable permission, hook dispatch, and `git update-server-info`.

The integration creates temporary credential-store files for URL credentials
and removes them afterward. SSH pushes set `GIT_SSH_COMMAND` with an identity
file, `IdentitiesOnly`, host-key policy, and a known-hosts path. These are
security-sensitive and filesystem-sensitive on iOS.

The likely iOS blocker is obtaining a compatible native Git executable and its
helper commands/hooks, then proving that Forgejo's `os/exec`, cwd, environment,
pipe, timeout, process-group, and credential cleanup behavior works on-device.
The target iPad already has Git 2.39.1, which meets Forgejo's minimum, but that
is only a device observation; it does not prove the production launch path or
the Git binary's suitability for the eventual deployment environment.

Recommended order: validate a standalone device Git command from a temporary
probe, then `git init`, clone/fetch/push, hooks, SSH transport, maintenance,
and cancellation. Do not rewrite Forgejo Git integration before those probes.

### I. SSH

- `modules/ssh/ssh.go` interprets `exec.ExitError.Sys()` as a Unix
  `syscall.WaitStatus` and implements the built-in SSH session by spawning the
  Forgejo executable with `serv key-<id>`, connecting stdin/stdout/stderr, and
  applying process cancellation.
- `modules/ssh/init.go` implements the optional built-in SSH server in Go and
  manages host/CA/authorized-key files. This is a promising reusable path, but
  its child-process and key-file assumptions still need device tests.
- `modules/git/git.go` only records whether an external `ssh` executable is
  available; `modules/git/repo.go` uses it for SSH pushes through
  `GIT_SSH_COMMAND`.
- `cmd/serv.go` is the external Git-over-SSH entry point and depends on
  `git-upload-pack`/`git-receive-pack` or equivalent Git subcommands.

The jailbroken device has OpenSSH and Git helper binaries, but SSH host-key,
known-hosts, identity-file permissions, child process status, and network
reachability remain runtime work. Preserve the built-in server as an option;
do not assume it removes the need for external SSH for all clone/push cases.

### J. Networking and TLS

- `cmd/web.go` and `modules/graceful/server_http.go` use Go's HTTP/TLS stack
  and support TCP, TCP4/TCP6 resolution, Unix sockets, FCGI, HTTPS, HTTP/2,
  and proxy-protocol modes.
- `modules/graceful/net_unix.go` also understands inherited listener file
  descriptors and systemd notification variables. The systemd path is
  optional and should be inert without those environment variables.
- `modules/hostmatcher/http.go` uses `net.Dialer.Control` and
  `syscall.RawConn` to enforce host matching. This is a small Unix syscall
  portability surface that must compile and be tested on iOS.
- Go `crypto/tls` and `net/http` are preferred unchanged. iOS runtime tests
  must cover IPv4/IPv6 availability, loopback, LAN binding, TLS certificates,
  HTTP/2, Unix sockets, DNS, proxy settings, and battery/background behavior.

Classification: mostly reusable source, with compile validation for
`RawConn`/x/sys and device-only listener/TLS behavior. No Apple networking API
rewrite is justified by the audit.

### K. Background workers, queues, and indexers

Forgejo uses Go goroutines, context cancellation, cron tasks, task queues,
indexer queues, mirrors, federation delivery, and repository workers. Relevant
areas include `modules/queue`, `services/cron`, `services/task`,
`services/indexer`, `modules/indexer/issues`, `modules/indexer/code`, and
`modules/indexer/stats`.

- The worker and queue implementations are primarily Go channels, timers,
  contexts, and storage-backed queues; no iOS-specific source change is
  indicated by this audit.
- Local Bleve indexing is in the normal dependency graph and uses
  `github.com/blevesearch/mmap-go`. The mmap package provides a generic Unix
  implementation, so it needs an iOS compile and runtime test for mmap,
  unmap, file truncation, index locking, and storage pressure.
- Elasticsearch, Meilisearch, Redis, object storage, and similar remote
  services are optional or deployment-dependent and should not block the
  smallest SQLite-first device server.
- An A7 device has materially less CPU, memory, and storage throughput than a
  normal server. Queue sizes, worker concurrency, index rebuilds, cron
  shutdown, mmap pressure, and battery/background suspension are runtime-only
  performance and reliability questions.

Recommended order: get the core server and SQLite stable, then run a reduced
worker/indexer matrix on the real device before changing queue semantics.

### L. Optional subsystems

- PAM is build-tagged (`modules/auth/pam/pam.go` with `pam`, and
  `pam_stub.go` without it). The default no-PAM build is pure Go; the `pam`
  variant depends on the Linux-oriented `msteinert/pam` and external PAM
  library and should remain disabled on iOS unless a separately justified
  implementation is requested.
- Systemd integration is environment-driven in `modules/graceful/net_unix.go`
  and `manager_unix.go`. There is no systemd supervisor on the target, so the
  code should be harmless when unset; graceful restart and ordinary signals
  still need separate validation.
- Sendmail in `services/mailer/mailer.go` is an optional external command.
  SMTP and dummy mail are more portable deployment choices; sendmail should
  be treated as unavailable until a device binary is intentionally supplied.
- External markup in `modules/markup/external/external.go` runs configured
  commands with temp files, stdin/stdout pipes, and process cancellation.
  Leave it disabled or explicitly provision each renderer; do not make an
  iOS port depend on arbitrary shell tools.
- Docker, Linux PAM packages, systemd service files, and Linux release image
  contents are deployment artifacts, not iOS runtime requirements.

### M. Runtime-only issues requiring the real device

The following cannot be proven by the current Linux checkout or the failed
cross-compile probe:

- launch/signing/entitlement behavior of the native executable under the
  rootful jailbreak;
- Go external linking and CGO callback behavior on iOS 12.5.7;
- SQLite bundled C library, WAL, busy timeout, unlock notification, and crash
  recovery on the target filesystem;
- `os/user`, `$HOME`, temp directory, mode, rename, socket, and Git lock
  behavior;
- `fork`/exec-like child process behavior, process groups, signals, wait
  status, pipes, timeout cancellation, and graceful restart;
- Git hooks, Bash/sh availability in the service's environment, SSH key
  handling, and upload/receive pack behavior;
- TCP/Unix listener binding, IPv4/IPv6, TLS, HTTP/2, DNS, and long-lived
  connections;
- memory use, mmap pressure, queue shutdown, index rebuild time, and battery
  or background execution constraints on an A7 device;
- filesystem paths and write permissions chosen for the final deployment.

## Blocker order

The audit yields this implementation sequence. It is an order of dependency,
not permission to implement all items in Prompt 002.

1. **Toolchain proof:** establish or obtain the reproducible arm64 iPhoneOS
   C/SDK/linker environment and compile a minimal CGO Go iOS executable.
2. **Small source compile matrix:** compile affected generic Unix packages and
   the root Forgejo executable with the selected tags; fix only confirmed
   compiler/API failures, preserving upstream code where possible.
3. **SQLite device proof:** build the default bundled `go-sqlite3` path, then
   run a minimal SQLite open/WAL/lock test and the narrow Forgejo SQLite tests.
4. **Core filesystem and process probe:** validate paths, modes, temp files,
   Unix sockets, signals, process groups, cancellation, and ordinary shutdown.
5. **Git executable probe:** validate version, init, clone/fetch/push,
   upload/receive pack, hooks, maintenance, SSH, and timeout cancellation.
6. **Minimal Forgejo runtime:** launch the server with SQLite, bind a local/LAN
   HTTP endpoint, exercise TLS as configured, and collect memory/runtime data.
7. **Optional workers and features:** enable queues, cron, indexes, LFS,
   mail, external renderers, and other subsystems one at a time, with explicit
   device evidence.
8. **Build/release automation:** only after the device path works, add narrow
   reproducible build and artifact transfer support. Keep `main` upstream-only.

## Known unknowns and audit boundaries

- The Linux control build does not establish iOS source compatibility.
- The failed CGO probe does not establish a Forgejo source bug; it establishes
  that the current host toolchain is not an iPhoneOS toolchain.
- No iOS executable was produced in Prompt 001, so no runtime or checksum
  claim about a Forgejo binary is made.
- No broad source compatibility patch, SQLite fork, Git rewrite, or optional
  subsystem removal was attempted.
- The exact iPhoneOS SDK version, minimum deployment flag spelling, Mach-O
  linker choice, and SQLite CFLAGS/LDFLAGS remain unresolved until the actual
  build environment is supplied.
- Device behavior must be recorded separately from source findings; a
  Darwin-compatible file is not considered iOS-compatible without compile and
  real-device evidence.

## Prompt 002 recommendation

Prompt 002 should be narrowly scoped to the first dependency in the list:
produce a reproducible minimal `GOOS=ios GOARCH=arm64 CGO_ENABLED=1` toolchain
probe and, if that probe succeeds, compile the smallest Forgejo package/root
set needed to expose confirmed compiler and linker errors. It should not begin
Git rewrites, broad `_ios.go` abstractions, SQLite design changes, or optional
feature work until the toolchain and first source errors are demonstrated.
