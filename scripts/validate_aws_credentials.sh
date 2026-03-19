#!/bin/bash
# AWS Credentials Validation Script
# Verifies that credentials are properly configured for S3 backup access

set -e

PROJECT_ROOT="$( cd "$( dirname "${BASH_SOURCE[0]}" )/.." && pwd )"
source "${PROJECT_ROOT}/scripts/helpers/load_config.sh"
CONFIG_FILE="$PROJECT_ROOT/config/project.conf"

PASSED=0
FAILED=0
WARNINGS=0

# Helper functions
mask_key() { echo "${1:0:4}...${1: -4}"; }

pass() {
    echo -e "${GREEN}✓${NC} $1"
    ((PASSED++))
}

fail() {
    echo -e "${RED}✗${NC} $1"
    ((FAILED++))
}

warn() {
    echo -e "${YELLOW}!${NC} $1"
    ((WARNINGS++))
}

info() {
    echo -e "${BLUE}ℹ${NC} $1"
}

# Header
echo ""
echo -e "${BLUE}╔════════════════════════════════════════════════════════════════╗${NC}"
echo -e "${BLUE}║        AWS Credentials Validation - Hospital Backup            ║${NC}"
echo -e "${BLUE}╚════════════════════════════════════════════════════════════════╝${NC}"
echo ""

# 1. Check configuration file exists
echo -e "${BLUE}[1/8] Checking Configuration Files${NC}"
if [ -f "$CONFIG_FILE" ]; then
    pass "Configuration file found: $CONFIG_FILE"
else
    fail "Configuration file not found: $CONFIG_FILE"
fi

# 2. Check AWS CLI installation
echo ""
echo -e "${BLUE}[2/8] Checking AWS CLI Installation${NC}"
if command -v aws &> /dev/null; then
    AWS_VERSION=$(aws --version)
    pass "AWS CLI installed: $AWS_VERSION"
else
    fail "AWS CLI not installed. Install: curl https://awscli.amazonaws.com/awscli-exe-linux-x86_64.zip -o awscliv2.zip"
fi

# 3. Check environment credentials
echo ""
echo -e "${BLUE}[3/8] Checking Environment Credentials${NC}"
if [ -n "$S3_ACCESS_KEY_ID" ]; then
    pass "S3_ACCESS_KEY_ID set ($(mask_key "$S3_ACCESS_KEY_ID"))"
else
    warn "S3_ACCESS_KEY_ID not set in environment"
fi

if [ -n "$S3_SECRET_ACCESS_KEY" ]; then
    pass "S3_SECRET_ACCESS_KEY set"
else
    warn "S3_SECRET_ACCESS_KEY not set in environment"
fi

# 4. Check config file credentials
echo ""
echo -e "${BLUE}[4/8] Checking Config File Credentials${NC}"
if grep -q 'S3_ACCESS_KEY_ID="AKIA' "$CONFIG_FILE" 2>/dev/null; then
    KEY=$(grep 'S3_ACCESS_KEY_ID=' "$CONFIG_FILE" | cut -d'"' -f2)
    pass "Credentials in config file ($(mask_key "$KEY"))"
elif grep -q 'S3_ACCESS_KEY_ID=""' "$CONFIG_FILE" 2>/dev/null; then
    info "Config file has empty credentials (using environment or ~/.aws/)"
else
    warn "Cannot parse S3_ACCESS_KEY_ID from config file"
fi

# 5. Check AWS credentials file
echo ""
echo -e "${BLUE}[5/8] Checking ~/.aws/credentials File${NC}"
if [ -f ~/.aws/credentials ]; then
    if grep -q "aws_access_key_id" ~/.aws/credentials; then
        pass "AWS credentials file exists: ~/.aws/credentials"
        PERMS=$(stat -c %a ~/.aws/credentials 2>/dev/null || stat -f %A ~/.aws/credentials 2>/dev/null)
        if [ "$PERMS" = "600" ]; then
            pass "Correct file permissions (600)"
        else
            warn "Credentials file permissions are $PERMS (should be 600). Fix: chmod 600 ~/.aws/credentials"
        fi
    else
        fail "AWS credentials file is empty"
    fi
else
    info "No AWS credentials file at ~/.aws/credentials"
fi

