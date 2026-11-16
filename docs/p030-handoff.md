# P030: PARTIAL — RESUMABLE

P029 received HEAD `c5d065cf7e0f2bce457f0986ee40c2d49a886a75` was verified before editing. Reconciled P029 HEAD/base `df69dda44` changes documentation only from that HEAD and exact test/workflow checkpoint `67e337fc5f07b4857bafd4d7fffa73ca840474e8`. All four terminal runs PASS, including independent consumers; exact IDs and artifact hashes are in `p029-handoff.md` and `evidence/p029-terminal-ci.json`. P029 is host/native qualified within implemented scope, with force-push history explicitly excluded and BLOCKED.

P030 branch `ios/p030-upstream-integration` targets `ios/p029-upstream-integration`. Official Codeberg refs refreshed: supported `v15.0/forgejo` `32db264fb3127358eb4d57ba34f506cca60dc9b8`; development `forgejo` `10615cce5019acefd625c1300cba85d228b045cc`. Compared against actual P029 review baselines `7f7e02bd2d2ba7c7d121edc06d1e321450f7cad0` and `4d2648a1baf8d38ec530a330c4fe7e5026bee779`. No development merge performed. Refreshed interval and risks: `p030-upstream-ledger.csv`.

## First implemented batch

- Supported-v15 `32db264fb3127358eb4d57ba34f506cca60dc9b8`: organization fixture options, all existing callers updated, including retained P029 team persistence regression. New test reloads public/limited/private visibility from synthetic SQLite and checks anonymous/owner application paths and nil/default creation.
- Development `68932ee9bdf734d5f78b21a21e713d92ab1243e0`: compatible one-line release-list optimization reuses the repository already authorized by the handler; avoids one redundant repository query per release. Existing draft/filter and attachment tests retained; URL ownership assertions added. No schema or API contract change.
- Local frontend isolation repair (no upstream SHA): automatically unmount Actions-view test components after each test so polling cannot outlive its fetch mock. All existing assertions and strict error handling retained. Initial Vitest run: FAIL (103 assertions passed but one unhandled localhost rejection); focused retry PASS (11 tests), full retry PASS (26 files / 103 tests / no unhandled errors).
- Existing host workflow additionally selects all release API tests and the new visibility test; no security gate weakened. Go 1.26.11, A7 runtime, security dependencies, strict npm audit low threshold, iOS launcher/packaging/deployment target and synthetic fixtures retained.

No new supported-v15 security patch exists in the refreshed interval. Development pgx update remains a separate dependency review requiring PostgreSQL qualification; no vulnerability finding is asserted without a fresh scan.

## Qualification and excluded work

Fresh local/hosted source-checkpoint results will be appended. Full new-source security/frontend/native/provenance qualification is **NOT RUN** until those results are recorded; old CI does not qualify new code.

**BLOCKED — force-push history:** `6c2b8b9d726a44abbaf7bc07d293cb10e93829a7` and `efa00103570af0d7ad5eea92be9a02fa209459b2` remain excluded. No new implementation or evidence changes `p029-force-push-compatibility.md`. SQL/Git crash/retry design, duplicate events, orphan pins, both namespaces, receive hooks, mirror behavior and actual deletion cleanup remain unresolved. Passing baseline CI is not qualification of this feature.

Production modifications **NONE**. No tags, releases, merges, scheduled watcher changes, production database/repository access or device operations. Physical-device validation **DEFERRED — OWNER APPROVED**; device tests **NOT RUN**. This branch is not production-release-ready.

Local setup note: incomplete runs through a newer launcher were stopped when it did not downgrade to the supported toolchain. They are not Go 1.26.11 qualification. Fresh commands explicitly use `GOTOOLCHAIN=go1.26.11`; `go version` verified `go1.26.11 linux/amd64`. Backend/SQLite results pending below. Module verification and `go mod tidy -diff` PASS on Go 1.26.11. Frontend Webpack production build PASS; strict `npm audit --audit-level=low --json` PASS with zero findings. No lockfile changes.
