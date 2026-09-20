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

This was the first hard dependency for Prompt 002. Prompt 002 now proves the
toolchain path in GitHub Actions; the exact flags come from the active Xcode
SDK rather than from a version-specific absolute Xcode path in the repository.

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

1. **Toolchain proof (completed in Prompt 002):** establish or obtain the
   reproducible arm64 iPhoneOS C/SDK/linker environment and compile a minimal
   CGO Go iOS executable. The device execution gate remains a blocker below.
2. **Small source compile matrix (Prompt 003):** compile affected generic Unix packages and
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
- The Prompt 002 CI environment resolved the iPhoneOS SDK version, deployment
  flag spelling, Mach-O load-command validation, and Apple linker path for the
  minimal probe. SQLite CFLAGS/LDFLAGS remain unresolved until the Forgejo
  SQLite build is attempted with the same toolchain.
- Device behavior must be recorded separately from source findings; a
  Darwin-compatible file is not considered iOS-compatible without compile and
  real-device evidence.

## Prompt 002 toolchain result

Prompt 002 established the build infrastructure and minimal CGO probe without
changing Forgejo production packages.

- Strategy: GitHub Actions on the standard `macos-15` runner, using the active
  Xcode installation through `xcrun --sdk iphoneos`; no Apple SDK or Xcode
  files are committed. The observed runner label resolved to `macos-15-arm64`.
- CI run: `35430530376`, successful job `105864153811` for the final
  pre-device-validation workflow state. The uploaded build metadata records
  the exact Git commit used for that artifact.
- Toolchain: macOS `15.7.9` build `24G830`, Xcode `16.4` build `16F6`,
  iPhoneOS SDK `18.5`, Apple clang `17.0.0`
  (`clang-1700.0.13.5`), and Go `go1.26.7 darwin/arm64`.
- Target: `GOOS=ios`, `GOARCH=arm64`, `CGO_ENABLED=1`, physical-device
  target `arm64-apple-ios12.0`, with deployment target `12.0`. This is
  compatible with the initial iOS `12.5.7` device target.
- Compiler wrapper: `scripts/ios/clang-wrapper` resolves the SDK and clang
  from `xcrun`, rejects simulator/macOS arguments, and supplies `-arch arm64`,
  `-target arm64-apple-ios12.0`, the active iPhoneOS `-isysroot`, and
  `-mios-version-min=12.0`. It fails clearly outside an active Xcode
  environment.
- Probe command: `scripts/ios/build-cgo-probe.sh build/ios/ios-cgo-probe`,
  which invokes `go build -mod=readonly -trimpath -buildvcs=false
  -buildmode=exe -ldflags=-linkmode=external` for
  `./tools/ios-cgo-probe`. The probe uses `import "C"` and a deterministic C
  function returning `42`.
- Mach-O inspection: `file` reported `Mach-O 64-bit arm64 executable` and
  `otool -hv` reported `MH_MAGIC_64`, `ARM64`, and `EXECUTE`. `LC_BUILD_VERSION`
  reported physical iOS platform enum `2`, `minos 12.0`, and SDK `18.5`.
  The workflow accepts the symbolic `IOS` spelling used by older tools and
  numeric platform `2` used by this Xcode, while rejecting simulator platform
  `7`.
- Linked libraries: `/System/Library/Frameworks/CoreFoundation.framework/CoreFoundation`,
  `/usr/lib/libresolv.9.dylib`, and `/usr/lib/libSystem.B.dylib`. No
  Homebrew or macOS-only dynamic dependency was found.
- Signing: CI used `codesign --force --sign - --timestamp=none`, producing an
  ad-hoc signature with `VersionPlatform=2`, `VersionMin=786432` (12.0), and
  no team identifier or provisioning profile.
- Artifact: the uploaded `ios-cgo-probe` was retrieved on Linux, identified as
  Mach-O arm64, and passed `sha256sum -c SHA256SUMS`. The executable was
  `1769008` bytes with SHA-256
  `ca05ccb276f61706403e02c6423ceae29bbecf7ccb2eeab84d0e603243eb801a`.
- Initial CI failure: the first run reached and built the valid Mach-O but
  failed only because the validator expected the textual platform name
  `IOS`; the final workflow corrected this to recognize Xcode's numeric
  platform enum without loosening the physical-device check.
- Device preflight: the configured Tailscale peer `ipad-server` was verified
  as iOS `12.5.7` build `16H81`, `iPad4,4`, arm64, with user `nghianguyen`.
  The transferred artifact's checksum matched on the device at
  `/var/nghianguyen/forgejo-ios-p2-preflight-b14ea0835a95288df4cfdc5cab149d1bb0570381`.
  Direct execution produced empty stdout/stderr and exit `137` (SIGKILL).
  The existing `/usr/bin/ldid` was detected; the minimum retry was applied to
  a copy, changing its SHA-256 to
  `f6d523e7c853ef0751bbb2cc444d183882511cd0b01e5cbff95ae7deca3fe009`, but
  that copy also produced empty stdout/stderr and exit `137`. No device-side
  diagnostic message was available to the configured user. This is an
  unresolved device execution blocker, not evidence of a Forgejo source
  failure.

## Prompt 003 runtime compatibility result

Prompt 003 remained diagnosis-only. It did not modify Forgejo production
packages, `go.mod`, `go.sum`, or the existing Prompt 002 compiler wrapper and
CGO build script. The workflow now builds one native C control and the
smallest pure-Go/CGO version matrix, but it preserves the original
Prompt 002 Go 1.26.7 CGO command as a regression check.

### Build evidence

The final matrix artifact records the exact Git commit and toolchain in
`build-info.txt`. The successful build environment was:

- GitHub Actions `macos-15`, runner architecture `arm64`.
- macOS `15.7.9`, Xcode `16.4` build `16F6`, iPhoneOS SDK `18.5`.
- Apple clang `17.0.0` (`clang-1700.0.13.5`).
- `GOOS=ios`, `GOARCH=arm64`, `CGO_ENABLED=1`, deployment target `12.0`.
- Go `1.20.14 darwin/arm64` and Go `1.26.7 darwin/arm64`, both obtained with
  the official `actions/setup-go` action. Go 1.20.14 was built in module-off
  file mode so the standalone probe did not inherit Forgejo's `go 1.26.0`
  module requirement.

Every successful executable was inspected with `file`, `otool -hv`,
`otool -l`, and `otool -L`. Each is a thin `Mach-O 64-bit arm64` executable
with `LC_BUILD_VERSION` physical iOS platform `2`, minimum iOS `12.0`, and
SDK `18.5`. No simulator, macOS, x86_64, Homebrew, or other host dynamic
library dependency was present. The native C probe links only
`/usr/lib/libSystem.B.dylib`; the Go probes link the expected system
libraries (`libSystem`, `libresolv`, and, where emitted by the Go external
link, CoreFoundation).

The CI signing treatment was `codesign --force --sign - --timestamp=none`.
The resulting signatures were ad hoc, with `VersionPlatform=2`,
`VersionMin=786432` (iOS 12.0), no team identifier, and no provisioning
profile. The artifact contained only the five probes, `SHA256SUMS`, and
`build-info.txt`:

| Probe | Build result | Size | SHA-256 |
| --- | --- | ---: | --- |
| `native-c-probe` | Apple clang native C: PASS | 68,112 bytes | `b53936f97cde0a332cd5f185bce8cc3489d90238f445d501229de8a6531c39e8` |
| `go120-probe` | Go 1.20.14 pure Go: PASS | 1,471,504 bytes | `b9cb2115575ed5ced0674fe1054218a145aa277702a5e137b551c774eb1ee864` |
| `go120-cgo-probe` | Go 1.20.14 CGO: PASS | 1,471,904 bytes | `e94d1e0bf4bd5ff818678952a6d0b398f2fb333fc1bfdb37e1b3988918496440` |
| `go126-probe` | Go 1.26.7 pure Go: PASS | 1,768,688 bytes | `01e87196666f84b96a10edf8f68c4ac8f9e8b195dc2fbef4ee5e0bb6ddbf617b` |
| `go126-cgo-probe` | Go 1.26.7 CGO and Prompt 002 path: PASS | 1,769,008 bytes | `a17286a05ad07edf96f834a12201779a70702a1849ea122c59ddacd8b0a2c72f` |

The only build warning was the Go 1.20.14 external linker's
`-ld_classic` deprecation warning from Xcode 16.4; it did not prevent either
Go 1.20.14 executable from being produced. The device-side `sha256sum -c
SHA256SUMS` check passed for all five transferred artifacts before execution.

### Real-device execution evidence

The target was the configured iPad mini 2 (`iPad4,4`, Apple A7, arm64),
iOS/iPadOS `12.5.7`, Darwin `18.7.0`. The probes were transferred to a
dedicated P3 directory without replacing the Prompt 002 artifacts. The
original CI ad-hoc copies were run first, in this order: native C, Go 1.20.14
pure Go, Go 1.20.14 CGO, Go 1.26.7 pure Go, and Go 1.26.7 CGO.

All five original CI ad-hoc copies had the same result:

- stdout: `0` bytes;
- stderr: `10` bytes, exactly `Killed: 9`;
- exit code: `137`.

This was not a Go-only result. The native C control died before printing
`forgejo-ios native C probe` or `C_RUNTIME=ok`. Both Go 1.20.14 probes and
both Go 1.26.7 probes likewise produced no startup marker, including the
runtime version/GOOS/GOARCH lines in the pure-Go probes.

The separately named `/usr/bin/ldid` copies were then tested without
mutating the checksum-controlled originals. Default `ldid -S` completed with
exit `0` and empty stdout/stderr for every copy; every resulting executable
still exited `137` with empty stdout and `Killed: 9` on stderr. As a signing
diagnostic, explicit `ldid -S -Cadhoc` copies were also tested. They reported
CodeDirectory flags `0x2(adhoc)` and also all exited `137`. The explicit ldid
retry therefore did not turn the matrix into a Go-version distinction.

Two lower-layer controls were useful:

- `/private/var` was mounted without `noexec`; the P3 directory itself was
  not an execution-disabled filesystem.
