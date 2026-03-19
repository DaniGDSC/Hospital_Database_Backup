# Deployment Pipeline

**Promotion path**: Dev → Staging → Production

---

## Environment Summary

| | Development | Staging | Production |
|---|---|---|---|
| **Database** | `HospitalBackupDemo_Dev` | `HospitalBackupDemo_Staging` | `HospitalBackupDemo` |
| **S3 Bucket** | `hospital-backup-dev` | `hospital-backup-staging` | `hospital-backup-prod-lock` |
| **Data** | Fake (synthetic) | Anonymized from prod | Real PHI |
| **Object Lock** | No | No | Yes (WORM) |
| **Approval** | Not required | Required | Required + Separation of Duties |
| **Alerts** | Dev channel | Staging channel | Production channel |

---

## Dev → Staging

**Who can promote**: Any developer
**Requirements**:
1. All scripts execute successfully on dev database
2. `bash -n` passes on all `.sh` files
3. Git branch is clean (no uncommitted changes)

**Steps**:
```bash
# 1. Run full pipeline on dev
APP_ENV=development ./run_all_phases.sh

# 2. Create anonymized staging database
APP_ENV=staging ./scripts/utilities/anonymize_for_staging.sh

# 3. Verify anonymization passed
./scripts/utilities/verify_anonymization.sh

# 4. Run full pipeline on staging
APP_ENV=staging ./run_all_phases.sh
```

---

## Staging → Production

**Who can promote**: Senior DBA (Separation of Duties)
**Requirements**:
1. All staging tests pass
2. Staging pipeline completes without error
3. `verify_anonymization.sh` PASS (confirms no data leak)
4. Approved by `DEPLOY_APPROVER` (different person from deployer)
5. Within maintenance window (`02:00-04:00`)

**Steps**:
```bash
# 1. Use production deployment script (enforces all gates)
DEPLOY_APPROVER="senior_dba_name" ./scripts/deploy_production.sh

# This automatically:
#   - Verifies approval (no self-approval)
#   - Runs pre-deployment checks
#   - Takes backup before deployment
#   - Executes deployment
#   - Runs post-deployment verification
#   - Sends Telegram notification
#   - Logs to deployment_history.json
```

---

## Rollback

| Scenario | Action |
|---|---|
| Schema change failed | `./scripts/utilities/emergency_rollback.sh` |
| Data corruption | Point-in-time restore (PITR) |
| Security breach | Emergency lockdown + DR procedure |
| Wrong deployment | `git revert` + redeploy |

See: [ROLLBACK_RUNBOOK.md](ROLLBACK_RUNBOOK.md)

---

## Safety Guards

- **Production guard**: `PRODUCTION_CONFIRMED=yes` required
- **Self-approval blocked**: Deployer ≠ Approver
- **Environment logging**: Every config load logged to `logs/environment.log`
- **PHI flag**: `PHI_ENVIRONMENT=true` only in production
