# Pipeline Architecture & Execution Model

## Overview

The Hospital Database Backup Project uses a **phase-based execution model** where 7 interdependent phases build upon each other to create a complete backup and disaster recovery solution.

```
┌─────────────────────────────────────────────────────────────────────────────┐
│                    HOSPITAL BACKUP PROJECT PIPELINE                         │
├─────────────────────────────────────────────────────────────────────────────┤
│                                                                             │
│  Phase 1    Phase 2    Phase 3    Phase 4    Phase 5    Phase 6   Phase 7  │
│  ──────     ──────     ──────     ──────     ──────     ──────    ──────   │
│ Database → Security → Backup  → Recovery → Monitor  → Testing → Automate  │
│ (Schema)   (Encrypt) (Strategy) (Methods)  (Alerts)   (Validation)(Jobs)  │
│                                                                             │
│   ✓ 18 Tables    ✓ TDE       ✓ 3-2-1      ✓ 5 Methods  ✓ Alerts   ✓ Tests  │
│   ✓ 153 Records  ✓ RBAC      ✓ Local+S3   ✓ RTO<1min   ✓ Health   ✓ 11 Jobs│
│                  ✓ Audit     ✓ Backup     ✓ RPO<1min   ✓ Reports  ✓ Running│
│                                                                             │
└─────────────────────────────────────────────────────────────────────────────┘
```

## Execution Models

### Model 1: Complete Pipeline (Recommended)
```bash
./run_all_phases.sh
```
- Runs all 7 phases sequentially
- ~2 hours total execution time
- Single command, end-to-end automation
- Proper validation between phases
- Comprehensive logging

### Model 2: Individual Phase Execution
```bash
./scripts/runners/run_phase.sh 3
```
- Run any phase independently
- Useful for testing or re-running failed phases
- Requires prior phases to be completed
- Takes 10-30 minutes per phase

### Model 3: Selective Phase Execution
```bash
./run_all_phases.sh --phase 5
```
- Run specific phase with full pipeline context
- Includes validation and error handling
- Good for targeted fixes

## Phase Dependencies

```
Phase 1 (Database)
    ↓
Phase 2 (Security) ← Requires Phase 1
    ↓
Phase 3 (Backup) ← Requires Phase 1 & 2
    ↓
Phase 4 (Recovery) ← Requires Phase 1, 2, & 3
    ↓
Phase 5 (Monitoring) ← Requires Phase 1-4
    ↓
Phase 6 (Testing) ← Requires Phase 1-5
    ↓
Phase 7 (Automation) ← Requires Phase 1-6
```

Each phase has prerequisites and builds on previous work. Running phases out of order will fail.

## Detailed Phase Architecture

### Phase 1: Database Development
**Inputs**: SQL Server instance running  
**Outputs**: HospitalBackupDemo database with 18 tables  
**Subdirectories** (execution order):
1. `schema/` → Create database and tables
2. `data/` → Insert sample data (150+ records)
3. `procedures/` → Create stored procedures
4. `functions/` → Create functions
5. `views/` → Create views
6. `triggers/` → Create triggers

**Validation**: Verify 18 tables exist

### Phase 2: Security Implementation
**Inputs**: HospitalBackupDemo database from Phase 1  
**Outputs**: Encrypted database with RBAC configured  
**Subdirectories** (execution order):
1. `certificates/` → Create master key and certificates
2. `encryption/` → Enable TDE, create column encryption
3. `rbac/` → Create 5 security roles with permissions
4. `audit/` → Configure SQL audit logging

**Validation**: Verify encryption_state = 3 (encrypted)

### Phase 3: Backup Configuration
**Inputs**: Encrypted database from Phase 2  
**Outputs**: Local and S3 backup infrastructure  
**Subdirectories** (execution order):
1. `s3-setup/` → Configure S3 credentials and buckets
2. `full/` → Full backup procedures (weekly)
3. `differential/` → Differential backup (daily)
4. `log/` → Log backup procedures (hourly)
5. `verification/` → Backup verification scripts

**Validation**: Verify /var/opt/mssql/backup directories exist

### Phase 4: Disaster Recovery
**Inputs**: Backups from Phase 3  
**Outputs**: 5 recovery methods validated  
**Subdirectories** (execution order):
1. `full-restore/` → Full database restore
2. `from-s3/` → Restore from S3 backup
3. `point-in-time/` → PITR to specific point
4. `cloud-base-with-local-chain/` → Hybrid restore
5. `testing/` → Recovery validation
6. `drp/` → Disaster recovery procedures

**Validation**: Verify recovery procedures exist

### Phase 5: Monitoring & Alerting
**Inputs**: Running database from Phase 4  
**Outputs**: Monitoring framework and alert procedures  
**Subdirectories** (execution order):
1. `health-checks/` → Database health monitoring
2. `alerts/` → Backup failure, RPO/RTO, disk space alerts
3. `reports/` → Daily/weekly monitoring reports
4. `dashboards/` → Dashboard configurations (manual setup)

