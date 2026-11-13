// Copyright 2026 The Forgejo Authors. All rights reserved.
// SPDX-License-Identifier: GPL-3.0-or-later

package integration

import (
	"fmt"
	"testing"

	"forgejo.org/models/organization"
	"forgejo.org/models/perm"
	unit_model "forgejo.org/models/unit"
	"forgejo.org/tests"
	"forgejo.org/tests/forgery"

	"github.com/stretchr/testify/require"
)

func TestForgeryCreateTeamUnitPersistence(t *testing.T) {
	defer tests.PrepareTestEnv(t)()

	owner := forgery.CreateUser(t, nil)
	org := forgery.CreateOrganisation(t, owner)
	explicitUnits := []*organization.TeamUnit{
		{Type: unit_model.TypeCode, AccessMode: perm.AccessModeWrite},
		{Type: unit_model.TypePullRequests, AccessMode: perm.AccessModeRead},
	}

	for i := range 2 {
		team := forgery.CreateTeam(t, org, &forgery.CreateTeamOptions{
			Name:  fmt.Sprintf("custom-units-%d", i),
			Mode:  perm.AccessModeAdmin,
			Units: explicitUnits,
		})
		require.NoError(t, team.LoadUnits(t.Context()))
		require.Len(t, team.Units, len(explicitUnits))
		require.Equal(t, perm.AccessModeWrite, team.UnitAccessMode(t.Context(), unit_model.TypeCode))
		require.Equal(t, perm.AccessModeRead, team.UnitAccessMode(t.Context(), unit_model.TypePullRequests))
		require.Equal(t, perm.AccessModeNone, team.UnitAccessMode(t.Context(), unit_model.TypeIssues))
	}

	// Callers that do not select units keep the fixture's historical defaults.
	defaultTeam := forgery.CreateTeam(t, org, nil)
	require.NoError(t, defaultTeam.LoadUnits(t.Context()))
	require.Len(t, defaultTeam.Units, len(unit_model.AllRepoUnitTypes))
	require.Equal(t, perm.AccessModeRead, defaultTeam.UnitAccessMode(t.Context(), unit_model.TypeCode))
}
