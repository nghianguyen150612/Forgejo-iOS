# Forgejo-iOS P11 Performance Profile

Status: measured on the primary A7 device; no feature-removing runtime tuning
was adopted.

Date: 2026-09-20

## Scope and measurement boundary

This is the Prompt 011 performance record for:

```text
Source starting SHA: 9c5aff19c7580f7a97e7b184a9c291372cb14f16
Forgejo: 15.0.9
Runtime: go1.26.7-a7
Device: iPad4,4 / Apple A7 / iOS 12.5.7 / Darwin 18.7.0
Git: 2.39.1 (/usr/bin/git)
SQLite build tags: bindata timetzdata sqlite sqlite_unlock_notify
```

The P11 runtime evidence was isolated below:

```text
/var/nghianguyen/forgejo-ios-p11/9c5aff19c7580f7a97e7b184a9c291372cb14f16
```

The existing P8 six-hour monitor and service on port `39129` remained running
and was not modified. P11 used port `39133` for the `GOMAXPROCS=1` profile and
port `39134` for the comparison profile. Database files, logs, working clones,
and the Git test repository remain outside this repository.

RSS and CPU values below are process-local `ps` measurements. CPU is the
device process percentage and can exceed 100% during parallel workloads; it is
not whole-device CPU usage. `lsof` is not installed on the device, so file
descriptor counts are reported as unavailable rather than estimated.

## Baseline: idle service

The baseline used the P10-accepted A7 Forgejo binary and the P10 service
wrapper, copied into the new P11 root. The P10 configuration retained both
Bleve issue and repository/code indexers, used a level queue, and bound HTTP to
loopback. It was started with `GOMAXPROCS=1`, then left without workload for
24 samples at five-second intervals (120 seconds maximum observation window).

| Metric | Baseline result | Evidence boundary |
| --- | ---: | --- |
| Wrapper start returned | 1,216 ms | Process was alive and PID was recorded |
| Launch to HTTP ready | 8,350 ms | First `HTTP 200` from `127.0.0.1:39133/` |
| Idle samples | 24 / 120 s | One sample every 5 s; no workload requests |
| RSS | 136,708–136,780 KB, average 136,744 KB | Forgejo PID 41939 |
| CPU | 0.0–22.1%, average 0.996% | Process-local sampled CPU |
| Threads | 11–11 | `ps -M` |
| Database at HTTP ready | db 1,282,048 B; WAL 4,120,032 B; SHM 32,768 B | SQLite files |
| Database after idle | db 1,282,048 B; WAL 4,120,032 B; SHM 32,768 B | No growth during idle window |
| Final HTTP probe | 200 | Loopback |
| Clean SIGTERM stop | 1,843 ms | PID file removed; no P11 process remained |
| Database after stop | db 2,326,528 B; WAL/SHM absent | Clean shutdown checkpointed WAL |

The historical P10 profile recorded `150,224–150,372 KB`, `0.0–0.7%` CPU,
and 14 threads over approximately 20 seconds. It was an earlier empty-root
sample and is retained for context, not treated as a before/after improvement
claim against the P11 120-second profile.

## Background activity analysis

The classification below is deliberately conservative. An item is marked
unknown when the configuration or short log window did not prove its runtime
state.

| Component | State in the P11 profile | Evidence and decision |
| --- | --- | --- |
| HTTP web service | enabled | Loopback readiness and all thermal-window requests returned HTTP 200 |
| SQLite bundled driver and WAL | enabled | Startup log, `PRAGMA journal_mode=wal`, WAL/SHM files |
| Bleve issue indexer | enabled | Startup and shutdown log entries; initialization completed |
| Bleve repository/code indexer | enabled | `REPO_INDEXER_ENABLED = true`; initialization and shutdown logged |
| Repository statistics indexer | enabled | Population task logged at startup |
| Level queue | enabled | `[queue] TYPE = level`; queue data directory created |
| Queue worker count | unknown/dynamic | No explicit `MAX_WORKERS`; Forgejo default is dynamic, and the internal count was not exposed by the wrapper |
| Cron scheduler/tasks | unknown for this deployment | No `[cron]` overrides and no cron execution in the bounded log window; no task was disabled based on this observation |
| Mirrors, Actions, packages, mailer | unknown/not exercised | Not needed for the idle profile and not changed |
| SSH and LFS servers | disabled by profile | Explicitly disabled in the isolated app configuration; HTTP Git remained enabled |

