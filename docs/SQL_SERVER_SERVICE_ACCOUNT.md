# SQL Server Service Account Documentation

**CIS Benchmark**: SQL Server must run as a non-root service account.

---

## Expected Configuration

| Item | Expected Value |
|---|---|
| Service user | `mssql` (not `root`) |
| Backup directory | `/var/opt/mssql/backup/` owned by `mssql` |
| Log directory | `/var/opt/mssql/log/` owned by `mssql` |
| Data directory | `/var/opt/mssql/data/` owned by `mssql` |

## Verification Commands

```bash
# Check SQL Server process owner
ps aux | grep sqlservr | grep -v grep

# Check mssql user exists
id mssql

# Check directory ownership
ls -la /var/opt/mssql/

# Automated check
./scripts/utilities/verify_service_account.sh
```

## Docker Environment

When SQL Server runs inside a Docker container (this project's setup),
the `sqlservr` process runs as `mssql` inside the container by default.
The Docker image `mcr.microsoft.com/mssql/server:2022-latest` configures
this automatically.

Verify inside container:
```bash
docker exec hospital-mssql whoami
# Expected output: mssql
```

## Remediation (if running as root)

If SQL Server is running as root on bare metal:

```bash
# 1. Stop SQL Server
sudo systemctl stop mssql-server

# 2. Change ownership
sudo chown -R mssql:mssql /var/opt/mssql/

# 3. Start SQL Server
sudo systemctl start mssql-server

# 4. Verify
ps aux | grep sqlservr
```
