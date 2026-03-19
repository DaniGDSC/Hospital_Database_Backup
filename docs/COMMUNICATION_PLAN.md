# Incident Communication Plan

**HIPAA 45 CFR 164.308(a)(7)**: Contingency Plan
**Last Updated**: 2026-03-19

---

## Severity Levels

| Level | Definition | Example | Notify Within |
|---|---|---|---|
| **SEV-1 CRITICAL** | Database completely down; patient safety at risk | Server failure, ransomware, TDE cert loss | 15 minutes |
| **SEV-2 HIGH** | Backup failure or data at risk | Backup verification failed, S3 upload failed, RPO breach | 30 minutes |
| **SEV-3 MEDIUM** | Performance degradation; operations affected | Disk >80%, long-running queries, cert expiring | 2 hours |

---

## Notification Chain

### SEV-1 CRITICAL — Database Down

| Order | Role | Method | Response Time | Escalate If No Response |
|---|---|---|---|---|
| 1 | On-call DBA | Telegram (auto) + Phone | 5 min | 10 min → IT Manager |
| 2 | IT Manager | Phone call | 10 min | 15 min → Hospital Director |
| 3 | Hospital Director | Phone call | 15 min | 30 min → Emergency committee |
| 4 | Clinical Staff | PA system + Charge Nurse | Immediate | N/A |
| 5 | Patients (if breach) | Written mail (HIPAA) | 60 days | Legal team manages |

### SEV-2 HIGH — Data at Risk

| Order | Role | Method | Response Time |
|---|---|---|---|
| 1 | On-call DBA | Telegram (auto) + Email | 15 min |
| 2 | IT Manager | Email | 30 min |

### SEV-3 MEDIUM — Performance Issue

| Order | Role | Method | Response Time |
|---|---|---|---|
| 1 | On-call DBA | Email | 2 hours |

---

## Contact Directory

| Role | Name | Phone | Telegram | Email |
|---|---|---|---|---|
| Primary DBA | _[configure]_ | _[configure]_ | Via bot | _[configure]_ |
| Backup DBA | _[configure]_ | _[configure]_ | Via bot | _[configure]_ |
| IT Manager | _[configure]_ | _[configure]_ | N/A | _[configure]_ |
| Hospital Director | _[configure]_ | _[configure]_ | N/A | _[configure]_ |
| Legal/Compliance | _[configure]_ | _[configure]_ | N/A | _[configure]_ |

---

## Status Update Schedule

| Severity | Update Frequency | Channel |
|---|---|---|
| SEV-1 | Every 30 minutes | Telegram + Email |
| SEV-2 | Every 1 hour | Email |
| SEV-3 | Every 4 hours | Email |

---

## Message Templates

### SEV-1: Initial Notification
```
🔴 SEV-1 CRITICAL — HospitalBackupDemo

Database is DOWN. Patient care systems affected.
Timestamp: [TIME UTC]
DBA notified and investigating.
ETA: Unknown — next update in 30 minutes.
Manual procedures: ACTIVATE paper-based backup.
```

### SEV-1: Clinical Staff (PA Announcement)
```
"Attention all staff: The hospital IT system is temporarily
unavailable. Please use paper-based backup procedures until
further notice. Patient safety remains the top priority."
```

### Resolution Notification
```
🟢 RESOLVED — HospitalBackupDemo

Incident resolved at [TIME UTC].
Duration: [X hours Y minutes]
Root cause: [brief description]
Data loss: [None / X records / X hours]
Next steps: Post-incident review scheduled for [DATE].
```

---

## Automated Alerts

| Source | SEV-1 | SEV-2 | SEV-3 |
|---|---|---|---|
| Grafana | Telegram + Email | Telegram + Email | Email |
| SQL Agent jobs | Telegram | Telegram | Email |
| Bash scripts | Telegram | Telegram | Log only |

Script: `./scripts/utilities/send_incident_alert.sh SEV-1 "Database DOWN"`

---

## Post-Resolution

1. Notify all parties in **reverse order** (patients last)
2. Send resolution summary within 1 hour
3. Schedule post-incident review within 48 hours
4. File incident report: `reports/incidents/INC-[DATE]-[SEQ].md`
5. If PHI breach: initiate HIPAA notification process (see [HIPAA_BREACH_NOTIFICATION.md](HIPAA_BREACH_NOTIFICATION.md))
