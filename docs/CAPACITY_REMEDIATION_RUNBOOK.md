# Capacity Remediation Runbook

---

## When Disk Reaches 80%

### Immediate (within 24 hours)
1. Run emergency cleanup: `./scripts/utilities/emergency_disk_cleanup.sh`
2. Check backup retention is working: verify old backups being deleted
3. Verify S3 uploads are succeeding (backups should move off local disk)
4. Check for unexpected large files:
   ```sql
   SELECT TOP 10 name, size*8/1024 AS SizeMB
   FROM sys.master_files ORDER BY size DESC;
   ```

### Short-term (within 1 week)
1. Review backup retention: reduce `LOCAL_RETENTION_DAYS` if safe
2. Enable backup compression: `WITH COMPRESSION` in backup commands
3. Request additional disk space from infrastructure team

### Long-term (within 1 month)
1. Add dedicated backup disk (separate from data)
2. Implement tiered storage (SSD for data, HDD for backups)
3. Review database growth patterns — investigate unexpected tables

---

## When S3 Reaches Budget Threshold

### Immediate
1. Review S3 lifecycle rules: `aws s3api get-bucket-lifecycle-configuration --bucket hospital-backup-prod-lock`
2. Confirm Glacier transition is working (after 1 year)
3. Check for duplicate uploads

### Short-term
1. Enable S3 Intelligent Tiering for audit logs
2. Review backup frequency — reduce diff/log intervals if RPO allows
3. Adjust retention periods

---

## When Transaction Log > 70%

### Immediate
1. Take a log backup immediately:
   ```sql
   EXEC dbo.usp_PerformBackup @BackupType = 'LOG';
   ```
2. Check for long-running transactions:
   ```sql
   SELECT * FROM sys.dm_exec_requests WHERE total_elapsed_time > 300000;
   ```
3. Check log reuse wait:
   ```sql
   SELECT name, log_reuse_wait_desc FROM sys.databases WHERE name = 'HospitalBackupDemo';
   ```

### If log_reuse_wait = 'LOG_BACKUP'
- Hourly log backup may have failed — restart the SQL Agent job
- Check: `EXEC sp_start_job @job_name = 'HospitalBackup_Hourly_LogBackup';`

### If log_reuse_wait = 'ACTIVE_TRANSACTION'
- A long-running transaction is holding the log open
- Find it: `DBCC OPENTRAN('HospitalBackupDemo');`
- Consider killing the session if safe

---

## Emergency Disk Space Recovery (> 95%)

**Safe to delete immediately:**
- `/tmp` files older than 1 day
- Log files older than retention period
- Failed backup temp files (`*.tmp`)

**Safe to delete after verification:**
- Differential backups if a more recent full backup exists
- Log backups older than the backup chain requires

**NEVER delete without verification:**
- Last full backup
- TDE certificates (`*.cer`, `*.pvk`)
- Audit log exports not yet uploaded to S3

**Emergency script:** `./scripts/utilities/emergency_disk_cleanup.sh`

---

## Monitoring

| Metric | Check | Alert |
|---|---|---|
| Disk usage | `dbo.CapacityHistory` | >80% = HIGH, >90% = CRITICAL |
| Days to full | `dbo.CapacityForecast` | <30 = HIGH, <14 = CRITICAL |
| Transaction log | `DBCC SQLPERF(LOGSPACE)` | >70% = WARNING, >85% = CRITICAL |
| Backup size trend | `dbo.CapacityHistory` | >20% weekly growth = WARNING |
| S3 storage | `aws s3 ls --summarize` | Budget threshold |

**Dashboard**: Grafana > Database Availability > Capacity Planning row
**Job**: `HospitalBackup_Daily_Capacity` runs daily at 23:00
