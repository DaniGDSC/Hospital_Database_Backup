# Contributing to HospitalBackupDemo

Guide for DBAs and engineers maintaining this system.

## Development Workflow

1. Clone repo and set up dev environment
2. Create feature branch: `git checkout -b feature/description`
3. Make changes (follow coding standards below)
4. Pre-commit hooks run automatically (secrets scan + shellcheck)
5. Push and create Pull Request
6. CI pipeline runs: lint, test, scan
7. Get review from Senior DBA
8. Merge to main — CD auto-deploys to staging
9. Test on staging
10. Manual trigger — CD deploys to production

## Coding Standards

### SQL (T-SQL)

- Keywords: `UPPERCASE` (`SELECT`, `INSERT`, `CREATE`)
- Table names: `PascalCase` (`MedicalRecords`, `LabTests`)
- Column names: `PascalCase` (`PatientID`, `FirstName`)
- Always include `SET NOCOUNT ON` at the top
- Always use `TRY/CATCH` for error handling
- Always make scripts idempotent (`IF NOT EXISTS` / `DROP IF EXISTS`)
- Never hardcode passwords — use `$(VARIABLE)` for sqlcmd variables
- Add header comment:

```sql
-- File: filename.sql
-- Purpose: one line description
-- HIPAA: note any PHI handling
USE HospitalBackupDemo;
GO
```

### Bash

- Always start with: `set -euo pipefail`
- Always source config: `source "${SCRIPT_DIR}/../helpers/load_config.sh"`
- Always log to `${PROJECT_ROOT}/logs/`
- Never hardcode passwords — use `${VARIABLE}` from `.env`
- Use `shellcheck` before committing
- Use `${SQLCMD_ENCRYPT_FLAGS}` for all sqlcmd calls (never bare `-C`)

### Documentation

- Filename: `UPPER_SNAKE_CASE.md`
- Include purpose, prerequisites, and verification steps
- Link to related docs rather than duplicating content

## Adding New SQL Agent Jobs

1. Create file: `phases/phase7-automation/NN_job_description.sql` (next available number)
2. Follow existing job pattern (see `09_job_cert_backup_monthly.sql`)
3. Must include: Telegram notification on failure via `usp_SendTelegramAlert`
4. Must include: AuditLog entry on completion
5. Update `verify_jobs.sql` with the new job name
6. Update `deploy_jobs.sh` to include the new file

## Adding New Utility Scripts

1. Create file: `scripts/utilities/script_name.sh`
2. Source `load_config.sh` for all environment variables
3. Make executable: `chmod +x scripts/utilities/script_name.sh`
4. Add `bash -n` syntax check verification
5. Log all actions to `${PROJECT_ROOT}/logs/`

## Secret Rotation

See [SECRETS_ROTATION_RUNBOOK.md](docs/SECRETS_ROTATION_RUNBOOK.md).

## On-Call Procedures

- [COMMUNICATION_PLAN.md](docs/COMMUNICATION_PLAN.md) — who to notify
- [ESCALATION_POLICY.md](docs/ESCALATION_POLICY.md) — severity levels and timing
- [POST_INCIDENT_REVIEW_TEMPLATE.md](docs/POST_INCIDENT_REVIEW_TEMPLATE.md) — after incidents

## Pull Request Checklist

Before submitting a PR, verify:

- [ ] Pre-commit hooks pass (gitleaks + shellcheck)
- [ ] SQL scripts are idempotent
- [ ] No hardcoded passwords or secrets
- [ ] Bash scripts have `set -euo pipefail`
- [ ] New jobs include Telegram alerting
- [ ] Relevant docs updated
- [ ] CHANGELOG.md updated
