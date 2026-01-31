# Hospital Database Backup Project - Pipeline Execution Guide

## 📋 Table of Contents
1. [Quick Start](#quick-start)
2. [Execution Options](#execution-options)
3. [Phase Overview](#phase-overview)
4. [Verification](#verification)
5. [Troubleshooting](#troubleshooting)

---

## Quick Start

### Fastest Way to Run Everything
```bash
cd ~/hospital-db-backup-project
chmod +x run_all_phases.sh
./run_all_phases.sh
```

**What you get** (in ~2 hours):
- ✅ Complete hospital database (18 tables, 150+ records)
- ✅ Enterprise encryption (TDE + column encryption)
- ✅ 3-2-1 backup strategy (local + S3 with WORM protection)
- ✅ 5 disaster recovery methods (tested RTO < 1 min)
- ✅ Real-time monitoring & alerts
- ✅ Comprehensive test framework
- ✅ 11 production SQL Agent jobs (automated backups, monitoring, recovery)

---

## Execution Options

### Option 1: Run All Phases (Master Pipeline)

```bash
./run_all_phases.sh
```

**What it does**:
- Executes all 7 phases in sequence
- Validates each phase before proceeding
- Provides comprehensive logging
- Reports total execution time

**Output**:
```
╔════════════════════════════════════════════════════════════════╗
║   Hospital Database Backup Project - Complete Pipeline        ║
╚════════════════════════════════════════════════════════════════╝

PHASE 1: Database Development...
✓ Phase 1 completed

PHASE 2: Security Implementation...
✓ Phase 2 completed

... (phases 3-7)

╔════════════════════════════════════════════════════════════════╗
║          All Phases Completed Successfully!                   ║
╚════════════════════════════════════════════════════════════════╝

Execution Summary:
  Start Time: 2026-01-09 10:00:00
  End Time:   2026-01-09 12:15:00
  Duration:   2h 15m 00s
```

**When to use**: Initial setup, production deployment

---

### Option 2: Run Specific Phase Only

```bash
./run_all_phases.sh --phase 3
```

**What it does**:
- Runs only Phase 3 (Backup Configuration)
- Validates prerequisites (Phase 1-2 must exist)
- Full logging and error handling

**Replace 3 with**:
- `1` = Database Development
- `2` = Security Implementation
- `3` = Backup Configuration
- `4` = Disaster Recovery
- `5` = Monitoring & Alerting
- `6` = Testing & Validation
- `7` = Automation & Jobs

**When to use**: Rerun failed phase, test specific phase, selective deployment

---

### Option 3: Run Phase via Phase Runner

```bash
./scripts/runners/run_phase.sh 3
```

**What it does**:
- Direct phase execution (no master pipeline wrapper)
- Executes subdirectories in dependency order
- Basic error handling

**Advantages**:
- Faster for single phases
- Minimal overhead
- Direct output to console

**Disadvantages**:
- No cross-phase validation
- Manual error handling
- Limited logging

**When to use**: Debugging, manual execution, scripting individual phases

---

### Option 4: Manual Step-by-Step Execution

```bash
./scripts/runners/run_phase.sh 1  # Database
./scripts/runners/run_phase.sh 2  # Security
./scripts/runners/run_phase.sh 3  # Backup
./scripts/runners/run_phase.sh 4  # Recovery
./scripts/runners/run_phase.sh 5  # Monitoring
./scripts/runners/run_phase.sh 6  # Testing
./scripts/runners/run_phase.sh 7  # Automation
```

**What it does**:
- Gives full control over execution timing
- Can insert manual testing between phases
- Ability to review results before proceeding

**When to use**: Learning, detailed testing, phase-by-phase validation

---

### Option 5: Continue on Errors

```bash
./run_all_phases.sh --continue
```

**What it does**:
- Runs all phases
- If a phase fails, continues to next phase
- Logs all failures
- Reports all failed phases at end

**Example output**:
```
Phase 3 execution failed
Continuing to Phase 4...

Phase 5 execution failed
Continuing to Phase 6...

Pipeline completed with failures in phases: 3 5
```

**When to use**: Development/testing, identifying multiple issues

---

### Option 6: Verbose Execution

```bash
./run_all_phases.sh --verbose
```

**What it does**:
- Shows detailed output for each step
- More granular progress reporting
- Helpful for debugging

**When to use**: Troubleshooting, detailed investigation

---

## Phase Overview

### Phase 1: Database Development
**Duration**: 10-15 minutes  
**Purpose**: Create database schema and sample data  
**Key Files**: 
- `phases/phase1-database/schema/` → Table definitions
- `phases/phase1-database/data/` → Insert sample data
- `phases/phase1-database/procedures/` → Stored procedures

**Success Criteria**:
- ✅ HospitalBackupDemo database created
- ✅ 18 tables with structure
- ✅ 150+ sample records inserted
- ✅ Stored procedures, views, functions, triggers created

**Validation**:
```bash
sqlcmd -S 127.0.0.1,14333 -U SA -P 'Daniel@2410' \
  -Q "SELECT COUNT(*) FROM INFORMATION_SCHEMA.TABLES WHERE TABLE_CATALOG='HospitalBackupDemo';"
# Expected: 18
```

---

### Phase 2: Security Implementation
**Duration**: 10-15 minutes  
**Purpose**: Implement encryption and access control  
**Key Files**:
- `phases/phase2-security/certificates/` → Master key & TDE
- `phases/phase2-security/encryption/` → Column encryption
- `phases/phase2-security/rbac/` → 5 security roles
- `phases/phase2-security/audit/` → SQL audit logging

**Success Criteria**:
- ✅ Transparent Data Encryption (TDE) enabled
- ✅ Column-level encryption configured
- ✅ 5 RBAC roles created (app_readwrite, app_readonly, app_billing, app_security_admin, app_auditor)
- ✅ SQL Server audit configured

**Validation**:
```bash
sqlcmd -S 127.0.0.1,14333 -U SA -P 'Daniel@2410' -d master \
  -Q "SELECT encryption_state FROM sys.dm_database_encryption_keys WHERE database_id=DB_ID('HospitalBackupDemo');"
# Expected: 3 (encrypted)
```

---

### Phase 3: Backup Configuration
**Duration**: 15-20 minutes  
**Purpose**: Set up 3-2-1 backup strategy  
**Key Files**:
- `phases/phase3-backup/s3-setup/` → AWS S3 configuration
- `phases/phase3-backup/full/` → Weekly full backup
- `phases/phase3-backup/differential/` → Daily differential
- `phases/phase3-backup/log/` → Hourly log backup
- `phases/phase3-backup/verification/` → Backup verification

**Success Criteria**:
- ✅ Backup directories created (/var/opt/mssql/backup/full, diff, log)
- ✅ Backup stored procedures created
- ✅ AWS S3 integration configured
- ✅ 3-2-1 strategy implemented:
  - 3 copies: local full + local differential + S3 full
  - 2 media: local disk + AWS S3
  - 1 offsite: AWS S3 in different region

**Validation**:
```bash
# Check backup directories
ls -lh /var/opt/mssql/backup/full/
ls -lh /var/opt/mssql/backup/diff/
ls -lh /var/opt/mssql/backup/log/
```

---

### Phase 4: Disaster Recovery
**Duration**: 10-15 minutes  
**Purpose**: Implement and validate recovery procedures  
**Key Files**:
- `phases/phase4-recovery/full-restore/` → Full database restore
- `phases/phase4-recovery/point-in-time/` → PITR procedures
- `phases/phase4-recovery/from-s3/` → S3 restore
- `phases/phase4-recovery/testing/` → Recovery validation

**Success Criteria**:
- ✅ 5 recovery methods implemented:
  1. Full restore from local backup
  2. Hybrid restore (S3 full + local chain)
  3. Point-in-time recovery
  4. Alternate server recovery
  5. Emergency recovery
- ✅ RTO validated: < 1 minute (vs 4h target) ✓
- ✅ RPO validated: < 1 minute (vs 1h target) ✓
- ✅ Data integrity verified in recovered database

**Validation**:
```bash
# Run recovery validation
sqlcmd -S 127.0.0.1,14333 -U SA -P 'Daniel@2410' -d master \
  -i phases/phase4-recovery/testing/01_recovery_validation.sql
```

---

### Phase 5: Monitoring & Alerting
**Duration**: 10-15 minutes  
**Purpose**: Set up continuous monitoring and alerts  
**Key Files**:
- `phases/phase5-monitoring/health-checks/` → Database health
- `phases/phase5-monitoring/alerts/` → Backup, disk, RPO/RTO alerts
- `phases/phase5-monitoring/reports/` → Daily/weekly reports
- `phases/phase5-monitoring/EXECUTION_GUIDE.md` → Setup guide

**Success Criteria**:
- ✅ Health check procedures created
- ✅ Alert procedures for:
  - Backup failure detection
  - RPO/RTO threshold monitoring
  - Disk space monitoring
  - Failed login detection
- ✅ Alert thresholds configured:
  - Full backup age: 2 days (critical)
  - Log backup: 1 hour (RPO)
  - Disk space: 20 MB (critical)
  - Failed logins: 5 (warning)

**Validation**:
```bash
# Test health check
sqlcmd -S 127.0.0.1,14333 -U SA -P 'Daniel@2410' -d master \
  -i phases/phase5-monitoring/health-checks/01_health_check.sql
```

**Note**: Email alerts require manual Database Mail configuration (see EXECUTION_GUIDE.md)

---

### Phase 6: Testing & Validation
**Duration**: 20-30 minutes  
**Purpose**: Create and execute comprehensive tests  
**Key Files**:
- `phases/phase6-testing/99_test_metrics_framework.sql` → Test tracking
- `phases/phase6-testing/unit-tests/` → Table structure tests
- `phases/phase6-testing/security-tests/` → RBAC, encryption tests
- `phases/phase6-testing/scenarios/` → Disaster scenario execution
- `phases/phase6-testing/performance-tests/` → Load/stress tests
- `phases/phase6-testing/TEST_EXECUTION_GUIDE.md` → Detailed guide

**Success Criteria**:
- ✅ Test metrics framework created (5 tracking tables)
- ✅ Unit tests: Table structure and data types
- ✅ Security tests: RBAC enforcement, encryption verification
- ✅ Disaster recovery tests: RTO/RPO measurement
- ✅ Performance tests: Load testing with severity levels
- ✅ Integration tests: Cross-table relationships

**Validation**:
```bash
# View test results
sqlcmd -S 127.0.0.1,14333 -U SA -P 'Daniel@2410' -d HospitalBackupDemo \
  -Q "SELECT * FROM vw_TestExecutionSummary;"
```

---

### Phase 7: Automation & Jobs
**Duration**: 15-20 minutes  
**Purpose**: Deploy SQL Agent jobs for continuous automation  
**Key Files**:
- `phases/phase7-automation/deploy_jobs.sh` → Job deployment script
- `phases/phase7-automation/verify_jobs.sql` → Job verification
- `phases/phase7-automation/README.md` → Job documentation
- 11 SQL job definition files (.sql)

**Success Criteria**:
- ✅ 11 SQL Agent jobs deployed and enabled:
  1. `HospitalBackup_Weekly_Full_Backup` (Sunday 01:30 AM)
  2. `HospitalBackup_Daily_Differential_Backup` (02:00 AM)
  3. `HospitalBackup_Hourly_Log_Backup` (hourly)
  4. `HospitalBackup_Daily_Verify` (01:00 AM)
  5. `HospitalBackup_Weekly_Recovery_Drill` (Sunday 02:00 AM)
  6. `HospitalBackup_Configure_Alerts` (once)
  7. `HospitalBackup_Hourly_Log_Backup_Check` (hourly)
  8. `HospitalBackup_Daily_Backup_Alert` (06:00 AM)
  9. `HospitalBackup_Monthly_Encryption_Check` (1st of month)
  10. `HospitalBackup_Disaster_Detection` (every 5 minutes)
  11. `HospitalBackup_Auto_Recovery` (on-demand, disabled by default)

**Validation**:
```bash
# Verify jobs
sqlcmd -S 127.0.0.1,14333 -U SA -P 'Daniel@2410' -d msdb \
  -Q "SELECT COUNT(*) FROM sysjobs WHERE name LIKE 'HospitalBackup_%';"
# Expected: 11

# Or run full verification
sqlcmd -S 127.0.0.1,14333 -U SA -P 'Daniel@2410' \
  -i phases/phase7-automation/verify_jobs.sql
```

---

## Verification

### Complete Health Check
```bash
#!/bin/bash

echo "=== Hospital Backup Project Health Check ==="
echo ""

# 1. Database
echo "1. Database Status:"
sqlcmd -S 127.0.0.1,14333 -U SA -P 'Daniel@2410' -h -1 \
  -Q "SELECT 'Tables: ' + CAST(COUNT(*) AS VARCHAR) FROM INFORMATION_SCHEMA.TABLES WHERE TABLE_CATALOG='HospitalBackupDemo';"

# 2. Encryption
echo "2. Encryption Status:"
sqlcmd -S 127.0.0.1,14333 -U SA -P 'Daniel@2410' -d master -h -1 \
  -Q "SELECT 'Encryption: ' + CAST(encryption_state AS VARCHAR) FROM sys.dm_database_encryption_keys WHERE database_id=DB_ID('HospitalBackupDemo');"

# 3. Backups
echo "3. Backup Files:"
ls -lh /var/opt/mssql/backup/full/ | tail -5

# 4. RBAC Roles
echo "4. Security Roles:"
sqlcmd -S 127.0.0.1,14333 -U SA -P 'Daniel@2410' -d HospitalBackupDemo -h -1 \
  -Q "SELECT 'Roles: ' + CAST(COUNT(*) AS VARCHAR) FROM sys.database_principals WHERE type='R';"

# 5. Jobs
echo "5. SQL Agent Jobs:"
sqlcmd -S 127.0.0.1,14333 -U SA -P 'Daniel@2410' -d msdb -h -1 \
  -Q "SELECT 'Jobs: ' + CAST(COUNT(*) AS VARCHAR) FROM sysjobs WHERE name LIKE 'HospitalBackup_%';"

echo ""
echo "✓ Health check complete"
```

---

## Troubleshooting

### Pipeline Won't Start

**Problem**: `Cannot connect to SQL Server`

**Solution**:
```bash
# Check if SQL Server is running
docker ps | grep mssql

# If not running, start it
docker run -e "ACCEPT_EULA=Y" -e "SA_PASSWORD=Daniel@2410" \
  -p 14333:1433 --name mssql-server-latest \
  -d mcr.microsoft.com/mssql/server:2019-latest

# Wait 30 seconds for startup
sleep 30

# Test connection
sqlcmd -S 127.0.0.1,14333 -U SA -P 'Daniel@2410' -Q "SELECT 1"
```

### Phase 1 Fails

**Problem**: Database creation fails

**Check**:
```bash
# Is database already created?
sqlcmd -S 127.0.0.1,14333 -U SA -P 'Daniel@2410' \
  -Q "SELECT name FROM sys.databases WHERE name='HospitalBackupDemo';"

# If exists, drop it and retry
sqlcmd -S 127.0.0.1,14333 -U SA -P 'Daniel@2410' -d master \
  -Q "ALTER DATABASE HospitalBackupDemo SET SINGLE_USER WITH ROLLBACK IMMEDIATE; DROP DATABASE HospitalBackupDemo;"

# Retry Phase 1
./run_all_phases.sh --phase 1
```

### Phase 3 Fails (Backup Issues)

**Problem**: Backup creation fails

**Check**:
```bash
# Verify backup directories exist
ls -ld /var/opt/mssql/backup/
ls -ld /var/opt/mssql/backup/full/
ls -ld /var/opt/mssql/backup/diff/
ls -ld /var/opt/mssql/backup/log/

# Check permissions
ls -la /var/opt/mssql/ | grep backup

# Create if missing
mkdir -p /var/opt/mssql/backup/{full,diff,log}
sudo chown -R mssql:mssql /var/opt/mssql/backup
sudo chmod -R 755 /var/opt/mssql/backup
```

### Phase 7 Fails (Job Creation)

**Problem**: SQL Agent jobs not created

**Check**:
```bash
# Is SQL Agent running?
systemctl status mssql-server

# Check job creation log
cat logs/phase7/*.log

# Verify manually
sqlcmd -S 127.0.0.1,14333 -U SA -P 'Daniel@2410' -d msdb \
  -Q "SELECT name, enabled FROM sysjobs WHERE name LIKE 'HospitalBackup_%' ORDER BY name;"

# If missing, redeploy
./phases/phase7-automation/deploy_jobs.sh
```

### View Pipeline Logs

```bash
# Most recent pipeline log
tail -100 logs/pipeline_*.log

# Specific phase logs
tail -50 logs/phase3/*.log

# Search for errors
grep -i "error" logs/pipeline_*.log

# Full pipeline log with context
cat logs/pipeline_YYYYMMDD_HHMMSS.log | less
```

---

## Performance Expectations

| Phase | Size | Time | Key Metrics |
|-------|------|------|-------------|
| 1 | 50 MB | 8-12 min | 18 tables, 153 records |
| 2 | 55 MB | 8-12 min | TDE enabled, RBAC configured |
| 3 | 55 MB | 12-18 min | Backup dirs created, 3-2-1 ready |
| 4 | 300 MB | 8-12 min | RTO < 1 min, RPO < 1 min |
| 5 | 300 MB | 8-12 min | Alerts configured, health checks |
| 6 | 350 MB | 15-25 min | Tests executed, metrics logged |
| 7 | 350 MB | 10-15 min | 11 jobs deployed |
| **TOTAL** | **~300 MB** | **~90-120 min** | **Complete solution** |

---

## Next Steps After Pipeline

1. ✅ **Verify**: Run health checks (see Verification section)
2. 📧 **Configure Email**: Set up Database Mail for Phase 5 alerts
3. 🧪 **Test Recovery**: Run Phase 4 recovery procedures manually
4. 📊 **Review Reports**: Check Phase 5 monitoring reports
5. 📅 **Monitor Jobs**: Verify Phase 7 SQL Agent jobs are running
6. 🔄 **Schedule Testing**: Run Phase 6 tests monthly
7. ☁️ **Test S3**: Verify backups reaching AWS S3 bucket

---

## Quick Reference

```bash
# Run everything
./run_all_phases.sh

# Run specific phase
./run_all_phases.sh --phase 3

# Run with error tolerance
./run_all_phases.sh --continue

# Direct phase execution
./scripts/runners/run_phase.sh 3

# View latest log
tail -50 logs/pipeline_*.log

# Full health check
sqlcmd -S 127.0.0.1,14333 -U SA -P 'Daniel@2410' \
  -Q "SELECT DB_NAME(database_id), encryption_state FROM sys.dm_database_encryption_keys;"
```

---

**For detailed documentation**, see:
- [RUN_PIPELINE.md](RUN_PIPELINE.md) - Complete pipeline guide with all steps
- [PIPELINE_ARCHITECTURE.md](PIPELINE_ARCHITECTURE.md) - Technical architecture details
- [QUICK_START_PIPELINE.md](QUICK_START_PIPELINE.md) - Quick reference guide
- Phase READMEs in each `phases/phase*/` directory

