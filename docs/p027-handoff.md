# P027 first implementation batch — 2026-11-10

Verified baseline: `dfb0b0664f1245f7436a306baf711540f712a03f`.
Official upstream: `1520459a202feb2be7643cbf2ff38ff811ed8607 (2026-11-10T04:14:33+01:00)`.
Development branch: `ios/p027-security-port`.

The verified iOS architecture is the v15.0.9 native executable with Apple CGO,
rootful packaging, manual/LaunchDaemon launchers, SQLite, and the custom
Go 1.26.7 A7 runtime. This batch preserves that architecture and version
identity; it does not claim a full development-line upgrade.

Official upstream advertises HEAD -> refs/heads/forgejo and NO main branch.
Fetching official main failed with "couldn't find remote ref main"; official
forgejo and v15.0/forgejo were fetched directly from Codeberg instead.
Fork main is 92d5abd016b692a9ce2b419d4f883934b44d03d8, ancestor of official
forgejo and four commits behind it. We did not update that tracking branch
or its scheduled watcher. The correct PR base is iOS.

Official v15 maintenance head:
3e36a8f11a05122570e325412d76f3582ed17549 (2026-11-10T04:13:18+01:00).
Its common ancestor with the iOS branch is the frozen stable source
19b9b9d216bbfb501c18514bd1a8c980246ca3f7. There are 48 maintenance ancestry
commits (including merge records); the 46 non-merge patches were not
patch-equivalent to the baseline according to git cherry.

Implemented official v15 backports:
- 96230346557fc94c9818c97f124ce71e8819d209: prevent arbitrary label metadata reads.
- 5e4dc852a4302f55e341ce541540899e8ef76ece: enforce label deletion ownership.
- 4ff23f1ffb5950abafb6c20c9dfac4be8a67fbdb: preserve NuGet token scopes/reducers.
- 6ff8b8e14f88623dd2536402b5420a4f26d4e95e: keep fork review events untrusted.
- cc039bc494818cf5bd78d319d03661f2ecf77b40: upstream workflow trust regression prerequisites.
- 291cf0126691d2d54a6813f3a0bf94d7dfa95bf0: review events use PR head, not arbitrary review commit.

No iOS-specific source substitution was needed: these are portable Go access
checks and tests. Existing source test APIs apply directly after including
the prerequisite workflow trust tests. Original commits are recorded with
cherry-pick trailers. Added host CI runs focused unit/SQLite/API/trust checks;
existing macOS native build workflows are retained.

p027-v15-ledger.csv is the actionable stable-line ledger.
p027-development-inventory.csv inventories all 1379 development-line ancestry
commits absent from the iOS history. Its classifications are initial triage,
NOT proof that stable backports lack equivalent functionality. A full semantic
mapping of this much larger divergent development line remains BLOCKED pending
a dedicated architecture/schema/dependency review. Do not blindly merge it.

Next batch: remaining security fixes for watched/starred repository visibility
and actor permissions; x/net 0.62.0, brotli, compress, frontend security updates;
then qualify the newer Go toolchain against the exact A7 patch contract before
changing native pins. Review branch-state concurrency fix 289d60b47 and token
foreign-key fix 7cac26743 with synthetic databases. New development-line Git,
OAuth, repository, SSH/internal socket, API and migration changes remain pending.
No schema change is introduced by the current batch.

Baseline remote CI: latest production run 42558668710 succeeded; no open PRs
existed at audit time. This is historical evidence, not candidate qualification.

Device qualification: **DEFERRED — OWNER APPROVED**. No SSH/device access,
production service/database access, deployment, installation, migration on a
device, release/tag, production branch update, merge or watcher change occurred.
Host validation and exact results are recorded below before final handoff.

Implementation commits and modified files (documentation commit follows):