- The device's existing Apple-signed `/usr/bin/true` ran directly and also
  ran after copying it into the P3 directory. A copy of that same system
  binary re-signed with `ldid` was killed with `137`, just like the probes.
  This supports a device code-signing/AMFI enforcement explanation for the
  user-built files, but does not by itself identify the exact required
  entitlement or signature form.

The available device user could not read the kernel buffer (`dmesg` reported
`Operation not permitted`), and no readable system log or `otool`/`codesign`
diagnostic was available on the iPad. Therefore the exact subreason within
device signing enforcement, dyld rejection, or another jailbreak execution
policy is not claimed as proven.

### Classification

- **Proven fact:** Apple clang produced a valid physical-iOS arm64 Mach-O
  native C executable with minimum iOS 12.0, and both official Go versions
  produced valid equivalent pure-Go and CGO Mach-O executables. All five
  failed identically before application output on the real device.
- **Strong inference:** the Prompt 002 launch blocker is below the Go runtime
  layer and is shared by any user-built executable under the current device
  signing/execution policy. The native C failure rules out Go 1.26.7 as the
  explanation for the observed `SIGKILL`.
- **Untested hypothesis:** the device may require a particular jailbreak
  signing path, entitlement set, or older-compatible Mach-O/signature shape;
  the available unprivileged diagnostics cannot distinguish those causes.

The current evidence does **not** support classifying Go 1.26.7 as the iOS
12.5.7 runtime compatibility boundary. Go 1.20.14 is build-compatible with
the Xcode 16.4/iPhoneOS 18.5 toolchain, but its real-device runtime behavior
is presently masked by the same lower-layer failure as Go 1.26.7. No Go
runtime patch or Forgejo compatibility backport should be selected from this
matrix alone.

## Prompt 004 recommendation

First establish a device-accepted signing/execution path with the native C
control, using a known-working jailbreak signing procedure or privileged
AMFI/kernel diagnostics. In parallel, compare the complete Mach-O load
commands against a device-native executable and, if necessary, obtain a
supported older Apple toolchain/SDK diagnostic without downloading an
unofficial SDK. Repeat the same five-probe matrix only after native C runs;
then the Go 1.20.14-versus-1.26.7 runtime boundary can be evaluated directly.

Do not backport Forgejo to Go 1.20.14, patch the Go runtime, change Forgejo's
module requirements, or compile Forgejo production packages until that lower
device execution blocker is resolved. This is a device/toolchain/signing
investigation, not yet evidence for strategy A or B.

## Prompt 004 device-accepted execution path

Prompt 004 continued from commit
`8306fd07b11d16c481a26d42fc34c920e99ba066`. It remained a probe and signing
diagnosis only: no Forgejo production package, `go.mod`, or `go.sum` was
changed. The purpose was to distinguish a device acceptance failure from a Go
runtime failure and to rerun the existing P3 matrix after that lower layer was
fixed.

### Device and Amethyst inventory

The checks below were performed through the existing SSH session as the
unprivileged `nghianguyen` account. No jailbreak update, re-jailbreak, package
installation, root escalation, or system-file modification was attempted.

- The device is `iPad4,4`, Apple A7, arm64, iOS/iPadOS `12.5.7` build `16H81`,
  Darwin `18.7.0`.
- This is a rootful layout: `/amethyst` exists and `/var/jb` does not. The
  jailbreak base components were present at `/amethyst/jbutil`,
  `/amethyst/launchd_hook.dylib`, and `/usr/lib/base_hook.dylib`.
- All three components had owner `mobile:staff`, mode `0755`, and the same
  installation timestamp, `Sep 17 21:47`. Their SHA-256 values were:

  ```text
  /amethyst/jbutil             8e491f060d0963ac375ab8065712f6f7ddad31e4056a02b00c5164da3fb2542b
  /amethyst/launchd_hook.dylib e785970d74870cfe7883f5e7824792987b68f286c87b53652603ff64d715431f
  /usr/lib/base_hook.dylib     63515ea4274ed3dd35aa61caff005832df7f4b39ae6145a4e044742846e3f6a
  /usr/lib/libjailbreak.dylib  d0028116d23e163a93748244fc61332050716278ab4eb2f1a270d95e081a0723
  ```

- No core Amethyst package/version file was exposed by the readable local
  metadata. The installed package `com.staturnz.tnsv2-updater` is version
  `1.0.3`; its package description identifies it as the TNSv2 support package
  for updating Amethyst jailbreak files, so this is bootstrap/updater evidence
  and not proof that the device's core Amethyst binaries are release `1.0.3`.
  The core Amethyst version is therefore **UNKNOWN**, not silently equated to
  an upstream release. The readable `/amethyst` directory contained only
  `dyld_patch`, `handoff.plist`, `jbutil`, and `launchd_hook.dylib`.
- The SSH shell already exported
  `DYLD_INSERT_LIBRARIES=/usr/lib/base_hook.dylib`. With
  `DYLD_PRINT_LIBRARIES=1`, the device reported that `base_hook.dylib` was
  loaded into both the shell and a child `/usr/bin/true`. This proves the
  expected hook was active for this diagnostic launch path, although the
  unprivileged session cannot inspect its kernel-side state.
- `launchctl print system` and the readable launch-daemon directories did not
  expose a separately named Amethyst/jbserver service. The visible launchd
  process was PID 1. The launchd hook's presence and the observed base-hook
  load are the usable state evidence.

