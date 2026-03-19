# GitHub Secrets Configuration

All sensitive values are stored in GitHub Secrets — never in code.

---

## Repository Secrets

Go to: GitHub > Settings > Secrets and variables > Actions

| Secret Name | Description | Used By |
|---|---|---|
| `CI_SA_PASSWORD` | SA password for CI Docker SQL Server | ci.yml |
| `TELEGRAM_BOT_TOKEN` | Telegram bot token for alerts | All pipelines |
| `TELEGRAM_CHAT_ID` | Telegram chat ID for alerts | All pipelines |

## Environment: staging

Go to: GitHub > Settings > Environments > staging > Secrets

| Secret Name | Description |
|---|---|
| `STAGING_SQL_PASSWORD` | SQL Server password for staging |

## Environment: production

Go to: GitHub > Settings > Environments > production > Secrets

| Secret Name | Description |
|---|---|
| `PROD_SQL_PASSWORD` | SQL Server password for production |

### Production Protection Rules

Configure at: GitHub > Settings > Environments > production

- **Required reviewers**: Add Senior DBA GitHub username
- **Deployment branches**: Restrict to `main` only
- **Wait timer**: 0 (manual trigger already provides control)

---

## Setup Steps

1. Create a strong CI password (>= 16 chars):
   ```bash
   openssl rand -base64 24
   ```

2. Add repository secrets:
   - Go to repo > Settings > Secrets > New repository secret
   - Add `CI_SA_PASSWORD`, `TELEGRAM_BOT_TOKEN`, `TELEGRAM_CHAT_ID`

3. Create staging environment:
   - Settings > Environments > New environment > "staging"
   - Add `STAGING_SQL_PASSWORD`

4. Create production environment:
   - Settings > Environments > New environment > "production"
   - Enable "Required reviewers" > add Senior DBA
   - Add `PROD_SQL_PASSWORD`

5. Verify by pushing a test commit — CI pipeline should trigger.
