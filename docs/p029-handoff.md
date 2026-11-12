# P029: PARTIAL — RESUMABLE

## Branch and source

- Repository: `nghianguyen150612/Forgejo-iOS`.
- Resume branch: `ios/p029-upstream-integration`; the live branch and origin were at `9334a4914f2c358cb1617c512ea8b5ac60dd4acb` when this session resumed. The prompt expected `ac8022b0698664249ff36018818abeaf7b13a2ee`; that commit was not the live branch tip. No reset or overwrite was done.
- P028 base: `2739b4a98e8be791c4c27807de3ad8a48c923d67`.
- P029 code source qualified by hosted CI: `67a54b38c829357f3c943d53f1fd1946f1bc664a`. Origin matched.
- Existing Draft PR #12: https://github.com/nghianguyen150612/Forgejo-iOS/pull/12, targeting `ios/p028-security-compatibility`.
- Official heads refreshed: development `4d2648a1baf8d38ec530a330c4fe7e5026bee779`; supported `v15.0/forgejo` `7f7e02bd2d2ba7c7d121edc06d1e321450f7cad0`.

This handoff update changes documentation only after the tested source SHA. The final P029 branch tip must be reported alongside that source SHA; compare the documentation-only tip against `67a54b38` before claiming source qualification.

## Implemented P029 changes

- Supported-v15 team fixture: upstream `f2a37353aa84f67e08cba69e4de468bb9fe2d533`, local fixture API `bed7432aba` and persistence fix `82a9053d30`. Explicit units persist without duplicates or default-unit overrides; default callers keep the original unit set.
- Development timeline safety: upstream `14d5d663e9e0a62c5e6dec83bf3509be3c18bdaf`, local `e2823a0776`. The v15 adapter checks that a collected commit can still be loaded before rendering a link.
- Prerelease migration comparison: upstream `92d5abd016b692a9ce2b419d4f883934b44d03d8`, local `67a54b38c8`. This preserves reaction import and pagination for prerelease Forgejo versions.
- Existing P028 security work, Go 1.26.11, A7 runtime patches, SQLite support, and strict npm audit threshold remain intact. No incompatible development default-branch changes were copied to supported v15.

## Qualification

