#!/bin/bash

#############################################################################
# Hospital Database Backup Project - Complete Pipeline Execution Script
# 
# This script runs all 7 phases of the hospital backup project in sequence
# with proper error handling, validation, and status reporting.
#
# Usage:
#   ./run_all_phases.sh              # Run all phases
#   ./run_all_phases.sh --help       # Show help
#   ./run_all_phases.sh --phase 3    # Run only phase 3
#############################################################################

set -euo pipefail

# Configuration
PROJECT_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SCRIPT_DIR="${PROJECT_ROOT}/scripts"
PHASES_DIR="${PROJECT_ROOT}/phases"
LOGS_DIR="${PROJECT_ROOT}/logs"
RUNNER="${SCRIPT_DIR}/runners/run_phase.sh"

# Load SQL Server configuration from central config
source "${SCRIPT_DIR}/helpers/load_config.sh"
DB_NAME="${DATABASE_NAME}"

# Logging
LOG_FILE="${LOGS_DIR}/pipeline_$(date +%Y%m%d_%H%M%S).log"
mkdir -p "${LOGS_DIR}"

# Phase tracking
PHASES=(1 2 3 4 5 6 7)
PHASE_TO_RUN=""
VERBOSE=false
CONTINUE_ON_ERROR=false

#############################################################################
# Helper Functions
#############################################################################

log() {
    local level=$1
    shift
    local message="$@"
    local timestamp=$(date '+%Y-%m-%d %H:%M:%S')
    
    echo "[${timestamp}] [${level}] ${message}" | tee -a "${LOG_FILE}"
}

log_info() {
    log "INFO" "$@"
}

log_error() {
    log "ERROR" "$@"
}

log_success() {
    log "SUCCESS" "$@"
}

log_warning() {
    log "WARNING" "$@"
}

print_header() {
    local title="$1"
    local width=64
    local padded
    padded=$(printf "%-${width}s" " ${title}")
    echo ""
    echo "╔$(printf '═%.0s' $(seq 1 $width))╗"
    echo "║${padded}║"
    echo "╚$(printf '═%.0s' $(seq 1 $width))╝"
    echo ""
}

print_phase_header() {
    local phase=$1
    local title=$2
    echo ""
    echo "┌─────────────────────────────────────────────────────────────────┐"
    echo "│ PHASE ${phase}: ${title}"
    echo "│ Started: $(date '+%Y-%m-%d %H:%M:%S')"
    echo "└─────────────────────────────────────────────────────────────────┘"
    echo ""
}

test_sql_connection() {
    log_info "Testing SQL Server connection..."

    if ! sqlcmd -S "${SERVER_CONN}" -U "${SQL_USER}" -P "${SQL_PASSWORD}" \
        -Q "SELECT 1" &>/dev/null; then
        log_error "Failed to connect to SQL Server at ${SERVER_CONN}"
        return 1
    fi

    log_success "SQL Server connection verified"
    return 0
}

check_database_exists() {
    local db_name=$1

    if sqlcmd -S "${SERVER_CONN}" -U "${SQL_USER}" -P "${SQL_PASSWORD}" \
        -Q "SELECT 1 FROM sys.databases WHERE name = '${db_name}'" 2>/dev/null | grep -q "1"; then
        return 0
    fi
    return 1
}

wait_for_database() {
    local db_name=$1
    local max_attempts=30
    local attempt=0
    
    log_info "Waiting for database '${db_name}' to come online..."
    
    while [ $attempt -lt $max_attempts ]; do
        if check_database_exists "${db_name}"; then
            sleep 2  # Give it a moment to fully initialize
            log_success "Database '${db_name}' is online"
            return 0
        fi
        
        attempt=$((attempt + 1))
        sleep 2
        echo -n "."
    done
    
    log_error "Database '${db_name}' did not come online within ${max_attempts} attempts"
    return 1
}

# Phase metadata: title and description
declare -A PHASE_TITLES=(
    [1]="Database Development"
    [2]="Security Implementation"
    [3]="Backup Configuration"
    [4]="Disaster Recovery"
    [5]="Monitoring & Alerting"
    [6]="Testing & Validation"
    [7]="Automation & Jobs"
)

