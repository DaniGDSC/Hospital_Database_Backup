# Scripts Usage

This folder contains helper, runner, and utility scripts for the Hospital Backup Project.

## Configuration
- Config is loaded by `scripts/helpers/load_config.sh`.
- Base config: `config/project.conf`.
- Environment overrides: `config/development.conf`, `config/production.conf`.
- Select environment by setting `HOSPITAL_DB_ENV` (defaults to `development`).

## Runners
- `scripts/runners/run_phase.sh <n>`: executes all `.sql` files in `phase<n>-*` in sorted order.

## Helpers
- `scripts/helpers/run_sql.sh <sql_file> [database]`: runs a SQL file against the configured server and logs output to `logs/`.
- `scripts/helpers/load_config.sh`: sources configuration into environment variables used by other scripts.

## Utilities
- `scripts/utilities/test_connection.sh`: verify SQL connectivity and server info.
- `scripts/utilities/check_status.sh`: quick status (service, database, backups, logs, certificates).
- `scripts/utilities/clean_logs.sh`: delete log files older than 30 days.

## Examples
```bash
# Test connection
./scripts/utilities/test_connection.sh

# Run phase 1 setup
cd phase1-database
../scripts/runners/run_phase.sh 1

# Clean old logs
./scripts/utilities/clean_logs.sh
```
