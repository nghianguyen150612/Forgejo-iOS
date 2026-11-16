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

	xormlog "code.forgejo.org/xorm/xorm/log"
	"github.com/stretchr/testify/require"
)

type p030ReleaseQueryKey struct{ id int }
type p030ReleaseQueries struct {
	xormlog.ContextLogger
	key   *p030ReleaseQueryKey
	count atomic.Int64
}

// Use the SQL logger rather than adding a context hook: the older XORM hook
// chain does not pass each hook's returned context to the following hook, so
// adding a hook can discard Forgejo's runtime tracing task.
func (*p030ReleaseQueries) IsShowSQL() bool { return true }
func (h *p030ReleaseQueries) BeforeSQL(c xormlog.LogContext) {
	if h.ContextLogger.IsShowSQL() {
		h.ContextLogger.BeforeSQL(c)
	}
}
func (h *p030ReleaseQueries) AfterSQL(c xormlog.LogContext) {
	if c.Ctx.Value(h.key) != nil && strings.HasPrefix(c.SQL, "SELECT ") && strings.Contains(c.SQL, "FROM `repository`") {
		h.count.Add(1)
	}
	if h.ContextLogger.IsShowSQL() {
		h.ContextLogger.AfterSQL(c)
	}
}

// Repository lookups must not grow with the number of releases returned.
// The observer counts only marked synthetic HTTP requests and is restored afterwards.
func TestAPIReleaseListRepositoryQueries(t *testing.T) {
	defer tests.PrepareTestEnv(t)()
	engine, err := db.GetMasterEngine(db.GetEngine(db.DefaultContext))
	require.NoError(t, err)
	original := engine.Logger()
	hook := &p030ReleaseQueries{ContextLogger: original, key: &p030ReleaseQueryKey{1}}
	engine.SetLogger(hook)
	defer engine.SetLogger(original)
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
	require.Positive(t, counts[0], "observer must see the route's repository lookup")
	require.Equal(t, counts[0], counts[1], "extra releases must reuse the authorized repository")
}