**Validation**: Verify alert procedures created

### Phase 6: Testing & Validation
**Inputs**: All components from Phase 5  
**Outputs**: Test execution results and metrics  
**Subdirectories** (execution order):
1. `unit-tests/` → Table structure and data type validation
2. `integration-tests/` → Cross-table relationship testing
3. `scenarios/` → Disaster scenario execution
4. `security-tests/` → RBAC, encryption, audit validation
5. `performance-tests/` → Load/stress testing

**Validation**: Verify test metrics tables created

### Phase 7: Automation & Jobs
**Inputs**: All components from Phase 6  
**Outputs**: 11 SQL Agent jobs deployed and running  
**Files** (execution order):
1. `00_job_daily_differential_backup.sql`
2. `00_job_hourly_log_backup.sql`
3. `00_job_weekly_full_backup.sql`
4. `01_job_daily_backup_verify.sql`
5. `02_job_weekly_recovery_drill.sql`
6. `03_job_configure_alerts.sql`
7. `04_job_hourly_log_backup_check.sql`
8. `05_job_daily_backup_alert.sql`
9. `06_job_monthly_encryption_check.sql`
10. `07_job_disaster_detection.sql`
11. `08_job_auto_recovery.sql`

**Deployment**: `deploy_jobs.sh` creates all jobs with schedules  
**Validation**: Verify 11 jobs in msdb.dbo.sysjobs

## Execution Framework

### run_phase.sh (Single Phase Runner)
Located at: `scripts/runners/run_phase.sh`

**Function**: Executes subdirectories of a phase in dependency order

**Logic**:
```
For each subdirectory in phase folder (in alphabetical order):
  1. Check if subdirectory exists
  2. For each .sql file in subdirectory:
     - Execute with sqlcmd
     - Capture output and errors
     - Log results
  3. Report completion or error
```

**Error Handling**: Stops on first error (fail-fast)

### run_all_phases.sh (Master Pipeline)
Located at: `run_all_phases.sh` (project root)

**Function**: Orchestrates execution of all 7 phases with:
- Connection validation
- Phase dependency checking
- Post-phase validation
- Error recovery options
- Comprehensive logging
- Summary reporting

**Logic**:
```
1. Parse command-line arguments
2. Test SQL Server connection
3. For each phase (1-7):
   a. Run phase via run_phase.sh
   b. Validate phase completion
   c. Continue or abort based on --continue flag
   d. Log results
4. Generate execution summary
```

**Options**:
- `--phase N` → Run only phase N
- `--continue` → Continue on error
- `--verbose` → Enable verbose output
- `--help` → Show help

## Execution Timeline

```
Phase 1: Database
├─ schema/01_create_database.sql (1 min)
├─ schema/02_create_tables.sql (2 min)
├─ data/01-12_insert_*.sql (5 min)
├─ procedures/* (1 min)
└─ triggers, views, functions (1 min)
Total: ~10 min

Phase 2: Security
├─ certificates/ (2 min)
├─ encryption/ (3 min)
├─ rbac/ (3 min)
└─ audit/ (2 min)
Total: ~10 min

Phase 3: Backup
├─ s3-setup/ (3 min)
├─ full/ (3 min)
├─ differential/ (3 min)
├─ log/ (3 min)
└─ verification/ (3 min)
Total: ~15 min

Phase 4: Recovery
├─ full-restore/ (2 min)
├─ from-s3/ (2 min)
├─ point-in-time/ (2 min)
├─ cloud-base/ (2 min)
├─ testing/ (1 min)
└─ drp/ (1 min)
Total: ~10 min

Phase 5: Monitoring
├─ health-checks/ (2 min)
├─ alerts/ (5 min)
├─ reports/ (2 min)
└─ dashboards/ (1 min)
Total: ~10 min

Phase 6: Testing
├─ unit-tests/ (3 min)
├─ integration-tests/ (5 min)
├─ scenarios/ (8 min)
├─ security-tests/ (2 min)
└─ performance-tests/ (2 min)
Total: ~20 min

Phase 7: Automation
├─ deploy_jobs.sh (3 min)
├─ verify_jobs.sql (2 min)
└─ job verification (2 min)
Total: ~7 min

=============================
TOTAL PIPELINE TIME: ~92 min
=============================
```

## Data Flow

```
┌─────────────────┐
│   SQL Server    │
│   127.0.0.1     │
│   Port 14333    │
└────────┬────────┘
         │
         ├─ Phase 1: Creates HospitalBackupDemo database
         │           └─ 18 tables with 153+ records
         │
         ├─ Phase 2: Enables security
         │           ├─ TDE encryption (AES-256)
         │           └─ Column encryption (symmetric keys)
         │
         ├─ Phase 3: Configures backups
         │           ├─ Local: full + diff + log
         │           └─ AWS S3: full + diff (Object Lock)
         │
         ├─ Phase 4: Validates recovery
         │           ├─ Full restore
         │           ├─ PITR (point-in-time)
         │           └─ S3 restore
         │
         ├─ Phase 5: Monitors continuously
         │           ├─ Health checks (hourly)
         │           ├─ Alerts (backup, disk, RPO/RTO)
         │           └─ Reports (daily/weekly)
         │
         ├─ Phase 6: Executes tests
         │           ├─ Unit tests (table structure)
         │           ├─ Integration tests (relationships)
         │           ├─ Disaster recovery tests (RTO/RPO)
         │           ├─ Security tests (RBAC, encryption)
         │           └─ Performance tests (load/stress)
         │
         └─ Phase 7: Deploys automation
                     ├─ 11 SQL Agent jobs
                     ├─ Backup job schedules
                     └─ Monitoring job schedules
```

