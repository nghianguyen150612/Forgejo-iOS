# P028 security dependencies and legacy iOS compatibility

Audit date: 2026-11-11. Verified P027 base:
`0452d8113a7bc50886ad020bfccadb764de45494`. Branch:
`ios/p028-security-compatibility`. Draft PR:
https://github.com/nghianguyen150612/Forgejo-iOS/pull/11, target
`ios/p027-security-port`. Production `iOS` remains
`dfb0b0664f1245f7436a306baf711540f712a03f`; P027 remains unmerged.

Official Codeberg default is `forgejo`, audited at
`71ad73984701aa1a7f4e6748f12a9cf0fa0da6fa`; supported v15 maintenance is
`v15.0/forgejo` at `11c63cb45e74dd99d455550910e3b71a29d28fb2`.
Since P027, v15 added Go 1.26.11; default added Go 1.27.4 and a test-forgery
team-unit extension. The latter is still unported. Development Go 1.27.4 does
not replace the supported v15 toolchain. Both existing ledgers are updated;
the divergent development inventory remains an inventory, not a wholesale port.

## Dependencies and advisory evidence

| Dependency | P027 | P028 | Official source |
| --- | --- | --- | --- |
| klauspost/compress | 1.18.7 | 1.20.2 | `2f15a8d1282acf9def06553952d697292b922234` |
| andybalholm/brotli, indirect | 1.2.0 | 1.2.7 | `0c83767960fb78ffd3f38e4dfa3a6306bbe8cb61` |
| minimatch | 10.2.4 | 11.0.1 | `70f889ebb297ecd18db065f564327ab252a2ee78` |
| sharp | 0.35.0 | 0.35.5 | `cb23914d456062a8453bd4fc28eabd8c4bf916de` |
| KaTeX | 0.16.38 | 0.18.2 | `b6291844dc60de72afdbf012e418bce26b121bc6` |
| happy-dom | 20.8.9 | 21.0.4 | `115c57529aeb63f9214be2186e22e28eb1f01b29` |
| custom Go/A7 | 1.26.7 | 1.26.11 | `11c63cb45e74dd99d455550910e3b71a29d28fb2` |

P027 x/crypto 0.58.0, x/net 0.62.0, x/sync 0.24.0, x/sys 0.49.0,
x/term 0.47.0, x/text 0.43.0, x/tools 0.51.0 and x/mod 0.41.0 remain intact.
The lockfile was retained and reconciled with npm; no security override,
automatic major-version audit fix or advisory exclusion was used.

Compress is directly imported by zstd, HTTP and asset paths; brotli is a
transitive dependency. Module evidence before the update identifies
GO-2026-6865 / CVE-2026-116591 / GHSA-fpmh-frq8-7rj8 and GO-2026-6888 /
CVE-2026-111497 / GHSA-c9gr-gmg4-2vqv. A module finding alone is not proof that
the affected symbol was reachable before the fix.

`p028-go-advisory-delta.json` records fresh P027 and P028 module scans using
their supported Go versions: 17 distinct advisory IDs before, one after.
The 16 IDs no longer reported include the compression advisories and the
Go 1.26.7 standard-library findings. The remaining GO-2026-5932 concerns the
unmaintained x/crypto/openpgp package; its imported-package/reachable-symbol
classification is recorded with the final full scan below. It is not suppressed.

`p028-p027-npm-audit.json` and `p028-npm-audit.json` preserve the complete
before/after npm reports. Dependency entries fall from 61 to 58 (after: four
critical, 33 high, 17 moderate, four low). These counts include development and
transitive dependencies, not 58 proven runtime exploits. Top-level sharp and
happy-dom no longer appear in the candidate report. Addressed advisories include
sharp GHSA-rgj7-g3m4-5g8c / GHSA-wq5f-xc86-pv6w and happy-dom
GHSA-834v-8h66-3h79 / GHSA-c8p4-j97h-3vg8 / GHSA-5fpq-26gf-qwcr.
The direct minimatch 11.0.1 addresses GHSA-g3hv-75wg-m249 and direct KaTeX
0.18.2 addresses GHSA-238p-pmpm-9mq7. Older transitive KaTeX and minimatch
copies remain, along with other runtime/build-tool findings. The full npm gate
therefore fails; frontend compilation passing is not a clean security result.

## Functional ports

- `5ee59b5b`: check auto-merge authority on the base repository; include the
  upstream cross-fork regression. This preserves authorized fork merges and
  prevents the head repository from supplying inappropriate merge authority.
- `289d60b4`: synchronize branch state from Git under the shared per-branch
  lock, preventing stale concurrent post-receive requests from rolling it back;
  include the upstream concurrency seam and regression.
- `e25a5505`: preserve explicit read grants in the access table and its fixture.
- `f2e20193`: team-only review-request authorization and synthetic fixtures.
- `484a8844`: reject unknown/invalid dispatch refs and workflows with 4xx
  responses and retain API integration regressions.
- `49a36912`: apply organization visibility updates including explicit public.
- `eb36b984`, `f2564216`, `efd3322a`, `1b6d6fb2`: stream Actions transfers,
  finalize logs on empty last updates, avoid duplicate transfer and preserve
  post-step logs after skipped final steps; retain the upstream tests.

No schema or reference-history migration was introduced by these fixes. Existing
P027 OAuth, authorization, private star/watch, token cleanup, Actions trust and
repository visibility fixes remain. Mirror fix
`efa00103570af0d7ad5eea92be9a02fa209459b2` remains **BLOCKED**: v15 lacks its
force-push reference-history prerequisite. No incomplete namespace-only change
or divergent-development merge was attempted.

## A7 toolchain

