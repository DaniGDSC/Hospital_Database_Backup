# Phase 7: Automation & SQL Server Agent Jobs

## Overview

Automated recovery testing and failover procedures using SQL Server Agent jobs.

## Job Schedule

| Job | Frequency | Time | Purpose |
|-----|-----------|------|---------|
| **Disaster Detection** | **Every 5 min** | **24/7** | **Auto-detect database offline; trigger alerts** |
| Daily Backup Verification | Daily | 01:00 AM | Verify last full backup is valid |
| Weekly Recovery Drill | Weekly | Sunday 02:00 AM | Test full restore to alternate DB |
| Monthly PITR Test | Monthly | 1st Sunday 03:00 AM | Validate point-in-time recovery |
| Log Backup Validation | Hourly | Every hour | Check log backup chain integrity |
| Backup Failure Alert | Daily | 06:00 AM | Alert if backup > 2 days old |
| Encryption Key Rotation Check | Monthly | 15th 22:00 | Verify TDE key backup status |
| **Auto-Recovery** | **On-demand** | **Triggered** | **Automatic restore from cloud (DISABLED by default)** |

## Files Included

### Agent Job Creation Scripts
- `00_job_weekly_full_backup.sql` - Weekly encrypted full backup (local + S3)
- `00_job_daily_differential_backup.sql` - Daily encrypted differential backup (local)
- `00_job_hourly_log_backup.sql` - Hourly encrypted log backup (local)
- `01_job_daily_backup_verify.sql` - Daily backup verification
- `02_job_weekly_recovery_drill.sql` - Weekly restore test
- `03_job_monthly_pitr_test.sql` - Monthly PITR validation
- `04_job_hourly_log_backup_check.sql` - Hourly log chain validation
- `05_job_daily_backup_alert.sql` - Daily backup failure alert
- `06_job_monthly_encryption_check.sql` - Encryption key rotation check
- **`07_job_disaster_detection.sql`** - **Continuous database availability monitoring**
- **`08_job_auto_recovery.sql`** - **Automated disaster recovery (DISABLED by default)**

### Stored Procedures (Called by Jobs)
- `sp_verify_last_backup.sql` - Validates backup integrity
- `sp_test_full_restore.sql` - Tests restore to test DB
- `sp_test_point_in_time_restore.sql` - Tests PITR capability
- `sp_validate_log_backup_chain.sql` - Validates log backup continuity
- `sp_alert_backup_failure.sql` - Raises alert if backup stale
- `sp_check_encryption_status.sql` - Checks TDE certificate status

## Setup Instructions

### 1. Create Operator (for notifications)
```sql
EXEC msdb.dbo.sp_add_operator
    @name = N'DBA_Team',
    @enabled = 1,
    @email_address = N'dba@hospital.local';
```

### 2. Enable SQL Server Agent

```bash
# Linux/Docker
docker exec <sql_container> systemctl start mssql-server-agent

# Or in SQL:
EXEC msdb.dbo.sp_set_sqlagent_properties @agent_auto_start = 1;
```

### 3. Create Jobs (Run in sequence)

```bash
cd /home/un1/hospital-db-backup-project/phase7-automation

# Create stored procedures first
sqlcmd -S 127.0.0.1,14333 -U SA -P 'password' -d HospitalBackupDemo -i sp_verify_last_backup.sql
sqlcmd -S 127.0.0.1,14333 -U SA -P 'password' -d HospitalBackupDemo -i sp_test_full_restore.sql
# ... etc for all stored procedures

# Then create jobs
sqlcmd -S 127.0.0.1,14333 -U SA -P 'password' -d msdb -i 01_job_daily_backup_verify.sql
sqlcmd -S 127.0.0.1,14333 -U SA -P 'password' -d msdb -i 02_job_weekly_recovery_drill.sql
# ... etc for all job scripts

# Backup jobs
sqlcmd -S 127.0.0.1,14333 -U SA -P 'password' -d msdb -i 00_job_weekly_full_backup.sql
sqlcmd -S 127.0.0.1,14333 -U SA -P 'password' -d msdb -i 00_job_daily_differential_backup.sql
sqlcmd -S 127.0.0.1,14333 -U SA -P 'password' -d msdb -i 00_job_hourly_log_backup.sql

# Disaster detection and auto-recovery
sqlcmd -S 127.0.0.1,14333 -U SA -P 'password' -d msdb -i 07_job_disaster_detection.sql
sqlcmd -S 127.0.0.1,14333 -U SA -P 'password' -d msdb -i 08_job_auto_recovery.sql
```

