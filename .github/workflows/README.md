# CI/CD Pipelines

## Overview

| Pipeline | File | Trigger | Environment | Duration |
|---|---|---|---|---|
| **CI** | `ci.yml` | Every push/PR | Docker (ephemeral) | ~5 min |
| **CD Staging** | `cd-staging.yml` | Merge to main | Self-hosted staging | ~15 min |
| **CD Production** | `cd-production.yml` | Manual only | Self-hosted production | ~20 min |

## Promotion Path

```
Push → CI (auto) → Merge to main → Staging (auto) → Manual trigger → Production
```

## Required GitHub Secrets

### Repository Secrets (all pipelines)
- `TELEGRAM_BOT_TOKEN` — Telegram bot token
- `TELEGRAM_CHAT_ID` — Telegram chat ID
- `CI_SA_PASSWORD` — SA password for CI Docker SQL Server

### Environment: staging
- `STAGING_SQL_PASSWORD`

### Environment: production
- `PROD_SQL_PASSWORD`

## Environment Protection Rules

Configure in GitHub: Settings > Environments > production:
- Required reviewers: Senior DBA
- Wait timer: 0 (manual trigger already requires approval)
- Deployment branches: main only

## Self-Hosted Runner Setup

Staging and production pipelines require a self-hosted GitHub Actions runner:

```bash
# On staging/production server:
mkdir actions-runner && cd actions-runner
curl -o actions-runner-linux-x64.tar.gz -L https://github.com/actions/runner/releases/latest/download/actions-runner-linux-x64-2.311.0.tar.gz
tar xzf actions-runner-linux-x64.tar.gz
./config.sh --url https://github.com/DaniGDSC/Hospital_Database_Backup --token [TOKEN]
sudo ./svc.sh install
sudo ./svc.sh start
```