# 6. Check .env file
echo ""
echo -e "${BLUE}[6/8] Checking .env File${NC}"
if [ -f "$PROJECT_ROOT/.env" ]; then
    pass "Local .env file exists"
    PERMS=$(stat -c %a "$PROJECT_ROOT/.env" 2>/dev/null || stat -f %A "$PROJECT_ROOT/.env" 2>/dev/null)
    if [ "$PERMS" = "600" ]; then
        pass "Correct file permissions (600)"
    else
        warn ".env file permissions are $PERMS (should be 600). Fix: chmod 600 .env"
    fi
else
    info "No .env file found (optional)"
fi

# 7. Test AWS CLI access
echo ""
echo -e "${BLUE}[7/8] Testing AWS S3 Access${NC}"

# Check if credentials are available
if [ -n "$S3_ACCESS_KEY_ID" ] && [ -n "$S3_SECRET_ACCESS_KEY" ]; then
    if aws s3 ls "s3://hospital-backup-prod-lock/" --region ap-southeast-1 &> /dev/null; then
        pass "Successfully connected to S3 bucket (hospital-backup-prod-lock)"
        
        # Check bucket contents
        BACKUP_COUNT=$(aws s3 ls "s3://hospital-backup-prod-lock/" --region ap-southeast-1 | grep -c "\.bak" || true)
        if [ $BACKUP_COUNT -gt 0 ]; then
            pass "Found $BACKUP_COUNT backup file(s) in S3"
        else
            info "No backup files yet in S3 (expected on first run)"
        fi
    else
        fail "Cannot access S3 bucket. Check credentials and bucket name."
        fail "Verify: aws s3 ls s3://hospital-backup-prod-lock/"
    fi
elif [ -f ~/.aws/credentials ]; then
    if aws s3 ls "s3://hospital-backup-prod-lock/" --region ap-southeast-1 &> /dev/null; then
        pass "Successfully connected to S3 bucket (using ~/.aws/credentials)"
    else
        fail "Cannot access S3 bucket. Check AWS credentials file."
    fi
else
    warn "No credentials found (environment, config, or ~/.aws/credentials). Set them up first:"
    warn "  bash scripts/setup_aws_credentials.sh"
fi

# 8. Check SQL Server connectivity
echo ""
echo -e "${BLUE}[8/8] Checking SQL Server Configuration${NC}"

# Source config to get SQL details
if [ -f "$CONFIG_FILE" ]; then
    source "$CONFIG_FILE" 2>/dev/null || true
    
    if [ -n "$SQL_SERVER" ] && [ -n "$DATABASE_NAME" ]; then
        pass "SQL Server: $SQL_SERVER"
        pass "Database: $DATABASE_NAME"
        info "To test SQL connection: sqlcmd -S $SQL_SERVER -U $SQL_USER -P '***' -d $DATABASE_NAME"
    fi
fi

# Summary
echo ""
echo -e "${BLUE}╔════════════════════════════════════════════════════════════════╗${NC}"
echo -e "${BLUE}║                         VALIDATION SUMMARY                     ║${NC}"
echo -e "${BLUE}╚════════════════════════════════════════════════════════════════╝${NC}"
echo ""
echo -e "Passed:  ${GREEN}$PASSED${NC}"
echo -e "Failed:  ${RED}$FAILED${NC}"
echo -e "Warnings: ${YELLOW}$WARNINGS${NC}"
echo ""

# Final verdict
if [ $FAILED -eq 0 ]; then
    if [ $WARNINGS -eq 0 ]; then
        echo -e "${GREEN}✓ All checks passed! Ready for S3 backups.${NC}"
        echo ""
        echo "Next step:"
        echo "  bash scripts/runners/run_phase.sh 3"
    else
        echo -e "${YELLOW}⚠ Some warnings found. Review and fix if needed.${NC}"
        echo ""
        echo "You can still proceed, but recommended to address warnings first:"
        echo "  bash scripts/setup_aws_credentials.sh"
    fi
else
    echo -e "${RED}✗ Some checks failed. Fix issues before proceeding.${NC}"
    echo ""
    echo "Setup instructions:"
    echo "  bash scripts/setup_aws_credentials.sh"
fi

echo ""

# Return appropriate exit code
if [ $FAILED -eq 0 ]; then
    exit 0
else
    exit 1
fi
