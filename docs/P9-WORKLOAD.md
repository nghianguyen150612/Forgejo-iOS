# Forgejo-iOS Prompt 009 — Storage Scale and Git Workload Validation

Status: workload evidence collected on the primary iPad target; final source
and CI handoff is recorded at the end of this document.

Date: 2026-09-20

## Scope and test boundary

The workload run used the existing A7-compatible Forgejo production artifact
with this provenance:

```text
Forgejo: 15.0.9
Runtime: go1.26.7-a7
Target: iPad4,4 / iOS 12.5.7 / Darwin 18.7.0
Git: 2.39.1 (/usr/bin/git)
SQLite tags: bindata timetzdata sqlite sqlite_unlock_notify
Workload source/artifact SHA: de9576d6fb0ccfda3b15fc4963d1f4ff85413b31
P9 port: 127.0.0.1:39130
P9 isolated root: /var/nghianguyen/forgejo-ios-p9/de9576d6fb0ccfda3b15fc4963d1f4ff85413b31
```

The P9 database, repositories, indexers, temporary files, logs, and working
clones were isolated under the P9 root. No real repository was used. The
previous P8 service remained on port `39129` while P9 ran; therefore the
resource numbers below are process-local measurements for the P9 Forgejo PID,
not a claim about the total free-memory or thermal capacity of an otherwise
idle iPad.

No Forgejo source architecture, Git integration, SQLite support, Go runtime
patch, or iOS dependency was changed for this workload validation.

## Small workload — 10 repositories

Ten private repositories, `p9-repo-01` through `p9-repo-10`, were created by
the Forgejo API. Each repository received an initial commit, a branch, a tag,
an initial push, a clone-side update push, and a fast-forward pull.

| Operation | Result | Evidence |
| --- | --- | --- |
| Repository creation | PASS | 10/10 API responses were HTTP 201. |
| Initial Git push | PASS | 10/10 pushes, including `main`, one branch, and one tag per repository. |
| Clone | PASS | 10/10 local HTTP clones. |
| Clone-side push | PASS | 10/10 update pushes. |
| Pull | PASS | 10/10 fast-forward pulls. |
| API repository access | PASS | 10/10 repository API responses were HTTP 200. |
| API contents browsing | PASS | Sampled private repository contents returned HTTP 200. |
| HTML browsing of a public repository | PASS | `p9-repo-01` was made public for this check and returned HTTP 200. |
| Private HTML browsing with HTTP Basic Auth | NOT TESTED | The direct Basic Auth request returned HTTP 404 because it did not establish a Forgejo browser session. |

The Git operation wall time across the 30 clone/push/pull operations was
237.559 seconds, with a maximum individual operation of 7.098 seconds. API
repository creation responses were approximately 1.72–1.94 seconds. The
initial server readiness check returned HTTP 200 in 5,914 ms.

The P9 process sampler captured 245 samples during the small workload:

```text
peak RSS: 156,528 KB
peak sampled CPU: 137.3%
peak threads: 16
```

The CPU value is the device `ps` process percentage and can exceed 100 on the
two-processor runtime; it is not a whole-device CPU percentage.

## Medium workload — 10,000-file repository

The controlled repository was `p9-large-workload`. It contained exactly
10,000 incompressible files, plus a README, history file, and code-search
token. The generated file payload was 120 MiB before the final 240 split files
were removed; the resulting data set was approximately 117.2 MiB. The source
working tree including `.git` occupied 254,119,936 bytes and the clone
occupied 248,389,632 bytes. The Forgejo bare repository settled at about
117.93 MiB packed.

The history contained 262 commits on `main` after the clone update, 321 commits
on `p9-feature`, and three tags: `p9-large-v1`, `p9-large-v2`, and
`p9-large-v3`.