```text
539d36a5841b2ffd816010e8f1f69a90e85dddc1 ci(p027): run portable security and SQLite integration regressions
b938955a85141b09fd2a1a0ecea98a4d79675190 fix: pull_request_review Actions can be triggered and run as trusted from arbitrary commits
f82ce8ab4b08aad5110f22c3f153db043b8c448a test: integration tests for workflow trust in uncommon events
696f5be1a5afde39f6cebdca761730fb8a62f0ba fix: don't allow fork pull requests for pull_request_review & pull_request_review_comment events to access secrets
e228b7b95596848a287ad5b34ab0588189a3c6b9 fix: nuget-based access token authentication does not respect token scopes
ab1427f90e8c679bab286e70c3ea526d68084bbc fix: prevent deletion of labels from org/repo with mismatched ownership
471669f4db55d4cd6c05e30b0b9cf09fb23d817b fix: prevent reading arbitrary label metadata

.github/workflows/p027-host.yml              |  27 ++
 models/issues/label.go                       |  57 ++-
 models/issues/label_test.go                  |   6 +-
 routers/api/packages/nuget/auth.go           |  23 +-
 routers/api/v1/org/label.go                  |   2 +-
 routers/api/v1/repo/issue_label.go           |   2 +-
 routers/api/v1/repo/label.go                 |   2 +-
 routers/web/org/org_labels.go                |   2 +-
 routers/web/repo/issue_label.go              |   2 +-
 services/actions/notifier.go                 |  10 +-
 services/f3/driver/label.go                  |   2 +-
 tests/integration/actions_trigger_test.go    | 610 ++++++++++++++++++++++++++-
 tests/integration/api_issue_label_test.go    |  27 ++
 tests/integration/api_packages_nuget_test.go |  14 +
 14 files changed, 748 insertions(+), 38 deletions(-)
```

Additional audit limitation: development-line git cherry produced 56 entries,
including 20 patch-equivalent baseline patches, before GitHub's promisor fetch
returned HTTP 503 for blob 7bcafa7ae2d8c0f5c877823550f40449d391ed7b.
Only those completed equivalences are marked ALREADY PORTED in the development
inventory. Full development-line semantic/equivalence audit remains BLOCKED.

