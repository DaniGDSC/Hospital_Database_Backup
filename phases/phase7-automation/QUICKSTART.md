# Phase 7 Quick Start Guide

## Overview
Phase 7 automates recovery testing and monitoring through SQL Server Agent jobs. Five critical jobs run automatically to ensure database backup integrity, recovery capability, and encryption status.

## Files Included

### Job Creation Scripts
- `01_job_daily_backup_verify.sql` - Daily backup verification (01:00 AM)
- `02_job_weekly_recovery_drill.sql` - Weekly restore test (Sunday 02:00 AM)
- `04_job_hourly_log_backup_check.sql` - Hourly log chain validation
- `05_job_daily_backup_alert.sql` - Daily backup failure alert (06:00 AM)
- `06_job_monthly_encryption_check.sql` - Monthly TDE certificate check (15th at 22:00)
 - `00_job_weekly_full_backup.sql` - Weekly encrypted full backup (local + S3)
 - `00_job_daily_differential_backup.sql` - Daily encrypted differential backup (local)
 - `00_job_hourly_log_backup.sql` - Hourly encrypted log backup (local)

### Deployment & Verification
- `deploy_jobs.sh` - Automated deployment script
- `verify_jobs.sql` - Verification and testing guide
- `07_configure_alerts.sql` - Optional email alert configuration
- `README.md` - Comprehensive documentation

## Quick Deployment

### Option 1: Automated Deployment (Recommended)
```bash
cd /home/un1/hospital-db-backup-project
chmod +x phase7-automation/deploy_jobs.sh
./phase7-automation/deploy_jobs.sh
```

To enable immutable S3 backups (WORM), create an Object Lock bucket (run without sudo so your AWS credentials are used):
```bash
chmod +x scripts/utilities/configure_s3_object_lock.sh
bash scripts/utilities/configure_s3_object_lock.sh hospital-backup-prod-lock ap-southeast-1 30
# Then set S3_BUCKET_NAME="hospital-backup-prod-lock" in config/project.conf
```

### Option 2: Manual Deployment
Execute each job script in order:
```bash
sqlcmd -S 127.0.0.1,14333 -U SA -P 'YourPassword' -i phase7-automation/01_job_daily_backup_verify.sql
sqlcmd -S 127.0.0.1,14333 -U SA -P 'YourPassword' -i phase7-automation/02_job_weekly_recovery_drill.sql
sqlcmd -S 127.0.0.1,14333 -U SA -P 'YourPassword' -i phase7-automation/04_job_hourly_log_backup_check.sql
sqlcmd -S 127.0.0.1,14333 -U SA -P 'YourPassword' -i phase7-automation/05_job_daily_backup_alert.sql
sqlcmd -S 127.0.0.1,14333 -U SA -P 'YourPassword' -i phase7-automation/06_job_monthly_encryption_check.sql
 
 # Backup jobs
 sqlcmd -S 127.0.0.1,14333 -U SA -P 'YourPassword' -d msdb -i phase7-automation/00_job_weekly_full_backup.sql
 sqlcmd -S 127.0.0.1,14333 -U SA -P 'YourPassword' -d msdb -i phase7-automation/00_job_daily_differential_backup.sql
 sqlcmd -S 127.0.0.1,14333 -U SA -P 'YourPassword' -d msdb -i phase7-automation/00_job_hourly_log_backup.sql
```

## Automation Schedule

| Job | Schedule | Purpose | Risk |
|-----|----------|---------|------|
| Daily Verify | 01:00 AM | Check backup integrity | None - read-only |
| Weekly Drill | Sunday 02:00 AM | Test recovery capability | Medium - creates test DB |
| Hourly Chain | Every hour | Validate log chain | None - read-only |
| Daily Alert | 06:00 AM | Alert if backup stale | None - read-only |
| Monthly Crypt | 15th 22:00 | TDE certificate status | None - read-only |

**Note:** Weekly recovery drill creates a test database (~1 GB) that auto-deletes after 7 days.

## Immediate Actions

### 1. Verify Jobs Deployed
```sql
SELECT name, enabled FROM msdb.dbo.sysjobs WHERE name LIKE 'HospitalBackup_%';
```

### 2. Test a Job Manually
```sql
-- Test backup verification (safe - read-only)
EXEC msdb.dbo.sp_start_job @job_name = 'HospitalBackup_Daily_Verify';

-- Wait for completion
WAITFOR DELAY '00:00:05';

-- Check results
SELECT TOP 5 * FROM HospitalBackupDemo.dbo.BackupHistory ORDER BY VerificationDate DESC;
SELECT TOP 5 * FROM HospitalBackupDemo.dbo.SystemConfiguration ORDER BY LastUpdated DESC;
```