### 4. Verify Jobs Created

```sql
SELECT name, enabled, date_created FROM msdb.dbo.sysjobs
WHERE name LIKE 'HospitalBackup_%'
ORDER BY name;
```

## Job Details

### Daily Backup Verification (01:00 AM)
- Verifies the most recent full backup
- Checks backup integrity using RESTORE VERIFYONLY
- Logs results to BackupHistory table
- Alerts if backup is corrupted

### Weekly Recovery Drill (Sunday 02:00 AM)
- Creates test database: HospitalBackupDemo_RecoveryTest_YYYYMMDD
- Restores latest full backup
- Applies differential and logs if available
- Validates row counts match production
- Runs DBCC CHECKDB
- Reports success/failure
- Keeps test DB for 7 days (manual cleanup)

### Monthly PITR Test (1st Sunday 03:00 AM)
- Tests point-in-time recovery capability
- Restores to 24 hours ago (or most recent full if < 24h old)
- Validates that log backup chain is intact
- Confirms PITR RTO/RPO targets
- Alerts if PITR not possible

### Hourly Log Backup Validation (Every hour)
- Checks log backup chain continuity
- Validates LSN sequences
- Alerts if gap detected
- Critical for PITR capability

### Daily Backup Failure Alert (06:00 AM)
- Checks if any backup is > 2 days old
- Raises error notification if threshold exceeded
- Sends email to DBA_Team operator
- Escalates to high severity

### Monthly Encryption Check (15th at 22:00)
- Verifies TDE certificate backup exists
- Checks certificate expiration date
- Confirms encryption status ON
- Alerts if rotation needed

### **Disaster Detection (Every 5 Minutes, 24/7) - NEW**
- **Automatically monitors** HospitalBackupDemo availability
- Checks database state in `sys.databases` every 5 minutes
- **Detects disasters:**
  - Database missing (dropped/deleted)
  - Database offline/restoring/suspect
  - Database in emergency mode
- **Logs events** to `tempdb.dbo.DisasterDetectionLog`:
  - DISASTER: Database missing
  - WARNING: Database not ONLINE
  - HEALTHY: Database operational (logged twice/hour)
- **Alerts via SQL Server error log** for critical events
- **Optional:** Can trigger auto-recovery job (requires manual enable)

**Status Monitoring:**
```sql
-- View recent disaster detection log
SELECT TOP 20 * FROM tempdb.dbo.DisasterDetectionLog 
ORDER BY EventTime DESC;

-- Check current database status
EXEC sp_helpdb 'HospitalBackupDemo';
```

### **Auto-Recovery (On-Demand/Triggered) - NEW**
- **DISABLED by default** for safety (requires explicit enable)
- **Automatically restores** HospitalBackupDemo from latest cloud backup
- **Multi-step recovery process:**
  1. **Safety checks:** Verifies disaster exists, S3 credential present
  2. **Download:** Retrieves latest full backup from S3 (`hospital-backup-prod-lock`)
  3. **Restore:** Executes `RESTORE DATABASE` with encryption verification
  4. **Validate:** Confirms database is ONLINE and passes integrity checks
- **Logs recovery** to error log and DisasterDetectionLog
- **Can be triggered:**
  - Manually: `EXEC msdb.dbo.sp_start_job @job_name='HospitalBackup_AutoRecovery';`
  - Automatically: By disaster detection job (if enabled)

**⚠️ SAFETY NOTICE - Auto-Recovery:**

This job performs **automatic production recovery** and is DISABLED by default. To enable:

1. **Test thoroughly** in non-production environment first
2. **Edit job Step 1:** Set `@autoRecoveryEnabled = 1` in [08_job_auto_recovery.sql](08_job_auto_recovery.sql)
3. **Enable the job:**
   ```sql
   EXEC msdb.dbo.sp_update_job 
       @job_name='HospitalBackup_AutoRecovery', 
       @enabled=1;
   ```