- **PASS — Go 1.26.11 synthetic SQLite team-unit regression.** `make test-sqlite GOTESTCOMPILEDRUNSUFFIX="-test.run='Test(PullViewConversation|ActionsForcePushCommitStatus|ForgeryCreateTeamUnitPersistence)'"` passed. It verified explicit team units persist in SQLite; default insertion does not override them; repeated creation adds no duplicate/conflicting units; loaded permissions match the selected units; and nil/default callers retain the expected defaults.
- **PASS — local migration regression.** With Go 1.26.11 and tags `sqlite sqlite_unlock_notify`, `go test -p 1 ./services/migrations -run 'Test(ForgejoDownloadRepo|GiteaDownloadRepo)$' -count=1` passed. The prerelease fixture retains reaction import and pagination.
- **PASS — exact-source hosted P027 host security regressions**, run [43206198080](https://github.com/nghianguyen150612/Forgejo-iOS/actions/runs/43206198080), source `67a54b38c829357f3c943d53f1fd1946f1bc664a`:
  - Frontend job 131141852666: `npm ci`, 26 Vitest files passed, Webpack production build passed, and `npm audit --audit-level=low` exited 0. No npm audit findings were reported. The strict low threshold remains enabled.
  - Security job 131141853061: Go 1.26.11; `go mod tidy -diff`, `go mod verify`, full `go vet`, unit suites, team-unit and timeline regressions, and API/workflow trust integration checks passed.
  - Vulnerability job 131141853230: full module, package, and symbol scan returned `VERIFIED PASS` with all listed packages covered and no exclusions.
- **PASS — A7 runtime build and stock regression**, run [43206197913](https://github.com/nghianguyen150612/Forgejo-iOS/actions/runs/43206197913), source `67a54b38c829357f3c943d53f1fd1946f1bc664a`. Linux stock Go 1.26.11 job 131141851875 and A7 production job 131141852116 passed, including launcher lifecycle and isolated backup/restore. Independent A7 artifact consumer job 131145158106 passed: source SHA, Go 1.26.11 A7 runtime marker, SQLite status, binary SHA256SUMS, and arm64 Mach-O architecture matched.
- **PASS — runtime compatibility matrix**, run [43206197846](https://github.com/nghianguyen150612/Forgejo-iOS/actions/runs/43206197846), job 131141855228.
- **PASS — production artifact provenance**, run [43206197839](https://github.com/nghianguyen150612/Forgejo-iOS/actions/runs/43206197839), source `67a54b38c829357f3c943d53f1fd1946f1bc664a`. Build job 131141851936 and independent verifier 131144144576 passed. Artifact `ios-forgejo-production` ID `13938360590`, 74,981,435 bytes, ZIP SHA-256 `090418e0b72cb4bbf41f99ca5062369a3d02bd68e3ee7d731a6777d85873adf8`. The verifier confirmed the exact source SHA, Go 1.26.11 darwin/arm64, `GOOS=ios`, `GOARCH=arm64`, both binary checksums, and Mach-O arm64 architecture.
- **PASS — A7 artifact provenance.** Artifact `ios-forgejo-a7-runtime` ID `13937278958`, 75,704,018 bytes, ZIP SHA-256 `2d001e18d7d397fb43e4de28e10abbd6cd9c869f20c0d6b756d3bec3456fd479`. Independent verifier matched source SHA `67a54b38`, A7 runtime and SQLite markers, binary checksums, and arm64 Mach-O. Vulnerability evidence artifact ID `13936219479`, SHA-256 `d58cc27fe6fd1c991cc19a3a29c301f233a860f6a678f34ef521b5dbfb07fbe7`; npm audit evidence artifact ID `13939045504`, SHA-256 `50d682b0bb89a8de7861a4b352c21af69a274a0018fcb03252abf8e3efc64840`.

No release was created and no production installation or physical device was touched.

## Force-push history prerequisite

**BLOCKED — FORCE-PUSH HISTORY PREREQUISITE.**

Development `6c2b8b9d726a44abbaf7bc07d293cb10e93829a7` adds refs under `refs/pull/N/comment/M/{old,new}`; `efa00103570af0d7ad5eea92be9a02fa209459b2` moves those pins to `refs/pr-force-push/` and changes `receive.hideRefs`. Supported v15 currently has only `refs/pull/N/head` and hides `refs/pull/` from receive-pack. There is no SQL migration, but repositories can already contain legacy Git refs; `receive.hideRefs` does not hide them from upload-pack.

Synthetic Git tests ran only in isolated temporary repositories at `/tmp/p029-forgejo-ref-qualification.d1m1lutn`. Repository setup, new pin creation, repeated force-push events, legacy and new ref fetching, protected direct writes, public-only `git push --mirror` preservation, and deletion by both namespace prefixes passed. A mirror carrying internal refs was rejected by receive protection. The prefix cleanup test exercised Git commands only, not Forgejo issue deletion. The v15 application still lacks the ref creation, hook protection, PR deletion cleanup, and migration from legacy refs needed for a safe port; do not mark this gate PASS.

## Upstream/security review and remaining gates

- Current development inventory was refreshed through `4d2648a1`. The P029 development mapping and supported-v15 ledger record the handled changes. The latest remaining changes are CI-only, test-fixture-only, localization, refactor, or version-specific features; the Mermaid dependency update has no npm audit findings.
- No new supported-v15 security fix was identified beyond the team fixture update. Previously ported P027 security fixes remain. Development Go 1.27.4 is not adopted.
- **DEFERRED — OWNER APPROVED:** physical-device validation. Host native builds do not establish device execution.
- **NOT RUN:** app-level force-push history lifecycle/migration qualification, and physical-device testing.
- **NEXT:** design and test v15 migration and lifecycle behavior for old and new force-push ref namespaces, including mirror push and PR deletion; then rerun the existing exact-source host, A7, runtime matrix, and artifact checks on any new source SHA.