The official Go 1.26.11 source archive SHA-256 is
`d44101b0ff27ed2a4c75ad46c17b9c74359209e2eb2ca7c9df6cb4fdb68e1969`.
Its runtime `asm_arm64.s` and `stubs.go` hashes are exactly the 1.26.7 patch
inputs, so the existing iOS-only bounded YIELD loop applies without changing
the stock non-iOS counter loop. The VERSION input hash and source/provenance
pins are updated. CGO/SQLite, external linking, iOS 12, ARM64, Mach-O checks,
signing expectations, packaging and launcher contracts remain required.
Legacy 1.26.7 provenance paths are still recognized by backup/restore discovery.

The local compiler was built from the verified source and reports Go 1.26.11
when checked with `GOTOOLCHAIN=local`. An initial final assertion followed an
inherited 1.26.7 selection instead; the script now makes local selection
explicit. This was an inspection redirection, not evidence that the compiler
was built from the wrong source. Hosted native results below qualify the exact
source SHA, patched scheduler path and artifact; physical A7 execution remains
deferred. A stock cross-build is not substituted for the patched compiler.

## Vulnerability scan investigation

P027 documented govulncheck 1.9.0, a module scan with exit 3 and a full
`govulncheck -tags=sqlite,sqlite_unlock_notify ./...` terminated with exit 137.
The original host kernel/process telemetry is not retained. Inspection of hosted
run 42931727875/job 130231877075 confirms Go 1.26.7 and no govulncheck step;
its successful security tests never resolved that separate host failure.
Exit 137 alone still does not establish memory exhaustion or a specific killer.

P028 provides an isolated full-graph CI job and local scanner. It records
the exact source archive, every application package, build tags, Go/tool
versions, JSON streams, per-scan exit status, kernel peak RSS/CPU/page-fault
accounting and cgroup memory/OOM counters. All application packages are scanned;
no package partition or exclusion is used. Native generated compiler tests are
outside the source archive. Negative tests reject incomplete inventory,
truncated JSON and exit 137, and distinguish module evidence from actual
package/function traces. Module findings continue to fail the strict gate even
when no reachable vulnerability is found.

Initial P028 attempts failed closed on generated Go-distribution negative test
files, an unavailable GNU time binary, and a transient advisory-database HTTP
502. The scanner now uses `git archive HEAD` and direct `wait4` accounting.
These are separate measured failures; none proves the cause of P027's exit 137.
The subsequent full symbol scan covered 396 application packages, completed
with exit 0, peaked at 2,574,700 KiB RSS, and reported no reachable or imported
package findings. It retained one required-module advisory. Final-head scans at `2f58d3aa53fd9b150d1b02ef727030ca4cd56399` completed
all three levels locally and in isolated hosted job 130300939459/run
42952840539. Both inventoried all 396 application packages with no exclusions.
The local symbol scan took 130.673 seconds and peaked at 2,566,188 KiB RSS;
the hosted symbol scan peaked at 3,112,924 KiB. All scan processes exited 0,
with complete JSON evidence and no cgroup OOM kill. Both reports contain only
GO-2026-5932 at required-module level, with zero imported-package and zero
reachable-symbol findings. The wrapper and hosted gate intentionally return
exit 3 / **FAILED** because that module advisory is unresolved. Scan completeness
is verified; a clean dependency-security result is not claimed.

`p028-govulncheck-report.json`, `p028-govulncheck-ci-report.json` and
`p028-govulncheck-packages.txt` preserve the consolidated reports and coverage.
The original hosted JSON streams/stderr/resource files are artifact
13826695623, archive SHA-256
`600a9c3e644d06b65829ece8cc91377cd5686b64a25758c1a8e9c332c6c2981f`,
independently downloaded and byte-verified. No package partition was needed.
The original P027 termination cause remains unknown because its original kernel
and process telemetry are unavailable; the full P028 result supersedes its
incomplete coverage without pretending to diagnose that earlier killer.

## Historical validation checkpoint — before source 20be51e7

Final exact-source test results, CI runs, artifact evidence and remaining
limitations are appended after active checks finish. Earlier source successes
are not attributed to a later commit. The NuGet symbol-package size assertion
is retained and must pass on the supported toolchain. Fixture/setup failures
are recorded separately from product regressions.

Device status: **DEFERRED — OWNER APPROVED**. No device SSH, owner database,
installation, reboot, PF, LaunchDaemon or production branch action occurred.
No merge, release, tag or deployment was performed.

## Historical checkpoint — source 20be51e7

Repository: `/workspace/work/Forgejo-iOS`. Branch
`ios/p028-security-compatibility`. Latest pushed source commit:
`20be51e710d451306e4458b25f1337b63729f53b`; remote branch matched after push.
P028 base is P027 `0452d8113a7bc50886ad020bfccadb764de45494`. Draft PR #11 is open
and targets `ios/p027-security-port`. Production `iOS` remains
`dfb0b0664f1245f7436a306baf711540f712a03f`.

Since source `dabfb6fe60fc1153fe4784ec51980490181ce646`, commit
`20be51e710d451306e4458b25f1337b63729f53b` applies only semver-compatible
lockfile patches selected by `npm audit fix`: @humanfs/node 0.16.7→0.16.8,
@humanfs/core 0.19.1→0.19.2, colord 2.9.3→2.12.0, minimatch 3.1.2→3.1.5 and
minimatch 9.0.5→9.0.9. No package ranges, audit thresholds or tests were
weakened. Direct KaTeX remains pinned to fixed 0.18.2 and direct minimatch to
11.0.1; the earlier nested KaTeX and frontend overrides remain unchanged.

Validation against the exact lockfile content committed at `20be51e7`:

- `npm ci --no-audit --no-fund`: PASS, 1,131 packages installed. npm printed
  deprecation warnings for inflight, read-package-json, glob 7, glob 10 and
  sourcemap-codec; these were not suppressed.
- `npx vitest run`: PASS, 26 files / 103 tests.
- `make frontend`: PASS, webpack compiled successfully in 26.996 seconds. It
  printed the existing `Go: Unknown option: env` messages from the environment.