| Operation | Result | Duration |
| --- | --- | ---: |
| Generate/split 10,000 files on device | PASS | 99.153 s |
| Add 10,000 files to the index | PASS | 97.125 s |
| Initial large commit | PASS | 1.415 s |
| Large one-shot push with default Git HTTP buffering | FAIL / boundary observed | The client reported `send-pack: unexpected disconnect while reading sideband packet`; the server logged `receive-pack` exit 128 and retained zero objects. |
| Same large push with explicit 250,000,000-byte `http.postBuffer` | PASS | Server receive-pack elapsed 13.620 s; 117.93 MiB pack accepted. |
| Clone over local HTTP | PASS | 131.515 s |
| Feature-branch checkout | PASS | 0.594 s |
| Tag checkout | PASS | 0.523 s |
| Return to main | PASS | 0.437 s |
| `git log` on main and feature history | PASS | 0.116 s / 0.112 s |
| `git diff p9-large-v1..main` | PASS | 0.083 s |
| `git blame history.txt` | PASS | 0.154 s |
| Clone update push | PASS | 6.979 s |
| Source fast-forward pull | PASS | 5.666 s |
| Forgejo API/contents/branches/tags after large push | PASS | All sampled responses were HTTP 200. |

The first large push failure is retained as evidence rather than hidden. An
explicit client-side HTTP post buffer allowed the identical pack to pass, so
this run identifies a transport/buffering boundary rather than a repository
storage or Git object-integrity failure. The exact threshold was not isolated,
and no product or Git-integration change was made.

The large-workload process samplers captured the following peaks:

```text
initial receive/profile: 907 samples, 178,376 KB RSS, 138.9% CPU, 17 threads
clone/follow-up profile: 342 samples, 178,012 KB RSS, 135.5% CPU, 17 threads
```

## Git history and repository maintenance

The large clone successfully exercised branch and tag checkout, log traversal,
diff, blame, update push, pull, and post-restart fetch. Maintenance was run
against the stopped Forgejo bare repository:

```text
git fsck --full       PASS, 3.394 s before maintenance
git gc                PASS, 3.237 s
git repack -ad        PASS, 4.789 s
git fsck --full       PASS, 3.021 s after maintenance
```

The sorted `git show-ref` output before and after maintenance was identical.
After the server restart, a second full fsck, ref comparison, and clone fetch
also passed. Forgejo continued to return HTTP 200 for the large repository and
the authenticated user API.

## Indexing and search

The P9 configuration enabled the built-in Bleve repository/code indexer and
retained the Bleve issue indexer. The repository indexer initialized in
150.391 ms and created its on-device store.

| Search surface | Result | Evidence |
| --- | --- | --- |
| Repository API search | PASS | HTTP 200 for `p9-repo`. |
| User API search | PASS | HTTP 200 for `p9admin`. |
| Issue API search | PASS | HTTP 200 for `P9_ISSUE_SEARCH_TOKEN`; 20 issues were created and all returned HTTP 201. |
| Code search | PASS | HTTP 200 for `P9_CODE_SEARCH_TOKEN`; the indexed token was found on the first bounded retry. |
| Repository HTML search | PASS | HTTP 200. |
| User HTML search | PASS | HTTP 200. |
| Sign-in-protected HTML issue search without a browser session | EXPECTED AUTH BOUNDARY | HTTP 303 redirect to sign-in; the API issue search passed. |

Post-workload indexer sizes were approximately 304 KB for the issue index and
5,652 KB for the repository/code index. No indexer panic or failed search was
observed. The P9 process peak during the large index/Git workload is included
in the medium-workload resource profile above.

## iOS filesystem behavior

The probes ran under the device user on the APFS-backed writable runtime:

