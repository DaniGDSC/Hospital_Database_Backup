#!/bin/bash
SCRIPT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"
source "${SCRIPT_DIR}/../helpers/load_config.sh"

echo "╔════════════════════════════════════════════════════╗"
echo "║           Project Status Check                     ║"
echo "╚════════════════════════════════════════════════════╝"
echo ""

# Check SQL Server
echo "1. SQL Server Status:"
if sudo systemctl is-active --quiet mssql-server; then
    echo "   ✓ Running"
else
    echo "   ✗ Not running"
fi

# Check database
echo ""
echo "2. Database Status:"
sqlcmd -S "$SQL_SERVER" -U "$SQL_USER" -P "$SQL_PASSWORD" -C -Q "
IF EXISTS (SELECT name FROM sys.databases WHERE name = '$DATABASE_NAME')
    SELECT '   ✓ Database exists: $DATABASE_NAME' AS Status
ELSE
    SELECT '   ✗ Database not found: $DATABASE_NAME' AS Status;
" -h -1

# Check backups
echo ""
echo "3. Recent Backups:"
ls -lt /var/opt/mssql/backup/full/*.bak 2>/dev/null | head -3 || echo "   No backups found"

# Check logs
echo ""
echo "4. Recent Logs:"
ls -lt logs/ 2>/dev/null | head -5 || echo "   No logs found"

# Check certificates
echo ""
echo "5. Certificate Backups:"
ls -l certificates-backup/ 2>/dev/null | grep -E '\.(cer|pvk)$' | wc -l | xargs echo "   Certificates:"

echo ""
