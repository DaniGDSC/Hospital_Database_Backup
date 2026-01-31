# Dashboard Notes

- Use these queries as data sources for Grafana/Power BI:
  - Health: state of `HospitalBackupDemo`, last backup times (full/diff/log), XP fixed drives output.
  - Performance: top waits (from 01_health_check.sql) and custom DMV queries for CPU, IO, and blocking.
  - Security: counts from SecurityEvents by day and severity.
  - Backups: trend of backup sizes and durations from msdb.backupset.
- Export report query results (phase5-monitoring/reports/01_weekly_report.sql) to CSV for ingestion.
- Hook alert script into Agent job; publish success/failure status to dashboard.