- `npx eslint web_src --color --max-warnings=0`: PASS.
- `npm audit --json`: exit 1, 13 moderate, 0 high, 0 critical advisories;
  findings remain in development tooling. Full report:
  `docs/p028-npm-audit-after-lock-update.json`.
- `npm audit --omit=dev --json`: exit 0, zero production findings. Report:
  `docs/p028-npm-audit-prod-after-lock-update.json`.
- The prior exact Go scan at source `15f93c550c8db82210bd84494fe97419de85ff5b`
  covered all 396 application packages, returned scanner exit 0 at all scan
  levels, and retained GO-2026-5932 at required-module level only. The strict
  CI gate returned exit 3; there were zero imported-package and reachable-symbol
  findings. New exact-source scan is pending below.
- `go mod verify` passed on earlier source `dabfb6fe`; no Go module files changed
  in `20be51e7`. `go mod tidy -diff` previously exited 1 while walking the
  embedded Go 1.26.11 toolchain's `goroot/test` fixtures. That failure was not
  changed by this lockfile-only commit and has not been requalified on `20be51e`.

Exact-source hosted workflows for `20be51e710d451306e4458b25f1337b63729f53b`:

- Runtime compatibility matrix run `42986670777`: PASS.
- Production build run `42986670775`: queued at last check.
- A7 runtime build run `42986670794`: queued at last check.
- Host security regressions run `42986670884`: queued at last check. Its
  scanner and frontend audit artifacts must be inspected after completion.
- Do not transfer the older source `dabfb6fe` CI conclusions to this newer
  exact source. Poll the runs, retain exit codes/findings, and update this file
  with artifact IDs and digests before claiming hosted qualification.

P028 functional/security implementations and original upstream commit mapping
remain in the ledgers and earlier sections. P028 is not complete. Outstanding
supported-v15 rows still requiring review or a compatible port include the
scheduled-workflow parsing fix (`ab972d7b`), Arch package naming and epochs
(`85b0721`, `0d5d66fb`), avoiding unnecessary tag-creation data (`65ca1b0d`),
invalid commit-status filtering (`4b6fc5c1`) and FilesInit LatestSha fixture
(`4dd2cb29`). The test fixture helper migration (`ee9ea751`) is not a production
fix and should be considered separately. The default-branch Go 1.27.4 and
test-forgery team-unit extension remain outside the supported v15 port. The
mirror-reference change `efa00103570af0d7ad5eea92be9a02fa209459b2` remains
blocked on its missing history prerequisite; do not port it or merge the
divergent default line wholesale.

Next exact action: poll the four current-source workflows, capture their jobs
and artifact evidence, then continue with the highest-value compatible v15
functional fix. Keep PR #11 Draft and based on `ios/p027-security-port`.

Device qualification: **DEFERRED — OWNER APPROVED**. No device, owner database,
installation, reboot, PF, LaunchDaemon, production mutation, release, merge or
deployment action occurred. Production `iOS` remains unchanged.

## Current recovery checkpoint — 2026-11-11

Repository: `/workspace/work/Forgejo-iOS`. Branch
`ios/p028-security-compatibility`. Latest pushed implementation commit:
`8d4c3eae9a246640c9f13045345e202f3294944b`; origin matched this source SHA
when its exact-source workflows ran. The handoff and evidence were committed
in docs-only commit `36e7d1257ec2b02f93a1424c2195e523fe3184df`, which adds no
application changes. P028 base is P027
`0452d8113a7bc50886ad020bfccadb764de45494`. Draft PR #11 is open and targets
`ios/p027-security-port`. Production `iOS` remains
`dfb0b0664f1245f7436a306baf711540f712a03f`.

New incremental commits after source `dabfb6fe`:

- `20be51e710d451306e4458b25f1337b63729f53b`: semver-compatible lockfile
  security patches selected by `npm audit fix`; packages and details are in the
  historical checkpoint above.
- `43cc08da2cd03d74c0ba89163fa255f44456d2ea`: captures source dirtiness before
  creating evidence output and makes the runtime compatibility matrix check out
  the exact PR head SHA.
- `173b0e0d7f457a5bb049b17dd9a048d8e925b573`: disables Python bytecode output
  during scanner regression fixtures. The prior exact scanner artifact at
  `43cc08da` still reported `dirty=true` because those fixtures had created
  `scripts/security/__pycache__`; the exact `173b0e0d` report now records
  `dirty=false`. Its Go source is unchanged from the previous source.
- `8d4c3eae9a246640c9f13045345e202f3294944b`: ports supported-v15 commit
  `4b6fc5c16e3403f6e05806ae10bfb2ce2b8f719f`, returning cleanly for an empty
  repository/SHA list in the latest commit-status query and adding the upstream
  nil, populated, unknown-repository/SHA, and database-error regression cases.

Exact-source hosted qualification currently available for
`173b0e0d7f457a5bb049b17dd9a048d8e925b573`:

- Runtime compatibility matrix run `42989452289`, job `130418455489`: PASS.
  Artifact `13841267008` archive SHA-256
  `1c85f8b5e93a85eb9808c3302c411017204567b1efd06b03d273540fb2ebf30b` was
  independently downloaded and verified. Its build-info records exact commit
  `173b0e0d7f457a5bb049b17dd9a048d8e925b573`; all 11 payload hashes in
  `SHA256SUMS` match. Go 1.26.11, iOS ARM64, CGO enabled and iOS 12.0 probes
  pass.
- Host security run `42989452261`: Go vulnerability job `130418455404` failed
  with the strict scanner gate (exit 3); frontend audit job `130418455709`
  failed because `npm audit --json` exited 1; Go security/integration job
  `130418455785` passed. Vulnerability artifact `13841137442` SHA-256
  `1cecd159bce9980245a27e864ce397b65be3af4834a8d543f7b19c46316a0e1f` and
  frontend audit artifact `13841371884` SHA-256
  `a3c6774dd1c84e652f410e7c37e5d1dea906eac8e0e9e021647041e7ba75fb23` were
  independently downloaded and matched GitHub's digests.