### 3. Run Verification Script
```bash
sqlcmd -S 127.0.0.1,14333 -U SA -P 'YourPassword' -i phase7-automation/verify_jobs.sql
```

## Viewing Results

### Check Job History
```sql
SELECT TOP 20
    j.name, 
    h.run_status,
    h.run_date,
    h.run_time,
    h.message
FROM msdb.dbo.sysjobhistory h
JOIN msdb.dbo.sysjobs j ON h.job_id = j.job_id
WHERE j.name LIKE 'HospitalBackup_%'
ORDER BY h.run_date DESC, h.run_time DESC;
```

### Check Backup History Logging
```sql
SELECT * FROM HospitalBackupDemo.dbo.BackupHistory 
WHERE BackupType IN ('FULL_VERIFY', 'RECOVERY_DRILL_SUCCESS', 'LOG_CHAIN_VERIFY')
ORDER BY VerificationDate DESC;
```

### Check Automation Alerts
```sql
SELECT * FROM HospitalBackupDemo.dbo.SystemConfiguration
WHERE ConfigKey LIKE '%BACKUP_%' OR ConfigKey LIKE '%ENCRYPTION_%' OR ConfigKey LIKE '%LOG_%'
ORDER BY LastUpdated DESC;
```

## Key Features

### 1. Automated Backup Verification
- Runs daily at 1:00 AM
- Verifies latest full backup using RESTORE HEADERONLY
- Detects corrupted backups before they're needed
- Logs results to BackupHistory

### 2. Recovery Drill Testing
- Runs weekly Sunday at 2:00 AM
- Performs full restore to test database
- Validates row counts and data integrity
- Runs DBCC CHECKDB
- Auto-deletes old test databases after 7 days

### 3. Log Chain Validation
- Runs every hour at top of hour
- Ensures log backup continuity
- Detects LSN gaps that would break PITR
- Critical for RPO compliance

### 3.1 Scheduled Backup Jobs
- Weekly full backups (encrypted AES-256, local + S3)
- Daily differential backups (encrypted AES-256, local)
- Hourly transaction log backups (encrypted AES-256, local)

### 4. Backup Failure Alert
- Runs daily at 6:00 AM
- Alerts if any backup > 2 days old
- Checks both full and log backup status
- Raises alarm before disaster occurs

### 5. Encryption Status Check
- Runs monthly on 15th at 22:00 (10 PM)
- Verifies TDE is enabled
- Checks certificate expiry dates
- Alerts if rotation needed

## Troubleshooting

### Jobs Not Executing
1. Verify SQL Server Agent is running
2. Check SQL Agent service status
3. Review sysjobhistory for error messages
4. Manually test job: `EXEC sp_start_job @job_name='HospitalBackup_Daily_Verify';`
5. If S3 uploads fail, confirm you’re using the Object Lock bucket and avoid `sudo` (root may not have AWS credentials)

### Recovery Drill Failing
1. Check disk space: `df -h /var/opt/mssql/`
2. Verify backup files exist
3. Test backup manually: `RESTORE HEADERONLY FROM DISK='...'`
4. Check SQL Server error log

### Email Alerts Not Working
1. Configure SMTP in SQL Server
2. Test mail: `EXEC sp_send_dbmail @subject='Test', @recipients='dba@hospital.local';`
3. Check Database Mail configuration
4. Review SQL Agent alert settings

## Next Steps

1. **Monitor Job Execution** - Check job history weekly
2. **Review Alerts** - Check SystemConfiguration table for alerts
3. **Test Restore** - Monthly full recovery validation
4. **Update Runbooks** - Document automation procedures
5. **Schedule DR Drills** - Quarterly full disaster recovery testing

## Documentation

- See `README.md` for comprehensive documentation
- See `verify_jobs.sql` for verification procedures
- See individual job scripts for implementation details
 - See `scripts/utilities/configure_s3_object_lock.sh` to create an immutable S3 bucket (Object Lock)

## Support

For issues or questions:
1. Review the error message in SystemConfiguration table
2. Check SQL Server error log: `~/log/` directory
3. Run verification script: `verify_jobs.sql`
4. Manually test job with `sp_start_job`
5. Review job history with `sysjobhistory` query

---

**Deployment Date:** Auto-populated by deployment script  
**Phase:** 7 - Automation  
**Status:** Ready for production deployment
