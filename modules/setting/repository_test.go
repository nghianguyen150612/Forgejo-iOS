// Copyright 2025 The Forgejo Authors. All rights reserved.
// SPDX-License-Identifier: GPL-3.0-or-later

package setting

import (
	"fmt"
	"maps"
	"os"
	"path/filepath"
	"testing"

	"github.com/stretchr/testify/assert"
	"github.com/stretchr/testify/require"
	"golang.org/x/crypto/ssh"
)

func TestSSHInstanceKey(t *testing.T) {
	sshSigningKeyPath, err := filepath.Abs("../../tests/integration/ssh-signing-key.pub")
	require.NoError(t, err)

	originalRepository, originalSSHKey := Repository, SSHInstanceKey
	originalRepoRoot, originalArchive, originalScript := RepoRootPath, RepoArchive, ScriptType
	Repository.DetectedCharsetScore = maps.Clone(Repository.DetectedCharsetScore)
	t.Cleanup(func() {
		Repository, SSHInstanceKey = originalRepository, originalSSHKey
		RepoRootPath, RepoArchive, ScriptType = originalRepoRoot, originalArchive, originalScript
	})

	load := func(t *testing.T, config string) error {
		t.Helper()
		Repository.Signing = originalRepository.Signing
		cfg, err := NewConfigProviderFromData("[repository.signing]\n" + config)
		require.NoError(t, err)
		return loadRepositoryFrom(cfg)
	}

	invalidKeyPath := filepath.Join(t.TempDir(), "invalid.pub")
	require.NoError(t, os.WriteFile(invalidKeyPath, []byte("invalid public key"), 0o600))
	for _, tc := range []struct {
		name, keyConfig, wantError string
	}{
		{"omitted", "", "missing [repository.signing].SIGNING_KEY"},
		{"empty", "SIGNING_KEY =\n", "missing [repository.signing].SIGNING_KEY"},
		{"default", "SIGNING_KEY = default\n", "missing [repository.signing].SIGNING_KEY"},
		{"none", "SIGNING_KEY = none\n", "missing [repository.signing].SIGNING_KEY"},
		{"missing file", "SIGNING_KEY = " + invalidKeyPath + ".missing\n", "reading SSH signing key"},
		{"invalid file", "SIGNING_KEY = " + invalidKeyPath + "\n", "parsing SSH signing key"},
	} {
		t.Run(tc.name, func(t *testing.T) {
			require.ErrorContains(t, load(t, "FORMAT = ssh\n"+tc.keyConfig), tc.wantError)
			assert.Nil(t, SSHInstanceKey)
		})
	}

	require.NoError(t, load(t, fmt.Sprintf("FORMAT = ssh\nSIGNING_KEY = %s\n", sshSigningKeyPath)))
	require.NotNil(t, SSHInstanceKey)
	assert.Equal(t, "ssh-ed25519", SSHInstanceKey.Type())
	assert.EqualValues(t, "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIFeRC8GfFyXtiy0f1E7hLv77BXW7e68tFvIcs8/29YqH\n", ssh.MarshalAuthorizedKey(SSHInstanceKey))

	require.NoError(t, load(t, "FORMAT = openpgp\nSIGNING_KEY = none\n"))
	assert.Nil(t, SSHInstanceKey)
}