- The exact scanner report is
  `docs/p028-govulncheck-ci-report-173b0e0d7f45.json`; it records source
  `173b0e0d7f457a5bb049b17dd9a048d8e925b573`, `dirty=false`, 396 inventoried
  application packages, no exclusions, and complete module/package/symbol
  scans. Each scanner process exited 0. The required-module finding
  GO-2026-5932 appears at all three levels with no imported-package or
  reachable-symbol trace; the strict job step returns exit 3 and remains
  **FAILED**, not clean.
- The exact CI npm audit is
  `docs/p028-npm-audit-ci-173b0e0d7f45.json`: 13 moderate, zero high, zero
  critical; its SHA-256 is
  `526162bcc45f29ee4d9ff5ca07a0d47da8274b75be30b288010c4231e7acfbce`.
  Production-only `npm audit --omit=dev --json` exited 0 with zero findings on
  the unchanged lockfile committed at `20be51e7`. The advisory gate remains
  failed; development dependency findings are not waived.
- Production build run `42989452369`, job `130418455614`, and A7 runtime run
  `42989452372`, jobs `130418455707` and `130418456091`, passed. The production
  artifact is ID `13840374959`, GitHub archive SHA-256
  `b1e31285969ca9bd1c3a4608a23539028aeabfb562a3ae7cba3a480a407f6e9c`,
  74,975,630 bytes. The A7 artifact is ID `13841013769`, GitHub archive
  SHA-256 `ff8dd7dc8800a1aee1cc4e00fd43f51d686ff6b2aefc6379670a3080aa0b83e8`,
  75,698,437 bytes. GitHub reports both artifacts unexpired; their archive
  digests are recorded from the Actions API and were not independently
  downloaded because each exceeds the workspace downloader's 32 MiB limit.

The complete hosted workflow set for prior source
`173b0e0d7f457a5bb049b17dd9a048d8e925b573` is: runtime matrix run
`42989452289` job `130418455489` PASS; host security run `42989452261` has Go
scanner and npm audit failures as above plus security/integration PASS;
production build run `42989452369` PASS; and A7 runtime run `42989452372` PASS,
including stock Go regression. All those runs identify head SHA
`173b0e0d7f457a5bb049b17dd9a048d8e925b573` and PR #11 base
`ios/p027-security-port` at `0452d8113a7bc50886ad020bfccadb764de45494`.

Local validation on the Go source tree at `43cc08da2cd03d74c0ba89163fa255f44456d2ea`
used an isolated `git archive HEAD` tree (so the embedded compiler source under
`build/` could not be mistaken for Forgejo packages): Go 1.26.11
`go mod verify`, `go mod tidy -diff` and
`go vet -p 2 -tags=sqlite,sqlite_unlock_notify ./...` all passed. The direct
worktree `go mod tidy -diff` attempt exited 1 after walking generated
`build/ios/go1.26.11-a7/goroot/test` fixtures, reporting relative/malformed
imports and forbidden example HTTPS fetches; the diagnostics are preserved in
`docs/p028-go-mod-tidy-diff-20be51e.txt`. The isolated archive check is the
valid source-tree result. Commit `173b0e0d` changes only scanner workflow
environment, not Go source or module files.

P028 is **PARTIAL — RESUMABLE**. Remaining supported-v15 rows for review or a
compatible port are scheduled-workflow parsing (`ab972d7b`), Arch package
names/versions and epochs (`85b0721`, `0d5d66fb`), unnecessary tag-creation
data (`65ca1b0d`) and FilesInit LatestSha fixture coverage (`4dd2cb29`). The
invalid commit-status fix (`4b6fc5c1`) is now implemented in source commit
`8d4c3eae9a246640c9f13045345e202f3294944b`; its focused Go 1.26.11 test and
vet pass, and exact-source native builds pass. The test fixture helper migration
(`ee9ea751`) is test-only and can be considered separately. The default-branch
Go 1.27.4 and test-forgery team-unit extension remain outside supported v15.
Mirror-reference change `efa00103570af0d7ad5eea92be9a02fa209459b2` remains
blocked on its missing history prerequisite; do not port it or merge the
divergent default branch wholesale.

Local validation of source `8d4c3eae9a246640c9f13045345e202f3294944b`:

- `PATH=/workspace/.tools/go1.27.1/bin:$PATH GOTOOLCHAIN=go1.26.11 go test -count=1 -p 2 -tags='sqlite sqlite_unlock_notify' ./models/git -run '^TestGetLatestCommitStatusForRepoAndSHAs$' -v`: PASS, all five subtests, Go 1.26.11 linux/amd64.
- `PATH=/workspace/.tools/go1.27.1/bin:$PATH GOTOOLCHAIN=go1.26.11 go vet -p 2 -tags='sqlite sqlite_unlock_notify' ./models/git`: PASS, Go 1.26.11.

Exact-source hosted validation for `8d4c3eae9a246640c9f13045345e202f3294944b`:

- Runtime matrix run `42992702064`, job `130429177657`: PASS. Artifact
  `13843485129`, archive SHA-256
  `294b1043fa1cf397b6c0e26c6ea9e642eeda658c988496bd88e732c8869f013a`, was
  independently downloaded and verified. Its build-info records source
  `8d4c3eae9a246640c9f13045345e202f3294944b`, Go 1.26.11 darwin/arm64,
  GOOS=ios/GOARCH=arm64, CGO enabled, and deployment target 12.0. All 11
  `SHA256SUMS` payload entries match; the manifest SHA-256 is
  `9c36afa78023920a9925fe0f851af1a6d32ced704c2b76b32936577718e2a22e`.
