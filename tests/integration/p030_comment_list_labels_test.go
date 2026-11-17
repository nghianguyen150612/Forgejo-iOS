// Copyright 2026 The Forgejo Authors. All rights reserved.
// SPDX-License-Identifier: MIT

package integration

import (
	"testing"

	"forgejo.org/models/issues"
	"forgejo.org/models/unittest"
	"forgejo.org/tests"

	"github.com/stretchr/testify/require"
)

func TestP030CommentListLoadsLabels(t *testing.T) {
	defer tests.PrepareTestEnv(t)()

	// Fixture comment IDs are unrelated to their distinct label IDs, so indexing
	// the batch result by comment ID cannot pass accidentally.
	comment1 := unittest.AssertExistsAndLoadBean(t, &issues.Comment{ID: 2020})
	comment2 := unittest.AssertExistsAndLoadBean(t, &issues.Comment{ID: 2021})
	comments := issues.CommentList{comment1, comment2}

	require.NoError(t, comments.LoadAttributes(t.Context()))
	require.NotNil(t, comment1.Label)
	require.EqualValues(t, 1, comment1.Label.ID)
	require.NotNil(t, comment2.Label)
	require.EqualValues(t, 2, comment2.Label.ID)
}