No background component was disabled as a P11 optimization. In particular,
the repository/code indexer was retained because P9 verified code search and
disabling it would remove functionality.

## Configuration tuning experiments

### Scheduler parallelism

The current A7 policy defaults to `GOMAXPROCS=1` when the target is recognized,
while preserving an explicit operator override. A fresh root with the same
binary and configuration was measured with `GOMAXPROCS=2` for 12 samples at
five-second intervals.

| Metric | `GOMAXPROCS=1` baseline | `GOMAXPROCS=2` candidate | Result |
| --- | ---: | ---: | --- |
| Launch to HTTP ready | 8,350 ms | 7,441 ms | Candidate 10.9% faster |
| RSS average | 136,744 KB | 135,671 KB | Candidate 1,073 KB lower |
| RSS range | 136,708–136,780 KB | 135,668–135,676 KB | Candidate slightly lower |
| Idle CPU average | 0.996% | 3.500% | Candidate higher |
| Idle CPU peak | 22.1% | 41.2% | Candidate higher |
| Threads | 11 | 14 | Candidate higher |
| Clean stop | 1,843 ms | 1,877 ms | No improvement |
| HTTP and SQLite | 200; integrity `ok` | 200; integrity `ok` | Both passed |

The P=2 runtime is now safe from the previously observed A7 `CNTVCT_EL0`
fault because the accepted runtime patch is present, but it is not the better
default for an always-on iPad service. The P=1 policy was retained to reduce
idle CPU activity, thread count, and expected thermal/battery pressure. This
was a measured policy decision; no Go runtime patch was changed.

### Other safe-setting decisions

- SQLite durability settings were not changed. WAL, checkpoint, restart, and
  integrity behavior were already correct, so there is no evidence to trade
  durability for a speculative speed gain.
- The repository/code indexer was not disabled. P9 exercised code search, and
  the P11 logs confirmed that the indexer starts and stops cleanly.
- No queue length, batch size, cache size, or cron schedule was changed. The
  short idle data does not establish that any such change is safe or useful,
  and the current queue worker default is already bounded by Forgejo's dynamic
  policy on this two-CPU device.
- No Git functionality, SQLite support, mailer behavior, or repository
  maintenance feature was removed.

The resulting tuned operational profile is therefore the existing, measured
profile: A7-aware launcher policy with `GOMAXPROCS=1`, bundled SQLite with WAL,
level queues, and both configured Bleve indexers retained.

## SQLite validation

The P11 idle root reported the following active files:

```text
PRAGMA journal_mode: wal
At HTTP-ready:   forgejo.db 1,282,048 B; forgejo.db-wal 4,120,032 B; forgejo.db-shm 32,768 B
After idle:      forgejo.db 1,282,048 B; forgejo.db-wal 4,120,032 B; forgejo.db-shm 32,768 B
After SIGTERM:   forgejo.db 2,326,528 B; WAL/SHM absent
PRAGMA integrity_check: ok
PRAGMA wal_checkpoint(PASSIVE): 0|835|835
```

The Git profile later observed `forgejo.db-wal=416,152 B` and
`forgejo.db-shm=32,768 B` while the service was active. It again returned
`PRAGMA integrity_check: ok`; clean stop removed the transient WAL/SHM files.
No `journal_mode`, synchronous, locking, or durability setting was changed.

## Git operation memory profile

The isolated P11 Git profile used one private repository containing 1,000
small files, an initial commit, one update commit, and local loopback HTTP Git
transport. The sampled RSS/CPU/thread values are for the Forgejo service PID
while each operation was in progress.

| Operation | Result | Duration | Peak RSS | Peak CPU | Peak threads |
| --- | --- | ---: | ---: | ---: | ---: |
| Initial push | PASS | 9.260 s | 156,428 KB | 79.6% | 10 |
| Clone | PASS | 20.278 s | 176,396 KB | 72.7% | 13 |
| Update push | PASS | 12.022 s | 181,880 KB | 72.2% | 13 |
| Pull | PASS | 11.452 s | 186,676 KB | 82.7% | 14 |
| `git gc --prune=now` | PASS | 0.621 s | 186,332 KB | 58.4% | 14 |
| `git fsck --full` | PASS | 0.339 s | 186,332 KB | 4.1% | 14 |

The clone and pull working trees matched the expected two-commit history, and
the repository remained valid after maintenance. The first push attempt in
the harness exited 128 because the temporary credential helper was configured
under the wrong HOME; after correcting only that test setup, all six operations
passed. This is recorded as harness setup evidence, not as a Forgejo failure.

