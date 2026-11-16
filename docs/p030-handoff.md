# P030: PARTIAL — RESUMABLE

P029 received HEAD `c5d065cf7e0f2bce457f0986ee40c2d49a886a75` was verified before editing. Reconciled P029 HEAD/base `df69dda444b0aa447cb2da15cad90be052cd2026` changes documentation only from that HEAD and exact test/workflow checkpoint `67e337fc5f07b4857bafd4d7fffa73ca840474e8`. All four terminal runs PASS, including independent consumers; exact IDs and artifact hashes are in `p029-handoff.md` and `evidence/p029-terminal-ci.json`. P029 is host/native qualified within implemented scope, with force-push history explicitly excluded and BLOCKED.

P030 branch `ios/p030-upstream-integration` targets `ios/p029-upstream-integration`. Official Codeberg refs refreshed: supported `v15.0/forgejo` `32db264fb3127358eb4d57ba34f506cca60dc9b8`; development `forgejo` `10615cce5019acefd625c1300cba85d228b045cc`. Compared against actual P029 review baselines `7f7e02bd2d2ba7c7d121edc06d1e321450f7cad0` and `4d2648a1baf8d38ec530a330c4fe7e5026bee779`. No development merge performed. Refreshed interval and risks: `p030-upstream-ledger.csv`.

## First implemented batch

- Supported-v15 `32db264fb3127358eb4d57ba34f506cca60dc9b8`: organization fixture options, all existing callers updated, including retained P029 team persistence regression. New test reloads public/limited/private visibility from synthetic SQLite and checks anonymous/owner application paths and nil/default creation.
- Development `68932ee9bdf734d5f78b21a21e713d92ab1243e0`: compatible one-line release-list optimization reuses the repository already authorized by the handler; avoids one redundant repository query per release. Existing draft/filter and attachment tests retained; URL ownership assertions added. No schema or API contract change.
- Local frontend isolation repair (no upstream SHA): automatically unmount Actions-view test components after each test so polling cannot outlive its fetch mock. All existing assertions and strict error handling retained. Initial Vitest run: FAIL (103 assertions passed but one unhandled localhost rejection); focused retry PASS (11 tests), full retry PASS (26 files / 103 tests / no unhandled errors).
- Existing host workflow additionally selects all release API tests and the new visibility test; no security gate weakened. Go 1.26.11, A7 runtime, security dependencies, strict npm audit low threshold, iOS launcher/packaging/deployment target and synthetic fixtures retained.

No new supported-v15 security patch exists in the refreshed interval. Development pgx update remains a separate dependency review requiring PostgreSQL qualification; no vulnerability finding is asserted without a fresh scan.

## Qualification and excluded work

