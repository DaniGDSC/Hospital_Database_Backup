# Alert Escalation Policy

**System**: HospitalBackupDemo
**Channels**: Email (Layer 1) + Telegram (Layer 2)

---

## Severity Definitions

| Severity | Meaning | Examples |
|---|---|---|
| **CRITICAL** | Patient safety risk or data loss | Backup failed, TDE disabled, database offline, DR drill failed |
| **WARNING** | Approaching limits, performance degradation | Disk >80%, log backup >45 min old, cert expiring in <30 days |
| **INFO** | Successful operations, scheduled events | Backup completed, deployment succeeded, DR drill passed |

---

## Escalation Tiers

### Tier 1 — Automated (0-15 minutes)
- Email + Telegram sent simultaneously for CRITICAL/HIGH
- Email only for MEDIUM
- DBA expected to acknowledge within 15 minutes

### Tier 2 — Repeat Escalation (15-30 minutes)
- If CRITICAL alert not acknowledged:
  - Telegram resent with prefix: "UNACKNOWLEDGED — 15 min passed"
  - Email resent with URGENT subject line
- Grafana repeat interval handles this automatically (30 min for CRITICAL)

### Tier 3 — Manual Escalation (30+ minutes)
- Phone call required to on-call DBA
- Contact order:
  1. Primary DBA: _[configure in production]_
  2. Senior DBA: _[configure in production]_
  3. IT Manager: _[configure in production]_
- Future: PagerDuty/OpsGenie for automated phone escalation

---

## Channel Routing

| Severity | Email | Telegram | Repeat Interval |
|---|---|---|---|
| CRITICAL | Yes | Yes | Every 30 min |
| HIGH/WARNING | Yes | Yes | Every 1 hour |
| MEDIUM | Yes | No | Every 4 hours |
| INFO | No | No (on-demand) | None |

---

## Alert Sources

| Source | Channel | Trigger |
|---|---|---|
| Grafana | Email + Telegram | Metric threshold crossed |
| SQL Agent jobs | Telegram via `usp_SendTelegramAlert` | Job failure |
| Bash scripts | Telegram via `send_telegram.sh` | Script failure |
| All sources | AuditLog | Every alert logged regardless of delivery |

---

## Verification

Daily health check at 08:00 AM (`check_alert_health.sh`):
- Sends test Telegram message — verifies delivery
- Checks Grafana alerting is active
- Checks Database Mail profile exists
- If any channel unhealthy: sends WARNING via remaining channels
