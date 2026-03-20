# Infrastructure Runbook

**IaC Principle**: Automation + Verification + Audit Trail

---

## Architecture Overview

```
┌─────────────────────────────────────────────┐
│              Hospital Server                 │
│                                             │
│  ┌──────────────────────────────────┐       │
│  │ SQL Server 2022 (host or Docker) │       │
│  │   Port: 14333 (localhost only)   │       │
│  │   TDE: AES-256                   │       │
│  │   TLS: 1.2 (forceencryption)    │       │
│  └──────────────────────────────────┘       │
│                                             │
│  ┌──────────── Docker ──────────────┐       │
│  │ Grafana  :3000 (127.0.0.1)      │       │
│  │ Loki     :3100 (127.0.0.1)      │       │
│  │ Prometheus:9090 (127.0.0.1)     │       │
│  │ Promtail (no exposed port)      │       │
│  │ Node Exporter :9100 (127.0.0.1) │       │
│  └──────────────────────────────────┘       │
│                                             │
│  Backup: Local disk + AWS S3 Object Lock    │
│  Firewall: UFW (deny all, allow localhost)  │
└─────────────────────────────────────────────┘
```

---

## Quick Rebuild (from scratch)

**Time estimate**: 30-45 minutes | **RTO target**: 4 hours

```bash
# 1. Provision server (Ubuntu 24 LTS)
# 2. Clone repository
git clone https://github.com/DaniGDSC/Hospital_Database_Backup.git
cd Hospital_Database_Backup

# 3. Copy .env from secure storage
cp /secure/backup/.env .env
chmod 600 .env

# 4. Run setup (all steps verified + logged)
sudo bash scripts/setup_server.sh

# 5. Restore latest backup from S3
aws s3 cp s3://hospital-backup-prod-lock/full/[latest].bak /var/opt/mssql/backup/full/
sqlcmd -S 127.0.0.1,14333 -U hospital_dba_admin -P "$SQL_PASSWORD" -N -C \
    -Q "RESTORE DATABASE HospitalBackupDemo FROM DISK = '/var/opt/mssql/backup/full/[latest].bak' WITH REPLACE"

# 6. Senior DBA approval
bash scripts/utilities/approve_setup.sh logs/setup_[latest].log
```

---

## Environment-Specific Commands

| Environment | Start Command |
|---|---|
| **Development** | `docker compose -f docker-compose.yml -f docker-compose.dev.yml up -d` |
| **Staging** | `docker compose -f docker-compose.yml -f docker-compose.staging.yml up -d` |
| **Production** | `docker compose up -d` (uses base compose only) |

---

## Key Scripts

| Script | Purpose | When to Run |
|---|---|---|
| `scripts/setup_server.sh` | Full server setup with audit | New server build |
| `scripts/utilities/approve_setup.sh` | DBA approval of setup | After setup_server.sh |
| `scripts/utilities/test_rebuild.sh` | Destroy + rebuild test | Quarterly on dev only |
| `scripts/utilities/verify_versions.sh` | Version consistency check | Every deployment |
| `scripts/utilities/verify_tls_connection.sh` | TLS verification | After cert changes |
| `scripts/utilities/verify_network_security.sh` | Network hardening check | Weekly |

---

## Docker Volumes

| Volume | Contains | Backup Strategy |
|---|---|---|
| `sqlserver-data` | Database files | TDE encrypted, backed up via SQL Agent |
| `sqlserver-backup` | Local backup files | Uploaded to S3 by automation |
| `loki-data` | Log aggregation data | 30-day retention |
| `grafana-data` | Dashboard configs | Git-managed (config/grafana/) |
| `prometheus-data` | Metrics history | 15-day retention |

---

## Rebuild Test

Run quarterly on development:
```bash
APP_ENV=development bash scripts/utilities/test_rebuild.sh
```

Reports saved to: `reports/rebuild_test_[DATE].md`
