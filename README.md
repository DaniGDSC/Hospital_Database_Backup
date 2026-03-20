# HospitalBackupDemo

**Hospital Database Backup & Recovery System**
Production Readiness Score: 100/100

A comprehensive database backup, security, and disaster recovery system for a hospital management database. Built on SQL Server 2022, this project implements HIPAA-compliant encryption, automated backups with ransomware-resistant S3 storage, real-time monitoring, and tested disaster recovery procedures.

**Course**: INS3199 — Management System and Database Security, VNU Hanoi
**Author**: DaniGDSC

---

## Architecture

```
                    ┌─────────────────────────────┐
                    │      Hospital Server         │
                    │                             │
  ┌─────────┐      │  ┌───────────────────────┐  │      ┌──────────────┐
  │ Grafana  │◄─────│──│ SQL Server 2022       │  │      │ AWS S3       │
  │ :3000    │      │  │ Port 14333 (TLS 1.2)  │──│─────►│ Object Lock  │
  │          │      │  │ TDE AES-256           │  │      │ (WORM)       │
  ├─────────┤      │  │ 18 tables, 5 RBAC     │  │      │ 6yr retain   │
  │Prometheus│◄─────│──│ 16 SQL Agent jobs     │  │      └──────────────┘
  │ :9090    │      │  └───────────────────────┘  │
  ├─────────┤      │                             │
  │  Loki   │◄─────│── Promtail (log shipper)    │
  │ :3100    │      │                             │
  └─────────┘      └─────────────────────────────┘

  Backup flow: DB ──► Local disk ──► AWS S3 (Object Lock)
  Alert flow:  SQL Agent / Grafana ──► Email + Telegram
```

## Prerequisites

| Tool | Version | Purpose |
|---|---|---|
| SQL Server | 2022 CU14+ | Database engine |
| AWS CLI | 2.15.0 | S3 backup uploads |
| Docker + Compose | 24.0+ | Monitoring stack |
| sqlcmd | 17.10+ | SQL script execution |
| Bash | 5.0+ | Orchestration |
| OpenSSL | 3.0+ | TLS + certificate encryption |

All versions are pinned in [`config/versions.conf`](config/versions.conf).

## Quick Start

```bash
# 1. Clone
git clone https://github.com/DaniGDSC/Hospital_Database_Backup.git
cd Hospital_Database_Backup

# 2. Configure secrets
cp .env.example .env
chmod 600 .env
nano .env  # Fill in all required passwords

# 3. Verify tools
bash scripts/utilities/verify_versions.sh

# 4. Deploy everything (7 phases)
bash run_all_phases.sh

# 5. Start monitoring stack
docker compose up -d

# 6. Access Grafana
# http://localhost:3000 (credentials in .env)
```

For production deployment, use the audited setup:
```bash
sudo bash scripts/setup_server.sh
```

## Project Structure

```
HospitalBackupDemo/
├── phases/                         # Database deployment (7 phases)
│   ├── phase1-database/            #   Schema, data, procedures, triggers
│   ├── phase2-security/            #   TDE, RBAC, audit, certificates
│   ├── phase3-backup/              #   Full/diff/log + S3 backup
│   ├── phase4-recovery/            #   Restore, PITR, DR scenarios
│   ├── phase5-monitoring/          #   Health checks, alerts, capacity
│   ├── phase6-testing/             #   Unit, integration, security, DR tests
│   └── phase7-automation/          #   16 SQL Agent jobs
├── scripts/                        # Operational scripts
│   ├── helpers/                    #   load_config.sh, run_sql.sh
│   ├── runners/                    #   run_phase.sh
│   └── utilities/                  #   40+ utility scripts
├── config/                         # Configuration
│   ├── grafana/                    #   Dashboards, alerts, datasources
│   ├── versions.conf               #   Pinned tool versions
│   ├── development.conf            #   Dev environment
│   ├── staging.conf                #   Staging environment
│   └── production.conf             #   Production environment
├── docs/                           # 14 runbooks and compliance docs
├── .github/workflows/              # CI/CD (3 pipelines)
├── docker-compose.yml              # Monitoring stack
├── Dockerfile                      # SQL Server environment image
├── run_all_phases.sh               # Main deployment orchestrator
└── .env.example                    # Secrets template
```

## Security & Compliance

| Standard | Status | Key Controls |
|---|---|---|
| **HIPAA** | Compliant | TDE AES-256, RBAC (5 roles), PHI audit triggers, session timeout, NationalID masking |
| **NIST SP 800-34** | Compliant | Backup verified (RESTORE VERIFYONLY), DR tested weekly, documented runbooks |
| **CIS SQL Server** | Hardened | SA disabled, xp_cmdshell restricted, OLE/CLR disabled, TLS 1.2 enforced |

**Encryption**: TDE (database-level) + column encryption (sensitive fields) + TLS 1.2 (connections) + AES-256 (S3 uploads)

