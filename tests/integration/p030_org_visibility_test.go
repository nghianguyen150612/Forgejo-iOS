// Copyright 2026 The Forgejo Authors. All rights reserved.
// SPDX-License-Identifier: MIT

package integration

import (
	"net/http"
	"testing"

	"forgejo.org/models/organization"
	"forgejo.org/models/unittest"
	"forgejo.org/modules/structs"
	"forgejo.org/tests"
	"forgejo.org/tests/forgery"

	"github.com/stretchr/testify/require"
)

// Reload from SQLite so this exercises persisted permissions, not just options.
func TestP030OrganisationVisibility(t *testing.T) {
	defer tests.PrepareTestEnv(t)()
	owner := forgery.CreateUser(t, nil)
	for _, visibility := range []structs.VisibleType{structs.VisibleTypePublic, structs.VisibleTypeLimited, structs.VisibleTypePrivate} {
		t.Run(visibility.String(), func(t *testing.T) {
			org := forgery.CreateOrganisation(t, owner, &forgery.CreateOrganisationOptions{Visibility: visibility})
			loaded := unittest.AssertExistsAndLoadBean(t, &organization.Organization{ID: org.ID})
			require.Equal(t, visibility, loaded.Visibility)
			status := http.StatusNotFound
			if visibility == structs.VisibleTypePublic {
				status = http.StatusOK
			}
			MakeRequest(t, NewRequest(t, http.MethodGet, "/api/v1/orgs/"+org.Name), status)
			session := loginUser(t, owner.Name)
			session.MakeRequest(t, NewRequest(t, http.MethodGet, "/"+org.Name), http.StatusOK)
		})
	}
	defaultOrg := forgery.CreateOrganisation(t, nil, nil)
	loaded := unittest.AssertExistsAndLoadBean(t, &organization.Organization{ID: defaultOrg.ID})
	require.Equal(t, structs.VisibleTypePublic, loaded.Visibility)
}
