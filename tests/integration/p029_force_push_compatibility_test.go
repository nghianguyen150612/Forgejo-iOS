// Copyright 2026 The Forgejo Authors. All rights reserved.
// SPDX-License-Identifier: MIT

package integration

import (
	"fmt"
	"net/http"
	"testing"

	"forgejo.org/models/db"
	issues_model "forgejo.org/models/issues"
	"forgejo.org/models/unittest"
	user_model "forgejo.org/models/user"
	"forgejo.org/modules/git"
	"forgejo.org/modules/gitrepo"
	"forgejo.org/modules/json"
	issue_service "forgejo.org/services/issue"
	pull_service "forgejo.org/services/pull"
	"forgejo.org/tests"

	"github.com/stretchr/testify/assert"
	"github.com/stretchr/testify/require"
)

// This characterizes the supported-v15 exclusion, not a passing history-pin
// implementation. All database rows and Git data are disposable test fixtures.
func TestP029ForcePushCompatibilityBaseline(t *testing.T) {
	defer tests.PrepareTestEnv(t)()
	ctx := t.Context()
	issue := unittest.AssertExistsAndLoadBean(t, &issues_model.Issue{ID: 19})
	require.NoError(t, issue.LoadRepo(ctx))
	require.NoError(t, issue.LoadPullRequest(ctx))
	pr := issue.PullRequest
	pr.BaseRepo = issue.Repo
	pr.Issue = issue
	doer := unittest.AssertExistsAndLoadBean(t, &user_model.User{ID: 2})
	repo, err := gitrepo.OpenRepository(ctx, issue.Repo)
	require.NoError(t, err)
	defer repo.Close()
	const oldSHA = "1978192d98bb1b65e11c2cf37da854fbf94bffd6"
	const newSHA = "9b93963cf6de4dc33f915bb67f192d099c301f43"

	// Simulate an upgraded repository containing both layouts, without moving
	// any real branch. Prefix-neighbor pins must remain independent.
	pins := []string{
		fmt.Sprintf("refs/pull/%d/comment/17/old", issue.Index),
		fmt.Sprintf("refs/pr-force-push/%d/comment/17/old", issue.Index),
		fmt.Sprintf("refs/pr-force-push/%d0/comment/17/old", issue.Index),
	}
	for _, ref := range pins {
		require.NoError(t, repo.SetReference(ref, oldSHA))
	}
	before, err := repo.GetRefs()
	require.NoError(t, err)

	first, err := pull_service.CreatePushPullComment(ctx, doer, pr, oldSHA, newSHA)
	require.NoError(t, err)
	require.NotNil(t, first)
	var payload issues_model.PushActionContent
	require.NoError(t, json.Unmarshal([]byte(first.Content), &payload))
	require.True(t, payload.IsForcePush)
	assert.Equal(t, []string{oldSHA, newSHA}, payload.CommitIDs)
	first.Issue = issue
	require.NoError(t, first.LoadPushCommits(ctx))
	assert.Equal(t, oldSHA, first.OldCommit)
	assert.Equal(t, newSHA, first.NewCommit)
	MakeRequest(t, NewRequest(t, "GET", issue.Repo.Link()+"/commit/"+oldSHA), http.StatusOK)

	// A retry currently inserts a second SQL timeline row. Neither event pins
	// Git objects. Do not silently label this behavior idempotent or GC-safe.
	second, err := pull_service.CreatePushPullComment(ctx, doer, pr, oldSHA, newSHA)
	require.NoError(t, err)
	require.NotNil(t, second)
	assert.NotEqual(t, first.ID, second.ID)
	after, err := repo.GetRefs()
	require.NoError(t, err)
	assert.Equal(t, before, after, "v15 preserves existing pins but creates none")

	// A missing object fails before SQL insertion, and a subsequent valid
	// event succeeds. This does not qualify failures after SQL commit.
	count := func() int64 {
		n, err := db.GetEngine(ctx).Where("issue_id = ? AND type = ?", issue.ID, issues_model.CommentTypePullRequestPush).Count(new(issues_model.Comment))
		require.NoError(t, err)
		return n
	}
	n := count()
	_, err = pull_service.CreatePushPullComment(ctx, doer, pr, "0123456789012345678901234567890123456789", newSHA)
	require.Error(t, err)
	assert.Equal(t, n, count())
	third, err := pull_service.CreatePushPullComment(ctx, doer, pr, newSHA, oldSHA)
	require.NoError(t, err)
	require.NotNil(t, third)
	assert.Equal(t, n+1, count())

	// The application deletion paths currently leave both legacy and new
	// history pins behind. This is evidence for keeping the port BLOCKED.
	require.NoError(t, issue_service.DeleteComment(ctx, doer, first))
	unittest.AssertNotExistsBean(t, &issues_model.Comment{ID: first.ID})
	require.NoError(t, issue_service.DeleteIssue(ctx, doer, repo, issue))
	unittest.AssertNotExistsBean(t, &issues_model.Issue{ID: issue.ID})
	for _, ref := range pins {
		sha, _, err := git.NewCommand(ctx, "rev-parse", "--verify").AddDynamicArguments(ref).RunStdString(&git.RunOpts{Dir: issue.Repo.RepoPath()})
		require.NoError(t, err)
		assert.Equal(t, oldSHA+"\n", sha)
	}
	_, err = repo.GetCommit(oldSHA)
	require.NoError(t, err, "baseline must not lose the pinned Git history")
}
