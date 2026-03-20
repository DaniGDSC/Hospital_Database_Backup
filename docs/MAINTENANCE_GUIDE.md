# Maintenance Guide

Routine tasks for operating HospitalBackupDemo in production.

## Daily Tasks (Automated)

These run via SQL Agent jobs. Check Grafana each morning to confirm.

| Time | Job | What It Does |
| --- | --- | --- |
| Every hour | `HourlyLogBackup` | Transaction log backup (RPO = 1 hour) |
| Every hour | `HourlyLogBackupCheck` | Verify log backup chain integrity |
| Every 5 min | `SessionTimeout` | Kill idle sessions exceeding 30 min |
| Every 5 min | `DisasterDetection` | Check for database corruption/offline |
| 01:00 | `NightlyAuditExport` | Export audit logs to S3 (immutable) |
| 02:00 | `DailyDifferentialBackup` | Differential backup |
| 06:00 | `DailyBackupVerify` | Verify all recent backups with RESTORE VERIFYONLY |
| 06:30 | `DailyBackupAlert` | Alert if any backup is stale |
| 23:00 | `DailyCapacityCollection` | Collect disk, DB, and S3 metrics + forecast |

**Morning check**: Open Grafana (http://localhost:3000) and verify all 3 dashboards show green.

## Weekly Tasks (Automated)

| Day | Time | Job | What It Does |
| --- | --- | --- | --- |
| Sunday | 02:00 | `WeeklyFullBackup` | Full database backup |
| Sunday | 03:00 | `WeeklyRecoveryDrill` | Automated DR test (restore + validate) |
| Sunday | 06:00 | `WeeklyPHIReport` | PHI access summary for HIPAA compliance |
| Monday | 08:00 | `TLSCertCheck` | Check TLS certificate expiry |

**Monday check**: Review weekly report email. Check Telegram for any weekend alerts.

## Monthly Tasks

| When | What | How |
| --- | --- | --- |
| 1st Monday | Patch check | Job `MonthlyPatchCheck` runs automatically. Review Telegram alert. |
| 1st Monday | Encryption check | Job `MonthlyEncryptionCheck` verifies TDE status. |
| 1st Sunday | Certificate backup | Job `CertBackupMonthly` uploads TDE cert to S3. |
| Any time | Review capacity forecast | Check Grafana DB Availability dashboard, capacity row. |

## Quarterly Tasks

| When | What | How |
| --- | --- | --- |
| 1st Sunday of quarter | Rebuild test | `APP_ENV=development bash scripts/utilities/test_rebuild.sh` |
| Any time | Certificate expiry review | Check Grafana Panel 4 (cert days remaining). |
| Any time | HIPAA compliance review | Run `02_phi_access_report.sql` for full audit. |
| End of quarter | Update CHANGELOG.md | Document any changes made this quarter. |

## Annual Tasks

| When | What | Reference |
| --- | --- | --- |
| Anniversary | TDE certificate rotation | [KEY_ROTATION_RUNBOOK.md](KEY_ROTATION_RUNBOOK.md) |
| Anniversary | Full security audit | Run `03_cis_benchmark_check.sql` + `01_rbac_validation.sql` |
| Anniversary | DR documentation review | Review all docs in `docs/` for accuracy |
| As needed | BAA renewal check | Legal/compliance team responsibility |

## Common Maintenance Procedures

### Rotate a password

See [SECRETS_ROTATION_RUNBOOK.md](SECRETS_ROTATION_RUNBOOK.md) for step-by-step.

### Add disk space

See [CAPACITY_REMEDIATION_RUNBOOK.md](CAPACITY_REMEDIATION_RUNBOOK.md) for when disk hits 80%.

### Respond to an incident

1. Check [ESCALATION_POLICY.md](ESCALATION_POLICY.md) for severity and notification chain
2. Follow [COMMUNICATION_PLAN.md](COMMUNICATION_PLAN.md) for who to notify
3. After resolution, use [POST_INCIDENT_REVIEW_TEMPLATE.md](POST_INCIDENT_REVIEW_TEMPLATE.md)

### Deploy a change to production

See [DEPLOYMENT_PIPELINE.md](DEPLOYMENT_PIPELINE.md) for the full Dev -> Staging -> Production workflow.

### Rotate TDE certificate

See [KEY_ROTATION_RUNBOOK.md](KEY_ROTATION_RUNBOOK.md). Schedule annually or after suspected compromise.

### Handle a HIPAA breach

See [HIPAA_BREACH_NOTIFICATION.md](HIPAA_BREACH_NOTIFICATION.md). 60-day notification deadline.