| Probe | Result | Evidence |
| --- | --- | --- |
| Atomic same-filesystem rename | PASS | A completed temporary payload was renamed and read back with no source temporary file remaining. |
| Lock primitive | PASS | Two concurrent `mkdir` attempts produced exactly one winner. |
| Temporary files | PASS | `mktemp` created a writable/readable file below `runtime/tmp`, and cleanup removed it. |
| Permissions | PASS | The owner could read/write the created file; `ls -l` showed the `umask 077` probe as mode `600`. |
| Repository creation directories | PASS | Owner directory, bare `objects`, `refs`, and `hooks` directories were present. |
| SQLite WAL/SHM files | PASS | `forgejo.db-wal` and `forgejo.db-shm` were present during the active server workload. |

The final device filesystem snapshot reported 3,698,780 KB available on the
15 GiB `/private/var` APFS volume after the workload and cleanup of the P9
server process. This is a device snapshot, not a storage quota guarantee.

## SQLite growth and restart

The post-workload database files were measured both before maintenance and
after the restart:

```text
forgejo.db       2,359,296 bytes
forgejo.db-wal   4,169,472 bytes
forgejo.db-shm      32,768 bytes
PRAGMA integrity_check: ok
rows after restart: 1 user | 11 repositories | 20 issues
```

The repository and user API checks returned HTTP 200 after restart, and the
large repository refs remained available. The exact empty-database
pre-workload byte snapshot was not captured, so an absolute byte delta from
the initial database is `NOT TESTED`; the post-workload WAL/SHM growth,
integrity, row survival, and restart behavior are `PASS`.

## Resource summary

| Profile | RSS peak | CPU peak | Threads peak | Duration/evidence |
| --- | ---: | ---: | ---: | --- |
| Startup | 139,888 KB at first readiness sample | 1.6% at sample | 10 | HTTP 200 in 5.914 s |
| Ten repositories | 156,528 KB | 137.3% | 16 | 245 one-second samples |
| Large receive/commit | 178,376 KB | 138.9% | 17 | 907 samples |
| Large clone/follow-up | 178,012 KB | 135.5% | 17 | 342 samples |
| Post-maintenance restart | 140,492 KB | 0.0% at sample | 15 | HTTP 200 in 4.736 s |

`lsof` was not installed on the device, so file-descriptor counts are
`NOT TESTED`; the launcher reported this explicitly instead of fabricating a
value.

## Known limitations

- The P9 load was local loopback traffic on the iPad. It does not qualify LAN,
  Wi-Fi, WAN, battery, thermal, background-execution, or long-duration P9
  behavior.
- The previous P8 service was intentionally left running on another port while
  P9 ran. RSS/CPU numbers are for the P9 process and should not be read as a
  clean whole-device idle baseline.
- Private HTML browsing was not exercised through a real browser login/session;
  API authentication and public HTML browsing were used instead.
- The default Git HTTP-buffer large-push failure was reproduced once and an
  explicit 250 MB client buffer passed. The precise failure threshold and
  behavior over a network link remain unresolved.
- SSH Git transport was not part of this P9 run; the isolated server used
  HTTP Git transport with the device's native `/usr/bin/git`.
- The empty-database byte baseline and `lsof` file-descriptor count were not
  captured.

## Acceptance evidence index

```text
[PASS] P8 artifact/runtime provenance used
[PASS] 10 repositories created and exercised
[PASS] 10,000-file repository stored and cloned
[PASS] Hundreds of commits, multiple branches, and multiple tags
[PASS] log, diff, blame, checkout, push, pull
[PASS] fsck, gc, repack, refs, post-maintenance service
[PASS] repository/user/issue/code search checks
[PASS] atomic rename, lock, temp, permissions, repository directories
[PASS] SQLite WAL/SHM, integrity, restart persistence
[PASS] process-local RSS/CPU/thread measurements
[NOT TESTED] empty-database byte delta, lsof FD count, private browser session, LAN/thermal soak
```

The final CI and synchronization SHA table is appended after the one-commit
P9 handoff:

```text
P9 final commit:
GitHub SHA:
iPad SHA:
Linux regression run:
iOS CI run:
```
