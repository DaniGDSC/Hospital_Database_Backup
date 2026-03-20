# Changelog

All notable changes to HospitalBackupDemo are documented here.

## [1.0.0] — 2026-03-20 — Production Ready (100/100)

### Tier 1 — Patient Safety (Critical)

- Backup verification with `RESTORE VERIFYONLY` after every backup
- TDE certificate backup to S3 with client-side AES-256 encryption
- Master key and certificate passwords removed from source code
- Audit log protection: `DENY DELETE/UPDATE`, DDL trigger blocking `DROP/TRUNCATE`
- Audit logs exported nightly to S3 Object Lock (6-year immutable retention)
- SA account disabled, replaced with named `hospital_dba_admin` login
- All passwords parameterized via `.env` and sqlcmd variables

### Tier 2 — Compliance (High)

- Multi-channel alerting: Email (Database Mail) + Telegram bot
- Centralized log management: Loki + Promtail shipping 4 log types
- Grafana dashboards: Backup Health, DB Availability, Security Monitor (28 panels)
- HIPAA technical safeguards: session timeout enforcement, PHI audit triggers on 5 tables
- NationalID masking in audit logs (last 4 digits only)
- Change management: pre-commit hooks (gitleaks + shellcheck), deployment approval gate
- Schema migration tracking with `SchemaVersionHistory` table

### Tier 3 — Operational Excellence (Medium)

- Environment separation: Dev / Staging / Production with isolated configs and S3 buckets
- DR documentation: 10 scenarios with execution scripts, communication plan, breach notification
- Capacity planning: daily collection, linear regression forecasting, remediation runbook
- SQL Server hardening: CIS Benchmark (SA disabled, xp_cmdshell restricted, OLE/CLR off)
- Network security: TLS 1.2, firewall rules, Docker ports bound to localhost

### Tier 4 — DevSecOps Maturity (Low)

- CI/CD: 3 GitHub Actions pipelines (CI on push, CD staging on merge, CD production manual)
- Infrastructure as Code: Dockerfile, docker-compose (3 environments), `setup_server.sh` with audit trail
- Dependency management: `versions.conf` pinning all tool versions, monthly patch checks
- Secrets scanning: gitleaks pre-commit + manual scan script

## [0.1.0] — 2026-01-09 — Initial Implementation

### Added

- 7-phase deployment pipeline (`run_all_phases.sh`)
- Hospital database schema: 18 tables with sample data (150 records per table)
- Stored procedures, functions, views, triggers
- TDE AES-256 encryption + column-level encryption
- RBAC: 5 roles with least-privilege permissions
- 3-2-1 backup strategy: full (weekly), differential (daily), log (hourly)
- S3 Object Lock (WORM) for ransomware-resistant off-site backups
- Disaster recovery: full restore, PITR, S3 restore, DR drill
- Health checks, alerts (email), weekly reports
- 11 SQL Agent automation jobs
- First DR drill report: `disaster_recovery_drill_20260109.md`
