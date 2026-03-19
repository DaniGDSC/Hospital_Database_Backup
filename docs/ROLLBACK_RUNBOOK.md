# Rollback Runbook

**System**: HospitalBackupDemo
**Authority**: Only `sysadmin` or `app_security_admin` may initiate rollback

---

## Decision Tree

| Scenario | Action | Script |
|---|---|---|
| Schema change failed | Phase rollback | `emergency_rollback.sh --to-phase N` |
| Data corruption | Point-in-time restore | `phases/phase4-recovery/point-in-time/01_point_in_time_restore.sql` |
| Wrong deployment | Git revert + redeploy | `git revert HEAD && deploy_production.sh` |
| Ransomware | S3 restore | `phases/phase4-recovery/from-s3/01_restore_full_from_s3.sql` |
| Security breach | Emergency lockdown | Disable all app logins, rotate passwords |

---

## Schema Rollback Order

Rollback scripts must run in this order (reverse dependency):

```
1. rollback_system_tables.sql   — AuditLog, SecurityEvents, etc.
2. rollback_billing_tables.sql  — Payments, BillingDetails, Billing
3. rollback_clinical_tables.sql — Admissions, LabTests, Prescriptions, etc.
4. rollback_core_tables.sql     — Rooms, Patients, Nurses, Doctors, Departments
```

## Emergency Rollback

```bash
# Requires sysadmin access
./scripts/utilities/emergency_rollback.sh --to-phase 1
# Type: CONFIRM ROLLBACK
```

This will:
1. Take an emergency backup before any changes
2. Execute rollback scripts in reverse dependency order
3. Verify remaining table count
4. Log to `deployment_history.json`

---

## Post-Rollback Checklist

- [ ] Verify database is ONLINE
- [ ] Verify application connectivity
- [ ] Review rollback log for errors
- [ ] Notify stakeholders of rollback
- [ ] File incident report
- [ ] Plan corrective action before re-deployment
