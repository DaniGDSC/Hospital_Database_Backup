# Audit Log Retention Policy

**System**: HospitalBackupDemo
**Compliance**: HIPAA 45 CFR 164.530(j) — Documentation Retention
**Effective Date**: _Upon first production deployment_

---

## Retention Period

| Requirement | Value | Basis |
|---|---|---|
| Minimum retention | **6 years** | HIPAA 45 CFR 164.530(j) |
| Object Lock mode | **COMPLIANCE** | Cannot be deleted by anyone, including AWS root |
| Storage transition | Glacier after 1 year | Cost optimization |
| Automatic deletion | 6 years + 30 days | Via S3 Lifecycle rule |

---

## What Is Retained

| Audit Table | Contents | Sensitivity |
|---|---|---|
| `dbo.AuditLog` | All DML changes to PHI tables (who, what, when, old/new values) | High |
| `dbo.SecurityAuditEvents` | DDL changes (user/role creation), protection violations | High |
| `dbo.SecurityEvents` | Login attempts, permission denials, encryption events | Medium |

---

## Storage Architecture

```
Database (live)           S3 Object Lock (immutable archive)
┌──────────────┐          ┌───────────────────────────────────┐
│ AuditLog     │──nightly─→│ audit-logs/YYYY/MM/DD/            │
│ SecurityAudit│  export   │   audit_auditlog_20260319.csv.enc │
│ SecurityEvts │           │   audit_security*_20260319.csv.enc│
└──────────────┘           └───────────────────────────────────┘
                                     │
                                     ├── 0-365 days: S3 Standard
                                     ├── 365+ days: S3 Glacier
                                     └── 2220 days: Auto-delete
```

- **Export**: Daily at 01:00 AM via SQL Agent job `HospitalBackup_Nightly_AuditExport`
- **Encryption**: AES-256-CBC client-side + SSE-KMS server-side (double encryption)
- **Immutability**: S3 Object Lock COMPLIANCE mode, 2190-day retention

---

## Access Control

| Role | Can Read Audit Logs | Can Modify | Can Delete |
|---|---|---|---|
| `app_readwrite` | No (DENY SELECT) | No (DENY UPDATE) | No (DENY DELETE) |
| `app_readonly` | No (DENY SELECT) | No | No |
| `app_billing` | No (DENY SELECT) | No | No |
| `app_auditor` | **Yes** (SELECT) | No (DENY UPDATE) | No (DENY DELETE) |
| `sysadmin` | Yes | Yes (bypasses DENY) | Yes (bypasses DENY) |
| AWS IAM | Via S3 only | No (Object Lock) | No (Object Lock) |

---

## Review Schedule

| Review | Frequency | Performed By | Purpose |
|---|---|---|---|
| Export verification | Daily (automated) | `verify_audit_retention.sh` | Confirm export pipeline running |
| Compliance audit | Quarterly | Security Officer | Review access patterns, anomalies |
| Retention verification | Monthly | DBA | Confirm Object Lock still COMPLIANCE |
| Full retention test | Annually | Security team | Retrieve 1-year-old log, verify readable |

---

## Destruction Policy

Audit logs are automatically destroyed after 6 years + 30 days via S3 Lifecycle:
- S3 Object Lock prevents early deletion
- Lifecycle rule `AuditLogGlacierTransition` handles expiration
- No manual deletion is possible while Object Lock is active

**Early destruction is NOT permitted** under HIPAA unless:
- Legal counsel approves in writing
- Destruction is logged in SecurityAuditEvents
- A retention waiver is filed with the compliance officer

---

## Emergency Access

To retrieve audit logs from S3 Glacier (for compliance review or investigation):

```bash
# 1. Initiate Glacier restore (takes 3-12 hours)
aws s3api restore-object \
    --bucket hospital-backup-prod-lock \
    --key "audit-logs/2025/01/15/audit_auditlog_20250115.csv.enc" \
    --restore-request '{"Days": 7, "GlacierJobParameters": {"Tier": "Standard"}}'

# 2. After restore completes, download and decrypt
aws s3 cp "s3://hospital-backup-prod-lock/audit-logs/2025/01/15/audit_auditlog_20250115.csv.enc" .
openssl enc -aes-256-cbc -d -pbkdf2 -iter 100000 \
    -in audit_auditlog_20250115.csv.enc \
    -out audit_auditlog_20250115.csv \
    -pass env:AUDIT_EXPORT_PASSWORD
```
