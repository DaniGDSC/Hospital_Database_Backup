## Phase 5: Monitoring & Alerting - Execution Guide

### Overview
Phase 5 provides comprehensive monitoring and alerting for the hospital database backup and recovery infrastructure. This guide explains how to configure and execute the monitoring components.

### Quick Start

#### Run Health Checks (Manual)
```bash
sqlcmd -S 127.0.0.1,14333 -U SA -P 'Daniel@2410' -i phases/phase5-monitoring/health-checks/01_health_check.sql
```

#### Run Backup Alerts (Manual)
```bash
sqlcmd -S 127.0.0.1,14333 -U SA -P 'Daniel@2410' -i phases/phase5-monitoring/alerts/01_backup_failure_alert.sql
```

#### Run RPO/RTO Monitoring (Manual)
```bash
sqlcmd -S 127.0.0.1,14333 -U SA -P 'Daniel@2410' -i phases/phase5-monitoring/alerts/02_rpo_rto_alert.sql
```

#### Run Disk Space Monitoring (Manual)
```bash
sqlcmd -S 127.0.0.1,14333 -U SA -P 'Daniel@2410' -i phases/phase5-monitoring/alerts/03_disk_space_alert.sql
```

#### Run Weekly Report (Manual)
```bash
sqlcmd -S 127.0.0.1,14333 -U SA -P 'Daniel@2410' -i phases/phase5-monitoring/reports/01_weekly_report.sql
```

### Configuring Automated Monitoring

To enable continuous monitoring, create SQL Agent jobs to run these scripts on a schedule:

#### 1. Hourly Health Check Job
```sql
-- In SQL Server Management Studio or via sqlcmd:
USE msdb;
GO

-- Create job
EXEC sp_add_job
    @job_name = N'Phase5_HourlyHealthCheck',
    @description = N'Hourly database health check',
    @enabled = 1;

-- Add job step
EXEC sp_add_jobstep
    @job_name = N'Phase5_HourlyHealthCheck',
    @step_name = N'HealthCheck',
    @subsystem = N'TSQL',
    @database_name = N'master',
    @command = N'
        -- Execute health checks
        :r phases/phase5-monitoring/health-checks/01_health_check.sql
    ',
    @on_success_action = 1; -- Quit with success

-- Schedule: Every hour
EXEC sp_add_schedule
    @schedule_name = N'Hourly_TopOfHour',
    @freq_type = 4,           -- Daily
    @freq_interval = 1,       -- Every day
    @freq_subday_type = 8,    -- Hour
    @freq_subday_interval = 1; -- Every 1 hour

EXEC sp_attach_schedule
    @job_name = N'Phase5_HourlyHealthCheck',
    @schedule_name = N'Hourly_TopOfHour';
GO
```

#### 2. Hourly Backup Alert Job
```sql
USE msdb;
GO

EXEC sp_add_job
    @job_name = N'Phase5_HourlyBackupAlert',
    @description = N'Hourly backup failure alert check',
    @enabled = 1;

EXEC sp_add_jobstep
    @job_name = N'Phase5_HourlyBackupAlert',
    @step_name = N'BackupAlert',
    @subsystem = N'TSQL',
    @database_name = N'msdb',
    @command = N'
        :r phases/phase5-monitoring/alerts/01_backup_failure_alert.sql
    ',
    @on_success_action = 1;

EXEC sp_add_schedule
    @schedule_name = N'Hourly_Alert',
    @freq_type = 4,
    @freq_interval = 1,
    @freq_subday_type = 8,
    @freq_subday_interval = 1;

EXEC sp_attach_schedule
    @job_name = N'Phase5_HourlyBackupAlert',
    @schedule_name = N'Hourly_Alert';
GO
```

#### 3. Hourly RPO/RTO Monitoring Job
```sql
USE msdb;
GO

EXEC sp_add_job
    @job_name = N'Phase5_HourlyRPO_RTO',
    @description = N'Hourly RPO/RTO validation',
    @enabled = 1;

EXEC sp_add_jobstep
    @job_name = N'Phase5_HourlyRPO_RTO',
    @step_name = N'RPO_RTO_Check',
    @subsystem = N'TSQL',
    @database_name = N'msdb',
    @command = N'
        :r phases/phase5-monitoring/alerts/02_rpo_rto_alert.sql
    ',
    @on_success_action = 1;

EXEC sp_attach_schedule
    @job_name = N'Phase5_HourlyRPO_RTO',
    @schedule_name = N'Hourly_Alert';
GO
```

#### 4. Hourly Disk Space Check Job
```sql
USE msdb;
GO

EXEC sp_add_job
    @job_name = N'Phase5_HourlyDiskSpace',
    @description = N'Hourly disk space monitoring',
    @enabled = 1;

EXEC sp_add_jobstep
    @job_name = N'Phase5_HourlyDiskSpace',
    @step_name = N'DiskSpaceCheck',
    @subsystem = N'TSQL',
    @database_name = N'master',
    @command = N'
        :r phases/phase5-monitoring/alerts/03_disk_space_alert.sql
    ',
    @on_success_action = 1;

EXEC sp_attach_schedule
    @job_name = N'Phase5_HourlyDiskSpace',
    @schedule_name = N'Hourly_Alert';
GO
```