- Host security run `42992701991`: security/integration job `130429177715`
  PASS; vulnerability job `130429178043` FAIL, exact exit 3; frontend job
  `130429178087` FAIL, exact `npm audit --json` exit 1. Scanner fixture tests
  pass (5 tests); Vitest and `make frontend` steps pass. Vulnerability artifact
  `13842163948`, archive SHA-256
  `078d301eaebce2bcbc2c761883ebb839ec220bf85207ada0038fc65a7ca390bd`, and
  npm artifact `13841729340`, archive SHA-256
  `354bd562ad5f17c0b8b24851fe929df45b143f1f572e4bc3d650c775328d4ddf`, were
  independently downloaded and matched GitHub's digests.
- The exact scanner report
  `docs/p028-govulncheck-ci-report-8d4c3eae9a24.json` has SHA-256
  `be1b48d748af2eda565c064d4b16605f9c26a3898fc722347236e59f8a0f2972` and
  records source SHA `8d4c3eae9a246640c9f13045345e202f3294944b`, `dirty=false`,
  all 396 application packages, no exclusions, and complete module/package/
  symbol scans. Each scanner process exited 0. GO-2026-5932 is the only
  finding and remains required-module evidence, with no imported-package or
  reachable-symbol trace; the fail-closed wrapper returns exit 3. The exact
  396-line package inventory has SHA-256
  `ba36525d7a2561d3bf6e11c5125a26feb6ea497a9fe5e6002334a034fcd748c0`.
- Exact CI npm report `docs/p028-npm-audit-ci-8d4c3eae9a24.json` has SHA-256
  `526162bcc45f29ee4d9ff5ca07a0d47da8274b75be30b288010c4231e7acfbce` and
  retains 13 moderate, zero high, zero critical findings. The full npm gate
  remains failed; no audit threshold or dependency range was weakened.
- Production run `42992702030`, job `130429178672`: PASS. Artifact
  `13843515219`, 74,977,967 bytes, GitHub archive SHA-256
  `67b9cf93114304ec2b45e0c858e69a156734e2c95c279b36ae14534332846378`.
- A7 runtime run `42992701986`: stock regression job `130429177982` PASS and
  patched A7 job `130429178308` PASS. Artifact `13843041716`, 75,697,172
  bytes, GitHub archive SHA-256
  `2cd90bff40b1ef2b095b64c185b74d20b19e2e8d353ef04928f4ef8ba7135f5d`.
  Production and A7 artifacts are recorded from the GitHub API and were not
  independently downloaded because they exceed the 32 MiB workspace limit.

All four latest-source hosted workflows have final outcomes. The full scanner
and audit gates remain blockers; successful native builds do not waive them.
At this checkpoint implementation source is pushed; the current handoff,
ledgers and reports are preserved in the docs-only evidence commit above.
Exact-source application CI is for source `8d4c3eae`, and later docs-only
commits do not change that tested application tree. Next exact action is to
port and test scheduled-workflow parsing (`ab972d7b`) or Arch package/epoch
compatibility (`85b0721`, `0d5d66fb`). Keep PR #11 Draft and based on
`ios/p027-security-port`.

Device qualification: **DEFERRED — OWNER APPROVED**. No device, owner database,
installation, reboot, PF, LaunchDaemon, production mutation, release, merge or
deployment action occurred. Production `iOS` remains unchanged.


## Recovery checkpoint — 2026-11-11, x/crypto security fix

Repository: `/workspace/work/Forgejo-iOS`. Implementation source
`561abf5c16723b51d560dac2f097d192ec260558` is pushed on
`ios/p028-security-compatibility`, based on P027
`0452d8113a7bc50886ad020bfccadb764de45494`. PR #11 remains Draft and targets
`ios/p027-security-port`. Production `iOS` remains
`dfb0b0664f1245f7436a306baf711540f712a03f`. Official Codeberg refs remain
`forgejo` `71ad73984701aa1a7f4e6748f12a9cf0fa0da6fa` and
`v15.0/forgejo` `11c63cb45e74dd99d455550910e3b71a29d28fb2`.

