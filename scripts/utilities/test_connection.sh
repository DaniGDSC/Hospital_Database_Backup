#!/bin/bash
SCRIPT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"
source "${SCRIPT_DIR}/../helpers/load_config.sh"

echo "Testing SQL Server connection..."
echo "Server: $SQL_SERVER"
echo "Port: $SQL_PORT"
echo "User: $SQL_USER"
echo ""

# Build connection string with explicit port handling
SERVER_CONN="${SQL_SERVER}"
if [[ ! "$SERVER_CONN" =~ , ]]; then
    SERVER_CONN="${SQL_SERVER},${SQL_PORT}"
fi

sqlcmd -S "$SERVER_CONN" -U "$SQL_USER" -P "$SQL_PASSWORD" -C -Q "
SELECT 
    'Server: ' + @@SERVERNAME AS Info
    UNION ALL SELECT 'Version: ' + CAST(SERVERPROPERTY('ProductVersion') AS VARCHAR)
    UNION ALL SELECT 'Edition: ' + CAST(SERVERPROPERTY('Edition') AS VARCHAR)
    UNION ALL SELECT 'Status: Connected';
"

if [ $? -eq 0 ]; then
    echo ""
    echo "✓ Connection successful!"
else
    echo ""
    echo "✗ Connection failed!"
    exit 1
fi