## Error Handling & Recovery

### Phase Failure Scenarios

**Scenario 1: Connection Lost During Phase**
```bash
# Rerun failed phase
./run_all_phases.sh --phase 3

# Or continue from that phase
./run_all_phases.sh --phase 3 --continue
```

**Scenario 2: Partial Phase Execution**
```bash
# Run phase 3 only and see logs
./scripts/runners/run_phase.sh 3

# Check logs for errors
tail -100 logs/phase3/error.log
```

**Scenario 3: Complete Pipeline Failure**
```bash
# Check pipeline log
tail -200 logs/pipeline_*.log

# Run all phases with error tolerance
./run_all_phases.sh --continue
```

### Validation & Cleanup

**Between-phase validation**:
- Phase 1 → Verify 18 tables
- Phase 2 → Verify encryption_state = 3
- Phase 3 → Verify backup directories
- Phase 4 → Verify recovery procedures
- Phase 5 → Verify alert procedures
- Phase 6 → Verify test tables
- Phase 7 → Verify 11 jobs

**Cleanup** (if needed):
```sql
-- Drop database and start over
DROP DATABASE HospitalBackupDemo;

-- Then rerun from Phase 1
./run_all_phases.sh --phase 1
```

## Logging & Monitoring

### Pipeline Logs
```
logs/
├─ pipeline_20260109_143000.log   # Master pipeline log
├─ phase1/
│  └─ execution.log
├─ phase2/
│  ├─ execution.log
│  └─ error.log
└─ ...
```

### Viewing Logs
```bash
# Real-time pipeline
tail -f logs/pipeline_*.log

# Phase-specific logs
tail -50 logs/phase3/execution.log

# Error logs
tail -100 logs/phase*/error.log
```

### Log Levels
- `INFO` - General information
- `SUCCESS` - Phase/task completed
- `WARNING` - Non-blocking issue
- `ERROR` - Blocking issue, phase failed

## Performance Benchmarks

Expected execution times (with modern hardware):

| Phase | Database Size | Execution Time |
|-------|---------------|----------------|
| 1 | ~50 MB | 8-12 min |
| 2 | ~55 MB | 8-12 min |
| 3 | ~55 MB | 12-18 min |
| 4 | ~300 MB | 8-12 min |
| 5 | ~300 MB | 8-12 min |
| 6 | ~350 MB | 15-25 min |
| 7 | ~350 MB | 10-15 min |
| **TOTAL** | **~300 MB** | **~90-120 min** |

## Environment Configuration

### Default Settings
```bash
SQL_HOST=127.0.0.1
SQL_PORT=14333
SQL_USER=SA
SQL_PASSWORD=Daniel@2410
DB_NAME=HospitalBackupDemo
```

### Custom Configuration
```bash
# Set environment variables
export SQL_HOST=192.168.1.100
export SQL_PORT=1433
export SQL_USER=sa
export SQL_PASSWORD=MyPassword

# Run pipeline
./run_all_phases.sh
```

### Configuration File
```bash
source config/project.conf
./run_all_phases.sh
```

## Troubleshooting Pipeline

### Pipeline Won't Start
```bash
# Check SQL Server
docker ps | grep mssql
sqlcmd -S 127.0.0.1,14333 -U SA -P 'Daniel@2410' -Q "SELECT 1"

# Check script permissions
ls -l run_all_phases.sh  # Should have x (executable)
chmod +x run_all_phases.sh
```

### Phase Fails Silently
```bash
# Run with verbose output
./run_all_phases.sh --verbose

# Run phase directly
./scripts/runners/run_phase.sh 3

# Check specific log file
cat logs/phase3/execution.log
```

### Partial Phase Completion
```bash
# Check which files succeeded
ls -l phases/phase3/full/

# Continue from specific point
./run_all_phases.sh --phase 3 --continue
```

## Next Steps After Pipeline

1. **Verify Backups**: Check `/var/opt/mssql/backup/full/` for backup files
2. **Test Recovery**: Run Phase 4 recovery procedures manually
3. **Enable Monitoring**: Configure email alerts in Phase 5
4. **Schedule Jobs**: Verify SQL Agent jobs are scheduled
5. **Regular Testing**: Run Phase 6 tests monthly
6. **Review Reports**: Check Phase 5 monitoring reports weekly

---

For detailed information on individual phases, see the respective phase README files.