Source commit `561abf5c` upgrades `golang.org/x/crypto` from v0.58.0 to
`v0.58.1-0.20261009181718-2f1f834330b2`, upstream source commit
`2f1f834330b2d36ab3db8bfb33aaa1ac16794588`, addressing GO-2026-5932. Other
P027 x/* selections remain unchanged. Earlier P028 dependency updates for
compress, brotli, minimatch, sharp, KaTeX and happy-dom remain in place.

Local validation for the exact source tree (Go 1.26.11, tags
`sqlite sqlite_unlock_notify`):

- In an isolated tracked-source archive with the updated go.mod/go.sum,
  `go mod verify`: PASS; `go mod tidy -diff`: PASS.
- Crypto-importing package tests: PASS for
  `./models/asymkey ./models/auth ./modules/auth/password/hash ./modules/keying
  ./modules/packages ./modules/setting ./modules/ssh ./modules/util
  ./routers/api/v1/misc ./services/auth/method`.
- Full-repository `go vet -p 2 -tags='sqlite sqlite_unlock_notify' ./...`:
  PASS in the isolated tracked-source archive.
- `govulncheck v1.9.0 -scan=module`: exit 0, 217 modules, x/crypto at the
  fixed version, zero findings. This root module scan is not substituted for
  the full application symbol scan.
- A local full scan directly in the working tree exited 1 before coverage
  because ignored Go 1.26.11 GOROOT test fixtures under
  `build/ios/go1.26.11-a7/goroot/test` are invalid as one Go package. A
  tracked-source archive scan was started, but the selected execution
  environment became unavailable before its exit/result could be collected;
  it is BLOCKED with no finding conclusion. The exact-source hosted scan below
  remains the authoritative full-coverage result.
- Current npm audit: exit 1, 13 moderate, zero high/critical; all findings are
  development tooling. `npm audit --omit=dev --json`: exit 0, zero production
  advisories. Suggested automatic fixes include downgrades and were not applied.

Exact-source hosted qualification for `561abf5c16723b51d560dac2f097d192ec260558`:

- Runtime compatibility matrix run 42998287857: PASS. Artifact 13845012380,
  SHA-256 `1b3b0a879c5a2b84ee74dabbb080149d954622c0ba617cb9575b8fc67b8e9bd9`.
- Runtime/A7 run 42998287874: stock Go 1.26.11 Linux regression and patched
  A7 runtime jobs PASS (130447765333, 130447765810), including toolchain,
  scheduler, production payload, launcher, backup/restore and security-surface
  validation. Artifact 13844404245, 75,696,298 bytes, SHA-256
  `ab000333281afa5c9713883441b2ea69d48eac0242aec2402224c58cb97b7667`.
- Production build run 42998288059 was IN PROGRESS; host security run
  42998288099 was QUEUED at this checkpoint. Their results must be recorded
  against this exact source, not inferred from previous commits.

P028 remains in progress. The full exact-source vulnerability scan and the
production build are outstanding. The npm development-tooling findings remain
unresolved; no version was downgraded and no audit threshold was weakened.
Remaining v15 ledger rows include scheduled-workflow parsing, Arch package
names/epochs, unnecessary tag data and FilesInit LatestSha. Mirror-reference
change `efa00103570af0d7ad5eea92be9a02fa209459b2` remains BLOCKED on missing
force-push history prerequisites. Next action: complete exact-source host
security and production CI, then continue the highest-priority compatible v15
port. Device qualification remains **DEFERRED — OWNER APPROVED**. Production
changes: none.


## Exact-source CI completion update — source 561abf5c

The previously pending workflows for implementation source
`561abf5c16723b51d560dac2f097d192ec260558` have completed:

- Runtime compatibility matrix 42998287857: PASS; artifact 13845012380,
  SHA-256 `1b3b0a879c5a2b84ee74dabbb080149d954622c0ba617cb9575b8fc67b8e9bd9`.
- Stock Linux and patched A7 runtime jobs in 42998287874: PASS. The run
  confirms the Go 1.26.11 A7 toolchain, scheduler path, production payload,
  launcher, backup/restore and security-surface checks. Artifact 13844404245,
  SHA-256 `ab000333281afa5c9713883441b2ea69d48eac0242aec2402224c58cb97b7667`.
- Production build 42998288059: PASS; artifact 13845439796, SHA-256
  `e3168b484b35aad9e4fa8664e97a8fc1838c916f0a8de09ae284bb0598a2da9b`.
- Host security run 42998288099: vulnerability job 130447765594 PASS; full
  module/package/symbol scan reports `VERIFIED PASS`, with all listed packages
  and no exclusions. Unit/SQLite fixtures, backend build and API/workflow trust
  integration job 130447765623 PASS. Vulnerability evidence artifact 13845364708,
  SHA-256 `c7206159550ab1c89bda87ca50b696596ecd594774949a62b76fa87c4d00bb7a`.
- Frontend Vitest and webpack build PASS. The strict npm audit step in frontend
  job 130447765042 exits 1 with 13 moderate development-tool advisories, zero
  high and zero critical. Production-only npm audit exits 0. Audit artifact
  13845798674, SHA-256
  `ea55edf6135a9ca7f4e0da32737e4221e8f30436ee4f9904e3fdab6ff21a6a52`.
  No security threshold was weakened and no downgrade was applied.

Thus GO-2026-5932 is absent from the complete exact-source vulnerability scan
with the fixed x/crypto version. The frontend development-tool advisories remain
the only failing exact-source security gate. PR #11 remains Draft and targets
`ios/p027-security-port`; production remains unchanged. The current P028 head
at this checkpoint includes a handoff-only documentation commit after source
`561abf5c`; the GitHub comparison confirms it changes only
`docs/p028-handoff.md`. Device qualification remains
**DEFERRED — OWNER APPROVED**.


## P028 resume checkpoint — 2026-11-12

Recovery started at requested head aa556f91d00a315a09471afa01030e9db4075037 on ios/p028-security-compatibility. PR #11 is Open Draft and still targets P027 ios/p027-security-port at 0452d8113a7bc50886ad020bfccadb764de45494. The first new implementation commit is c04a35987afa60e923f2ade848f6d0f5b2a67ce5; the five compatible v15 ports follow it, ending at source commit 29ce164cce525a5f6e98b9b55e7f70776df207b4. No production branch was changed.

### Frontend audit remediation

The pre-remediation strict audit captured 13 moderate findings, zero high/critical findings, all in development tooling. The production-only audit had zero advisories. The saved baseline is docs/p028-npm-audit-after-lock-update.json; after remediation, docs/p028-npm-audit-after-remediation.json and the production report both contain zero vulnerabilities. Fresh npm audit --audit-level=moderate --json and npm audit --omit=dev --audit-level=moderate --json also both exit 0 on this tree.

The baseline graph and changes were checked package by package:

- Direct typescript-eslint 8.56.1 brought @typescript-eslint parser, plugin, type-utils, utils and typescript-estree at 8.56.1; the package advisory also surfaced the nested @typescript-eslint/typescript-estree/node_modules/minimatch 10.2.6. The tool suite moved to 8.72.2 without changing its major. Its declared peers accept ESLint 9 and TypeScript 5.9; the current Node 24 test and webpack build pass.
- Direct eslint-plugin-sonarjs 4.2.2 had nested minimatch 10.2.6. Direct markdownlint-cli 0.50.0 had nested minimatch 10.2.6. Both now resolve to minimatch 11.0.8 through the scoped override. Other affected nested minimatch copies were under editorconfig 1.0.7, js-beautify 1.15.4 and read-package-json 6.0.4, at versions 9.0.9 or 10.2.6. The fixed advisory boundary is below 11.0.1; current development copies are 11.0.8. Existing production minimatch 11.0.1 is already outside that vulnerable range and remains unchanged.
- js-beautify was transitive through @vue/test-utils 2.4.6 and brought vulnerable editorconfig 1.0.7 plus glob 10.5.0 copies under itself and read-package-json. Updating @vue/test-utils to 2.5.1 selected js-beautify 2.0.3; overrides now select editorconfig 4.0.0 and glob 14.0.5. The glob advisory affects versions through 14.0.1. read-package-json remains reachable through the development-only license-checker-rseidelsohn chain, with its glob fixed to 14.0.5.
- typescript-eslint 8.72.2, minimatch 11.0.8, glob 14.0.5 and editorconfig 4.0.0 satisfy the current CI Node 24 toolchain; editorconfig 4.0.0 requires Node >=22. The repository root still declares Node >=20, and this is a development-only path (the production-only audit remains clean); Node 20 was not the qualified toolchain. No --force install, downgrade, audit threshold change or dependency path removal was used. The strict gate remains enabled.

### Supported-v15 ports

Baseline audit entries (13 total) and their dependency paths are itemized below. The saved pre-remediation report provides the vulnerable ranges and npm advisory metadata; current full and production-only audits return zero vulnerabilities.

| Finding | Direct/transitive path in baseline lockfile | Remediation and compatibility |
|---|---|---|
| @typescript-eslint/eslint-plugin | Transitive: typescript-eslint 8.56.1 → @typescript-eslint/eslint-plugin 8.56.1 → type-utils / utils | Updated the typescript-eslint suite to 8.72.2, same major; current ESLint 9 and TypeScript 5.9 peers are supported. |
| @typescript-eslint/parser | Transitive: typescript-eslint 8.56.1 → parser 8.56.1 → typescript-estree 8.56.1 | Updated the suite to 8.72.2. |
| @typescript-eslint/type-utils | Transitive: typescript-eslint → eslint-plugin → type-utils; advisory path included typescript-estree and utils | Updated the suite to 8.72.2. |
| @typescript-eslint/typescript-estree | Transitive through parser, type-utils and utils; nested minimatch 10.2.6 | Updated the suite to 8.72.2 and scoped minimatch to 11.0.8. |
| @typescript-eslint/utils | Transitive: typescript-eslint → eslint-plugin / type-utils → utils; advisory path included typescript-estree | Updated the suite to 8.72.2. |
| editorconfig | Transitive: @vue/test-utils 2.4.6 → js-beautify 1.15.4 → editorconfig 1.0.7 → nested minimatch 9.0.9 | @vue/test-utils 2.5.1 selects js-beautify 2.0.3; editorconfig 4.0.0 and minimatch 11.0.8 are fixed. editorconfig 4 requires Node 22; CI Node 24 qualifies this dev-only path. |
| eslint-plugin-sonarjs | Direct 4.2.2 → nested minimatch 10.2.6 | Kept the direct tool; the scoped minimatch 11.0.8 override fixes its vulnerable transitive dependency. |
| glob | Two transitive copies: js-beautify/node_modules/glob 10.5.0 and read-package-json/node_modules/glob 10.5.0 | Both copies use 14.0.5, above the advisory range through 14.0.1. |
| js-beautify | Transitive: @vue/test-utils 2.4.6 → js-beautify 1.15.4; findings came through editorconfig and glob | @vue/test-utils 2.5.1 selects js-beautify 2.0.3, whose editorconfig and glob paths are explicitly fixed. |
| markdownlint-cli | Direct 0.50.0 → nested minimatch 10.2.6 | Kept the direct tool; minimatch 11.0.8 fixes the nested path. |
| minimatch | Six transitive copies: typescript-estree/minimatch 10.2.6; editorconfig/minimatch 9.0.9; sonarjs/minimatch 10.2.6; js-beautify/minimatch 9.0.9; markdownlint-cli/minimatch 10.2.6; read-package-json/minimatch 9.0.9 | All six development copies resolve to 11.0.8, above the vulnerable range below 11.0.1. Production minimatch 11.0.1 already exceeded that range and was retained. |
| read-package-json | Transitive via license-checker-rseidelsohn → read-installed-packages → read-package-json 6.0.4 → glob 10.5.0 and minimatch 9.0.9 | Kept read-package-json; scoped overrides select glob 14.0.5 and minimatch 11.0.8. |
| typescript-eslint | Direct 8.56.1 → @typescript-eslint components listed above | Updated to 8.72.2 without a major change. The saved baseline metadata suggested 8.36.0, which would be a downgrade; it was not used. The current strict audit confirms zero findings. |

Five separate incremental code commits implement the requested upstream fixes:

- 7060a2af662ff89c39c34a5ef5dd00c6df065a5d ← ab972d7b9392a79991da9aa45963e3f6a3ae1927: scheduled workflows remain enabled after transient failures; persistent parsing/configuration errors remain distinguishable.
- f1122ecee94281c843fbd0bae07c9d8b453e1b20 ← 85b0721bc6f8a45c6a0ccf4b83dd69ee30543aba: Arch package names and versions follow accepted formats.
- 4de1973bd827bc470965cea299f39b69cacd65f7 ← 0d5d66fbd67046740abc72946e9b546e7e8840b1: numeric Arch package epochs are accepted and malformed epochs rejected.
- 9469bb1df6e83859a365cb1b97bd9643c00d38c8 ← 65ca1b0dbea21e1af3bc45dbfd7cad38913f078f: new tags avoid an unnecessary attribute load while stored releases still load attributes.
- 29ce164cce525a5f6e98b9b55e7f70776df207b4 ← 4dd2cb29351a87afb8a41cf0a70d50ce0b0fad4c: FilesInit sets LatestSha to the initialized default branch head, with an integration regression.

The mirror-reference change efa00103570af0d7ad5eea92be9a02fa209459b2 remains BLOCKED because supported v15 has no qualified force-push history storage/migration prerequisite. The test-only ee9ea7512bff1bbc466539b780299862f9f0569d helper migration is dispositioned separately in the ledger; it has no production behavior change and the new regression already uses forgery.CreateRepository. Full dispositions and mappings are in docs/p027-v15-ledger.csv and docs/p028-commit-map.csv.

### Local validation

On source 29ce164cce525a5f6e98b9b55e7f70776df207b4:

- Node 24.19.0 / npm 11.9.0 npx vitest run: PASS, 26 files / 103 tests.
- make GO=/workspace/.tools/go1.27.1/bin/go -B frontend: PASS, production webpack build with webpack 5.105.4. The application embeds the generated assets; generated outputs are ignored and no asset bundle was committed.
- Strict full audit and production-only audit at severity moderate: PASS, zero findings in each; production-only coverage remains separately represented.
- Go 1.26.11 go mod verify: PASS; SQLite-tagged production build: PASS.
- Go 1.26.11 focused package tests for ./models/actions ./services/actions ./modules/packages/arch ./models/repo ./services/release: PASS. Focused vet for those packages plus ./tests/forgery ./tests/integration: PASS.
- Go 1.26.11 TestFilesInitPopulatesLatestSha with SQLite integration tags: PASS. Focused package tests and vet plus the FilesInit integration regression also passed earlier with Go 1.27.1; final hosted qualification will use the exact pushed source.
- At this checkpoint the exact-source hosted Go vulnerability scan, Vitest/webpack/strict-audit workflow, Go integration workflow, stock/A7 runtime matrix, production build and artifact provenance were still pending. Their results are recorded below; prior results for 561abf5c and c04a359 do not qualify these commits.

At that checkpoint P028 remained PARTIAL — RESUMABLE. Physical-device tests remain DEFERRED — OWNER APPROVED.


## Exact-source hosted qualification — 2026-11-12

The hosted runs below checked out PR head 7bf526ed9e48d1c7c4c179105b5d581fe66e924f, whose application code ends at 29ce164cce525a5f6e98b9b55e7f70776df207b4. That head includes only the handoff, ledger and commit-map documentation after the code source; no application code changed after the tested source commit.

- Host security run 43147692077: **PASS** at head 7bf526e. Security job 130949261406 passed unit/SQLite fixture tests and API/workflow-trust integration tests. Vulnerability job 130949261708 passed all five scanner regression fixtures and the full module/package/symbol scan with status VERIFIED PASS, all listed packages covered and no exclusions. Artifact p028-vulnerability-evidence, ID 13911479841, 386838 bytes, SHA-256 b81845765b2dfe0f55ece690f541fbeb205d2385a8795f6e517423cc6a48d2d7. Frontend job 130949261710 passed 26 Vitest files / 103 tests, webpack 5.105.4 production build and strict npm audit; the audit exited successfully with zero findings. Artifact p028-frontend-audit, ID 13912172338, 317 bytes, SHA-256 ac42c09cbfabfc115a7002089e70bffd9da2341d17f3e67d8aa52e50eca4f8ca.
- Production build run 43147692109: **PASS**, job 130949261341. Go 1.26.11 SQLite production variant built, the binary inspection passed, and the ad-hoc signed binary was valid on disk and satisfied its Designated Requirement. Internal SHA-256 values: pristine 5aab51ba6a3526bf617eb24590542099c49cb7d7878f6371a36ff5ef871a261d; signed 07a4fb47ee22bee231ce07e76ab306b469c177f98265c900f281055ef5c6bd56. Artifact ios-forgejo-production, ID 13912737194, 74975286 bytes, SHA-256 b24527fd7dc09bbd5c96ee426a54f9241383ca1141e648756ad4689d983a736c.
- Patched A7 and stock runtime run 43147692083: **PASS**, A7 job 130949261523 and Linux stock regression job 130949262203. Go 1.26.11 A7 toolchain/runtime and launcher, backup/restore and security-surface checks passed. Payload SHA-256 values: pristine 0f4dccf43311273d89b0037378ec2756cbc0c73b00e3c966cc303d69660dbe22; A7 binary 157d969e12f24440d95b354d799b70e423fc162f7ec32bd6757a03f06cd2b22b; runtime probe a641daaf236a74bc313785306edb4100761e8754a3ce1ab3c811d3d55f18560d. Artifact ios-forgejo-a7-runtime, ID 13911709182, 75697591 bytes, SHA-256 9a5eb9a9f496aad8343777d920bb57192aa7cdbc789aa43c598c183e96d4abcc.
- Runtime compatibility matrix run 43147692172: **PASS**, job 130949261629. Artifact ios-runtime-compatibility-matrix, ID 13912207131, 4062870 bytes, SHA-256 b5e8d8d719e701c2d12810da8ca415ccb5fa2663aecfe2a494418c1dd38c0615.

The artifact upload logs and GitHub artifact metadata agree on the archive digests above. The production and A7 workflows also wrote payload SHA-256 manifests and verified binary/code-signing requirements. A direct artifact download for an additional local archive re-hash returned HTTP 403 from GitHub artifact blob storage, so the independent verification evidence is the workflow's build/checksum validation and matching upload/API digests.

The current strict frontend audit reports zero findings; the previous 13 moderate development-only findings are resolved, and the local production-only audit also passes with zero findings. The supported-v15 ports and dispositioned test-only migration are complete and hosted checks pass. Mirror-reference change efa00103570af0d7ad5eea92be9a02fa209459b2 remains **BLOCKED** until its force-push history prerequisite exists and is qualified. Physical-device tests remain **DEFERRED — OWNER APPROVED**. PR #11 remains Open Draft on ios/p027-security-port; production iOS is unchanged. P028 remains PARTIAL — RESUMABLE because the mirror-reference prerequisite is still outstanding.
