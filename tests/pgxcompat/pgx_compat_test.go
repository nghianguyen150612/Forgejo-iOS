package pgxcompat

import (
	"context"
	"crypto/rand"
	"database/sql"
	"encoding/hex"
	"errors"
	"fmt"
	"os"
	"sync"
	"testing"
	"time"

	"github.com/jackc/pgx/v5"
	_ "github.com/jackc/pgx/v5/stdlib"
	"github.com/stretchr/testify/require"
)

// P030_POSTGRES_DSN must point to a disposable local PostgreSQL database. The CI
// job binds its service to loopback and supplies no production credentials.
func TestP030PostgreSQLDriverCompatibility(t *testing.T) {
	dsn := os.Getenv("P030_POSTGRES_DSN")
	if dsn == "" {
		t.Skip("set P030_POSTGRES_DSN to run the isolated PostgreSQL driver regression")
	}

	ctx, cancel := context.WithTimeout(t.Context(), 30*time.Second)
	defer cancel()
	db, err := sql.Open("pgx", dsn)
	require.NoError(t, err)
	defer db.Close()
	db.SetMaxOpenConns(8)
	db.SetMaxIdleConns(8)
	require.NoError(t, db.PingContext(ctx), "driver connection initialization")

	random := make([]byte, 8)
	if _, err = rand.Read(random); err != nil {
		t.Fatal(err)
	}
	table := "p030_driver_" + hex.EncodeToString(random)
	qualified := "public." + table
	_, err = db.ExecContext(ctx, fmt.Sprintf(`CREATE TABLE %s (
		id BIGINT PRIMARY KEY,
		name TEXT NOT NULL,
		payload BYTEA NOT NULL,
		created_at TIMESTAMPTZ NOT NULL
	)`, qualified))
	require.NoError(t, err, "synthetic schema creation")
	t.Cleanup(func() { _, _ = db.ExecContext(context.Background(), "DROP TABLE IF EXISTS "+qualified) })
	_, err = db.ExecContext(ctx, "ALTER TABLE "+qualified+" ADD COLUMN revision INTEGER NOT NULL DEFAULT 1")
	require.NoError(t, err, "synthetic schema migration")

	insert, err := db.PrepareContext(ctx, "INSERT INTO "+qualified+" (id, name, payload, created_at) VALUES ($1, $2, $3, $4)")
	require.NoError(t, err, "prepared statement")
	defer insert.Close()
	timestamp := time.Date(2026, time.November, 17, 12, 30, 0, 123456000, time.UTC)
	arguments := []any{int64(1), "fixture", []byte{0, 1, 2}, timestamp}

	rolledBack, err := db.BeginTx(ctx, nil)
	require.NoError(t, err)
	_, err = rolledBack.StmtContext(ctx, insert).ExecContext(ctx, arguments...)
	require.NoError(t, err, "transactional insert")
	require.NoError(t, rolledBack.Rollback(), "rollback")
	var count int
	require.NoError(t, db.QueryRowContext(ctx, "SELECT count(*) FROM "+qualified).Scan(&count))
	require.Zero(t, count, "rolled-back insert must not persist")

	committed, err := db.BeginTx(ctx, nil)
	require.NoError(t, err)
	_, err = committed.StmtContext(ctx, insert).ExecContext(ctx, arguments...)
	require.NoError(t, err, "committed insert")
	require.NoError(t, committed.Commit(), "commit")

	updated, err := db.ExecContext(ctx, "UPDATE "+qualified+" SET name=$1, revision=revision+1 WHERE id=$2", "updated", int64(1))
	require.NoError(t, err, "update transaction")
	changed, err := updated.RowsAffected()
	require.NoError(t, err)
	require.EqualValues(t, 1, changed)
	var gotName string
	var gotPayload []byte
	var gotTime time.Time
	var revision int
	require.NoError(t, db.QueryRowContext(ctx, "SELECT name, payload, created_at, revision FROM "+qualified+" WHERE id=$1", int64(1)).Scan(&gotName, &gotPayload, &gotTime, &revision))
	require.Equal(t, "updated", gotName)
	require.Equal(t, []byte{0, 1, 2}, gotPayload)
	require.True(t, timestamp.Equal(gotTime))
	require.Equal(t, 2, revision)

	var wait sync.WaitGroup
	for i := 0; i < 16; i++ {
		wait.Add(1)
		go func(value int) {
			defer wait.Done()
			var result int
			if queryErr := db.QueryRowContext(ctx, "SELECT $1::integer", value).Scan(&result); queryErr != nil || result != value {
				t.Errorf("concurrent PostgreSQL query %d: result=%d error=%v", value, result, queryErr)
			}
		}(i)
	}
	wait.Wait()

	pgxConn, err := pgx.Connect(ctx, dsn)
	require.NoError(t, err, "native pgx type encoding connection")
	var arrayResult []int32
	require.NoError(t, pgxConn.QueryRow(ctx, "SELECT $1::integer[]", []int32{2, 4, 8}).Scan(&arrayResult))
	require.Equal(t, []int32{2, 4, 8}, arrayResult, "PostgreSQL array encoding")
	require.NoError(t, pgxConn.Close(ctx))

	deadline, stop := context.WithTimeout(ctx, 150*time.Millisecond)
	defer stop()
	err = db.QueryRowContext(deadline, "SELECT pg_sleep(5)").Scan(new(any))
	require.Error(t, err, "query cancellation should interrupt pg_sleep")
	require.True(t, errors.Is(err, context.DeadlineExceeded) || errors.Is(deadline.Err(), context.DeadlineExceeded), "cancellation error: %v", err)
	var recovered int
	require.NoError(t, db.QueryRowContext(ctx, "SELECT 1").Scan(&recovered), "connection pool recovers after cancellation")
	require.Equal(t, 1, recovered)

	_, err = db.ExecContext(ctx, "DELETE FROM "+qualified+" WHERE id=$1", int64(1))
	require.NoError(t, err, "delete transaction")
	require.NoError(t, db.QueryRowContext(ctx, "SELECT count(*) FROM "+qualified).Scan(&count))
	require.Zero(t, count)

	config, err := pgx.ParseConfig(dsn)
	require.NoError(t, err)
	config.DefaultQueryExecMode = pgx.QueryExecModeSimpleProtocol
	simpleConn, err := pgx.ConnectConfig(ctx, config)
	require.NoError(t, err, "simple protocol connection")
	batch := &pgx.Batch{}
	batch.Queue("SELECT 'first'::text --")
	batch.Queue("SELECT $1::text", "second")
	results := simpleConn.SendBatch(ctx, batch)
	var first string
	var second string
	require.NoError(t, results.QueryRow().Scan(&first))
	require.NoError(t, results.QueryRow().Scan(&second), "a trailing SQL comment must not swallow the next batch query")
	require.NoError(t, results.Close())
	require.NoError(t, simpleConn.Close(ctx))
	require.Equal(t, "first", first)
	require.Equal(t, "second", second)
}
