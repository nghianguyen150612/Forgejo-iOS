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