#### 5. Weekly Report Job (Sunday 7:00 AM)
```sql
USE msdb;
GO

EXEC sp_add_job
    @job_name = N'Phase5_WeeklyReport',
    @description = N'Weekly operational report',
    @enabled = 1;

EXEC sp_add_jobstep
    @job_name = N'Phase5_WeeklyReport',
    @step_name = N'WeeklyReport',
    @subsystem = N'TSQL',
    @database_name = N'HospitalBackupDemo',
    @command = N'
        :r phases/phase5-monitoring/reports/01_weekly_report.sql
    ',
    @on_success_action = 1;

EXEC sp_add_schedule
    @schedule_name = N'Weekly_Sunday_7AM',
    @freq_type = 8,           -- Weekly
    @freq_interval = 1,       -- Sunday
    @active_start_time = 070000; -- 7:00 AM

EXEC sp_attach_schedule
    @job_name = N'Phase5_WeeklyReport',
    @schedule_name = N'Weekly_Sunday_7AM';
GO
```

### Alert Thresholds

The monitoring scripts use the following thresholds:

| Metric | Critical | Warning | Target |
|--------|----------|---------|--------|
| Full Backup Age | > 2 days | > 24 hours | Daily |
| Differential Backup | None | > 1 day | Daily |
| Log Backup (RPO) | > 1 hour | > 45 min | 1 hour |
| Disk Space | < 20 MB | < 100 MB | > 100 MB |
| Failed Logins | > 10 | > 5 | < 5 |

### Alert Notification Setup

To enable email notifications for alerts, configure SQL Server Database Mail:

#### 1. Configure Database Mail Profile
```sql
-- Enable Database Mail
EXEC sp_configure 'show advanced options', 1;
RECONFIGURE;
EXEC sp_configure 'Database Mail XPs', 1;
RECONFIGURE;

-- Create mail account
EXEC msdb.dbo.sysmail_add_account_sp
    @account_name = 'DBA_Account',
    @email_address = 'dba@hospital.local',
    @mailserver_name = 'mail.hospital.local',
    @port = 25;

-- Create mail profile
EXEC msdb.dbo.sysmail_add_profile_sp
    @profile_name = 'DBA_Profile',
    @description = 'DBA Alerts Profile';

-- Associate account with profile
EXEC msdb.dbo.sysmail_add_profileaccount_sp
    @profile_name = 'DBA_Profile',
    @account_name = 'DBA_Account',
    @sequence_number = 1;
GO
```

#### 2. Modify Alert Scripts to Send Email
Add this to any alert script to send email on critical alerts:

```sql
-- After detecting a critical alert:
DECLARE @emailSubject NVARCHAR(MAX) = 'ALERT: HospitalBackupDemo - Backup Failure';
DECLARE @emailBody NVARCHAR(MAX) = 'Critical alert detected. Review backup status immediately.';

EXEC msdb.dbo.sp_send_dbmail
    @profile_name = 'DBA_Profile',
    @recipients = 'dba@hospital.local',
    @subject = @emailSubject,
    @body = @emailBody;
GO
```

### Monitoring Dashboard Integration

The monitoring data can be integrated into external dashboards:

#### Power BI Integration
1. Create Power BI data source pointing to SQL Server
2. Connect to these queries:
   - `01_health_check.sql` → Health dashboard
   - `01_backup_failure_alert.sql` → Backup status
   - `02_rpo_rto_alert.sql` → Recovery metrics
   - `01_weekly_report.sql` → Business metrics
3. Set refresh schedule to 1 hour

#### Grafana Integration
1. Install SQL Server data source plugin
2. Configure connection to HospitalBackupDemo
3. Create dashboards using these metrics:
   - Database availability (sys.databases.state_desc)
   - Backup history (msdb.backupset)
   - Wait statistics (sys.dm_os_wait_stats)
   - Disk space (xp_fixeddrives)

### Troubleshooting

#### Health Check Fails
- Verify HospitalBackupDemo is online
- Check SQL Server Agent is running
- Verify SQLCMD can connect to the server

#### No Backups Showing
- Verify Phase 3 backup jobs are configured and running
- Check /var/opt/mssql/backup directory exists
- Review backup job logs in SQL Server Agent

#### Disk Space Alerts Not Working
- Verify xp_cmdshell is enabled: `EXEC sp_configure 'xp_cmdshell', 1;`
- Check drive letters are correct (may differ on Linux)
- Verify SA account has permissions to execute xp_fixeddrives

#### Alert Emails Not Sending
- Verify Database Mail is configured
- Test with: `EXEC msdb.dbo.sp_send_dbmail @profile_name = 'DBA_Profile', @recipients = 'test@example.com', @subject = 'Test', @body = 'Test';`
- Check Database Mail logs in SQL Server

### Files in This Phase

| File | Purpose | Schedule |
|------|---------|----------|
| `01_health_check.sql` | Database & system health | Hourly |
| `01_backup_failure_alert.sql` | Backup age & status | Hourly |
| `02_rpo_rto_alert.sql` | Recovery objectives validation | Hourly |
| `03_disk_space_alert.sql` | Disk capacity monitoring | Hourly |
| `01_weekly_report.sql` | Business metrics summary | Weekly (Sun 7 AM) |
| `01_dashboards_notes.md` | Dashboard integration guide | Reference |

### Next Steps

1. **Immediate:** Run health checks manually to verify setup
2. **Today:** Configure SQL Agent jobs for automated scheduling
3. **This Week:** Set up Database Mail and email notifications
4. **This Month:** Integrate with Power BI/Grafana dashboard
5. **Ongoing:** Review alert thresholds monthly, adjust as needed

### Support

For issues or questions, review:
- Phase 5 README.md (overview)
- Individual script comments (implementation details)
- MISMATCH_ANALYSIS_REPORT.md (known issues)
