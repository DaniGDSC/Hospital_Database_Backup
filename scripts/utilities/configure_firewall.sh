#!/usr/bin/env bash
set -euo pipefail

# Configure UFW firewall for Hospital Database Server
# Restricts SQL Server and monitoring ports to localhost only
#
# ⚠️ MANUAL STEP: Review rules before running on production
# ⚠️ REQUIRES ROOT: sudo required for UFW commands

SCRIPT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"
source "${SCRIPT_DIR}/../helpers/load_config.sh"

echo -e "${BLUE}=== Firewall Configuration (UFW) ===${NC}"
echo ""

# Check UFW is installed
if ! command -v ufw &>/dev/null; then
    echo -e "${RED}ERROR: UFW not installed. Install with: sudo apt install ufw${NC}"
    exit 1
fi

echo "Configuring firewall rules..."
echo ""

# Enable UFW with default deny
sudo ufw default deny incoming
sudo ufw default allow outgoing

# Allow SSH (essential for remote management)
sudo ufw allow 22/tcp comment "SSH"
echo "  ✓ SSH (22/tcp): allowed from all"

# SQL Server: localhost only
sudo ufw allow from 127.0.0.1 to any port "${SQL_PORT}" proto tcp comment "SQL Server (localhost)"
echo "  ✓ SQL Server (${SQL_PORT}/tcp): localhost only"

# Monitoring services: localhost only
sudo ufw allow from 127.0.0.1 to any port 3000 proto tcp comment "Grafana (localhost)"
sudo ufw allow from 127.0.0.1 to any port 9090 proto tcp comment "Prometheus (localhost)"
sudo ufw allow from 127.0.0.1 to any port 9100 proto tcp comment "Node Exporter (localhost)"
sudo ufw allow from 127.0.0.1 to any port 3100 proto tcp comment "Loki (localhost)"
echo "  ✓ Monitoring (3000,9090,9100,3100): localhost only"

# Enable UFW
sudo ufw --force enable

echo ""
echo -e "${GREEN}✓ Firewall configured${NC}"
echo ""

# Show status
sudo ufw status verbose

echo ""
echo "To allow remote app server access:"
echo "  sudo ufw allow from [APP_SERVER_IP] to any port ${SQL_PORT} proto tcp"