The P9 reference used a larger and different workload, so the numbers are not
an apples-to-apples speed claim:

```text
P9 small workload: 30 clone/push/pull operations in 237.559 s;
  peak RSS 156,528 KB, peak sampled CPU 137.3%, peak threads 16.
P9 10,000-file large receive: 13.620 s server receive-pack;
  peak RSS 178,376 KB, peak sampled CPU 138.9%, peak threads 17.
P9 large clone: 131.515 s; peak RSS 178,012 KB, peak sampled CPU 135.5%,
  peak threads 17.
P9 maintenance: gc 3.237 s; fsck 3.394 s before and 3.021 s after;
  repack 4.789 s.
```

P11's 1,000-file profile confirms Git operations remain functional and gives
an updated memory envelope, but it does not claim an improvement over the
larger P9 workload.

## Startup and service wrapper review

The wrapper was reviewed at `scripts/ios/run-forgejo.sh` and no source change
was required:

- start checks are bounded at 50 attempts of 100 ms;
- stop waits for at most `FORGEJO_IOS_STOP_TIMEOUT` seconds (30 by default);
- lock acquisition is bounded at five 100 ms attempts;
- PID identity is checked before signaling;
- stale PID recovery, clean SIGTERM, duplicate start refusal, and crash
  recovery remained passing on the isolated P11 root;
- state writes use temporary files followed by same-directory rename.

The device measurements were `1,216 ms` for the wrapper's start return and
`1,843 ms` for clean stop in the idle baseline. A host-only 12-run wrapper
probe using `/bin/sleep` measured start `160–258 ms` (average `206.00 ms`),
status `96–219 ms` (average `134.42 ms`), and stop `46–120 ms` (average
`79.92 ms`). The host probe is overhead evidence only; it is not A7 runtime
performance.

Removing the bounded process checks would make failure and stale-PID behavior
less reliable for no demonstrated device saving, so the wrapper was retained.

## Short thermal and power observation

A separate 90-second bounded observation used `GOMAXPROCS=1`, one loopback HTTP
request every five seconds, and 18 samples:

```text
launch to HTTP ready: 4,859 ms
RSS: 148,116–148,352 KB, average 148,248.7 KB
CPU: 0.0–40.9%, average 2.356%
threads: 13–13
HTTP: 18/18 responses HTTP 200
clean stop: 1,814 ms
```

The only readable power source was IOKit battery data. Before/after snapshots
reported `CurrentCapacity=47`, `ExternalConnected=Yes`, and `IsCharging=Yes`.
The raw battery `Temperature` changed from `3550` to `3570` in the device's
IORegistry units. No independent temperature calibration or thermal sensor
was available, and the device was charging, so battery impact and long-term
thermal behavior are **not claimed**.

## Validation and limitations

Completed evidence:

```text
[PASS] A7 idle baseline measured for 120 seconds
[PASS] Background indexers/queue and unknown cron boundary documented
[PASS] GOMAXPROCS=2 candidate measured and rejected for default profile
[PASS] SQLite WAL/checkpoint/integrity behavior validated
[PASS] Clone, push, pull, gc, and fsck profile passed
[PASS] Launch-to-HTTP-ready and clean-stop timing measured
[PASS] Service wrapper bounded-wait and identity behavior reviewed
[PASS] 90-second thermal/power observation completed
[PASS] No Go runtime patch, Forgejo core, Git, SQLite, or feature removal
[PENDING] Final Linux/iOS CI on the P11 commit
[PENDING] Final push and iPad repository synchronization on the P11 commit
```

Known limitations are intentionally narrow:

- The P11 idle and thermal windows are short observations, not a long soak or
  battery-life claim. The existing P8 six-hour monitor was not reused as P11
  evidence because it has a different root and workload boundary.
- The Git profile is smaller than P9's 10,000-file workload, so direct peak
  memory comparisons are not valid.
- `lsof` is unavailable on iOS 12.5.7 in this environment.
- Temperature is available only as raw IOKit data and the device was externally
  powered throughout the thermal observation.
- The current wrapper status output reports SQLite/provenance as unknown when
  a separate build-info file is not supplied, although the binary version and
  startup log directly prove the SQLite build tags. CI remains the authoritative
  provenance check.

No database, log, test repository, or generated build artifact belongs in the
P11 Git commit.