Corrected application/test checkpoint: `818531e9441f1687cab442478327e33884ffe8f6`. Application port commit: `f8db44dd8cf6cbeeb334df1c0b640d98a7ed57a7`; query regression adapter repair: `818531e94`. Draft PR [#13](https://github.com/nghianguyen150612/Forgejo-iOS/pull/13) targets `ios/p029-upstream-integration`. Mappings: `p030-commit-map.csv`. Later documentation-only commits do not change the qualified source.

- **PASS — exact Go 1.26.11 local qualification:** backend with `sqlite sqlite_unlock_notify`; repository and API package tests; all selected release/visibility/P029 application regressions; `TestForgejoDownloadRepo` and `TestGiteaDownloadRepo` migration fixtures; `go mod verify`; `go mod tidy -diff`; full `go vet -p 2 ./...`.
- **PASS — frontend:** Bun is not used for this project; `npm ci`, Vitest 26 files / 103 tests, Webpack production build and `npm audit --audit-level=low --json` with zero findings. Existing threshold/assertions retained; no lockfile changed. Initial polling test leakage and its full passing retry are recorded below and in `p030-local-evidence.json`.
- **PASS — fresh exact-checkpoint security artifacts:** independently downloaded vulnerability ZIP `14210376571`, SHA-256 `710d620346dad7d47b9a6f7ec987cff08364418b9d09fd32a12fdd11c1b1b08c`, and npm ZIP `14209433253`, SHA-256 `1bcafa3010a6bc310153f92b04d777f13fac1d84dc9b78b8bee97ebc3b1ce657`. Both match GitHub digests. Vulnerability report records clean source `818531e94`, Go 1.26.11, complete module/package/symbol scans, **0 findings in all three modes**, all 396 application packages and no exclusions. OSV database records in the raw stream are retained and are not counted as findings. Report: `p030-vulnerability-summary.json` (full raw report retained in the hash-verified CI artifact).
- **PASS — native production**, run `43834491227`, build `133187632337`, independent consumer `133189595514`.
- **PASS — A7 and stock regression**, run `43834496553`, A7 build `133187654689`, stock regression `133187655278`, independent consumer `133190465586`.
- **PASS — runtime matrix**, run `43834501668`.
- Fresh host workflow `43834484957`: frontend and vulnerabilities PASS; remaining host integration status is recorded in the terminal table below. No earlier source run substitutes for it.

Independent native consumers verify same-run downloaded binaries/checksum manifests, exact source `818531e94`, Mach-O arm64, production Go 1.26.11 and A7 runtime/SQLite markers. iOS 12 deployment configuration, launcher lifecycle and isolated backup/restore gates are retained. Consumer output evidence: `p030-native-consumer-evidence.json`; full metadata: `p030-ci-snapshot.json`. This does not establish physical-device execution.

**BLOCKED — force-push history:** `6c2b8b9d726a44abbaf7bc07d293cb10e93829a7` and `efa00103570af0d7ad5eea92be9a02fa209459b2` remain excluded. No new implementation or evidence changes `p029-force-push-compatibility.md`. SQL/Git crash/retry design, duplicate events, orphan pins, both namespaces, receive hooks, mirror behavior and actual deletion cleanup remain unresolved. Passing baseline CI is not qualification of this feature.

Production modifications **NONE**. No tags, releases, merges, scheduled watcher changes, production database/repository access or device operations. Physical-device validation **DEFERRED — OWNER APPROVED**; device tests **NOT RUN**. This branch is not production-release-ready.

Local setup note: incomplete runs through a newer launcher were stopped when it did not downgrade to the supported toolchain. They are not Go 1.26.11 qualification. Fresh commands explicitly use `GOTOOLCHAIN=go1.26.11`; `go version` verified `go1.26.11 linux/amd64`. Backend/SQLite results pending below. Module verification and `go mod tidy -diff` PASS on Go 1.26.11. Frontend Webpack production build PASS; strict `npm audit --audit-level=low --json` PASS with zero findings. No lockfile changes.

Local Go 1.26.11 backend build **PASS**. Repository-model and API package unit suites **PASS** with tags `sqlite sqlite_unlock_notify`. Full selected synthetic application suite **PASS**: `TestP030OrganisationVisibility`, all `TestAPIRelease*` (including query-count, URL ownership, draft authorization and attachments), P029 force-push exclusion baseline, team persistence, conversation and Actions status. New query observer initially failed on context-bound session setup, then exposed older XORM multi-hook tracing-context loss; replaced with a temporary context-aware SQL logger restored at test exit. No runtime tracing or application code was weakened. The corrected test checkpoint requires fresh hosted qualification; results on `f8db44dd8` do not qualify this correction.

Corrected source checkpoint: `818531e9441f1687cab442478327e33884ffe8f6` (application changes in `f8db44dd8cf6cbeeb334df1c0b640d98a7ed57a7`, query-test correction in this checkpoint). Negative control: temporarily removing only repository reuse produced the expected **FAIL**, 2 versus 3 repository queries as list size grows; restored implementation **PASS**. Source file restored byte-for-byte before commit. No production repository or database used. All four hosted workflows are freshly dispatched on this corrected source.

The first P030 checkpoint `f8db44dd8` has host run `43833451011` **FAIL** (new query-test engine setup), with its frontend/vulnerability jobs PASS; production `43833455762`, A7 `43833459801` and matrix `43833464577` PASS. This failure is preserved, not relabeled. Corrected source `818531e94` received four new workflows. Local intermediate observer retry also failed by disrupting the old tracing hook chain; the final temporary SQL-logger adapter preserves tracing and the full suite passes. Neither failed test setup changed application behavior or production data.


## Terminal exact-checkpoint qualification — implemented batch PASS

- **PASS** run [43834484957](https://github.com/nghianguyen150612/Forgejo-iOS/actions/runs/43834484957), exact source `818531e9441f1687cab442478327e33884ffe8f6`.
  - `133187613728` frontend: **PASS**.
  - `133187614024` vulnerabilities: **PASS**.
  - `133187614388` security: **PASS**.
  - Artifact `p028-vulnerability-evidence`, ID `14210376571`, archive `sha256:710d620346dad7d47b9a6f7ec987cff08364418b9d09fd32a12fdd11c1b1b08c`.
  - Artifact `p028-frontend-audit`, ID `14209433253`, archive `sha256:1bcafa3010a6bc310153f92b04d777f13fac1d84dc9b78b8bee97ebc3b1ce657`.
- **PASS** run [43834491227](https://github.com/nghianguyen150612/Forgejo-iOS/actions/runs/43834491227), exact source `818531e9441f1687cab442478327e33884ffe8f6`.
  - `133187632337` forgejo-production: **PASS**.
  - `133189595514` verify-production-artifact: **PASS**.
  - Artifact `ios-forgejo-production`, ID `14209439784`, archive `sha256:de4847fa094dc4cca40237d6da95a282721d2c977a9617ff7ef9b3c75ec9749d`.
- **PASS** run [43834496553](https://github.com/nghianguyen150612/Forgejo-iOS/actions/runs/43834496553), exact source `818531e9441f1687cab442478327e33884ffe8f6`.
  - `133187654689` forgejo-a7-runtime: **PASS**.
  - `133187655278` linux-stock-regression: **PASS**.
  - `133190465586` verify-a7-artifact: **PASS**.
  - Artifact `ios-forgejo-a7-runtime`, ID `14209379923`, archive `sha256:4bda56b81b03121aa00dc198475722bf80f75525fe5c69cc3befbb503be7c7ee`.
- **PASS** run [43834501668](https://github.com/nghianguyen150612/Forgejo-iOS/actions/runs/43834501668), exact source `818531e9441f1687cab442478327e33884ffe8f6`.
  - `133187669074` ios-cgo-probe: **PASS**.
  - Artifact `ios-runtime-compatibility-matrix`, ID `14209283864`, archive `sha256:4d918c25e1140173f132d712d055919fc23c8ceb8cca0f8c144be8a70200224d`.

All four corrected-checkpoint workflows completed successfully. The native archive digests above are authenticated GitHub metadata; independent hosted consumers downloaded the uploaded bytes and verified source, binary checksums and architecture. Their actual terminal output is retained in `p030-native-consumer-evidence.json`. No older checkpoint substitutes for these results. Full host job includes Go 1.26.11 tidy/verify/vet, existing unit/security suites, backend build and all selected API/Actions/SQLite trust regressions, including the repaired query observer. Physical-device execution remains **NOT RUN**.

**P030: PARTIAL — RESUMABLE.** Supported-v15 fixture and compatible release-list batch are host/native qualified. Force-push prerequisite/mirror functionality stays **BLOCKED**, with the P029 compatibility decision unchanged. Remaining development/dependency/localization proposals have explicit dispositions in the ledger. Next exact source action: review `4a763714317f6064ed10b457ce2b301b66418faa` against retained pgx v5.10.0, inspect intervening fixes and supported-v15 compatibility, run isolated PostgreSQL regression fixtures before adopting any driver update, and obtain fresh host/native qualification after a source change. Do not blindly import development refactors or mandatory-pagination changes. No automatic continuation is implied.

Production modifications **NONE**; physical-device validation **DEFERRED — OWNER APPROVED**; no device, production Git/SQL, release, stable tag, merge or watcher operation. This is not production-release readiness.