The official Amethyst source was also inspected as a behavioral reference.
Its `base_hook` initializes the jailbreak server and loader, its loader calls
the binary-processing path before spawning a child, and the server can sign or
trust-cache fakesigned Mach-O dependencies. The source's unsandbox selection
also treats `com.apple.private.security.no-container` as a full-unsandbox
indicator. These source facts explain why the entitlement ladder below is a
meaningful test; they do not prove that the device binaries are byte-for-byte
from the currently published source. See the [Amethyst source repository](https://github.com/staturnzz/amethyst),
[`loader.c`](https://github.com/staturnzz/amethyst/blob/main/basebins/launchd_hook/src/loader.c),
[`basebin_jbserver.c`](https://github.com/staturnzz/amethyst/blob/main/basebins/common/src/basebin_jbserver.c),
and [`basebin_macho.c`](https://github.com/staturnzz/amethyst/blob/main/basebins/common/src/basebin_macho.c).

### Working jailbreak reference binaries

Two installed non-Apple command-line executables were selected as golden
references. Their byte-identical copies were placed under the dedicated P4
diagnostic directory and executed before any modification.

| Reference | Build/runtime evidence | Code signature and entitlements |
| --- | --- | --- |
| `/usr/bin/ldid` | Mach-O arm64; root:wheel `0755`; SHA-256 `67a735a3f8cd65dbf27015b1e92d69ee15956dac2bf14bf5af7a54f5548fe041`; `Link Identity Editor 2.1.5-procursus6`; no-argument usage exit `0` | CodeDirectory v`20400`, flags `0x2(adhoc)`, SHA-256; exactly `platform-application`, `com.apple.private.security.no-container`, and `com.apple.private.skip-library-validation` |
| `/usr/bin/git` | Mach-O arm64; root:wheel `0755`; SHA-256 `845447a72617d05813d03faa4b99d3d0a78816c7ae940ff4ee6a6a6761ac03fd`; `git version 2.39.1`; no-argument usage exit `1` | CodeDirectory v`20400`, flags `0x2(adhoc)`, SHA-256; the same three entitlements as `/usr/bin/ldid` |

`/amethyst/jbutil` was also inspected as a third reference. It is a universal
arm64/arm64e Mach-O with SHA-256
`8e491f060d0963ac375ab8065712f6f7ddad31e4056a02b00c5164da3fb2542b`,
CodeDirectory flags `0x0(none)`, and a much larger Amethyst helper entitlement
set. Its untouched copy executed its usage path with exit `22`. It was not
used as a signing template because most of its entitlements are privileged
helper-specific and are not justified for a Forgejo probe.

The installed ldid is the Procursus package `ldid 2.1.5-procursus6`, owned by
the `ldid` package. The available options include `-S`, `-Cadhoc`,
`-e`, and CodeDirectory inspection. No replacement ldid was installed, and
host-side ldid semantics were not assumed to match this device implementation.

### Untouched versus re-signed copies

The original installed files were never modified. Byte-identical copies of
`ldid`, `git`, and `jbutil` retained their normal usage behavior. A separate
copy of each was then processed with `/usr/bin/ldid -S`, and another with
`/usr/bin/ldid -S -Cadhoc`, without an entitlement plist. Every re-signed
copy was killed with exit `137` before its normal usage output. For example,
the ldid copy changed from CodeDirectory flags `0x2(adhoc)` and the three
entitlements to flags `0x0(none)` or `0x2(adhoc)` with no entitlements, and
both versions died.

This reproduces the P3 control behavior: an Apple-signed `/usr/bin/true` and
its byte-identical copied signature execute, while an ldid-re-signed copy is
killed. The result isolates the failure to device binary acceptance/signing
policy rather than the `/var` project directory, a Go startup path, or user
code.

### Native C entitlement ladder

Each row started from the same checksum-controlled P3 native C executable.
Only the copied file was signed. The test was run in the SSH shell with the
active Amethyst base hook.

| Entitlements in the ldid-generated copy | Runtime result |
| --- | --- |
| none (`ldid -S`) | exit `137`, no output |
| `platform-application` | exit `137`, no output |
| `com.apple.private.security.no-container` | **exit `0`**, required marker |
| `com.apple.private.skip-library-validation` | exit `137`, no output |
| `platform-application` + `com.apple.private.security.no-container` | **exit `0`**, required marker |
| `platform-application` + `com.apple.private.skip-library-validation` | exit `137`, no output |
| `com.apple.private.security.no-container` + `com.apple.private.skip-library-validation` | **exit `0`**, required marker |
| all three reference entitlements | **exit `0`**, required marker |

The accepted minimal copy was generated with:

```text
/usr/bin/ldid -Sdevice-entitlements-no-container.plist native-c-probe-copy
```

It had CodeDirectory flags `0x0(none)`, SHA-256, and only
`com.apple.private.security.no-container`. Its SHA-256 was
`360efa7b64084f5562e508a471cf10b54f07ae8ef1cf0ac7ecca5de2fcfc1b94`. It
printed exactly:

```text
forgejo-ios native C probe
C_RUNTIME=ok
```

and exited `0`. An explicit `-Cadhoc` copy containing all three reference
entitlements also passed, so the successful condition is not dependent on
the CodeDirectory adhoc flag alone. The project-side fixture intentionally
contains only the one entitlement demonstrated as sufficient by the ladder;
it does not copy the privileged `jbutil` plist.

### Filesystem-location experiment

The same checksum-identical, no-container-signed native C copy executed from
the P4 directory under `/var`, `/tmp`, and `/var/tmp`. All three produced the
required marker and exit `0`, with SHA-256
`360efa7b64084f5562e508a471cf10b54f07ae8ef1cf0ac7ecca5de2fcfc1b94`.
`/tmp` and `/var/tmp` are both on the device's `/private/var` APFS mount, so
this proves the result is not tied to the original project directory but does
not claim a root-filesystem path comparison. `/amethyst`, `/`, `/private`,
and `/usr/local/bin` were not writable by the SSH user and were not modified.

### Go matrix after accepted signing

The same minimal signing treatment was applied to fresh copies of the final
P3 artifacts. The original CI ad-hoc files remained unchanged. All transfers
were checksum-verified before execution, and every accepted copy was inspected
as a Mach-O arm64 physical-iOS executable before running.

| Probe | Signing treatment | Accepted-copy SHA-256 | stdout | stderr | exit |
| --- | --- | --- | --- | --- | ---: |
| Go 1.20.14 pure | `ldid -S` + no-container only | `882bb4a08d62cf9ead434d04efa079541d63e7ba94dc2f602584e072c52990b1` | `forgejo-ios pure Go probe`; `GO_VERSION=go1.20.14`; `GOOS=ios`; `GOARCH=arm64`; `GO_RUNTIME=ok` | empty | `0` |
| Go 1.20.14 CGO | `ldid -S` + no-container only | `90b765069453b3faf950da2b75f5f992fd66c682d39c7771b200f9d60b52920c` | `forgejo-ios cgo probe`; `GOOS=ios`; `GOARCH=arm64`; `CGO=ok`; `C_VALUE=42` | empty | `0` |
| Go 1.26.7 pure | `ldid -S` + no-container only | `a31223b83883d16fabd6e82ec3b871c278d49ab51fb8b44c96762a51061500ff` | `forgejo-ios pure Go probe`; `GO_VERSION=go1.26.7`; `GOOS=ios`; `GOARCH=arm64`; `GO_RUNTIME=ok` | empty | `0` |
| Go 1.26.7 CGO | `ldid -S` + no-container only | `dd2a2e95e895b28ae6e040dbae0259e4d4ca646491c3db42b4f89d627328d293` | `forgejo-ios cgo probe`; `GOOS=ios`; `GOARCH=arm64`; `CGO=ok`; `C_VALUE=42` | empty | `0` |

The explicit `ldid -S ... -Cadhoc` copies of all four Go probes also ran with
exit `0` and the same markers. Therefore the current real-device startup
matrix is:

```text
native C       -> PASS with accepted no-container entitlement
Go 1.20.14     -> PASS with accepted no-container entitlement
Go 1.20.14 CGO -> PASS with accepted no-container entitlement
Go 1.26.7      -> PASS with accepted no-container entitlement
Go 1.26.7 CGO  -> PASS with accepted no-container entitlement
```

### Evidence classification

- **PROVEN:** the Apple clang native C probe executes on iOS 12.5.7 and
  returns `0` after the minimal device-accepted ldid treatment.
- **PROVEN:** Go 1.20.14 and Go 1.26.7 both start and complete the pure-Go
  and CGO probes on the same iPad under the same accepted treatment.
- **PROVEN:** the P2/P3 `SIGKILL` was not caused by Go 1.26.7, Go 1.20.14,
  CGO, the physical-iOS Mach-O target, or the writable `/var` location in
  isolation. Removing the demonstrated entitlement-bearing acceptance model
  reproduces the failure even for known-working jailbreak tools.
- **STRONG INFERENCE:** the primary P2 launch blocker was the Amethyst/AMFI
  device acceptance model. For this rootful environment, the smallest
  empirically accepted probe signature is an ldid-generated CodeDirectory
  carrying `com.apple.private.security.no-container`; the hook was active,
  but the exact kernel-side action that made the entitlement necessary was not
  directly observable from the unprivileged account.
- **UNKNOWN:** this startup probe does not establish full Go 1.26.7 support
  for every Darwin 18 syscall or runtime path, nor does it establish that the
  full Forgejo binary will need no additional entitlements or launch setup.
  The official Go support boundary remains relevant for later compatibility
  auditing, but it is not the observed cause of the P2/P3 pre-startup death.

### Diagnostics and remaining uncertainty

The device user could not read the kernel buffer (`dmesg` returned
`Operation not permitted`). No readable system log, AMFI report, `codesign`,
or `otool` implementation was available. Consequently, the exact AMFI reason
for the no-entitlement kill is inferred from the controlled ladder and the
working-reference comparison, not from a kernel log line. The installed core
Amethyst version is also not recoverable from readable local metadata beyond
the TNSv2 updater package and component hashes above.

The reproducible project-side procedure is
`scripts/ios/run-device-runtime-probes.sh`. It refuses an existing remote
directory, transfers the final CI artifact and the minimal entitlement
fixture, verifies `SHA256SUMS` on the device, runs each original CI copy, and
then signs and runs a separate accepted copy with the existing
`/usr/bin/ldid`. It does not install packages, modify Amethyst, mutate source
artifacts, or overwrite P2/P3 directories.

### Prompt 005 recommendation

Carry the empirically accepted device-side signing step forward as a
deployment/test prerequisite, while keeping `go 1.26.0` and
`toolchain go1.26.7` unchanged. The next prompt can begin the smallest
Forgejo production build/runtime probe with the same physical-iOS toolchain,
the accepted signing treatment, and explicit artifact inspection. Start with
the root executable and SQLite/CGO boundary, then test process/filesystem/Git
behavior on-device. Do not backport Forgejo to Go 1.20.14 or patch the Go
runtime based solely on the previously masked SIGKILL.

## Prompt 005 production Forgejo build and boot

Prompt 005 continued from the single P4 commit
`45c6a719c3c36e35503465ad8a6321678def9c55`. The final production artifact
for this prompt is built by the `iOS Forgejo production build` workflow from
the final P5 commit. The workflow's `build-info.txt` and `SHA256SUMS` are the
authoritative final-commit provenance and checksum records; the same checksum
file was verified on the iPad before the working copy was signed. No
production binary, downloaded toolchain, SDK, or device runtime directory is
stored in Git.

### Production build path

The repository's existing build machinery was reused. The P5 wrapper is
`scripts/ios/build-forgejo.sh`; it resolves the active iPhoneOS SDK and clang
with `xcrun`, uses `scripts/ios/clang-wrapper`, forces `GOOS=ios`,
`GOARCH=arm64`, `CGO_ENABLED=1`, `GOTOOLCHAIN=local`, and an iOS 12.0
deployment target, and invokes the upstream `make backend` target. That
target performs Forgejo's normal backend generation and builds the root
package from `main.go`.

The two CI variants are:

```text
minimal diagnostic variant: bindata timetzdata
primary production variant: bindata timetzdata sqlite sqlite_unlock_notify
```

The minimal variant is diagnostic only. The SQLite variant is the accepted
P5 artifact. Both compiled successfully on the final macOS runner. The
production source was not patched, and `go.mod`/`go.sum` remain unchanged.

Final build environment recorded by CI:

```text
runner: macos-15, arm64
macOS: 15.7.9
Xcode: 16.4
iPhoneOS SDK: 18.5
Apple clang: 17.0.0 (clang-1700.0.13.5)
Go: go1.26.7 darwin/arm64
GOOS/GOARCH: ios/arm64
CGO_ENABLED: 1
deployment target: iOS 12.0
```

The final CI artifact contains the pristine executable, the separate CI
ad-hoc-signed copy, `SHA256SUMS`, and `build-info.txt`. The artifact's
`build-info.txt` records the exact final commit, runner, SDK, tags, and
inspection output. The separate device working copy is the only copy mutated
by ldid. The production wrapper passes `-buildvcs=false` so the binary
content is not changed merely by documenting the already-recorded source
commit; `build-info.txt` remains the authoritative source-provenance record.

The final artifact checksum records are:

```text
forgejo-ios-pristine  9b58986442624e3879c33cb45629f025b1462ae6460b81740b9db5435f699fd0
forgejo-ios            477c3cf8a459c7bc1eb717a8b9c4328dd966cdf027200f044c6f615fa57238cb
```

These are the two entries in the final CI `SHA256SUMS`; both were verified
on-device before the pristine copy was retained and the separate working copy
was signed.

### Production Mach-O and SQLite evidence

The primary executable was inspected by
`scripts/ios/inspect-forgejo-binary.sh` before CI ad-hoc signing:

```text
Mach-O 64-bit executable arm64
LC_BUILD_VERSION platform 2 (physical iOS)
minimum OS: 12.0
SDK: 18.5
```

The final artifact is approximately 103 MB pristine and approximately 104 MB
after the CI ad-hoc signature. Its dynamic dependencies are limited to the
Apple system libraries used by the Go runtime and external linker:

```text
/usr/lib/libresolv.9.dylib
/System/Library/Frameworks/CoreFoundation.framework/CoreFoundation
/System/Library/Frameworks/Security.framework/Security
/usr/lib/libSystem.B.dylib
```

No Homebrew, MacPorts, simulator, macOS, or runner-local library dependency
was found. The `sqlite` build tag compiled the bundled
`github.com/mattn/go-sqlite3` implementation, and `sqlite_unlock_notify` was
present in the selected tag set. The first successful device log explicitly
reported:

```text
SQLite3 support is enabled
Beginning ORM engine initialization.
ORM engine initialization successful!
```

This is direct CGO/SQLite runtime evidence, not only a link-time result.

### Device artifact and signing treatment

The final pristine artifact, the CI ad-hoc copy, `SHA256SUMS`, and
`build-info.txt` were transferred to a new prompt-owned directory below
`/var/nghianguyen/forgejo-ios-p5/`. Both CI artifact entries passed
`sha256sum -c SHA256SUMS` on the iPad. The pristine copy was retained
unchanged. A separate working copy was made executable and signed with the
already-installed device tool:

```text
/usr/bin/ldid -S/var/nghianguyen/forgejo-ios/scripts/ios/device-entitlements-no-container.plist forgejo-ios
```

The device implementation is Procursus `ldid 2.1.5-procursus6`. Inspection
showed the working copy contains only the empirically required entitlement:

```text
com.apple.private.security.no-container
```

No `platform-application` or `com.apple.private.skip-library-validation`
entitlement was added. The signed working copy remained a Mach-O arm64
physical-iOS executable. Its checksum is intentionally kept separate from
the pristine artifact checksum because signing changes the file.

### CLI startup evidence

The accepted device command environment was:

```text
DYLD_INSERT_LIBRARIES=/usr/lib/base_hook.dylib
GOMAXPROCS=1
```

With that environment, the final production binary passed both non-mutating
CLI gates:

- `forgejo --version`: exit `0`, empty stderr, and stdout identifying the
  P5 Forgejo build, Go 1.26.7, and `bindata`, `timetzdata`, `sqlite`, and
  `sqlite_unlock_notify`.
- `forgejo --help`: exit `0`, empty stderr, and the expected root command
  list including `web`, `admin`, `migrate`, `doctor`, `actions`, and
  `forgejo-cli`.

The `GOMAXPROCS=1` requirement is a new, real-device production finding.
Without it, the same signed binary reaches Go/Forgejo initialization and
exits with `SIGILL` (shell exit `2`) before printing version output. The
faulting PC is in Go 1.26.7's `runtime.procyieldAsm`; the stack shows the
failure while `github.com/go-enry/go-enry/v2` initializes its regexp data.
This is distinct from the P2/P3 pre-startup AMFI kill. The small P4 probes
completed before exercising this longer initialization/GC path, so their
success did not disprove this production workload-specific runtime issue.

`GOMAXPROCS=1` is an evidence-backed launch requirement for this prompt, not
a claim that the Go runtime has been repaired. No Go toolchain or runtime
source was modified. Prompt 006 should decide whether to retain a documented
single-process launcher or investigate a narrowly scoped runtime fix.

### Isolated SQLite-backed server

The server test used a new configuration at the prompt-owned runtime path and
did not reuse existing Forgejo or Git service data. The configuration was
derived from the repository's own Docker app.ini conventions and set:

```text
WORK_PATH:        /var/nghianguyen/forgejo-ios-p5/<final-sha>/runtime
config:           .../runtime/custom/conf/app.ini
database:         .../runtime/data/forgejo.db
repository root:  .../runtime/repositories
application data: .../runtime/data
logs:             .../runtime/log
bind address:     127.0.0.1
port:             39123
database:         sqlite3, automatic migration enabled
SSH:              disabled
```

With the signed working copy and `GOMAXPROCS=1`, Forgejo:

1. created the isolated storage directories and files;
2. ran `git.InitFull`, located and executed the device's existing
   `/usr/bin/git`, and logged `Git version: 2.39.1`;
3. enabled the bundled SQLite support and initialized the ORM/migrations;
4. created `forgejo.db`, `forgejo.db-wal`, and `forgejo.db-shm`;
5. reached `Listen: http://127.0.0.1:39123`;
6. returned HTTP `200 OK` from an on-device curl request to `/`, with the
   Forgejo HTML title/body identifying the test instance; and
7. handled SIGTERM, closed the listener, closed the issue indexer, and
   reported `Forgejo Web Finished`.

The first clean shutdown left no Forgejo process and no listening socket. One
restart with the same SQLite data directory again initialized the database,
returned HTTP `200`, and shut down cleanly. The only remaining socket entries
were expected TCP `TIME_WAIT` records from the local HTTP requests. No
orphaned Forgejo process was left running.

### Evidence classification and Prompt 006 boundary

**PROVEN**

- Forgejo v15.0.9 production source builds as a physical iOS arm64 Mach-O
  with Go 1.26.7, CGO, bundled SQLite, and `sqlite_unlock_notify`.
- The final artifact has iOS platform 2/minimum iOS 12.0 metadata and no
  unintended host-library dependency.
- The P4 no-container device signing treatment accepts the real production
  executable.
- The accepted binary starts its CLI, opens an isolated SQLite database,
  executes the existing Git binary, serves loopback HTTP, handles SIGTERM,
  and restarts once under `GOMAXPROCS=1`.

**INFERRED**

- The `GOMAXPROCS=1` requirement is probably an A7/Go 1.26 runtime
  instruction or scheduling-path compatibility issue, because the same
  signed binary faults at `runtime.procyieldAsm` only with the default
  multiprocessor setting and succeeds with one process.
- The successful web response establishes the core Forgejo/SQLite/Git path,
  but not every background service or repository operation.

**NOT YET TESTED**

- Git clone/push, Forgejo repository creation, SSH Git, LFS, Actions,
  packages, webhooks, mail, mirrors, and load/durability behavior.
- Default multi-processor Go 1.26.7 Forgejo startup without a launcher
  workaround.
- A patched Go runtime or an iOS-specific Forgejo launcher implementation.

The recommended Prompt 006 work is to make the `GOMAXPROCS=1` launch policy
explicit and reproducible, then evaluate the smallest safe path toward
restoring multi-processor behavior on A7. Keep the production Go requirement
at Go 1.26.7 until that evidence exists; do not backport Forgejo to Go 1.20
based on the earlier P2/P3 signing failure.

## Prompt 006 A7 scheduler policy and multi-P SIGILL isolation

Prompt 006 continued from the complete P5 commit
`7e2598540195461d7a42077c1ec1401f739cf581`. It did not change Forgejo
production Go packages, `go.mod`, `go.sum`, the iPhoneOS build target, or the
P5 signing entitlement. The prompt formalized the current A7-safe launch
policy and isolated the multi-processor crash to a userspace counter-register
access in Go 1.26.7's arm64 runtime yield path.

### Supported A7/iOS 12 launch policy

The project-owned launcher is `scripts/ios/run-forgejo.sh`. It preserves an
explicit `GOMAXPROCS` value for diagnostics, but when no override is supplied
and the target identifies as `iPad4,4`, `iPad4,5`, or `iPad4,6` on Darwin
`18.*`, it exports:

```text
GOMAXPROCS=1
```

This policy is intentionally scoped to the Apple A7 iPad mini 2/iPad Air
family on iOS 12.x. It is not a claim that all iOS devices require one P, and
it does not globally bake single-core operation into Forgejo source. Future
SoCs and iOS versions must be tested independently. The launcher prints the
detected machine, Darwin release, selected policy, and effective `GOMAXPROCS`,
then `exec`s the real Forgejo binary so signals are delivered to Forgejo
rather than retained by a long-lived wrapper.

The established P5 production Forgejo binary was retested on the iPad under a
new P6 runtime directory at:

```text
/var/nghianguyen/forgejo-ios-p6/7e2598540195461d7a42077c1ec1401f739cf581/runtime
```

With `GOMAXPROCS=1`, two consecutive server starts on port `39124` succeeded.
Each run detected `/usr/bin/git` version `2.39.1`, enabled SQLite3 support,
completed ORM initialization, listened on `127.0.0.1`, returned HTTP `200`
with the `Forgejo iOS Prompt 006` page title, handled SIGTERM with wait status
`0`, and left no orphan Forgejo process.

### Multi-P failure reproduction

Using the same signed production binary and only changing the scheduler
setting, `GOMAXPROCS=2 forgejo --version` reproduced the P5 crash under
`GOTRACEBACK=crash`:

```text
SIGILL: illegal instruction
PC=0x10095902c
runtime.procyieldAsm(0x80)
fault 0x10095902c
```

This confirmed that the failure is not tied to SQLite, HTTP, or the Forgejo
configuration. It occurs during Go/Forgejo initialization when the Go runtime
uses more than one P.

### Exact Go 1.26.7 runtime implementation

The exact Go 1.26.7 toolchain used by the final P6 runtime-matrix workflow was
recorded from GitHub Actions:

```text
Go: go1.26.7 darwin/arm64
GOROOT: /Users/runner/hostedtoolcache/go/1.26.7/arm64
runtime/asm_arm64.s SHA-256: c2d54a06306c90a1d6ab666101c563056578a84c9b11f50575874af9c54b2133
runtime/stubs.go SHA-256: 0572c8b87cdbd975e8fddc5e8e84240d6397445589641035f0ce95e6676ee90e
```

The relevant `runtime.procyieldAsm` body in Go 1.26.7 is a counter/timer based
delay loop. It starts with `ISB`, reads `CNTFRQ_EL0`, reads `CNTVCT_EL0`, then
loops with another `ISB` and further `CNTVCT_EL0` reads until the requested
counter delta has elapsed. The build artifact also records the corresponding
object dump:

```text
0x10007a4d8  ISB $15
0x10007a4e8  MRS $24320, R1   ; CNTFRQ_EL0
0x10007a4fc  MRS $24322, R2   ; CNTVCT_EL0
0x10007a500  ISB $15
0x10007a504  MRS $24322, R1   ; CNTVCT_EL0
```

The P6 minimal Go 1.26.7 scheduler-contention probe repeatedly crashed at
`runtime.procyieldAsm +0x2c`, which maps to `asm_arm64.s:1126`, the first
`MRS CNTVCT_EL0` instruction. Three `GOMAXPROCS=2` runs failed with SIGILL
before completing the bounded workload. Three `GOMAXPROCS=1` runs completed
successfully.

### ARM64 instruction matrix on A7/iOS 12

P6 added native physical-iOS instruction probes under
`tools/ios-runtime-probes/arm64-instructions/`. Each probe prints a marker
before and after its candidate instruction and is signed on-device with the
same `com.apple.private.security.no-container` entitlement.

| Instruction | Build | Launch | Execute | Exit/signal | Classification |
| ----------- | ----- | ------ | ------- | ----------- | -------------- |
| `ISB` | PASS | PASS | printed `AFTER=ISB` | `0` | SUPPORTED |
| `MRS CNTFRQ_EL0` | PASS | PASS | printed `AFTER=CNTFRQ_EL0 VALUE=24000000` | `0` | SUPPORTED at EL0 |
| `MRS CNTVCT_EL0` | PASS | PASS | printed `BEFORE=CNTVCT_EL0`, then signal handler | `132` / `SIGILL` | TRAPS at EL0 |
| `YIELD` | PASS | PASS | printed `AFTER=YIELD` | `0` | SUPPORTED |

This distinguishes CPU support from userspace accessibility: P6 proves that
`CNTVCT_EL0` is not usable from this process context on the A7/iOS 12 target.
It does not claim the A7 lacks the architectural counter.

### Minimal scheduler reproducer and Go 1.20 comparison

P6 added `tools/ios-runtime-probes/go-multip/`, a bounded standalone Go probe
with no third-party dependencies. It prints `runtime.Version`, `runtime.NumCPU`,
and `GOMAXPROCS`, then runs a finite allocation/synchronization/GC workload
across multiple goroutines and exits with `RESULT=PASS` on success.

Real-device results using the same no-container signing treatment:

| Toolchain | `GOMAXPROCS=1` | `GOMAXPROCS=2` |
| --------- | -------------- | -------------- |
| Go 1.20.14 | 3/3 PASS | 3/3 PASS |
| Go 1.26.7 | 3/3 PASS | 3/3 SIGILL at `runtime.procyieldAsm +0x2c` |

Go 1.20.14's arm64 runtime implementation was inspected only as a diagnostic
reference. Its `runtime.procyield` loop uses `YIELD`, `SUBW`, and `CBNZ`; it
does not read `CNTVCT_EL0`. This explains why the Go 1.20 multi-P probe can
complete on the same device while Go 1.26.7 fails, without implying Forgejo
should be backported to Go 1.20.

### Runtime experiment decision

**EXPERIMENTAL, NOT ADOPTED:** a narrowly patched Go 1.26.7 runtime could
replace the iOS/arm64 `procyieldAsm` counter-delay path with an older
`YIELD`-based fallback, but P6 did not adopt that patch. Although the culprit
instruction is now identified, changing scheduler-spin behavior in the Go
runtime is a correctness-sensitive toolchain change. The project currently has
a safe production policy (`GOMAXPROCS=1`) and a precise reproducer, so a
runtime patch should be developed and reviewed as a dedicated follow-up rather
than rushed into P6.

No system Go installation, runner toolchain, or local user Go installation was
modified. No Go runtime source or toolchain binary was committed.

### Evidence classification and Prompt 007 boundary

**PROVEN**

- P5 Forgejo production functionality remains green on A7/iOS 12 when launched
  with `GOMAXPROCS=1`.
- The multi-P production crash is reproducible with `GOMAXPROCS=2` and reaches
  `runtime.procyieldAsm`.
- Go 1.26.7's exact `procyieldAsm` uses `CNTVCT_EL0`; the minimal Go 1.26.7
  P=2 probe faults at the first `CNTVCT_EL0` read.
- Standalone native probes show `ISB`, `CNTFRQ_EL0`, and `YIELD` execute, while
  `CNTVCT_EL0` traps with SIGILL in this userspace context.
- Go 1.20.14's bounded multi-P scheduler probe passes on the same device.
- `scripts/ios/run-forgejo.sh` provides a scoped A7/iOS 12 default policy and
  preserves explicit diagnostic overrides.

**INFERRED**

- The production Forgejo SIGILL and minimal Go 1.26.7 P=2 SIGILL share the
  same root cause: Go 1.26.7's arm64 `procyieldAsm` reads `CNTVCT_EL0`, which
  traps from this A7/iOS 12 userspace environment.
- A YIELD-style fallback is a plausible compatibility strategy because it is
  used by Go 1.20.14 and the standalone `YIELD` probe succeeds, but scheduler
  correctness and performance require a separate toolchain experiment.

**NOT TESTED**

- A patched Go 1.26.7 runtime/toolchain.
- Production Forgejo with `GOMAXPROCS=2` after a runtime patch.
- Other iOS hardware, later iOS releases, or non-A7 devices.

Recommended Prompt 007: build an isolated Go 1.26.7 experimental toolchain that
changes only the iOS/arm64 `procyieldAsm` fallback away from `CNTVCT_EL0`, then
validate the bounded Go scheduler probe and production Forgejo with
`GOMAXPROCS=2` on the A7 device before considering that runtime path supported.

## Prompt 007 A7-compatible Go 1.26.7 runtime

Prompt 007 continues from the P6 commit `57d8464d3305a87915b35c42f234ef29f17bfa44`.
The purpose of this section is to record a version-specific, isolated Go
runtime experiment. It does not downgrade Forgejo, change Forgejo production
packages, change `go.mod`/`go.sum`, redesign the scheduler, or alter atomic
operations.

### Exact source and compatibility reference

The P7 builder retrieves the official Go 1.26.7 source distribution from
`https://go.dev/dl/go1.26.7.src.tar.gz` and rejects any archive or source tree
whose identity does not match the recorded guards:

```text
archive SHA-256: 0ed24eac755105085b89fe9cabc2742b91a0ad7b94b59d3ad364918ebc8956ad
VERSION SHA-256: 89f723ad27054a2ccc7c22f2a974886f3077f64623a231297fcea2e74a73a782
src/runtime/asm_arm64.s SHA-256: c2d54a06306c90a1d6ab666101c563056578a84c9b11f50575874af9c54b2133
src/runtime/stubs.go SHA-256: 0572c8b87cdbd975e8fddc5e8e84240d6397445589641035f0ce95e6676ee90e
```

The source was reproduced as `go1.26.7`, with release metadata timestamp
`2026-08-18T21:44:21Z`. The Go 1.20.14 source was also retrieved separately
as a compatibility reference. Its `runtime.procyield` implementation is:

```text
MOVWU cycles+0(FP), R0
again:
    YIELD
    SUBW $1, R0
    CBNZ R0, again
    RET
```

That older loop is bounded by the `cycles` argument and uses no counter-timer
register. The Go 1.26.7 callers pass the same runtime backoff argument to
`procyieldAsm`, while Go 1.26.7's stock arm64 implementation interprets it as
a short nanosecond delay and reads `CNTVCT_EL0`. The P7 choice is therefore a
conservative instruction-level fallback, not a copy of unrelated Go 1.20
runtime code.

### Narrow runtime patch

The project-side patch is:

```text
scripts/ios/go-runtime/go1.26.7-a7-procyield.patch
```

It changes only the `runtime·procyieldAsm` body in the exact Go 1.26.7
`src/runtime/asm_arm64.s`. The assembler's `GOOS_ios` preprocessor branch
selects a bounded `YIELD`/`SUBW`/`CBNZ` loop for `GOOS=ios` and `GOARCH=arm64`.
The existing timer-based body, including `CNTFRQ_EL0` and `CNTVCT_EL0`, remains
in the inverse branch for other ARM64 targets. The patch SHA-256 in this
checkout is:

```text
b9b077f8e5a3408f08b49601a792ba7e32f6c0930302c98a4686e13a74f0bbfc
```

The reproducible builder is:

```text
scripts/ios/go-runtime/build-go-a7.sh
```

It recreates only `build/ios/go1.26.7-a7/goroot`, verifies the official
archive and source hashes, applies the patch with a fail-closed clean-apply
check, builds with a separate bootstrap Go, and writes
`build/ios/go1.26.7-a7/provenance.env`. The generated GOROOT, `pkg/tool`,
compiled packages, downloaded archive, and SDK remain ignored build artifacts;
none are vendored or committed.

### Host assembly validation

The isolated toolchain was built on Linux using bootstrap
`go1.27.1-X:nodwarf5` and reports:

```text
go version go1.26.7 linux/amd64
```

The selected assembly function was assembled twice with the isolated Go
assembler. The `GOOS=ios`, `GOARCH=arm64` object contains only the argument
load, zero check, `YIELD`, bounded decrement/branch, and return; it contains no
`MRS` instruction and no `CNTVCT_EL0`. The Linux-selected object retains the
stock `CNTFRQ_EL0`/`CNTVCT_EL0` timer reads. This is source/object selection
evidence; it is not a substitute for the final iPhoneOS CGO link or physical
device execution.

The host cannot link an iOS executable because Go requires external CGO
linking for `ios/arm64` and this Linux environment has no iPhoneOS SDK. The
real iPhoneOS probe and Forgejo binary are therefore built by the dedicated
macOS workflow:

```text
.github/workflows/ios-forgejo-a7-runtime.yml
```

The existing `ios-cgo-probe.yml` remains the stock Go 1.26.7/Go 1.20.14
runtime matrix and continues to document the unpatched A7 failure. The new
workflow separately builds the A7-compatible toolchain, checks the scheduler
probe's symbolized `runtime.procyieldAsm` object dump, checks the final
stripped Forgejo artifact for the unique six-instruction fallback signature
inside `__text`, builds the SQLite production artifact, records provenance,
and runs a normal stock-Go Linux regression job. The final Forgejo binary is
built with the established `-s -w` flags, so its Go symbol table is absent;
the raw signature check is deliberately fail-closed and records the file and
VM offsets of the selected body rather than pretending a symbolized dump is
available.

### P7 validation evidence and acceptance boundary

The following evidence was collected from the dedicated A7-compatible
workflow and its physical-device artifact. The final completion handoff
records the final workflow run and commit SHA; generated toolchains, device
data, and signed working copies remain outside Git.

**PROVEN**

- The exact Go 1.26.7 source and all required archive/source hashes are
  verified before patching. The patch hash is
  `b9b077f8e5a3408f08b49601a792ba7e32f6c0930302c98a4686e13a74f0bbfc`.
- The Go 1.20.14 ARM64 reference loop uses `YIELD`, `SUBW`, and `CBNZ` and
  does not read `CNTVCT_EL0`.
- The project patch changes only the `GOOS=ios`, `GOARCH=arm64`
  `runtime.procyieldAsm` branch. The stock timer-based implementation remains
  in the inverse branch for other ARM64 targets.
- The isolated Go 1.26.7 toolchain builds successfully on Linux and macOS
  using a separate bootstrap Go. The host/system Go and the runner-installed
  bootstrap Go are not modified in place.
- The selected iOS runtime object contains `MOVWU`, `CBZ`, `YIELD`, `SUBW`,
  `CBNZ`, and `RET`, with no `MRS` or `CNTVCT_EL0`. The non-iOS assembly
  selection retains the stock timer reads.
- The final production artifact is a physical `Mach-O 64-bit executable
  arm64`, has iOS platform 2/minimum iOS 12.0 metadata, and links only the
  expected Apple system libraries. Its existing stripped build has one
  unique exact fallback byte signature in `__text`:

  ```text
  file __text offset: 16384
  fallback file offset: 593920
  fallback VM address: 0x100091000
  body: MOVWU, CBZ, YIELD, SUBW, CBNZ, RET
  CNTVCT_EL0: absent from selected fallback body
  ```

- The stock Go 1.26.7 control remained documented and reproduced the known
  failure on the same iPad: P=1 passed and P=2 reached
  `runtime.procyieldAsm +0x2c`, `asm_arm64.s:1126`, at
  `MRS CNTVCT_EL0`. The prior P6 matrix remains 3/3 PASS for P=1 and 3/3
  SIGILL for P=2.
- The patched minimal scheduler probe passed P=1 5/5 and P=2 10/10 on the
  iPad. Every run exited 0. The P=2 representative output identified
  `go1.26.7`, `NUM_CPU=2`, `GOMAXPROCS=2`, `COMPLETED=16`, and
  `RESULT=PASS`.
- The bounded extended probe ran for 30 seconds at P=2 and recorded 0
  failures. Repeated final-artifact runs completed 90-94 probe iterations;
  that count is scheduler-timing dependent, not an acceptance threshold. This
  is a stability check, not a thermal or performance qualification.
- The patched Forgejo artifact reported:

  ```text
  forgejo version 15.0.9 (release name 15.0.9) built with GNU Make 3.81,
  go1.26.7 : bindata, timetzdata, sqlite, sqlite_unlock_notify
  ```

  Both `--version` and `--help` exited 0 at P=1 and P=2. The launcher logged
  `policy=preserve-explicit`, proving that the explicit P=2 acceptance run
  did not accidentally use the P6 single-process fallback.
- Forgejo server validation used the isolated prompt-owned device directory
  and port `127.0.0.1:39127` for the final amended commit. P=1 passed two starts, and P=2 passed two
  starts. Each run returned HTTP 200, logged Git `2.39.1`, reported SQLite3
  support and successful ORM initialization, reached the expected listener,
  created `forgejo.db`, `forgejo.db-wal`, and `forgejo.db-shm`, and handled
  SIGTERM with wait status 0 and `Forgejo Web Finished`.
- The P=2 first run also handled eight bounded concurrent loopback GET
  requests with all eight responses returning HTTP 200. No Forgejo process
  was left running after any shutdown or restart.
- The dedicated macOS A7 workflow passed its isolated toolchain build,
  patched scheduler-probe build/inspection, final Forgejo build/inspection,
  provenance/checksum generation, and artifact upload. Its parallel Linux
  job passed `make build TAGS='bindata timetzdata sqlite sqlite_unlock_notify'`
  using normal stock Go 1.26.7.
- The final completion artifact was built from commit
  `1a81ea367219ecae035d3dc79908c4e0bcbb269f` in workflow run
  `35445809109`; the final physical-device acceptance used the matching
  artifact and the isolated directory
  `/var/nghianguyen/forgejo-ios-p7/1a81ea367219ecae035d3dc79908c4e0bcbb269f`.
- The existing stock iOS matrix remains separate from the A7-compatible
  production workflow. It continues to cover native C, Go 1.20, Go 1.20
  CGO, stock Go 1.26, stock Go 1.26 CGO, ARM64 instruction probes, and the
  known stock multi-P failure characterization.

**EXPERIMENTAL / STAGED**

- The `YIELD` fallback is now accepted for the tested Forgejo workload on
  `iPad4,4`, iOS 12.5.7, Darwin 18.7.0, with P=2. It has not been qualified
  for sustained production load, thermal behavior, battery impact, or every
  background worker and repository operation.
- The launcher policy remains conservative: absent an explicit override,
  `iPad4,4`, `iPad4,5`, and `iPad4,6` on Darwin `18.*` still receive
  `GOMAXPROCS=1`. An explicit `GOMAXPROCS=2` is supported only when the
  binary is known to carry the P7-compatible runtime provenance. This avoids
  launching a stock Go 1.26.7 binary at P=2.
- The binary/build provenance identifies the runtime as
  `P7_RUNTIME=go1.26.7-a7`, records the exact source guards and patch hash,
  and is emitted in CI build metadata. The user-facing Forgejo version was
  not changed.

**NOT TESTED**

- Other iOS releases, non-A7 SoCs, or the sibling A7 identifiers
  `iPad4,5`/`iPad4,6`.
- Long-duration soak, thermal/battery qualification, large repository
  operations, Git push/receive-pack workflows, graceful restart, and all
  optional Forgejo services.
- A future Go release. The builder intentionally rejects source revisions
  other than the exact guarded Go 1.26.7 source and must be revalidated before
  any Go 1.26.8 or Go 1.27 use.

P7 is complete only for the narrow tested compatibility boundary above. If a
future device or workload produces a hang, panic, scheduler corruption, or
runtime fault, revert that deployment to the existing `GOMAXPROCS=1` policy
and treat the fallback as unqualified for that boundary.

### Prompt 008 recommendation

Keep the P7 runtime/toolchain unchanged while extending evidence to the two
sibling A7 identifiers, one later iOS release if available, longer but
bounded service and repository exercises, and explicit provenance-aware
launcher selection. Do not broaden the patch to other ARM64 operating systems
or future Go versions without a new source review and device matrix.

## Prompt 008 resource profiling and provenance handoff

Prompt 008 extends the already accepted P7 runtime without changing the Go
runtime patch or Forgejo source architecture. Its changes are limited to the
launcher resource/status surface, path-free runtime provenance generation, and
the A7 workflow checks that exercise those surfaces.

### Resource profile evidence

The primary target remains `iPad4,4`, Apple A7, iOS 12.5.7, Darwin 18.7.0,
with the P7 artifact provenance `go1.26.7-a7`. The bounded P8 repository
lifecycle and resource profile used an isolated root and HTTP listener; no
real repository was used.

The completed short profiles recorded:

| Profile | Samples / workload | RSS | CPU | Threads | Result |
| --- | --- | ---: | ---: | ---: | --- |
| Idle | 28 samples | 136832–137068 KB | 0.2% max, 0.021% average | 10 | PASS |
| HTTP | 50/50 HTTP 200 | 137180–137216 KB | 0.9% max, 0.452% average | 10 | PASS |
| Git | clone/push/pull workload | 137264 KB peak | 96.7% max | 10–12 | PASS |

The six-hour service soak is run separately at the same isolated root. Its
monitor requires the Forgejo PID to remain alive, `/` and the authenticated
repository API to return HTTP 200, and SQLite `PRAGMA integrity_check` to
return `ok` on every ten-minute sample. The final soak status, sample count,
range, and stop/restart result are recorded below once the bounded monitor
finishes.

### Launcher and provenance

`scripts/ios/run-forgejo.sh status` reports the runtime, target device and
Darwin release, effective `GOMAXPROCS`, policy, Forgejo version, SQLite/Git
availability, build commit, runtime patch hash, process RSS/CPU, thread count,
and file-descriptor availability. It does not invent an FD value when the
device lacks `lsof`.

`scripts/ios/write-runtime-provenance.sh` writes the Forgejo version, source
commit, `go1.26.7-a7` runtime, exact patch hash, build tags, target tuple, and
patch scope through a temporary file followed by an atomic rename. The local
sanitization check passed with no private path or credential-like field.

### Prompt 008 acceptance boundary

The P8 status/provenance implementation is staged for the tested A7/iOS 12
boundary only. It does not broaden the P7 runtime patch, qualify other A7
identifiers, or claim thermal, battery, network, or indefinite-soak behavior.

## Prompt 010 service lifecycle and process management

Prompt 010 adds service management around the validated P7/P9 Forgejo
executable. It changes only `scripts/ios/run-forgejo.sh`, the iOS CI
launcher checks, and this documentation. It does not modify Forgejo core,
the Go runtime patch, the SQLite implementation, or the Linux service
definition. The launcher is a jailbreak-compatible process wrapper and does
not assume systemd or macOS launchd.

### Launcher commands

The command interface is provided by `scripts/ios/run-forgejo.sh`; on the
device it can be installed or symlinked as `forgejo-ios`:

```sh
export FORGEJO_IOS_BINARY=/var/nghianguyen/forgejo-ios-p10/<sha>/forgejo-ios-a7
export FORGEJO_IOS_SERVICE_DIR=/var/nghianguyen/forgejo-ios-p10/<sha>/runtime
export FORGEJO_IOS_DEVICE_MODEL=iPad4,4
export FORGEJO_IOS_DARWIN_RELEASE=18.7.0

forgejo-ios start --config /var/nghianguyen/forgejo-ios-p10/<sha>/app.ini
forgejo-ios status
forgejo-ios restart
forgejo-ios stop
```

The repository script may be called directly as
`scripts/ios/run-forgejo.sh`. A binary path may be supplied after `start`
or `restart`, and a first start may include Forgejo arguments. The launcher
stores those arguments in a mode-600 `forgejo.args` state file so a later
argument-free `restart` can reproduce the same invocation. Do not put
credentials in command-line arguments; use the Forgejo configuration and
device permissions instead. The legacy direct form,
`run-forgejo.sh FORGEJO_BINARY [ARG...]`, and the prior
`run-forgejo.sh status FORGEJO_BINARY [PID]` form remain supported.

### PID and lifecycle behavior

The default state files are below `FORGEJO_IOS_SERVICE_DIR`:

```text
forgejo.pid       mode 600, one validated numeric PID
forgejo.binary    mode 600, the executable identity used for validation
forgejo.args      mode 600, one launch argument per line
forgejo.pid.lock  transient atomic lifecycle-operation lock
logs/
```

`start` rejects an existing live PID that belongs to Forgejo with the
message `Forgejo already running PID <pid>`. It also scans the process table
when no PID file exists. An invalid PID file or a live PID belonging to a
different executable is retained and causes a refusal; the launcher never
signals an unverified process. PID and state writes use a temporary file and
same-directory rename. A dead numeric PID is stale state and is removed only
after the process table confirms it is no longer running.

`stop` sends `SIGTERM`, waits up to `FORGEJO_IOS_STOP_TIMEOUT` seconds
(default 30), and removes the PID file only after the process exits. A
timeout retains the PID file and returns an error so a potentially live
process is not hidden. `restart` runs this stop path first and then starts
from the saved or supplied arguments. The launcher does not automatically
send `SIGKILL` after a timeout.

The bounded host lifecycle harness and the A7 CI lifecycle step cover start,
duplicate refusal, status, SIGKILL-created stale PID recovery, restart,
SIGTERM stop, PID removal, and the no-credential log check. The corresponding
device run uses a new P10 runtime root and leaves the existing P8 service and
its monitor untouched.

### Logs and provenance

For a managed service, logs are created below
`$FORGEJO_IOS_SERVICE_DIR/logs`:

```text
forgejo.log       Forgejo stdout and stderr
launcher.log      start/stop/duplicate/error and exec events
runtime.log       timestamp, lifecycle event, PID, Forgejo version, runtime,
                  and executable path
```

The launcher deliberately does not write passwords, access tokens, private
keys, or full Forgejo arguments to these logs. `forgejo.log` is the
application's own output and must be reviewed if a custom Forgejo extension
or configuration emits sensitive data. The log and state files are created
with owner-only permissions where the filesystem permits it.

### Jailbreak startup strategy

The supported startup options are classified against the current target as
follows:

| Option | Classification | Boundary |
| --- | --- | --- |
| Manual `forgejo-ios start` from an SSH shell or local jailbreak shell | **PROVEN / TESTED** | The iPad lifecycle run starts, reports, restarts, and stops the A7 binary. It is operator initiated. |
| A rootful LaunchDaemon or equivalent launchd job | **NOT TESTED** | No plist was installed or enabled. Do not infer macOS launchd behavior or automatic boot support from this port. |
| A jailbreak-specific startup hook or tweak | **NOT TESTED** | No hook was installed. The hook, environment, filesystem readiness, and network ordering need a separate device test. |

Manual launch is the only supported deployment strategy in this prompt.
Automatic boot support is intentionally not claimed. A future startup test
must use a prompt-owned plist or hook, a finite timeout, explicit log paths,
and a reversible disable/remove procedure; it must not touch the existing P8
monitor.

### Network validation

The P10 local validation binds the Forgejo HTTP listener to
`127.0.0.1:<port>` and checks an HTTP 200 response from the iPad itself.
This is the safe default and is **TESTED**. A listener bound only to
`127.0.0.1` is not expected to be reachable through the device's Tailscale
address.

The separately documented Tailscale check uses the active device address
reported by `tailscale status` and an explicit `HTTP_ADDR` equal to that
address, not `0.0.0.0`. The host checks the Tailscale URL for HTTP 200 while
the device checks the local address and `netstat` listener tuple. This is
**TESTED** only for the finite P10 request; it does not qualify Wi-Fi,
internet exposure, firewall policy, or a permanent public bind. No
unexpected wildcard bind is accepted.

### Resource boundary and regression

The P10 resource check is limited to at most ten minutes and samples the
Forgejo PID's RSS, process CPU percentage, and thread count during startup,
HTTP checks, and stop/restart. It is compared with the P9 process-local
baseline rather than interpreted as whole-device capacity. It does not claim
thermal, battery, background-execution, or indefinite-soak behavior.

The Linux regression remains:

```sh
make build TAGS='bindata timetzdata sqlite sqlite_unlock_notify'
```

The iOS regression remains the A7 workflow's isolated Go 1.26.7 runtime
build, `runtime.procyieldAsm` inspection, physical-iOS Forgejo build,
provenance check, launcher lifecycle harness, and artifact upload. The P10
device evidence is limited to `iPad4,4`, Apple A7, iOS 12.5.7, Darwin
18.7.0, and the `go1.26.7-a7` runtime provenance.

### P10 device evidence

The bounded device run completed on 2026-09-20 through the existing SSH
connection to `ipad-server`. It used the P9-accepted A7 Forgejo artifact in
the isolated root below; no P8/P9 runtime data was modified:

```text
device: iPad4,4 / Apple A7 / iOS 12.5.7 / Darwin 18.7.0
runtime root: /var/nghianguyen/forgejo-ios-p10/de9576d6fb0ccfda3b15fc4963d1f4ff85413b31
local lifecycle port: 127.0.0.1:39131
Tailscale lifecycle port: 100.126.138.43:39132
launcher SHA-256: 7b7b654ba55a69b2f6aa87006be0de82ce8b1bb2909cc53fa22ccb317ecffe1b
runtime: go1.26.7-a7
runtime patch SHA-256: b9b077f8e5a3408f08b49601a792ba7e32f6c0930302c98a4686e13a74f0bbfc
```

The existing P8 process remained PID 12820 on loopback port 39129, including
its monitor. P10 duplicate detection did not mistake that process for the
isolated P10 binary after identity matching was tightened to the absolute
executable path.

| Check | Result | Evidence |
| --- | --- | --- |
| Start and PID file | **PASS** | P10 PID 40683; PID stored and status reported `running`. |
| Local HTTP | **PASS** | `127.0.0.1:39131/` returned HTTP 200 after startup. |
| SQLite initialization/integrity | **PASS** | `forgejo.db` was created; `PRAGMA integrity_check` returned `ok` before and after stop/restart. |
| Status/resource fields | **PASS** | RSS 150224 KB at first sample; CPU 0.3%; 14 threads; `lsof` unavailable was reported explicitly. |
| Duplicate start | **PASS** | A second start returned `Forgejo already running PID 40683`; P8 PID 12820 was not treated as the same instance. |
| Restart | **PASS** | PID 40683 stopped and PID 41096 started; local HTTP 200, `/explore/repos` HTTP 200, and SQLite `ok`. |
| Crash recovery | **PASS** | SIGKILL left PID 41221; status reported it stopped; start removed stale state and recovered as PID 41307. |
| Clean stop/orphan check | **PASS** | SIGTERM stopped each P10 process, removed `forgejo.pid`, and left no P10 Forgejo process. |
| Managed logs | **PASS** | `forgejo.log`, `launcher.log`, and `runtime.log` were present with mode 600; launcher/runtime logs contained no password/token/private-key text. |
| Manual startup | **PROVEN / TESTED** | All P10 starts were operator initiated through the launcher. |
| LaunchDaemon/startup hook | **NOT TESTED** | No plist or jailbreak hook was installed. |

The 20-sample resource window lasted approximately 20 seconds during an
idle local service with an HTTP request on every sample. All 20 requests
returned HTTP 200. The process-local range was RSS 150224--150372 KB, CPU
0.0--0.7 percent, and 14 threads throughout. This is compared with the P9
startup sample of 139888 KB and P9 post-restart sample of 140492 KB; it is
not a whole-device or thermal qualification.

For network reachability, the service was then restarted with an explicit
bind to `100.126.138.43:39132`. The host and the device both received HTTP
200 through that Tailscale address. Device loopback `127.0.0.1:39132`
returned connection failure as expected for an address-specific bind, and
`netstat` showed `100.126.138.43.39132 LISTEN` with no wildcard
`*.39132` or `0.0.0.0.39132` listener. The service was stopped cleanly
after the check. The Tailscale result is a finite reachability test, not a
claim about Wi-Fi, internet exposure, firewall policy, or automatic boot.

The P10 root contains runtime evidence only and is intentionally outside Git.
The P10 HTTP check used an empty isolated database, so `/explore/repos`
availability was verified after restart; the P9 workload remains the evidence
for actual repository objects, Git history, and repository persistence.

## Prompt 013 security hardening and deployment boundary

Prompt 013 hardens the deployment boundary without changing Forgejo
authentication, the A7 Go runtime patch, or Forgejo feature availability. The
new [`docs/SECURITY.md`](docs/SECURITY.md) is the operational contract, and
[`scripts/ios/audit-security.sh`](scripts/ios/audit-security.sh) is a read-only
mode and credential-surface audit. The launcher now applies `umask 077` and
restricts a dedicated service tree and explicit configuration file before
starting Forgejo. The P12 backup workflow now refuses a source or restored
payload with group/other file bits or non-`700` directories.

### Supported P13 deployment boundary

The supported initial deployment is rootful manual launch on the qualified
`iPad4,4` target. A dedicated runtime uses `custom/conf/app.ini`, `data/`,
`repositories/`, and `logs/` below an owner-only root. Configuration, database,
key, log, launcher-state, and backup metadata files are mode `600`; runtime,
data, repository, log, and backup directories are mode `700`. A P10 root with
`app.ini` beside the binary is historical and must be migrated to the P13
`custom/conf/app.ini` layout before using the strict backup procedure.

The local-only network default is explicit `HTTP_ADDR = 127.0.0.1` with the
built-in and external Forgejo SSH services disabled unless separately
qualified. Tailscale access is supported only as an explicit address-specific
bind with external ACLs. A reverse proxy may terminate TLS and expose the
service while Forgejo remains loopback-bound. No P13 deployment uses
`0.0.0.0`, `::`, or `*` as an implicit safe default.

### P13 disposable device evidence

The P13 check used a fresh runtime below
`/var/nghianguyen/forgejo-ios-p13/work/runtime` and the previously accepted A7
Forgejo artifact. The existing P8 service on `127.0.0.1:39129` was not
stopped, restarted, or chmodded. The P13 account, API tokens, cookies, private
repository, hook marker, database, logs, and backup were disposable and were
kept outside Git.

| Check | Result | Evidence boundary |
| --- | --- | --- |
| Runtime permissions | **PASS** | `audit-security.sh` passed; all P13 directories were `700`, sensitive files including `app.ini`, SQLite/WAL/SHM, private keys, state, and logs were `600`. |
| Legacy permission audit | **LIMITATION RECORDED** | Historical P8/P10/P11 roots contained `0644` configuration/database files and some `0755` data directories; the active P8 runtime was intentionally not mutated. A P13 restart/new deployment applies the owner-only policy. |
| Local network | **PASS** | `127.0.0.1:39136` returned HTTP 200; `netstat` showed only `127.0.0.1.39136 LISTEN` for the P13 PID and no wildcard tuple. |
| Tailscale local-only rejection | **PASS** | Host probe to the device Tailscale address and P13 port returned connection failure (`curl` exit 7, HTTP 000). |
| Secret leak surface | **PASS** | No tracked private-key/common-token pattern; disposable password was absent from P13 logs, backup output, and backup tree; metadata recorded `SECRETS_IN_METADATA=none`. |
| Web login/session/logout | **PASS** | Login followed a 303 to dashboard; protected settings returned 200 while signed in, logout returned 200, and settings returned 303 afterward. |
| Password storage | **PASS** | The temporary account's stored password value was a 100-character hash and did not equal the generated password. No plaintext token column was present in the access-token table. |
| API token handling | **PASS** | Disposable token authenticated `/api/v1/user` with HTTP 200; a modified token returned HTTP 401; the database retained a 100-character token hash, not the token value. |
| Private repository visibility | **PASS** | Repository creation returned 201; anonymous API read returned 404; owner token read returned 200. |
| Git access and hooks | **PASS** | Unauthenticated `git ls-remote` was rejected; authenticated clone/push passed; an owner-only mode `700` pre-receive hook executed; `git fsck --full` passed. |
| Backup/restore | **PASS** | Stopped-files backup and restore passed SQLite integrity and Git fsck; one repository was retained; backup root was `700`, metadata/manifest/payload were `600`. |
| Bounded resource window | **PASS** | Startup to loopback HTTP ready: 7 s; six HTTP probes: 6/6; 12 s sample RSS `124664--124780 KB`, CPU `0.0--0.3%`, average `0.150%`. |

The authentication and Git checks validate the existing Forgejo behavior at
the HTTP/SQLite/Git boundary; they do not replace Forgejo's upstream security
review. The disposable credentials were not deployment credentials and must
not be reused.

### CI and release boundary

The iOS workflow now runs the strict permission fixture, an expected-failure
mode test, backup/restore permission checks, source credential-pattern checks,
and a generated build/provenance secret scan in addition to the existing A7
runtime and Forgejo build checks. Linux remains:

```sh
make build TAGS='bindata timetzdata sqlite sqlite_unlock_notify'
```

The final P13 handoff must still report the exact Linux result, iOS workflow
result, one commit SHA, pushed `origin/ios` SHA, and the synchronized iPad
checkout/artifact SHA. Runtime data, credentials, keys, logs, cookies, and
backups are not release artifacts.

## Prompt 014 release candidate

Prompt 014 prepares a reproducible release candidate without changing
Forgejo source behavior, authentication, the Go runtime patch, or the set of
enabled features. The candidate is the combination of the source commit, the
CI-built artifact, its path-free `build-info.txt`, and `SHA256SUMS`.

### Qualified target and build contract

The release boundary remains deliberately narrow:

```text
Forgejo 15.0.9
Go runtime go1.26.7-a7
iPad4,4 / Apple A7 / iOS 12.5.7 / Darwin 18.7.0
GOOS=ios GOARCH=arm64 CGO_ENABLED=1
minimum physical iOS target: 12.0
build tags: bindata timetzdata sqlite sqlite_unlock_notify
```

The A7 runtime is built only by
[`scripts/ios/go-runtime/build-go-a7.sh`](scripts/ios/go-runtime/build-go-a7.sh)
from the guarded Go `1.26.7` source. Its patch SHA-256 is
`b9b077f8e5a3408f08b49601a792ba7e32f6c0930302c98a4686e13a74f0bbfc` and its
scope is limited to the `GOOS=ios`, `GOARCH=arm64` `runtime.procyieldAsm`
fallback. No generated runtime directory, SDK, private key, or credential is
part of the source release.

The reproducible CI environment is the existing `macos-15` arm64 runner with
Xcode `16.4`, iPhoneOS SDK `18.5`, Apple clang `17.0.0`, and the isolated
Go `1.26.7` toolchain. The build uses the physical-iOS Mach-O path and
records the exact source commit, toolchain hashes, deployment metadata,
runtime instruction inspection, signature result, and checksums in the
generated build files. The final source SHA is authoritative in the
candidate `build-info.txt` and the corresponding CI run.

### Candidate artifact and checksum

The release bundle names the CI ad-hoc-signed working copy `forgejo-ios` and
keeps the unsigned/pristine build separately when it is distributed for
device-side signing. The currently verified candidate values are:

```text
forgejo-ios           19dd23e3a78d13e1beb18a1e475d7b1a2c75959a0718d958905a0a540400218a
forgejo-ios-pristine  e8a8d55f9cb3a942bad8cb0a00e3b88201244e8e73b469b1d45884ab6347389d
```

The same executable and scheduler-probe bytes were reproduced by the two
latest CI checkpoints with unchanged Forgejo build inputs; the source commit
remains in the provenance file rather than being embedded through VCS build
metadata. Always verify the downloaded bundle with its accompanying
`SHA256SUMS`. The device-side `ldid` operation adds the tested no-container
entitlement and therefore produces a different installed-file checksum;
preserve the host checksum separately from the installed checksum.

### Installation and final smoke procedure

Only install into a new owner-only runtime tree. Do not point these commands
at an existing instance or copy a real database into a smoke-test root.

1. Verify `forgejo-ios` against `SHA256SUMS` before transfer. Transfer the
   executable, [`scripts/ios/run-forgejo.sh`](scripts/ios/run-forgejo.sh), and
   [`scripts/ios/device-entitlements-no-container.plist`](scripts/ios/device-entitlements-no-container.plist)
   to the rootful device.
2. Make a device-side working copy and sign that copy with the installed
   `/usr/bin/ldid` and the project entitlement plist. Confirm with `ldid -e`
   that `com.apple.private.security.no-container` is present. The host CI
   ad-hoc signature is not a promise that an arbitrary jailbreak will accept
   the file unchanged.
3. Create `custom/conf/app.ini`, `data/`, `repositories/`, and `logs/` below
   a dedicated mode-`700` runtime root. Keep `app.ini`, database files, logs,
   and launcher state at mode `600`. Set an explicit loopback address and
   disable both Forgejo SSH services for the initial deployment.
4. Start and inspect the service through the launcher, using a disposable
   port and the explicit configuration path:

   ```sh
   export FORGEJO_IOS_BINARY=/var/nghianguyen/forgejo-ios/<candidate>/bin/forgejo-ios
   export FORGEJO_IOS_SERVICE_DIR=/var/nghianguyen/forgejo-ios/<candidate>/runtime
   export FORGEJO_IOS_DEVICE_MODEL=iPad4,4
   export FORGEJO_IOS_DARWIN_RELEASE=18.7.0

   scripts/ios/run-forgejo.sh start "$FORGEJO_IOS_BINARY" \
     --config "$FORGEJO_IOS_SERVICE_DIR/custom/conf/app.ini"
   scripts/ios/run-forgejo.sh status "$FORGEJO_IOS_BINARY"
   "$FORGEJO_IOS_BINARY" --version
   PORT=39140
   curl --fail "http://127.0.0.1:${PORT}/"
   sqlite3 "$FORGEJO_IOS_SERVICE_DIR/data/forgejo.db" \
     'PRAGMA integrity_check;'
   scripts/ios/run-forgejo.sh stop "$FORGEJO_IOS_BINARY"
   ```

   The expected result is Forgejo `15.0.9`, runtime `go1.26.7-a7`, the A7
   default `GOMAXPROCS=1` policy, HTTP 200, SQLite `ok`, and a clean stop with
   no PID file left behind. Inspect the raw `netstat` listener address before
   following any URL; `0.0.0.0`, `::`, and `*` are not acceptable local-only
   defaults.

### P14 disposable device evidence

The release-candidate smoke and backup checks used only the isolated tree
below and did not touch the existing P8 service or any real repository:

```text
device: iPad4,4 / Apple A7 / iOS 12.5.7 / Darwin 18.7.0
runtime root: /var/nghianguyen/forgejo-ios-p14/276ef3b783c40348d35fc00ad249f3c9fd76742e
loopback port: 127.0.0.1:39140
host artifact SHA-256: 19dd23e3a78d13e1beb18a1e475d7b1a2c75959a0718d958905a0a540400218a
device ldid copy SHA-256: 90d21e21e14438b5edbc0745a326ffe4a3b3c95e763b9e3d6bab48f6fadb734e
backup payload SHA-256: b7d7f1f7fa5c97e04c9deab4f06c170de98f1d035d9f83c25c5cda30336cc7bc
```

The smoke result was **PASS**: the device-side signature exposed the required
no-container entitlement, `--version` reported Forgejo `15.0.9` with all four
requested tags, launcher status reported `go1.26.7-a7`, HTTP returned 200,
SQLite integrity returned `ok`, and the listener was only
`127.0.0.1:39140`. The service stopped cleanly.

The backup compatibility result was **PASS**: the stopped-files backup and
manifest verified, the owner-only audit passed for the source/backup/restored
trees, restore created a new runtime, and the restored service returned HTTP
200 and SQLite `ok` before a clean stop. The backup contained no repository
objects; it was intentionally a data-free compatibility check rather than a
repeat of the P12 workload.

### Release limitations

- Only the rootful Amethyst deployment on `iPad4,4` / Apple A7 / iOS 12.5.7
  / Darwin 18.7.0 is qualified. Other iOS versions, jailbreak layouts,
  devices, and non-A7 arm64 CPUs require new build, signing, and runtime
  evidence.
- Manual launcher operation is supported. LaunchDaemons, launchd hooks,
  jailbreak tweaks, automatic boot, and background execution are not claimed.
- Loopback HTTP is the recommended default. An address-specific Tailscale
  bind or separately managed reverse proxy requires its own access controls;
  no public or wildcard bind is qualified by this release candidate.
- The A7 runtime fallback has bounded device evidence, not a thermal,
  battery, capacity, or indefinite-soak qualification. Optional Forgejo
  services and external renderers remain deployment-specific.
- Backups are confidential filesystem payloads, not encrypted archives. They
  exclude the executable, signature, runtime, logs, and external storage, and
  must be protected and encrypted by the operator.

P14 deliberately does not create a tag or GitHub release. Prompt 015 should
only create the release metadata/changelog, freeze the branch, and install the
maintenance workflow after the candidate SHA and all three synchronization
SHAs in the final handoff have been checked.
