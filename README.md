# Hospital Database Backup & Recovery Project

**Course**: INS3199 - Management System and Database Security  
**Topic**: Project 6 - Ransomware-Resistant Database Backup and Recovery Plan  
**Author**: [Your Name]  
**Student ID**: [Your ID]

## 📋 Project Overview

This project implements a comprehensive database backup and recovery system for a hospital management system, featuring:

- ✅ **3-2-1 Backup Strategy**: 3 copies, 2 media types, 1 off-site
- ✅ **Ransomware Protection**: Immutable S3 backups with WORM
- ✅ **Full Security**: RBAC, TDE, Column Encryption
- ✅ **Automated Recovery**: Documented disaster recovery procedures
- ✅ **Comprehensive Monitoring**: Health checks and alerts

## 🏗️ Project Structure
```
hospital-db-backup-project/
├── phases/phase1-database/         # Database schema and data
├── phases/phase2-security/         # RBAC, encryption, auditing
├── phases/phase3-backup/           # Backup automation
├── phases/phase4-recovery/         # Disaster recovery
├── phases/phase5-monitoring/       # Health monitoring
├── phases/phase6-testing/          # Testing and validation
├── phases/phase7-automation/       # SQL Agent jobs & automation
├── scripts/                 # Helper and runner scripts
├── config/                  # Configuration files
├── logs/                    # Execution logs
├── docs/                    # Documentation
├── reports/                 # Generated reports
└── certificates-backup/     # Certificate backups (SECURE!)
```

## 🚀 Quick Start

### 1. Initial Setup
```bash
# Navigate to project
cd ~/hospital-db-backup-project

# Edit configuration
nano config/project.conf

# Verify SQL Server connection
./scripts/utilities/test_connection.sh
```

### 2. Run Project Phases
```bash
# Phase 1: Create Database
./scripts/runners/run_phase.sh 1

# Phase 2: Implement Security
./scripts/runners/run_phase.sh 2

# Phase 3: Configure Backups
./scripts/runners/run_phase.sh 3

# Phase 4: Setup Recovery
./scripts/runners/run_phase.sh 4

# Phase 5: Enable Monitoring
./scripts/runners/run_phase.sh 5

# Phase 6: Run Tests
./scripts/runners/run_phase.sh 6

# Phase 7: Deploy Automation Jobs
./phases/phase7-automation/deploy_jobs.sh
```

### 3. Run Individual Scripts
```bash
# Run specific SQL script
./scripts/helpers/run_sql.sh phases/phase1-database/schema/01_create_database.sql

# Check logs
ls -lt logs/ | head -10
```

## 📚 Documentation

- **Design Documents**: `docs/design/`
- **Procedures**: `docs/procedures/`
- **DRP**: `phases/phase4-recovery/drp/`
- **Screenshots**: `docs/screenshots/`
- **Presentation**: `docs/presentations/`

## 🔒 Security Notes

- **CRITICAL**: Backup all certificates in `certificates-backup/`
- Store certificates off-site securely
- Change default SA password in production
- Restrict access to configuration files

## 📊 Monitoring & Alerts

- Health checks and dashboards available in Phase 5
- Backup verification runs daily at 01:00 AM
- Log backup chain validation runs hourly
- Alerts on stale backups (daily at 06:00 AM)
- Weekly reports generated

## 🧪 Testing

- Unit tests for each component
- Integration tests for workflows
- Monthly DR drills
- Documented in `phases/phase6-testing/`

## 📈 Recovery Objectives

- **Targets**: RTO 4 hours, RPO 1 hour (configurable in `config/project.conf`)
- **Observed**: RTO < 2 hours (weekly recovery drill), RPO < 15 minutes (hourly log backups)

## 📞 Support

For questions or issues, refer to:
- Project documentation in `docs/`
- Phase-specific READMEs
- Course materials

## 📄 License

Educational project for INS3199 course.
