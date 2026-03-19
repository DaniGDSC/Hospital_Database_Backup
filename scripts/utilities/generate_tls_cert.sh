#!/usr/bin/env bash
set -euo pipefail

# Generate self-signed TLS certificate for SQL Server on Linux
# HIPAA 45 CFR 164.312(e)(1): Transmission Security
#
# Production: Replace with CA-signed certificate from your organization's CA
# This self-signed cert is suitable for development and internal environments

SCRIPT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"
source "${SCRIPT_DIR}/../helpers/load_config.sh"

echo -e "${BLUE}=== TLS Certificate Generation ===${NC}"
echo ""

# Create directory
sudo mkdir -p "$TLS_CERT_DIR"

# Check if cert already exists
if [ -f "$TLS_CERT_FILE" ]; then
    EXPIRY=$(openssl x509 -in "$TLS_CERT_FILE" -noout -enddate 2>/dev/null | cut -d= -f2)
    echo -e "${YELLOW}WARNING: Certificate already exists${NC}"
    echo "  Path:    $TLS_CERT_FILE"
    echo "  Expires: $EXPIRY"
    echo ""
    read -r -p "Regenerate? (y/N): " CONFIRM
    if [ "${CONFIRM,,}" != "y" ]; then
        echo "Keeping existing certificate."
        exit 0
    fi
fi

echo "Generating self-signed TLS certificate..."
echo "  CN:       ${TLS_CERT_CN}"
echo "  Key size: 2048 bits"
echo "  Validity: ${TLS_CERT_DAYS} days"
echo ""

# Generate private key and self-signed certificate
sudo openssl req -x509 -nodes \
    -newkey rsa:2048 \
    -days "${TLS_CERT_DAYS}" \
    -keyout "$TLS_KEY_FILE" \
    -out "$TLS_CERT_FILE" \
    -subj "/CN=${TLS_CERT_CN}/O=HospitalBackupDemo/C=VN"

# Set ownership and permissions
sudo chown mssql:mssql "$TLS_CERT_FILE" "$TLS_KEY_FILE"
sudo chmod 400 "$TLS_KEY_FILE"
sudo chmod 444 "$TLS_CERT_FILE"

# Verify
echo ""
echo -e "${GREEN}✓ TLS certificate generated${NC}"
echo "  Certificate: $TLS_CERT_FILE"
echo "  Private key: $TLS_KEY_FILE"
echo "  Expires:     $(openssl x509 -in "$TLS_CERT_FILE" -noout -enddate | cut -d= -f2)"
echo "  Subject:     $(openssl x509 -in "$TLS_CERT_FILE" -noout -subject | cut -d= -f2-)"
echo ""
echo "Next step: Run configure_mssql_tls.sh to apply to SQL Server"
