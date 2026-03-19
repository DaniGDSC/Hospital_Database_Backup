#!/usr/bin/env bash
set -euo pipefail

# Preliminary HIPAA breach assessment
# Queries AuditLog for unauthorized PHI access and generates report
# ⚠️ MANUAL STEP: Legal review required before any notifications
#
# HIPAA 45 CFR 164.402: 4-factor risk assessment

SCRIPT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"
source "${SCRIPT_DIR}/../helpers/load_config.sh"

REPORT_DIR="${PROJECT_ROOT}/reports/incidents"
TIMESTAMP=$(date +%Y%m%d_%H%M%S)
REPORT_FILE="${REPORT_DIR}/breach_assessment_${TIMESTAMP}.md"

mkdir -p "$REPORT_DIR"

echo -e "${RED}╔════════════════════════════════════════════════════════════╗${NC}"
echo -e "${RED}║         HIPAA BREACH ASSESSMENT (PRELIMINARY)               ║${NC}"
echo -e "${RED}╚════════════════════════════════════════════════════════════╝${NC}"
echo ""
echo -e "${YELLOW}⚠️  This is a preliminary automated assessment.${NC}"
echo -e "${YELLOW}    Legal review is REQUIRED before any notifications.${NC}"
echo ""

# Query 1: Unauthorized PHI access in last 7 days
echo -e "${BLUE}[1/4] Checking for unauthorized PHI access...${NC}"
UNAUTHORIZED=$(sqlcmd -S "$SERVER_CONN" -U "$SQL_USER" -P "$SQL_PASSWORD" ${SQLCMD_ENCRYPT_FLAGS} \
    -d "HospitalBackupDemo" -h -1 -W \
    -Q "SELECT COUNT(*) FROM dbo.AuditLog
        WHERE ActionType = 'PHI_ACCESS'
        AND IsSuccess = 0
        AND AuditDate >= DATEADD(DAY, -7, SYSDATETIME())" \
    2>/dev/null | tr -d ' ' || echo "ERROR")
echo "  Unauthorized PHI access attempts (7 days): ${UNAUTHORIZED}"

# Query 2: Failed logins
echo ""
echo -e "${BLUE}[2/4] Checking failed login attempts...${NC}"
FAILED_LOGINS=$(sqlcmd -S "$SERVER_CONN" -U "$SQL_USER" -P "$SQL_PASSWORD" ${SQLCMD_ENCRYPT_FLAGS} \
    -d "HospitalBackupDemo" -h -1 -W \
    -Q "SELECT COUNT(*) FROM dbo.SecurityEvents
        WHERE EventType = 'Login Failed'
        AND EventDate >= DATEADD(DAY, -7, SYSDATETIME())" \
    2>/dev/null | tr -d ' ' || echo "ERROR")
echo "  Failed logins (7 days): ${FAILED_LOGINS}"

# Query 3: Count of PHI tables accessed
echo ""
echo -e "${BLUE}[3/4] PHI table access summary...${NC}"
sqlcmd -S "$SERVER_CONN" -U "$SQL_USER" -P "$SQL_PASSWORD" ${SQLCMD_ENCRYPT_FLAGS} \
    -d "HospitalBackupDemo" -W \
    -Q "SELECT TableName, Action, COUNT(*) AS AccessCount
        FROM dbo.AuditLog
        WHERE ActionType = 'PHI_ACCESS'
        AND AuditDate >= DATEADD(DAY, -7, SYSDATETIME())
        GROUP BY TableName, Action
        ORDER BY AccessCount DESC" \
    2>/dev/null || echo "  (Could not query)"

# Query 4: Distinct patients potentially affected
echo ""
echo -e "${BLUE}[4/4] Potentially affected patients...${NC}"
AFFECTED_PATIENTS=$(sqlcmd -S "$SERVER_CONN" -U "$SQL_USER" -P "$SQL_PASSWORD" ${SQLCMD_ENCRYPT_FLAGS} \
    -d "HospitalBackupDemo" -h -1 -W \
    -Q "SELECT COUNT(DISTINCT RecordID) FROM dbo.AuditLog
        WHERE TableName = 'Patients'
        AND ActionType = 'PHI_ACCESS'
        AND AuditDate >= DATEADD(DAY, -7, SYSDATETIME())" \
    2>/dev/null | tr -d ' ' || echo "ERROR")
echo "  Distinct patient records accessed (7 days): ${AFFECTED_PATIENTS}"

# Generate report
echo ""
echo -e "${BLUE}Generating report...${NC}"

cat > "$REPORT_FILE" << EOF
# Breach Assessment Report

**Generated**: $(date -u '+%Y-%m-%d %H:%M:%S UTC')
**Environment**: ${ENVIRONMENT}
**Database**: HospitalBackupDemo
**Assessment Period**: Last 7 days

---

## Findings

| Metric | Count |
|---|---|
| Unauthorized PHI access attempts | ${UNAUTHORIZED} |
| Failed login attempts | ${FAILED_LOGINS} |
| Distinct patients with PHI access | ${AFFECTED_PATIENTS} |

## Classification

**Breach size**: ${AFFECTED_PATIENTS} individuals
**Notification tier**: $([ "${AFFECTED_PATIENTS:-0}" -ge 500 ] && echo ">= 500 → Immediate HHS + media" || echo "< 500 → Annual HHS report")

## Risk Mitigation Already in Place

- TDE AES-256 encryption (data encrypted at rest)
- TLS 1.2 encryption (data encrypted in transit)
- RBAC with 5 roles (minimum necessary access)
- Audit logging on all PHI tables (immutable)
- S3 Object Lock for backup immutability

## Next Steps

- [ ] Legal review of this assessment
- [ ] Determine if PHI was actually viewed/acquired
- [ ] Complete 4-factor risk assessment (45 CFR 164.402)
- [ ] If breach confirmed: initiate 60-day notification timeline
- [ ] File incident report: reports/incidents/INC-$(date +%Y%m%d)-001.md

---

**⚠️ This is an automated preliminary assessment.**
**Legal and compliance team review is REQUIRED.**
EOF

echo ""
echo -e "${GREEN}✓ Report saved: ${REPORT_FILE}${NC}"
echo ""
echo "Next steps:"
echo "  1. Review report with legal team"
echo "  2. Complete 4-factor risk assessment"
echo "  3. If breach confirmed: see docs/HIPAA_BREACH_NOTIFICATION.md"
