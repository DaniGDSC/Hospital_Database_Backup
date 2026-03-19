# TDE Certificate Key Rotation Runbook

**System**: HospitalBackupDemo
**Compliance**: HIPAA §164.312(a)(2)(iv) — Encryption Key Management
**Last Rotation**: _Never (initial certificate)_
**Next Scheduled**: _TBD after first production deployment_

---

## When to Rotate

| Trigger | Urgency | Timeline |
|---------|---------|----------|
| Annual scheduled rotation | Planned | Within maintenance window |
| DBA leaves the organization | Urgent | Within 24 hours |
| Suspected key compromise | Emergency | Immediately |
| Certificate approaching expiry | Planned | 30 days before expiry |
| Compliance audit finding | Urgent | Per audit timeline |

---

## Prerequisites

- [ ] Member of `sysadmin` or `app_security_admin` role
- [ ] Approval from Database Security Officer (two-person rule)
- [ ] Staging environment tested first
- [ ] Full backup taken before rotation begins
- [ ] `CERT_BACKUP_PASSWORD` available from secrets manager
- [ ] `CERT_S3_ENCRYPTION_KEY` available from secrets manager
- [ ] Maintenance window scheduled (off-peak hours)

---

## Rotation Procedure

### Step 1: Pre-Rotation Backup
```bash
# Take a full backup with the CURRENT certificate
sqlcmd -S "$SERVER_CONN" -U "$SQL_USER" -P "$SQL_PASSWORD" \
  -d HospitalBackupDemo \
  -Q "EXEC dbo.usp_PerformBackup @BackupType = 'FULL'"
```

### Step 2: Execute Rotation Script
```bash
# Replace 2026 with the year/version identifier
sqlcmd -S "$SERVER_CONN" -U "$SQL_USER" -P "$SQL_PASSWORD" \
  -d master \
  -v NEW_CERT_SUFFIX="2026" \
  -v CERT_BACKUP_PASSWORD="$CERT_BACKUP_PASSWORD" \
  -i phases/phase2-security/certificates/04_rotate_tde_certificate.sql
```

The script will:
1. Create a new certificate (`HospitalBackupDemo_TDECert_2026`)
2. Back up the new certificate to `/var/opt/mssql/backup/certificates/`
3. Re-encrypt the database encryption key with the new certificate
4. Verify encryption is active
5. Log the rotation event to `SecurityAuditEvents`

### Step 3: Upload New Certificate to S3
```bash
export CERT_S3_ENCRYPTION_KEY="$CERT_S3_ENCRYPTION_KEY"
./scripts/utilities/backup_cert_to_s3.sh
```

### Step 4: Post-Rotation Full Backup
```bash
# This backup will be encrypted with the NEW certificate
sqlcmd -S "$SERVER_CONN" -U "$SQL_USER" -P "$SQL_PASSWORD" \
  -d HospitalBackupDemo \
  -Q "EXEC dbo.usp_PerformBackup @BackupType = 'FULL'"
```

### Step 5: Verify New Backup Restores
```bash
# Restore to test database to confirm new certificate works
sqlcmd -S "$SERVER_CONN" -U "$SQL_USER" -P "$SQL_PASSWORD" \
  -d HospitalBackupDemo \
  -Q "EXEC dbo.usp_TestFullRestore @TestDBName = 'HospitalBackupDemo_RotationTest'"
```

### Step 6: Verify Certificate Backup
```bash
sqlcmd -S "$SERVER_CONN" -U "$SQL_USER" -P "$SQL_PASSWORD" \
  -d master \
  -i phases/phase2-security/certificates/03_verify_certificate_backup.sql
```

---

## Old Certificate Retention

**DO NOT DROP the old certificate.** Backups created before the rotation
can only be restored using the old certificate.

| Item | Retention |
|------|-----------|
| Old certificate in `master` DB | Minimum 90 days (matches S3 retention) |
| Old `.cer` and `.pvk` files | Minimum 90 days |
| Old certificate in S3 | Retained automatically via Object Lock |

After the retention period, the old certificate may be dropped:
```sql
-- ONLY after ALL backups using the old cert have expired
USE master;
DROP CERTIFICATE HospitalBackupDemo_TDECert;
```

---

## Rollback Procedure

If rotation fails mid-way or the new certificate is compromised:

```sql
-- Switch back to old certificate
USE HospitalBackupDemo;
ALTER DATABASE ENCRYPTION KEY
    ENCRYPTION BY SERVER CERTIFICATE HospitalBackupDemo_TDECert;

-- Verify
SELECT c.name, dek.encryption_state
FROM sys.dm_database_encryption_keys dek
JOIN master.sys.certificates c ON dek.encryptor_thumbprint = c.thumbprint
WHERE dek.database_id = DB_ID('HospitalBackupDemo');
```

Then take a new full backup to establish a clean backup chain.

---

## Authorization

| Action | Authorized Role |
|--------|----------------|
| Approve rotation | Database Security Officer |
| Execute rotation | `sysadmin` or `app_security_admin` |
| Access certificate passwords | Secrets Manager admin only |
| Download certificate from S3 | Requires MFA + IAM policy |

---

## Rotation Log

| Date | Old Certificate | New Certificate | Performed By | Approved By |
|------|----------------|-----------------|--------------|-------------|
| _Initial_ | — | HospitalBackupDemo_TDECert | — | — |
| | | | | |
