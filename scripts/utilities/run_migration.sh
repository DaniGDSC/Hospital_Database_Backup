#!/usr/bin/env bash
set -euo pipefail

# Safe schema migration runner
# Checks idempotency, records checksum, logs to SchemaVersionHistory
# Usage: ./scripts/utilities/run_migration.sh <migration_file.sql> <version> <description>

SCRIPT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"
source "${SCRIPT_DIR}/../helpers/load_config.sh"

MIGRATION_FILE="${1:-}"
VERSION="${2:-}"
DESCRIPTION="${3:-}"

if [ -z "$MIGRATION_FILE" ] || [ -z "$VERSION" ] || [ -z "$DESCRIPTION" ]; then
    echo "Usage: $0 <file.sql> <version> <description>"
    echo "  e.g.: $0 migrations/V002__add_columns.sql V002 'Add audit columns'"
    exit 1
fi

if [ ! -f "$MIGRATION_FILE" ]; then
    echo "ERROR: Migration file not found: $MIGRATION_FILE"
    exit 1
fi

echo "=== Schema Migration ==="
echo "File:        ${MIGRATION_FILE}"
echo "Version:     ${VERSION}"
echo "Description: ${DESCRIPTION}"
echo ""

# Check if already applied
ALREADY_APPLIED=$(sqlcmd -S "$SERVER_CONN" -U "$SQL_USER" -P "$SQL_PASSWORD" -C \
    -d HospitalBackupDemo -h -1 \
    -Q "SELECT COUNT(*) FROM dbo.SchemaVersionHistory WHERE Version='${VERSION}' AND Status='SUCCESS'" \
    2>/dev/null | tr -d ' ')

if [ "$ALREADY_APPLIED" = "1" ]; then
    echo "SKIP: Migration ${VERSION} already applied"
    exit 0
fi

# Calculate checksum
CHECKSUM=$(sha256sum "$MIGRATION_FILE" | awk '{print $1}')
echo "Checksum: ${CHECKSUM}"

# Execute migration
echo "Executing migration..."
START_MS=$(date +%s%N)

if sqlcmd -S "$SERVER_CONN" -U "$SQL_USER" -P "$SQL_PASSWORD" -C \
    -d HospitalBackupDemo \
    -i "$MIGRATION_FILE" 2>&1; then

    END_MS=$(date +%s%N)
    DURATION_MS=$(( (END_MS - START_MS) / 1000000 ))

    # Record success
    sqlcmd -S "$SERVER_CONN" -U "$SQL_USER" -P "$SQL_PASSWORD" -C \
        -d HospitalBackupDemo \
        -Q "INSERT INTO dbo.SchemaVersionHistory (Version, Description, ExecutionMs, Checksum, Status, RollbackScript) VALUES ('${VERSION}', '${DESCRIPTION}', ${DURATION_MS}, '${CHECKSUM}', 'SUCCESS', '${MIGRATION_FILE%.sql}__rollback.sql')" \
        2>/dev/null

    echo ""
    echo "✓ Migration ${VERSION} applied successfully (${DURATION_MS}ms)"
else
    END_MS=$(date +%s%N)
    DURATION_MS=$(( (END_MS - START_MS) / 1000000 ))

    # Record failure
    sqlcmd -S "$SERVER_CONN" -U "$SQL_USER" -P "$SQL_PASSWORD" -C \
        -d HospitalBackupDemo \
        -Q "INSERT INTO dbo.SchemaVersionHistory (Version, Description, ExecutionMs, Checksum, Status, ErrorMessage) VALUES ('${VERSION}', '${DESCRIPTION}', ${DURATION_MS}, '${CHECKSUM}', 'FAILED', 'See execution log')" \
        2>/dev/null

    echo ""
    echo "✗ Migration ${VERSION} FAILED (${DURATION_MS}ms)"
    echo "  Review error output above, then fix and retry"
    exit 1
fi
