#!/usr/bin/env bash
set -euo pipefail

# Configure SQL Server to use TLS for all connections
# HIPAA 45 CFR 164.312(e)(1): Transmission Security
#
# Sets: forceencryption=1 (all clients MUST use TLS)
# Sets: tlsprotocols=1.2 (disables TLS 1.0 and 1.1)
#
# ⚠️ MANUAL STEP: Requires SQL Server restart after configuration

SCRIPT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"
source "${SCRIPT_DIR}/../helpers/load_config.sh"

echo -e "${BLUE}=== SQL Server TLS Configuration ===${NC}"
echo ""

# Verify certificate files exist
if [ ! -f "$TLS_CERT_FILE" ]; then
    echo -e "${RED}ERROR: TLS certificate not found: $TLS_CERT_FILE${NC}"
    echo "  Run generate_tls_cert.sh first"
    exit 1
fi

if [ ! -f "$TLS_KEY_FILE" ]; then
    echo -e "${RED}ERROR: TLS private key not found: $TLS_KEY_FILE${NC}"
    echo "  Run generate_tls_cert.sh first"
    exit 1
fi

# Verify mssql user can read the files
if ! sudo -u mssql test -r "$TLS_CERT_FILE" 2>/dev/null; then
    echo -e "${YELLOW}WARNING: mssql user cannot read cert file — fixing permissions${NC}"
    sudo chown mssql:mssql "$TLS_CERT_FILE" "$TLS_KEY_FILE"
fi

echo "Configuring SQL Server TLS..."

# Use mssql-conf to set TLS parameters
sudo /opt/mssql/bin/mssql-conf set network.tlscert "$TLS_CERT_FILE"
echo "  ✓ network.tlscert = $TLS_CERT_FILE"

sudo /opt/mssql/bin/mssql-conf set network.tlskey "$TLS_KEY_FILE"
echo "  ✓ network.tlskey = $TLS_KEY_FILE"

sudo /opt/mssql/bin/mssql-conf set network.tlsprotocols "1.2"
echo "  ✓ network.tlsprotocols = 1.2 (TLS 1.0/1.1 disabled)"

sudo /opt/mssql/bin/mssql-conf set network.forceencryption 1
echo "  ✓ network.forceencryption = 1 (all clients must use TLS)"

echo ""
echo -e "${GREEN}✓ SQL Server TLS configured${NC}"
echo ""
echo -e "${YELLOW}╔════════════════════════════════════════════════════════════╗${NC}"
echo -e "${YELLOW}║  ⚠️  RESTART REQUIRED                                      ║${NC}"
echo -e "${YELLOW}║  sudo systemctl restart mssql-server                       ║${NC}"
echo -e "${YELLOW}║  After restart, verify: ./verify_tls_connection.sh          ║${NC}"
echo -e "${YELLOW}╚════════════════════════════════════════════════════════════╝${NC}"