**Access Control**: 5 RBAC roles (`app_readwrite`, `app_readonly`, `app_billing`, `app_security_admin`, `app_auditor`) with least-privilege enforcement

**Audit**: All PHI tables have INSERT/UPDATE/DELETE triggers logging WHO, WHAT, WHEN, WHERE. Audit logs are protected (DENY DELETE/UPDATE), exported nightly to S3 Object Lock (immutable 6-year retention).

## Backup Strategy

**3-2-1 Rule**: 3 copies, 2 media types (local disk + S3), 1 off-site (AWS)

| Type | Schedule | Retention (Local) | Retention (S3) |
|---|---|---|---|
| Full | Weekly (Sunday 02:00) | 7 days | 90 days |
| Differential | Daily (02:00) | 2 days | 30 days |
| Transaction Log | Hourly | 24 hours | 7 days |

**RPO**: 1 hour (log backup interval)
**RTO**: 4 hours target (measured: ~2 minutes for full restore)

Every backup is verified immediately with `RESTORE VERIFYONLY`. Failures trigger Telegram + email alerts.

## Monitoring

**3 Grafana Dashboards** (auto-provisioned):
- Backup Health — last backup times, verification status, storage trends
- Database Availability — connection count, TDE status, disk usage, cert expiry
- Security Monitor — failed logins, RBAC violations, PHI access patterns

**Alerting** (Email + Telegram):
- CRITICAL: backup failed, database offline, RPO breach, TDE disabled
- HIGH: disk >80%, cert expiring <30d, audit pipeline down
- MEDIUM: long queries, backup duration increasing

See [`docs/ESCALATION_POLICY.md`](docs/ESCALATION_POLICY.md) for notification chain.

## Environments

| Environment | Config | Database | S3 Bucket |
|---|---|---|---|
| Development | `development.conf` | `HospitalBackupDemo_Dev` | `hospital-backup-dev` |
| Staging | `staging.conf` | `HospitalBackupDemo_Staging` | `hospital-backup-staging` |
| Production | `production.conf` | `HospitalBackupDemo` | `hospital-backup-prod-lock` |

Production requires explicit `PRODUCTION_CONFIRMED=yes` and deployment approval (Separation of Duties). PHI never exists in dev/staging environments.

## CI/CD

| Pipeline | Trigger | What it does |
|---|---|---|
| `ci.yml` | Every push/PR | Secrets scan, ShellCheck, SQL lint, unit tests |
| `cd-staging.yml` | Merge to main | Deploy to staging, integration tests, DR drill |
| `cd-production.yml` | Manual only | Approval gate, version check, deploy, verify |

## Key Documentation

| Document | Purpose |
|---|---|
| [`INFRASTRUCTURE_RUNBOOK.md`](docs/INFRASTRUCTURE_RUNBOOK.md) | Server rebuild procedure |
| [`COMMUNICATION_PLAN.md`](docs/COMMUNICATION_PLAN.md) | Incident notification chain |
| [`ESCALATION_POLICY.md`](docs/ESCALATION_POLICY.md) | Alert severity + routing |
| [`SECRETS_ROTATION_RUNBOOK.md`](docs/SECRETS_ROTATION_RUNBOOK.md) | Password rotation procedures |
| [`KEY_ROTATION_RUNBOOK.md`](docs/KEY_ROTATION_RUNBOOK.md) | TDE certificate rotation |
| [`ROLLBACK_RUNBOOK.md`](docs/ROLLBACK_RUNBOOK.md) | Schema change rollback |
| [`HIPAA_BREACH_NOTIFICATION.md`](docs/HIPAA_BREACH_NOTIFICATION.md) | Breach response + HHS reporting |
| [`CAPACITY_REMEDIATION_RUNBOOK.md`](docs/CAPACITY_REMEDIATION_RUNBOOK.md) | Disk space remediation |
| [`DEPLOYMENT_PIPELINE.md`](docs/DEPLOYMENT_PIPELINE.md) | Dev -> Staging -> Prod workflow |
| [`PATCHING_SCHEDULE.md`](docs/PATCHING_SCHEDULE.md) | SQL Server + tool update policy |

## Troubleshooting

| Problem | Solution |
|---|---|
| `SQL_PASSWORD environment variable required` | Copy `.env.example` to `.env` and fill in passwords |
| Phase 2 fails: "database does not exist" | Run Phase 1 first: `bash run_all_phases.sh --phase 1` |
| Backup verification FAILED | Check disk space, review `/var/opt/mssql/backup/` permissions |
| Telegram alerts not sending | Verify `TELEGRAM_BOT_TOKEN` and `TELEGRAM_CHAT_ID` in `.env` |
| Grafana shows no data | Ensure Docker stack is running: `docker compose ps` |

## License

Academic project for INS3199 — Management System and Database Security, VNU Hanoi.
