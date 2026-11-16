// Copyright 2026 The Forgejo Authors. All rights reserved.
// SPDX-License-Identifier: MIT

package integration

import (
	"context"
	"fmt"
	"net/http"
	"strings"
	"sync/atomic"
	"testing"

	"forgejo.org/models/db"
	api "forgejo.org/modules/structs"
	"forgejo.org/tests"

	"code.forgejo.org/xorm/xorm/contexts"
	"github.com/stretchr/testify/require"
)

type p030ReleaseQueryKey struct{ id int }
type p030ReleaseQueries struct {
	key   *p030ReleaseQueryKey
	count atomic.Int64
}

func (h *p030ReleaseQueries) BeforeProcess(c *contexts.ContextHook) (context.Context, error) {
	if c.Ctx.Value(h.key) != nil && strings.HasPrefix(c.SQL, "SELECT ") && strings.Contains(c.SQL, "FROM `repository`") {
		h.count.Add(1)
	}
	return c.Ctx, nil
}
func (*p030ReleaseQueries) AfterProcess(*contexts.ContextHook) error { return nil }

// Repository lookups must not grow with the number of releases returned.
// The hook is inert outside these explicitly marked synthetic HTTP requests.
func TestAPIReleaseListRepositoryQueries(t *testing.T) {
	defer tests.PrepareTestEnv(t)()
	engine, err := db.GetMasterEngine(db.GetEngine(t.Context()))
	require.NoError(t, err)
	hook := &p030ReleaseQueries{key: &p030ReleaseQueryKey{1}}
	engine.AddHook(hook)
	counts := make([]int64, 0, 2)
	for _, limit := range []int{1, 2} {
		hook.count.Store(0)
		req := NewRequest(t, http.MethodGet, fmt.Sprintf("/api/v1/repos/user2/repo1/releases?limit=%d", limit))
		req.Request = req.Request.WithContext(context.WithValue(req.Context(), hook.key, true))
		resp := MakeRequest(t, req, http.StatusOK)
		var releases []*api.Release
		DecodeJSON(t, resp, &releases)
		require.Len(t, releases, limit)
		counts = append(counts, hook.count.Load())
	}
	require.Positive(t, counts[0], "hook must observe the route's repository lookup")
	require.Equal(t, counts[0], counts[1], "extra releases must reuse the authorized repository")
}
