#!/bin/bash
# Run all scripts in a phase

SCRIPT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"
PROJECT_ROOT="$( cd "$SCRIPT_DIR/../.." && pwd )"
# Load configuration from helpers
source "${PROJECT_ROOT}/scripts/helpers/load_config.sh"

if [ -z "$1" ]; then
    echo "Usage: $0 <phase_number>"
    echo "Example: $0 1  (runs phases/phase1-database)"
    exit 1
fi

PHASE=$1
PHASE_DIR="${PROJECT_ROOT}/phases/phase${PHASE}-*"

# Find phase directory
PHASE_PATH=$(ls -d $PHASE_DIR 2>/dev/null | head -1)

if [ -z "$PHASE_PATH" ]; then
    echo -e "${RED}Error: Phase $PHASE not found${NC}"
    exit 1
fi

echo -e "${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo -e "${CYAN}Running Phase $PHASE: $(basename $PHASE_PATH)${NC}"
echo -e "${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo ""

# Execute subdirectories in a specific order
# Default for database setup (Phase 1)
SUBDIRS_ORDER=("schema" "data" "procedures" "functions" "views" "triggers")

# Override order for specific phases when needed
PHASE_NAME="$(basename "$PHASE_PATH")"
if [ "$PHASE_NAME" = "phase2-security" ]; then
    # Security phase requires certificate setup before encryption, then audit and RBAC
    SUBDIRS_ORDER=("certificates" "encryption" "audit" "rbac")
fi

# Phase 3 backups: run S3 setup (credential), then full, differential, log, verification
if [ "$PHASE_NAME" = "phase3-backup" ]; then
    SUBDIRS_ORDER=("s3-setup" "full" "differential" "log" "verification")
fi

for subdir in "${SUBDIRS_ORDER[@]}"; do
    SUBDIR_PATH="${PHASE_PATH}/${subdir}"
    if [ -d "$SUBDIR_PATH" ]; then
        # Find and run SQL files in this subdirectory in sorted order
        # Exclude utility scripts prefixed with 00_ and 99_
        find "$SUBDIR_PATH" -maxdepth 1 -name "*.sql" -type f | sort | grep -vE "/(00_|99_)" | while read sql_file; do
            echo "Executing: $(basename $sql_file)"
            "${PROJECT_ROOT}/scripts/helpers/run_sql.sh" "$sql_file"
            
            if [ $? -ne 0 ]; then
                echo -e "${RED}Phase execution stopped due to error${NC}"
                exit 1
            fi
            echo ""
        done
    fi
done

echo -e "${GREEN}✓ Phase $PHASE completed successfully${NC}"