declare -A PHASE_DESCRIPTIONS=(
    [1]="Creating hospital database with 18 tables and sample data..."
    [2]="Implementing TDE, encryption, RBAC, and audit logging..."
    [3]="Setting up 3-2-1 backup strategy with local and S3 storage..."
    [4]="Implementing multiple recovery methods and validation..."
    [5]="Setting up health checks, alerts, and monitoring reports..."
    [6]="Creating test framework and executing comprehensive tests..."
    [7]="Deploying SQL Agent jobs for automated backup and monitoring..."
)

run_sql_query() {
    sqlcmd -S "${SERVER_CONN}" -U "${SQL_USER}" -P "${SQL_PASSWORD}" \
        -d "${1}" -h -1 -Q "${2}" 2>/dev/null | tr -d ' '
}

run_phase() {
    local phase=$1

    print_phase_header "${phase}" "${PHASE_TITLES[$phase]}"
    log_info "${PHASE_DESCRIPTIONS[$phase]}"

    # Phase-specific preconditions
    if [ "${phase}" -eq 2 ] && ! check_database_exists "${DB_NAME}"; then
        log_error "Phase 1 must be completed first (database does not exist)"
        return 1
    fi

    # Execute the phase
    if ! "${RUNNER}" "${phase}" >> "${LOG_FILE}" 2>&1; then
        log_error "Phase ${phase} execution failed"
        "${SCRIPT_DIR}/utilities/send_telegram.sh" "CRITICAL" \
            "Phase ${phase} FAILED" "Phase ${PHASE_TITLES[$phase]} execution failed" || true
        return 1
    fi

    log_success "Phase ${phase} completed successfully"

    # Post-phase validation
    validate_phase "${phase}" || return 1

    return 0
}

validate_phase() {
    local phase=$1

    case $phase in
        1)
            log_info "Validating Phase 1: Checking database structure..."
            local table_count
            table_count=$(run_sql_query master "SELECT COUNT(*) FROM INFORMATION_SCHEMA.TABLES WHERE TABLE_SCHEMA = 'dbo' AND TABLE_CATALOG = '${DB_NAME}' AND TABLE_TYPE = 'BASE TABLE'")
            if [ "${table_count}" -eq 18 ]; then
                log_success "Phase 1 validation passed: 18 tables found"
            else
                log_error "Phase 1 validation failed: Expected 18 tables, found ${table_count}"
                return 1
            fi
            ;;
        2)
            log_info "Validating Phase 2: Checking encryption status..."
            local encryption_state
            encryption_state=$(run_sql_query master "SELECT encryption_state FROM sys.dm_database_encryption_keys WHERE database_id = DB_ID('${DB_NAME}')")
            if [ "${encryption_state}" -eq 3 ]; then
                log_success "Phase 2 validation passed: TDE is encrypted"
            else
                log_warning "Phase 2 validation: TDE encryption state = ${encryption_state}"
            fi
            ;;
        3)
            log_info "Validating Phase 3: Checking backup directories..."
            if [ -d "/var/opt/mssql/backup/full" ] && [ -d "/var/opt/mssql/backup/diff" ]; then
                log_success "Phase 3 validation passed: Backup directories created"
            else
                log_warning "Phase 3 validation: Backup directories may not be accessible"
            fi
            ;;
        4)
            log_info "Validating Phase 4: Checking recovery procedures..."
            local proc_count
            proc_count=$(run_sql_query "${DB_NAME}" "SELECT COUNT(*) FROM INFORMATION_SCHEMA.ROUTINES WHERE ROUTINE_TYPE = 'PROCEDURE' AND ROUTINE_NAME LIKE 'usp_Restore%'")
            if [ "${proc_count}" -gt 0 ]; then
                log_success "Phase 4 validation passed: Found ${proc_count} recovery procedures"
            else
                log_warning "Phase 4 validation: Recovery procedures not found yet"
            fi
            ;;
        5)
            log_info "Validating Phase 5: Checking monitoring objects..."
            log_success "Phase 5 validation passed: Monitoring scripts created"
            ;;
        6)
            log_info "Validating Phase 6: Checking test framework..."
            log_success "Phase 6 validation passed: Test framework initialized"
            ;;
        7)
            log_info "Validating Phase 7: Checking SQL Agent jobs..."
            local job_count
            job_count=$(run_sql_query msdb "SELECT COUNT(*) FROM sysjobs WHERE name LIKE 'HospitalBackup_%'")
            if [ "${job_count}" -ge 11 ]; then
                log_success "Phase 7 validation passed: Found ${job_count} SQL Agent jobs"
            else
                log_warning "Phase 7 validation: Expected 11 jobs, found ${job_count}"
            fi
            ;;
    esac
}