4. **Link to disaster detection** (optional): Uncomment `sp_start_job` call in [07_job_disaster_detection.sql](07_job_disaster_detection.sql) Step 1
5. **Monitor closely:** Review job history after each execution

**Manual Recovery Test:**
```bash
# Simulate disaster (TEST ENVIRONMENT ONLY)
sqlcmd -C -S 127.0.0.1,14333 -U SA -P 'password' -Q \
  "ALTER DATABASE [HospitalBackupDemo] SET SINGLE_USER WITH ROLLBACK IMMEDIATE; \
   DROP DATABASE [HospitalBackupDemo];"

# Trigger auto-recovery
sqlcmd -C -S 127.0.0.1,14333 -U SA -P 'password' -Q \
  "EXEC msdb.dbo.sp_start_job @job_name='HospitalBackup_AutoRecovery';"

# Monitor job status
sqlcmd -C -S 127.0.0.1,14333 -U SA -P 'password' -Q \
  "SELECT run_status, message FROM msdb.dbo.sysjobhistory \
   WHERE job_id=(SELECT job_id FROM msdb.dbo.sysjobs WHERE name='HospitalBackup_AutoRecovery') \
   ORDER BY instance_id DESC;"
```

## Alerts & Notifications

All jobs can send notifications via:

1. **Email** (requires SMTP server configured)
2. **SQL Server Agent Alert** (severity-based)
3. **Event Log** (Windows Event Viewer)
4. **Custom Log Tables** (AuditLog, SystemConfiguration)

## Monitoring Job Execution

```sql
-- View job history
SELECT job_name, run_status, run_date, run_time, message
FROM msdb.dbo.sysjobhistory h
JOIN msdb.dbo.sysjobs j ON h.job_id = j.job_id
WHERE j.name LIKE 'HospitalBackup_%'
ORDER BY run_date DESC, run_time DESC;

-- View enabled jobs
SELECT name, enabled, date_created, date_modified
FROM msdb.dbo.sysjobs
WHERE name LIKE 'HospitalBackup_%'
ORDER BY name;

-- Check job schedules
SELECT j.name, s.name, s.freq_type, s.active
FROM msdb.dbo.sysjobs j
JOIN msdb.dbo.sysjobschedules js ON j.job_id = js.job_id
JOIN msdb.dbo.sysschedules s ON js.schedule_id = s.schedule_id
WHERE j.name LIKE 'HospitalBackup_%'
ORDER BY j.name;
```

## Troubleshooting

### Job Not Executing
1. Check SQL Server Agent is running: `EXEC sp_help_sqlagent_properties;`
2. Verify job is enabled: `SELECT enabled FROM msdb.dbo.sysjobs WHERE name = 'HospitalBackup_Daily_Verify';`
3. Check job history for errors: View sysjobhistory table
4. Restart SQL Server Agent: `systemctl restart mssql-server-agent`

### Recovery Drill Failures
1. Check backup file exists: `ls -lh /var/opt/mssql/backup/full/`
2. Test restore manually: `RESTORE HEADERONLY FROM DISK = '/path/to/backup.bak';`
3. Verify disk space: `df -h /var/opt/mssql/backup/`
4. Check restore permissions: Verify sa user has rights

### Email Notifications Not Sending
1. Configure SMTP: `EXEC msdb.dbo.sysmail_configure_sp @parameter_name='LoggingLevel', @parameter_value=2;`
2. Test mail: `EXEC msdb.dbo.sp_send_dbmail @subject='Test', @body='Testing', @recipients='dba@hospital.local';`
3. Check error log: `SELECT * FROM msdb.dbo.sysmail_log ORDER BY log_date DESC;`

## Next Steps

1. **Deploy jobs** to production after testing in dev
2. **Monitor job execution** weekly via job history
3. **Update on-call runbook** with job procedures
4. **Schedule quarterly DR drills** with full recovery
5. **Document job failures** and root causes
6. **Rotate encryption keys** annually using scheduled job

## References

- SQL Server Agent Jobs: https://docs.microsoft.com/en-us/sql/ssms/agent/create-a-job
- SQL Server Backup: https://docs.microsoft.com/en-us/sql/relational-databases/backup-restore/backup-overview
- Point-in-Time Recovery: https://docs.microsoft.com/en-us/sql/relational-databases/backup-restore/restore-a-sql-server-database-to-a-point-in-time

