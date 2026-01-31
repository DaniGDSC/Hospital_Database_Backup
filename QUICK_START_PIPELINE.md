# Hospital Database Backup Project - Quick Start Pipeline

## 30-Second Overview

This project implements a complete hospital database backup and disaster recovery solution with 7 integrated phases. You can run the entire project in one command.

## Quick Start (3 options)

### Option 1: Run Everything (Recommended)
```bash
cd ~/hospital-db-backup-project
chmod +x run_all_phases.sh
./run_all_phases.sh
```
**Time**: ~2 hours | **Result**: Complete backup system with 11 automated jobs

### Option 2: Run One Phase
```bash
./run_all_phases.sh --phase 3
```
Replace `3` with phase number 1-7

### Option 3: Step-by-Step
```bash
./scripts/runners/run_phase.sh 1  # Database
./scripts/runners/run_phase.sh 2  # Security
./scripts/runners/run_phase.sh 3  # Backups
./scripts/runners/run_phase.sh 4  # Recovery
./scripts/runners/run_phase.sh 5  # Monitoring
./scripts/runners/run_phase.sh 6  # Testing
./scripts/runners/run_phase.sh 7  # Automation
```

---

## What Each Phase Does

| Phase | Name | What | Time |
|-------|------|------|------|
| 1 | Database | Creates 18 tables with 150+ records | 10 min |
| 2 | Security | TDE encryption, RBAC, audit logging | 10 min |
| 3 | Backup | Weekly full, daily diff, hourly logs (3-2-1 strategy) | 15 min |
| 4 | Recovery | 5 recovery methods tested | 10 min |
| 5 | Monitoring | Health checks, alerts, reports | 10 min |
| 6 | Testing | Disaster scenarios, security, load testing | 20 min |
| 7 | Automation | 11 SQL Agent jobs deployed | 15 min |

---

## Key Results After Pipeline

✅ **Database**: HospitalBackupDemo with 18 tables (153+ sample records)  
✅ **Security**: TDE encryption (AES-256), column encryption, 5 RBAC roles  
✅ **Backups**: Local full + S3 backup (WORM protected, immutable 90 days)  
✅ **Recovery**: RTO < 1 minute (vs 4h target) ✓ RPO < 1 minute (vs 1h target)  
✅ **Monitoring**: Real-time health checks, backup alerts, RPO/RTO validation  
✅ **Testing**: Disaster recovery scenarios, security tests, load testing  
✅ **Automation**: 11 production-ready SQL Agent jobs running continuously  

---

## Verify Success

### Check Database
```bash
sqlcmd -S 127.0.0.1,14333 -U SA -P 'Daniel@2410' \
  -Q "SELECT COUNT(*) AS Tables FROM INFORMATION_SCHEMA.TABLES WHERE TABLE_SCHEMA='dbo' AND TABLE_CATALOG='HospitalBackupDemo';"
```
Expected: **18** tables

### Check Encryption
```bash
sqlcmd -S 127.0.0.1,14333 -U SA -P 'Daniel@2410' -d master \
  -Q "SELECT encryption_state FROM sys.dm_database_encryption_keys WHERE database_id=DB_ID('HospitalBackupDemo');"
```
Expected: **3** (encrypted)

### Check Backups
```bash
ls -lh /var/opt/mssql/backup/full/
```
Expected: Full backup file (.bak)

### Check Jobs
```bash
sqlcmd -S 127.0.0.1,14333 -U SA -P 'Daniel@2410' -d msdb \
  -Q "SELECT COUNT(*) AS Jobs FROM sysjobs WHERE name LIKE 'HospitalBackup_%';"
```
Expected: **11** jobs

---

## Troubleshooting

**SQL Server won't connect?**
```bash
docker ps | grep mssql  # Check if running
docker logs mssql-server-latest  # View logs
```

**Phase fails?**
- Check log: `tail logs/pipeline_*.log`
- Run individual phase: `./scripts/runners/run_phase.sh 3`
- Re-run from current phase: `./run_all_phases.sh --phase 3`

**AWS S3 not working?**
```bash
./scripts/setup_aws_credentials.sh  # Reconfigure AWS
```

---

## Documentation

- **Full Pipeline Guide**: [RUN_PIPELINE.md](RUN_PIPELINE.md)
- **Phase Details**: See README.md in each `phases/phase*/` directory
- **Architecture**: See `docs/design/`
- **Configuration**: See `config/project.conf`

---

## Next Steps

After running the pipeline:

1. **Monitor Backups**: Check Phase 5 alerts daily
2. **Test Recovery**: Run Phase 4 recovery procedures monthly
3. **Review Jobs**: Monitor Phase 7 SQL Agent jobs in SSMS
4. **Set Alerts**: Configure email in Phase 5 EXECUTION_GUIDE.md
5. **Schedule Tests**: DR drills quarterly (Phase 6)

---

## Configuration

If SQL Server connection details differ, set environment variables:

```bash
export SQL_HOST=192.168.1.100
export SQL_PORT=1433
export SQL_USER=sa
export SQL_PASSWORD=YourPassword

./run_all_phases.sh
```

---

## Support

For detailed information on any phase:
```bash
cat phases/phase3-backup/README.md  # Example for phase 3
```

View pipeline logs:
```bash
tail -f logs/pipeline_*.log
```

---

**Ready to go?** Run this command:
```bash
cd ~/hospital-db-backup-project && chmod +x run_all_phases.sh && ./run_all_phases.sh
```