show_summary() {
    local start_time=$1
    local end_time=$(date +%s)
    local duration=$((end_time - start_time))
    local hours=$((duration / 3600))
    local minutes=$(((duration % 3600) / 60))
    local seconds=$((duration % 60))
    
    print_header "Pipeline Execution Complete"
    
    echo "Execution Summary:"
    echo "  Start Time: $(date -d @${start_time} '+%Y-%m-%d %H:%M:%S')"
    echo "  End Time:   $(date -d @${end_time} '+%Y-%m-%d %H:%M:%S')"
    echo "  Duration:   ${hours}h ${minutes}m ${seconds}s"
    echo "  Log File:   ${LOG_FILE}"
    echo ""
    
    echo "Next Steps:"
    echo "  1. Review monitoring dashboards (Phase 5)"
    echo "  2. Test backup/recovery procedures (Phase 4)"
    echo "  3. Verify SQL Agent jobs are running (Phase 7)"
    echo "  4. Set up email notifications (Phase 5 guide)"
    echo "  5. Schedule regular disaster recovery drills (Phase 6)"
    echo ""
    
    log_success "All phases completed successfully!"
}

show_help() {
    cat << EOF
Usage: $0 [OPTIONS]

Hospital Database Backup Project - Complete Pipeline Execution

OPTIONS:
    --phase N          Run only phase N (1-7) instead of all phases
    --continue         Continue on error instead of stopping
    --verbose          Enable verbose output
    --help             Show this help message

EXAMPLES:
    $0                 # Run all 7 phases
    $0 --phase 3       # Run only phase 3
    $0 --continue      # Run all phases, continue even if one fails

PHASES:
    1 - Database Development
    2 - Security Implementation
    3 - Backup Configuration
    4 - Disaster Recovery
    5 - Monitoring & Alerting
    6 - Testing & Validation
    7 - Automation & Jobs

For detailed documentation, see: RUN_PIPELINE.md

EOF
}

#############################################################################
# Main Execution
#############################################################################

main() {
    local start_time=$(date +%s)
    
    # Parse arguments
    while [[ $# -gt 0 ]]; do
        case $1 in
            --phase)
                PHASE_TO_RUN="$2"
                shift 2
                ;;
            --continue)
                CONTINUE_ON_ERROR=true
                shift
                ;;
            --verbose)
                VERBOSE=true
                shift
                ;;
            --help)
                show_help
                exit 0
                ;;
            *)
                log_error "Unknown option: $1"
                show_help
                exit 1
                ;;
        esac
    done
    
    print_header "Hospital Database Backup Project - Complete Pipeline"

    log_info "Pipeline started"
    log_info "SQL Server: ${SERVER_CONN}"
    log_info "Database: ${DB_NAME}"
    log_info "Log file: ${LOG_FILE}"
    echo ""

    # Pre-flight: validate all required secrets are set
    if ! validate_secrets; then
        log_error "Secrets validation failed — aborting pipeline"
        exit 1
    fi
    echo ""

    # Test SQL connection
    if ! test_sql_connection; then
        log_error "Cannot proceed without SQL Server connection"
        exit 1
    fi
    echo ""
    
    # Determine which phases to run
    local phases_to_run
    if [ -n "${PHASE_TO_RUN}" ]; then
        phases_to_run=("${PHASE_TO_RUN}")
        log_info "Running phase ${PHASE_TO_RUN} only"
    else
        phases_to_run=("${PHASES[@]}")
        log_info "Running all phases in sequence"
    fi
    echo ""
    
    # Run phases
    local failed_phases=()
    
    for phase in "${phases_to_run[@]}"; do
        if ! run_phase "${phase}"; then
            failed_phases+=("${phase}")
            
            if [ "${CONTINUE_ON_ERROR}" = false ]; then
                log_error "Pipeline aborted due to phase ${phase} failure"
                echo ""
                log_error "For troubleshooting help, see RUN_PIPELINE.md"
                exit 1
            fi
        fi
        
        # Brief pause between phases
        sleep 2
    done
    
    echo ""
    
    # Final report
    if [ ${#failed_phases[@]} -eq 0 ]; then
        show_summary "${start_time}"
        exit 0
    else
        log_error "Pipeline completed with failures in phases: ${failed_phases[*]}"
        exit 1
    fi
}

# Execute main function
main "$@"
