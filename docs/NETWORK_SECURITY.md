# Network Security Architecture

**HIPAA 45 CFR 164.312(e)(1)**: Transmission Security

---

## TLS Encryption

All SQL Server connections use mandatory TLS 1.2 encryption.

| Setting | Value | Purpose |
|---|---|---|
| `forceencryption` | `1` | All clients MUST use TLS |
| `tlsprotocols` | `1.2` | TLS 1.0/1.1 disabled |
| `SQL_REQUIRE_TLS` | `true` | Adds `-N` flag to sqlcmd |
| `SQL_TRUST_CERT` | `true` (dev) / `false` (prod) | Controls `-C` flag |

### Connection Flow
```
Client (sqlcmd -N -C) → TLS 1.2 → SQL Server (forceencryption=1)
```

### Certificate Management
- **Self-signed cert** (current): `/var/opt/mssql/tls/mssql.pem`
- **Generate**: `./scripts/utilities/generate_tls_cert.sh`
- **Configure**: `./scripts/utilities/configure_mssql_tls.sh`
- **Verify**: `./scripts/utilities/verify_tls_connection.sh`
- **Monitoring**: SQL Agent job `HospitalBackup_TLS_Cert_Check` (weekly)

### Certificate Rotation
1. Generate new cert: `./scripts/utilities/generate_tls_cert.sh`
2. Apply to SQL Server: `./scripts/utilities/configure_mssql_tls.sh`
3. Schedule maintenance window
4. Restart SQL Server: `sudo systemctl restart mssql-server`
5. Verify: `./scripts/utilities/verify_tls_connection.sh`

### Production: CA-Signed Certificate
When deploying with a CA-signed certificate:
1. Place cert at `/var/opt/mssql/tls/mssql.pem`
2. Place key at `/var/opt/mssql/tls/mssql.key`
3. Set `SQL_TRUST_CERT=false` in `.env` (removes `-C` flag)
4. Restart SQL Server

---

## Port Access Control

| Port | Service | Binding | External Access |
|---|---|---|---|
| 14333 | SQL Server | `127.0.0.1` | Denied |
| 3000 | Grafana | `127.0.0.1` | Denied |
| 9090 | Prometheus | `127.0.0.1` | Denied |
| 9100 | Node Exporter | `127.0.0.1` | Denied |
| 3100 | Loki | `127.0.0.1` | Denied |
| 22 | SSH | `0.0.0.0` | Allowed (key-only) |

### Firewall
- Configure: `./scripts/utilities/configure_firewall.sh`
- Verify: `./scripts/utilities/verify_network_security.sh`

### Allowing Remote Application Access
```bash
sudo ufw allow from [APP_SERVER_IP] to any port 14333 proto tcp
```

---

## Network Architecture

```
                   Internet
                      │
              [Firewall / UFW]
                      │
        ┌─────────────┼─────────────┐
        │             │             │
   SSH (22)    All Other Ports   VPN Only
        │         DENIED            │
        ▼                           ▼
   ┌─────────── Hospital Server ───────────┐
   │                                       │
   │  SQL Server (:14333) ← localhost only │
   │  Grafana    (:3000)  ← localhost only │
   │  Prometheus (:9090)  ← localhost only │
   │  Loki       (:3100)  ← localhost only │
   │                                       │
   │  All internal connections: TLS 1.2    │
   └───────────────────────────────────────┘
```

---

## Verification Commands

```bash
# Full TLS check
./scripts/utilities/verify_tls_connection.sh

# Full network check
./scripts/utilities/verify_network_security.sh

# Check firewall status
sudo ufw status verbose

# Check port bindings
ss -tlnp | grep -E '14333|3000|9090|9100|3100'

# Check SQL encryption
sqlcmd -S 127.0.0.1,14333 -U hospital_dba_admin -P "$SQL_PASSWORD" -N -C \
    -Q "SELECT encrypt_option FROM sys.dm_exec_connections WHERE session_id = @@SPID"
```
