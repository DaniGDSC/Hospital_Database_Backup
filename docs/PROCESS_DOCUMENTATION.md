# HospitalBackupDemo — Process Documentation

Comprehensive workflow documentation for the Hospital Database Backup & Recovery System.

**Audience**: New DBA or engineer taking over this system.
**Last updated**: 2026-03-20

---

## Table of Contents

1. [System Architecture](#1-system-architecture)
2. [Deploy Workflow](#2-deploy-workflow)
3. [Daily Operations](#3-daily-operations)
4. [Maintenance Calendar](#4-maintenance-calendar)
5. [Change Management](#5-change-management)
6. [Secret Rotation](#6-secret-rotation)
7. [Disaster Recovery](#7-disaster-recovery)
8. [HIPAA Breach Response](#8-hipaa-breach-response)

---

## 1. System Architecture

```mermaid
graph TB
    subgraph "Developer Machine"
        DEV["Developer"] --> GIT["Git Repository<br/>github.com/DaniGDSC"]
    end

    subgraph "CI/CD — GitHub Actions"
        GIT --> CI["CI Pipeline<br/>Secrets + Lint + Tests"]
        CI --> CD_S["CD Staging<br/>Auto Deploy"]
        CD_S --> CD_P["CD Production<br/>Manual + Approval"]
    end

    subgraph "Production Server"
        subgraph "SQL Server 2022"
            DB[("HospitalBackupDemo<br/>TDE AES-256 + RBAC")]
            JOBS["16 SQL Agent Jobs"]
        end
        subgraph "Backup Storage"
            LOCAL["Local Disk<br/>/var/opt/mssql/backup"]
            S3[("AWS S3 Object Lock<br/>WORM — 6yr retention")]
        end
        subgraph "Monitoring — Docker"
            GRAF["Grafana :3000<br/>3 Dashboards"]
            PROM["Prometheus :9090<br/>Metrics"]
            LOKI["Loki :3100<br/>Logs"]
            TAIL["Promtail<br/>Log Shipper"]
        end
    end

    subgraph "Alert Channels"
        EMAIL["Email<br/>Layer 1"]
        TG["Telegram<br/>Layer 2"]
    end

    DB --> LOCAL
    LOCAL --> S3
    DB --> JOBS
    JOBS --> LOCAL
    JOBS --> EMAIL
    JOBS --> TG
    TAIL --> LOKI
    LOKI --> GRAF
    PROM --> GRAF
    GRAF --> EMAIL
    GRAF --> TG
```

### Components

| Component | Purpose | Port |
| --- | --- | --- |
| **SQL Server 2022** | Hospital database, 18 tables, TDE encrypted | 14333 (localhost) |
| **16 SQL Agent Jobs** | Backup, monitoring, DR drills, alerts | Internal |
| **Local Backup** | Full (weekly), Diff (daily), Log (hourly) | Filesystem |
| **AWS S3 Object Lock** | Ransomware-resistant off-site backup, 6-year audit retention | HTTPS |
| **Grafana** | 3 dashboards: Backup Health, DB Availability, Security | 3000 (localhost) |
| **Prometheus** | Metrics collection (DB, disk, backup sizes) | 9090 (localhost) |
| **Loki + Promtail** | Centralized log aggregation (4 log types) | 3100 (localhost) |
| **Email** | Layer 1 alerting via Database Mail | SMTP |
| **Telegram** | Layer 2 alerting via bot API | HTTPS |

---

## 2. Deploy Workflow

### 2.1 First-Time Server Setup

```mermaid
sequenceDiagram
    actor DBA as Senior DBA
    participant S as Server
    participant SQL as SQL Server
    participant MON as Monitoring Stack
    participant TG as Telegram

    DBA->>S: 1. Clone repository
    DBA->>S: 2. Copy .env from secure storage
    DBA->>S: 3. bash scripts/setup_server.sh

    Note over S: 12 automated steps (execute + verify + log)

    S->>S: Step 1-3: Load config, validate secrets, check versions
    S->>S: Step 4-5: Docker available, start monitoring
    S->>SQL: Step 6-7: Verify SQL Server, wait for ready
    S->>SQL: Step 8: Deploy all 7 phases (run_all_phases.sh)
    S->>S: Step 9-10: Verify TDE, verify audit protection
    S->>S: Step 11-12: Verify Grafana, verify Loki

    alt Any step fails
        S->>TG: CRITICAL: Setup FAILED
        S-->>DBA: Review setup log
    end

    S-->>DBA: Setup complete — review required
    DBA->>S: bash scripts/utilities/approve_setup.sh
    DBA->>TG: INFO: System approved and LIVE
```

**Responsible**: Senior DBA
**Time estimate**: 30-45 minutes
**Reference**: [INFRASTRUCTURE_RUNBOOK.md](INFRASTRUCTURE_RUNBOOK.md)

### 2.2 Seven-Phase Deployment

```mermaid
graph LR
    P1["Phase 1<br/>Database<br/>18 tables + data"] --> P2
    P2["Phase 2<br/>Security<br/>TDE + RBAC + Audit"] --> P3
    P3["Phase 3<br/>Backup<br/>Full + Diff + Log + S3"] --> P4
    P4["Phase 4<br/>Recovery<br/>PITR + S3 Restore"] --> P5
    P5["Phase 5<br/>Monitoring<br/>Health + Alerts + Capacity"] --> P6
    P6["Phase 6<br/>Testing<br/>10 DR Scenarios"] --> P7
    P7["Phase 7<br/>Automation<br/>16 SQL Agent Jobs"]
```

| Phase | Creates | Key Objects | Time |
| --- | --- | --- | --- |
| **1. Database** | Schema + seed data | 18 tables, 40+ indexes, 2 procedures, 2 views | ~2 min |
| **2. Security** | Encryption + access control | TDE cert, master key, 5 RBAC roles, audit triggers, session timeout | ~1 min |
| **3. Backup** | Backup infrastructure | usp_PerformBackup (with VERIFYONLY), S3 credential, verification log | ~1 min |
| **4. Recovery** | Restore procedures | Full restore, PITR, S3 restore, cloud-chain restore, validation | ~30s |
| **5. Monitoring** | Observability | Health checks, 3 alert scripts, capacity tables, PHI access report | ~30s |
| **6. Testing** | Test framework | Schema integrity, RBAC validation, CIS benchmark, 10 DR scenarios | ~30s |
| **7. Automation** | SQL Agent jobs | 16 jobs covering backup, monitoring, security, reporting | ~1 min |

**Total deployment**: ~6-7 minutes for all phases.

---

## 3. Daily Operations

### 3.1 24-Hour Timeline

```mermaid
gantt
    title Daily Automated Operations
    dateFormat HH:mm
    axisFormat %H:%M

    section Backup
    Log Backup (hourly)         :crit, 00:00, 24h
    Audit Export to S3          :01:00, 30m
    Differential Backup         :02:00, 15m
    Full Backup (Sunday only)   :milestone, 02:00, 0m
    Backup Verify               :06:00, 15m
    Backup Staleness Alert      :06:30, 10m

    section Security
    Session Timeout (every 5m)  :00:00, 24h
    Disaster Detection (5m)     :00:00, 24h
    Log Backup Chain Check      :00:00, 24h

    section Monitoring
    Capacity Collection         :23:00, 30m
    Metrics Export (60s)        :00:00, 24h

    section Weekly (Sunday)
    Full Backup                 :02:00, 2h
    DR Drill                    :03:00, 30m
    PHI Access Report           :06:00, 15m
```

### 3.2 Backup Flow

```mermaid
flowchart TD
    START(["SQL Agent Job Triggers"]) --> TYPE{"Backup Type?"}

    TYPE -->|"Hourly"| LOG["Log Backup<br/>usp_PerformBackup 'LOG'"]
    TYPE -->|"Daily"| DIFF["Differential Backup<br/>usp_PerformBackup 'DIFFERENTIAL'"]
    TYPE -->|"Weekly"| FULL["Full Backup<br/>usp_PerformBackup 'FULL'"]

    LOG --> CHECKSUM{"CHECKSUM<br/>valid?"}
    DIFF --> CHECKSUM
    FULL --> CHECKSUM

    CHECKSUM -->|"Fail"| ALERT_C["🔴 Telegram + Email<br/>Backup checksum failed"]
    CHECKSUM -->|"Pass"| VERIFY["RESTORE VERIFYONLY<br/>WITH CHECKSUM"]

    VERIFY -->|"Fail"| ALERT_V["🔴 Telegram + Email<br/>Backup file corrupt"]
    VERIFY -->|"Pass"| LOG_VER["Log to BackupVerificationLog<br/>Status = PASS"]

    LOG_VER --> LOCAL["Save to local disk<br/>/var/opt/mssql/backup/"]

    LOCAL --> S3{"Full backup?"}
    S3 -->|"Yes"| UPLOAD["Upload to S3<br/>SSE-KMS + Object Lock"]
    S3 -->|"No"| DONE(["Complete"])

    UPLOAD --> S3_CHECK{"S3 verify<br/>file exists + size match?"}
    S3_CHECK -->|"Fail"| ALERT_S3["🔴 Telegram<br/>S3 upload failed"]
    S3_CHECK -->|"Pass"| DONE

    ALERT_C --> DONE
    ALERT_V --> DONE
    ALERT_S3 --> DONE
```

### 3.3 Alert Escalation

```mermaid
flowchart TD
    EVENT(["System Event"]) --> SEV{"Severity?"}

    SEV -->|"🔴 CRITICAL"| C1["Email + Telegram<br/>immediately"]
    SEV -->|"🟡 WARNING"| W1["Email + Telegram<br/>5 min delay"]
    SEV -->|"🟢 INFO"| I1["Email only<br/>no escalation"]

    C1 --> ACK1{"DBA acknowledges<br/>within 15 min?"}
    ACK1 -->|"Yes"| RESOLVE["Investigate + Resolve"]
    ACK1 -->|"No"| C2["Repeat Telegram<br/>⚠️ UNACKNOWLEDGED"]

    C2 --> ACK2{"Acknowledges<br/>within 30 min?"}
    ACK2 -->|"Yes"| RESOLVE
    ACK2 -->|"No"| C3["Manual phone call<br/>to on-call chain"]
    C3 --> RESOLVE

    W1 --> RESOLVE

    RESOLVE --> PIR["Post-Incident Review<br/>within 24 hours"]
```

**Reference**: [ESCALATION_POLICY.md](ESCALATION_POLICY.md) | [COMMUNICATION_PLAN.md](COMMUNICATION_PLAN.md)

### 3.4 Morning Dashboard Check

**What to check every morning (5 minutes)**:

| Dashboard | Panel | Green | Yellow | Red |
| --- | --- | --- | --- | --- |
| **Backup Health** | Last Log Backup | < 1 hour ago | 1-2 hours | > 2 hours (RPO breach) |
| **Backup Health** | Last Full Backup | < 7 days | 7-10 days | > 10 days |
| **Backup Health** | Verification | 100% pass | Any fail in 7 days | Fail in last 24h |
| **DB Availability** | Database Status | ONLINE | RECOVERING | OFFLINE |
| **DB Availability** | Disk Usage | < 60% | 60-80% | > 80% |
| **DB Availability** | Cert Expiry | > 60 days | 30-60 days | < 30 days |
| **Security** | Failed Logins/hour | < 5 | 5-20 | > 20 (brute force?) |
| **Security** | RBAC Violations | 0 | 1-5 | > 5 (investigate!) |

**When to escalate**: Any red panel. Any yellow panel persisting > 24 hours.

---

## 4. Maintenance Calendar

```mermaid
graph TD
    subgraph "Daily — Automated"
        D1["Backup verify (06:00)"]
        D2["Capacity metrics (23:00)"]
        D3["Audit export to S3 (01:00)"]
        D4["Session timeout (every 5m)"]
    end

    subgraph "Weekly — Automated + Review"
        W1["Full backup + DR drill (Sun 02:00)"]
        W2["PHI access report (Sun 06:00)"]
        W3["TLS cert check (Mon 08:00)"]
        W4["Review Grafana dashboards"]
    end

    subgraph "Monthly — Manual"
        M1["Patch level check (1st Mon)"]
        M2["Tool version check"]
        M3["Capacity forecast review"]
        M4["Security events review"]
    end

    subgraph "Quarterly — Manual"
        Q1["Rebuild test on Dev"]
        Q2["Certificate expiry review"]
        Q3["HIPAA compliance review"]
    end

    subgraph "Annual — Manual"
        A1["TDE certificate rotation"]
        A2["Full security audit"]
        A3["DR documentation update"]
    end
```

**Reference**: [MAINTENANCE_GUIDE.md](../docs/MAINTENANCE_GUIDE.md)

---

## 5. Change Management

### Dev to Staging to Production

```mermaid
sequenceDiagram
    actor Dev as Developer
    actor SDBA as Senior DBA
    participant GIT as GitHub
    participant CI as CI Pipeline
    participant STG as Staging
    participant PROD as Production

    Dev->>GIT: Push to feature branch
    GIT->>CI: Trigger CI pipeline

    Note over CI: Secrets scan (gitleaks)<br/>ShellCheck + sqlfluff<br/>Unit + security tests

    alt CI Fails
        CI-->>Dev: ❌ Fix and re-push
    end

    Dev->>GIT: Create Pull Request
    SDBA->>GIT: Code review + approve
    GIT->>GIT: Merge to main

    GIT->>STG: Auto-deploy (cd-staging.yml)
    Note over STG: Integration tests<br/>DR drill<br/>Backup roundtrip

    alt Staging Fails
        STG-->>SDBA: ❌ Investigate
    end

    SDBA->>PROD: Manual trigger (cd-production.yml)
    Note over PROD: Input: approver, reason, window

    PROD->>PROD: Verify approver ≠ deployer
    PROD->>PROD: Version consistency check
    PROD->>PROD: Pre-deployment backup
    PROD->>PROD: Deploy + post-deploy tests

    PROD-->>SDBA: ✅ Deployment complete
    SDBA->>SDBA: Update CHANGELOG.md
```

| Gate | Who | Automated? |
| --- | --- | --- |
| CI pipeline (lint, test, scan) | System | Yes — every push |
| Code review | Senior DBA | Manual |
| Staging deploy | System | Yes — on merge |
| Staging tests | System | Yes |
| Production trigger | Senior DBA | Manual (workflow_dispatch) |
| Self-approval check | System | Yes — enforced in code |
| Post-deploy verification | System | Yes |

**Reference**: [DEPLOYMENT_PIPELINE.md](DEPLOYMENT_PIPELINE.md)

---

## 6. Secret Rotation

```mermaid
flowchart TD
    TRIGGER(["Rotation Trigger<br/>Scheduled or Incident"]) --> TYPE{"Which secret?"}

    TYPE -->|"SQL Password"| SQL_ROT["ALTER LOGIN<br/>WITH PASSWORD"]
    TYPE -->|"TDE Certificate"| CERT_ROT["Create new cert<br/>Backup to S3<br/>Rotate encryption key"]
    TYPE -->|"AWS Keys"| AWS_ROT["Generate new IAM keys<br/>in AWS Console"]
    TYPE -->|"SMTP Password"| SMTP_ROT["Update Gmail<br/>+ Database Mail account"]
    TYPE -->|"App Login"| APP_ROT["ALTER LOGIN<br/>for each RBAC user"]

    SQL_ROT --> UPDATE[".env update<br/>on all servers"]
    CERT_ROT --> UPDATE
    AWS_ROT --> UPDATE
    SMTP_ROT --> UPDATE
    APP_ROT --> UPDATE

    UPDATE --> TEST{"Test connection<br/>with new secret?"}
    TEST -->|"Fail"| ROLLBACK["Rollback to old secret<br/>Investigate failure"]
    TEST -->|"Pass"| VERIFY["Verify all SQL Agent jobs<br/>still running"]
    VERIFY --> LOG["Log rotation<br/>to SecurityAuditEvents"]
    LOG --> DONE(["Complete"])
    ROLLBACK --> DONE
```

| Secret | Rotation | Runbook |
| --- | --- | --- |
| SQL SA / DBA Admin | Every 90 days | [SECRETS_ROTATION_RUNBOOK.md](SECRETS_ROTATION_RUNBOOK.md) |
| RBAC app logins (4) | Every 90 days | [SECRETS_ROTATION_RUNBOOK.md](SECRETS_ROTATION_RUNBOOK.md) |
| TDE Certificate | Annually | [KEY_ROTATION_RUNBOOK.md](KEY_ROTATION_RUNBOOK.md) |
| Master Key | Annually | [KEY_ROTATION_RUNBOOK.md](KEY_ROTATION_RUNBOOK.md) |
| SMTP Password | When changed in Gmail | [SECRETS_ROTATION_RUNBOOK.md](SECRETS_ROTATION_RUNBOOK.md) |
| AWS Keys | Every 90 days | [SECRETS_ROTATION_RUNBOOK.md](SECRETS_ROTATION_RUNBOOK.md) |

---

## 7. Disaster Recovery

### 7.1 DR Decision Tree

```mermaid
flowchart TD
    DISASTER(["🔴 Disaster Detected"]) --> ASSESS{"What failed?"}

    ASSESS -->|"Database corrupt"| CORRUPT["Run DBCC CHECKDB<br/>Check last clean backup"]
    ASSESS -->|"Server destroyed"| REBUILD["Rebuild server<br/>setup_server.sh"]
    ASSESS -->|"Ransomware"| RANSOM["ISOLATE server<br/>Do NOT pay ransom<br/>Do NOT reboot"]
    ASSESS -->|"S3 access lost"| S3_FAIL["Check AWS creds<br/>Verify bucket policy"]
    ASSESS -->|"TDE cert lost"| CERT_FAIL["Restore cert from<br/>offline backup or S3"]
    ASSESS -->|"Accidental DROP"| DROP["Identify dropped objects<br/>Check backup chain"]

    CORRUPT --> PITR{"Point-in-time<br/>needed?"}
    PITR -->|"Yes"| PITR_R["01_point_in_time_restore.sql<br/>Stop at target time"]
    PITR -->|"No"| FULL_R["01_full_restore.sql<br/>Latest full + chain"]

    REBUILD --> S3_R["Restore from S3<br/>02_cloud_base_with_local_chain.sql"]
    RANSOM --> REBUILD
    DROP --> PITR_R

    S3_FAIL --> LOCAL_R["Restore from local disk<br/>01_full_restore.sql"]
    CERT_FAIL --> CERT_R["Restore cert<br/>Then restore database"]

    FULL_R --> VALIDATE["01_recovery_validation.sql<br/>CHECKDB + row counts"]
    PITR_R --> VALIDATE
    S3_R --> VALIDATE
    LOCAL_R --> VALIDATE
    CERT_R --> VALIDATE

    VALIDATE -->|"Fail"| ESCALATE["🔴 Escalate to<br/>Senior DBA + IT Manager"]
    VALIDATE -->|"Pass"| MEASURE["Measure actual RTO<br/>Compare vs target"]

    MEASURE --> PIR["Post-Incident Review<br/>within 24 hours"]
    PIR --> HIPAA{"PHI exposed?"}
    HIPAA -->|"Yes"| BREACH["HIPAA Breach Process<br/>(Section 8)"]
    HIPAA -->|"No"| CLOSE["Close incident<br/>Update runbook"]
```

### 7.2 Recovery Targets (10 Scenarios)

| # | Scenario | Severity | RPO | RTO Target | Recovery Script |
| --- | --- | --- | --- | --- | --- |
| DS-001 | Ransomware encryption | Critical | 1h | 4h | `01_ransomware_drill.sql` |
| DS-002 | Accidental DROP TABLE | High | 2h | 2h | `01_point_in_time_restore.sql` |
| DS-003 | Disk drive failure | Critical | 1h | 3h | `01_full_restore.sql` |
| DS-004 | SQL injection mass DELETE | Critical | 4h | 3h | `01_point_in_time_restore.sql` |
| DS-005 | DB corruption (power failure) | High | 2h | 4h | `01_full_restore.sql` |
| DS-006 | Complete server failure | Critical | 1h | 6h | `02_cloud_base_with_local_chain.sql` |
| DS-007 | Ransomware + local backups | Critical | 12h | 5h | `01_restore_full_from_s3.sql` |
| DS-008 | App bug data inconsistency | Medium | 6h | 3h | `01_point_in_time_restore.sql` |
| DS-009 | Datacenter outage | Critical | 4h | 8h | `01_restore_full_from_s3.sql` |
| DS-010 | Malicious insider | Critical | 24h | 6h | S3 immutable backup restore |

**Measured performance** (DR drill 2026-01-09):
- RTO actual: **1.43 minutes** (target: 4 hours) — 98% margin
- RPO actual: **~3 minutes** (target: 1 hour) — 95% margin

### 7.3 Recovery Scripts

| Script | Path | What It Does |
| --- | --- | --- |
| Full restore | `phase4-recovery/full-restore/01_full_restore.sql` | Latest full backup to `_Recovery` DB |
| Cloud-chain | `phase4-recovery/full-restore/02_cloud_base_with_local_chain.sql` | S3 full + local diff + log chain |
| S3 restore | `phase4-recovery/from-s3/01_restore_full_from_s3.sql` | Direct restore from S3 URL |
| PITR | `phase4-recovery/point-in-time/01_point_in_time_restore.sql` | Restore to specific timestamp |
| Validation | `phase4-recovery/testing/01_recovery_validation.sql` | CHECKDB + row counts on restored DBs |

---

## 8. HIPAA Breach Response

```mermaid
sequenceDiagram
    actor DBA as DBA
    actor ITM as IT Manager
    actor LEGAL as Legal Team
    actor HHS as HHS (Gov)
    actor PT as Patients

    Note over DBA: Day 0: Breach discovered

    DBA->>DBA: Run breach_assessment.sh
    DBA->>ITM: Notify within 1 hour

    Note over DBA,ITM: Day 1-3: Investigation

    ITM->>LEGAL: Notify within 24 hours
    LEGAL->>LEGAL: 4-factor risk assessment

    alt Breach NOT confirmed
        LEGAL-->>ITM: Document and close
    end

    alt Breach confirmed
        Note over DBA,PT: 60-day notification window begins

        LEGAL->>LEGAL: Day 7: Internal report complete
        LEGAL->>ITM: Day 30: Draft patient letters

        ITM->>PT: Day 30-60: Patient notification by mail
        ITM->>HHS: Day 60: Report via ocrportal.hhs.gov

        alt 500+ patients affected
            ITM->>ITM: Press release to media
        end
    end
```

### Breach Classification

| Size | HHS Notification | Media | Timeline |
| --- | --- | --- | --- |
| < 500 individuals | Annual report | No | End of calendar year |
| >= 500 individuals | Immediate | Yes (if same state) | Within 60 days |

### Key Contacts

| Role | Responsibility | When Notified |
| --- | --- | --- |
| On-call DBA | Initial detection + containment | Immediately |
| IT Manager | Incident coordination | Within 1 hour |
| Legal Team | Risk assessment + notifications | Within 24 hours |
| Hospital Director | Patient care impact decisions | If outage > 30 min |
| HHS | Government reporting | Within 60 days (if breach) |

**Reference**: [HIPAA_BREACH_NOTIFICATION.md](HIPAA_BREACH_NOTIFICATION.md) | [POST_INCIDENT_REVIEW_TEMPLATE.md](POST_INCIDENT_REVIEW_TEMPLATE.md)

---

## Quick Reference: All Runbooks

| Situation | Runbook |
| --- | --- |
| Server rebuild from scratch | [INFRASTRUCTURE_RUNBOOK.md](INFRASTRUCTURE_RUNBOOK.md) |
| Disk space > 80% | [CAPACITY_REMEDIATION_RUNBOOK.md](CAPACITY_REMEDIATION_RUNBOOK.md) |
| Rotate passwords | [SECRETS_ROTATION_RUNBOOK.md](SECRETS_ROTATION_RUNBOOK.md) |
| Rotate TDE certificate | [KEY_ROTATION_RUNBOOK.md](KEY_ROTATION_RUNBOOK.md) |
| Deploy to production | [DEPLOYMENT_PIPELINE.md](DEPLOYMENT_PIPELINE.md) |
| Rollback a bad deploy | [ROLLBACK_RUNBOOK.md](ROLLBACK_RUNBOOK.md) |
| Incident response | [COMMUNICATION_PLAN.md](COMMUNICATION_PLAN.md) + [ESCALATION_POLICY.md](ESCALATION_POLICY.md) |
| PHI breach detected | [HIPAA_BREACH_NOTIFICATION.md](HIPAA_BREACH_NOTIFICATION.md) |
| After any incident | [POST_INCIDENT_REVIEW_TEMPLATE.md](POST_INCIDENT_REVIEW_TEMPLATE.md) |
| SQL Server patching | [PATCHING_SCHEDULE.md](PATCHING_SCHEDULE.md) |
| Network/TLS issues | [NETWORK_SECURITY.md](NETWORK_SECURITY.md) |
| Routine maintenance | [MAINTENANCE_GUIDE.md](MAINTENANCE_GUIDE.md) |
