# Secrets Rotation Runbook

**System**: HospitalBackupDemo
**Compliance**: HIPAA 164.312(d) — Person/Entity Authentication
**Schedule**: Every 90 days (or immediately after compromise)

---

## Credential Inventory

| Secret | Variable | Rotation | Impact if Compromised |
|--------|----------|----------|----------------------|
| SA Password | `SQL_PASSWORD` | 90 days | Full database access |
| Master Key | `MASTER_KEY_PASSWORD` | Annual | Decrypt all TDE data |
| Cert Backup | `CERT_BACKUP_PASSWORD` | Annual | Decrypt certificate exports |
| App Read/Write | `APP_RW_PASSWORD` | 90 days | Read/write all tables |
| App Read-Only | `APP_RO_PASSWORD` | 90 days | Read all tables |
| App Billing | `APP_BILLING_PASSWORD` | 90 days | Billing data access |
| App Auditor | `APP_AUDIT_PASSWORD` | 90 days | Audit/view definition |
| SMTP | `SMTP_PASSWORD` | When changed at provider | Email alert capability |
| S3 Encryption | `CERT_S3_ENCRYPTION_KEY` | Annual | Decrypt cert backups in S3 |

---

## Rotation Procedures

### SQL SA Password (Every 90 Days)

```sql
-- Step 1: Change the password
ALTER LOGIN sa WITH PASSWORD = '$(NEW_SQL_PASSWORD)';
```

```bash
# Step 2: Update .env
sed -i 's/^SQL_PASSWORD=.*/SQL_PASSWORD=NEW_VALUE_HERE/' .env

# Step 3: Verify connection
./scripts/utilities/test_connection.sh

# Step 4: Verify all SQL Agent jobs still connect
sqlcmd -S "$SERVER_CONN" -U "$SQL_USER" -P "$NEW_SQL_PASSWORD" \
  -Q "SELECT name, enabled FROM msdb.dbo.sysjobs WHERE name LIKE 'HospitalBackup_%'"
```

### Application Login Passwords (Every 90 Days)

```sql
-- Rotate each login individually
ALTER LOGIN app_rw_login  WITH PASSWORD = '$(NEW_APP_RW_PASSWORD)';
ALTER LOGIN app_ro_login  WITH PASSWORD = '$(NEW_APP_RO_PASSWORD)';
ALTER LOGIN billing_login WITH PASSWORD = '$(NEW_APP_BILLING_PASSWORD)';
ALTER LOGIN auditor_login WITH PASSWORD = '$(NEW_APP_AUDIT_PASSWORD)';
```

```bash
# Update .env with all 4 new values, then verify:
./scripts/utilities/validate_secrets.sh
```

### Master Key Password (Annually)

```sql
-- This regenerates the master key — requires current key access
USE master;
ALTER MASTER KEY REGENERATE WITH ENCRYPTION BY PASSWORD = '$(NEW_MASTER_KEY_PASSWORD)';

USE HospitalBackupDemo;
ALTER MASTER KEY REGENERATE WITH ENCRYPTION BY PASSWORD = '$(NEW_MASTER_KEY_PASSWORD)';
```

After master key rotation, **immediately**:
1. Re-export TDE certificate: `04_rotate_tde_certificate.sql`
2. Upload to S3: `scripts/utilities/backup_cert_to_s3.sh`
3. Take a full backup

### TDE Certificate (Annually)

See [KEY_ROTATION_RUNBOOK.md](KEY_ROTATION_RUNBOOK.md) for the full procedure.

### SMTP Password

```bash
# Update after changing at email provider (Gmail, etc.)
# Step 1: Update .env
sed -i 's/^SMTP_PASSWORD=.*/SMTP_PASSWORD=NEW_VALUE_HERE/' .env

# Step 2: Update Database Mail account
sqlcmd -S "$SERVER_CONN" -U "$SQL_USER" -P "$SQL_PASSWORD" -Q "
EXEC msdb.dbo.sysmail_update_account_sp
    @account_name = 'Hospital_Backup_Alerts',
    @password = '$(SMTP_PASSWORD)';
"
```

---

## Post-Rotation Checklist

- [ ] New password meets complexity requirements (16+ chars, mixed case/numbers/symbols)
- [ ] `.env` updated with new value
- [ ] Old password is NOT the same as new password
- [ ] `validate_secrets.sh` passes all checks
- [ ] SQL Server connection verified
- [ ] SQL Agent jobs verified
- [ ] Backup/restore tested with new credentials
- [ ] Rotation logged in SecurityAuditEvents table

---

## Emergency Rotation (Suspected Compromise)

1. **Immediately** change the compromised credential via SQL
2. Update `.env`
3. Test all dependent services
4. Run `validate_secrets.sh`
5. File incident report per HIPAA breach notification rules
6. Review audit logs for unauthorized access during exposure window