Native CI correction: initial macOS PR jobs failed at checkout because iOS and
ios/* remote refs collide on a case-insensitive filesystem (run 42781284715).
Commit 29ffe92950b18d97026a01580c7eddb388ebe4a6 fetches only the immutable
candidate SHA at depth 1 in both native workflows. Explicit native version
pins and build/runtime contracts remain unchanged. Follow-up CI is pending.


## Host validation (Linux, stock Go 1.27.1)

| Result | Command / scope | Outcome |
| --- | --- | --- |
| PASS | `go test -p 2 -tags='sqlite sqlite_unlock_notify' ./models/issues ./routers/api/packages/nuget ./services/auth ./services/authz` | exit 0; issues 24.703s, authz 1.543s; NuGet compiles with no package-local tests; auth 1.481s with no runnable tests |
| PASS | `go build -p 2 -tags='sqlite sqlite_unlock_notify' -o /workspace/scratch/forgejo-p027 .` | exit 0; host executable built |
| PASS | `make backend TAGS='sqlite sqlite_unlock_notify'` | exit 0; generated fixture backend required by integration subprocesses |
| PASS | `go mod verify` | all modules verified |
| PASS | `scripts/ios/validate-launchdaemon.sh --self-test` | plist validator fixtures passed |
| PASS | `sh scripts/ios/install-forgejo.sh --self-test` | all mock lifecycle fixtures passed; no real installation |
| PASS | `git diff --check` | exit 0 |
| BLOCKED | `scripts/ios/build-forgejo.sh /workspace/scratch/forgejo-p027-ios` | local preflight exit 1, xcrun unavailable |
| FAIL | `govulncheck -tags=sqlite,sqlite_unlock_notify ./...` (v1.9.0) | process killed, exit 137; no completed symbol-level result |
| FAIL | `govulncheck -scan=module` | exit 3; 20 module/host-standard-library advisories, reachability not determined |
| NOT RUN | full repository suites, local race and full historical migration suites | this batch changes access checks, not schema; selected tests use synthetic SQLite/Git fixtures |
| DEFERRED | all device gates | OWNER APPROVED |

The module scanner reports the following advisory IDs (this is NOT a claim
that each is callable from the iOS executable):

GO-2026-6905, GO-2026-6888, GO-2026-6866, GO-2026-6865, GO-2026-6860, GO-2026-6809, GO-2026-6617, GO-2026-6613, GO-2026-6612, GO-2026-6611, GO-2026-6610, GO-2026-6609, GO-2026-6608, GO-2026-6607, GO-2026-6605, GO-2026-6604, GO-2026-6603, GO-2026-6600, GO-2026-6599, GO-2026-5932.

The module scan includes stock host Go 1.27.1, not the custom iOS Go 1.26.7
runtime. Its findings prioritize the next dependency/runtime batch; the full
symbol scan must be repeated with adequate resources. An initial module-scan
invocation with patterns exited 2 (module mode rejects patterns); the corrected
invocation above completed and returned actual advisory findings.

Initial integration invocations FAILED before executing tests: the Makefile
pattern target did not quote a combined regex; after quoting via
GOTESTCOMPILEDRUNSUFFIX, the harness required a root `gitea` binary. CI commits
401db438a and 67fa81564 correct the invocation and backend prerequisite without
changing test coverage or assertions. Final integration outcome follows.

Hosted evidence at source commit 401db438a: pristine iOS production build PASS
(run 42782313370); Linux stock regression PASS (42782313913). Custom A7 runtime
job remains pending. Initial macOS checkout failures and the earlier host-CI
invocation failures remain historical FAIL results; newer jobs are separate
attempts. The final documentation/host-workflow commits require their own CI
completion and are not silently covered by older exact-SHA evidence.

Draft PR: https://github.com/nghianguyen150612/Forgejo-iOS/pull/10
Host qualification: BLOCKED for full acceptance by unresolved dependency
advisories, symbol scan resource failure, development mapping and outstanding
A7/native gates. Selected host checks above PASS only within their scope.
Device qualification: DEFERRED — OWNER APPROVED.

Additional implementation/CI files beyond the initial inventory:
.github/workflows/ios-forgejo-a7-runtime.yml,
.github/workflows/ios-forgejo-production.yml, and
.github/workflows/p027-host.yml (backend prerequisite and quoted run flags).
No scheduled synchronization workflow changed.

## Final integration results

FAIL: `make test-sqlite GOTESTCOMPILEDRUNSUFFIX="-test.run='Test(APIModifyLabels|PackageNuGet|ActionsForkPullRequest)'"`
with the backend fixture built: exit 2 from make. Actions trust completed all
32 event scenarios (55.572s), and label checks completed without failures.
The only reported test failure was the existing NuGet symbol-package byte-size
assertion at api_packages_nuget_test.go:381: expected 616, actual 618 on host
Go 1.27.1. Toolchain sensitivity is a hypothesis; exact Go 1.26.7 CI remains
the comparison gate. The full combined run remains FAIL, and no assertion was
changed, test removed, or toolchain/dependency downgraded to hide it.

A first isolated token-scope selection also FAILED: it omitted the required
package upload fixture, so valid-token GET returned 404. With the upload
prerequisite included, the narrow security check PASSED (exit 0):

```sh
GITEA_ROOT=/workspace/Forgejo-iOS GITEA_CONF=tests/sqlite.ini \
  ./integrations.sqlite.test -test.v \
  -test.run '^TestPackageNuGet$/^(Upload|PackageService)$/^(DependencyPackage|validate_token_scope)$'
```

This verifies the valid-token path and rejection of repository-only scopes;
it does not convert the separate symbol-package failure into a PASS. The CI
workflow retains the full combined test selection, including that assertion.

Next steps in order: confirm/fix symbol-package byte-size portability using
exact supported Go evidence; complete host security/native CI; port security
dependency upgrades and the official ar mirror with full symbol scans; qualify
A7 toolchain updates; then remaining v15 fixes and development-line mapping.
Final qualification remains BLOCKED; the Draft PR is reviewable implementation,
not a completed upstream port or a release candidate.


## P027 upstream refresh and security batch — 2026-11-10

Fresh remote state: official Codeberg advertises `forgejo` (no `main`) at `3f67b3a685eb8fe358b5159aaa32b5213b122738` (`2026-11-10T21:14:56+01:00`). Fork tracking `main` is `92d5abd016b692a9ce2b419d4f883934b44d03d8`, seven commits behind the official default. The supported v15 maintenance head is `3e36a8f11a05122570e325412d76f3582ed17549` (`2026-11-10T04:13:18+01:00`), unchanged from the prior stable-line snapshot. Production iOS baseline remains `dfb0b0664f1245f7436a306baf711540f712a03f`; P027 remains a draft PR against `iOS`.

P027 now ports the v15 `blakesmith/ar` to `code.forgejo.org/crystal/ar` change (`3e36a8f11`, upstream main source `c7a1d39f`) while retaining `toolchain go1.26.7`, CGO/A7 runtime scripts, and packaging architecture. It also ports upstream private repository visibility checks for watched and starred repositories (`16811fea1`, `3f3e8bea8`), the acting-user permission correction (`dae5735ae`), and the regression fixes/tests (`93499a9a`, `45b8da39`, `e0bfad0d`). On the current default branch it ports the `fj` built-in OAuth application (`008a2846`) and removes the deprecated HTTP update-check endpoint (`64a8d3c2`); update checks use the existing Forgejo DNS endpoint. Exact dispositions and SHAs are in `p027-v15-ledger.csv` and `p027-development-inventory.csv`.

The current default-branch mirror-ref fix (`efa001035`) is `BLOCKED`: it depends on force-push ref history that does not exist in the v15 iOS baseline. Porting only the namespace/configuration patch would strand existing refs. The remaining new default-branch changes are CI-only or metadata and are classified upstream-only. The refreshed development inventory has 1,382 ancestry entries. The divergent development line is still not represented as a completed semantic port; the inventory remains a triage artifact, not proof of absence.

New implementation commits on `ios/p027-security-port`: `a7882540`, `9f7a2e12`, `d070c523`, `3b790c02`, `59c09684`, `5019970c`, `b2af3cf7`, `f3df7348`, `a434f9cf`, `08bd6c05`, `f04eb1cb`, and `3a826018`. The host CI workflow now includes auth, update-checker, user deletion, star/watch API and existing security regressions (`628e10da`). Existing P027 security, test, A7, and installer changes remain in the same separate Draft PR. Device qualification is **DEFERRED — OWNER APPROVED**; no production services or databases were accessed.


### Current P027 host validation — 2026-11-11

The security dependency batch is upstream v15 commit `44426ef4042a3b709795694b21db3bf1f034d116`, ported as `08bd6c05`. It updates `x/crypto` to v0.58.0, `x/net` to v0.62.0, `x/sync` to v0.24.0, `x/sys` to v0.49.0, `x/term` to v0.47.0, `x/text` to v0.43.0 and `x/tools` to v0.51.0; `go mod tidy` raised transitive `x/mod` to v0.41.0 in follow-up commit `f04eb1cb`. The module toolchain directive, custom A7 compiler source/patch, and native Go 1.26.7 pins remain unchanged.

| Result | Command / scope | Outcome |
| --- | --- | --- |
| PASS | `go test -p 2 -tags='sqlite sqlite_unlock_notify' ./models/auth ./models/issues ./modules/updatechecker ./services/auth ./services/authz` | Exit 0 under Go 1.26.7 after the dependency update. |
| PASS | `go test -p 2 -tags='sqlite sqlite_unlock_notify' ./services/user` | Exit 0; repo-specific access-token deletion regression included. |
| PASS | `go test -p 2 -tags='sqlite sqlite_unlock_notify' ./modules/packages/debian` | Exit 0 with the cfo `ar` mirror and refreshed module set. |
| PASS | `go vet -p 2 -tags='sqlite sqlite_unlock_notify' ./models/auth ./models/issues ./modules/updatechecker ./services/auth ./services/authz ./services/user` | Exit 0 after the security dependency and token deletion changes. |
| PASS | `go mod verify` and `go mod tidy -diff` | All modules verified; tidy diff empty after recording `x/mod` v0.41.0. |
| PASS | `make backend TAGS='sqlite sqlite_unlock_notify'` | Exit 0 using Go 1.26.7; built host binary reports `go1.26.7`, SQLite tags, and local P027 version `1.0.0-ios-44-3a826018b+gitea-1.22.0`. |
| PASS | `make test-sqlite GOTESTCOMPILEDRUNSUFFIX="-test.run='Test(APIModifyLabels|PackageNuGet|ActionsForkPullRequest|APIStar|APIWatch)'"` | Exit 0 on Go 1.26.7 at pre-dependency source `a434f9cf`; 32 Actions trust cases, NuGet token scope, labels, private star/watch visibility all passed using synthetic SQLite data. The final pushed head CI reruns this selection after the dependency updates. |
| PASS | `git diff --check` | Exit 0 before the documentation commit. |

An initial test invocation after selecting the newer security modules reported that `go.mod` needed tidying. `go mod tidy -diff` showed only the required indirect `x/mod` v0.41.0 update; that update is committed, after which the listed tests passed. No dependency was downgraded. The full symbol-level vulnerability scan remains unresolved: prior P027 scan was killed with exit 137, and the current dependency batch has not been rescanned. The prior module scan's 20 advisory list remains historical evidence, not reachability proof. Native hosted/A7 CI for the final head is pending; local iOS cross-build requires unavailable Xcode tooling. Migration suites were not needed for this no-schema-change batch. Device qualification: **DEFERRED — OWNER APPROVED**.

The v15 ledger now marks the token cleanup (#14622), October security batches (#14814/#15029), and x/net security batch (#15063) as ported. New commits also include `3a826018` for repo-specific token deletion. The next batch should address the remaining v15 security/dependency entries (including compress/brotli/minimatch) with reachability scans and exact A7 toolchain checks; the force-push mirror change remains blocked on its missing v15 reference-history prerequisite.
