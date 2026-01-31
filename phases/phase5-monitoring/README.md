# Phase 5: Monitoring & Alerting

## Purpose
Monitor database health, backup status, and security events.

## Directory Structure
```
phase5-monitoring/
├── health-checks/   # Database health monitoring
├── alerts/          # Alert configuration
├── reports/         # Automated reports
└── dashboards/      # Dashboard configurations
```

## Monitoring Points
- Database availability
- Backup success/failure
- Disk space utilization
- Security events
- Performance metrics

## Alert Triggers
- Backup failure
- Disk space < 20%
- Failed login attempts > 5
- Unauthorized access attempts

## How to Run
```bash
cd phase5-monitoring
../scripts/run_phase.sh 5
```
