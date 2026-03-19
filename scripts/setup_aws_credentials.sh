#!/bin/bash
# Secure AWS Credentials Configuration Helper
# This script guides you through setting up real AWS IAM credentials safely

set -e

PROJECT_ROOT="$( cd "$( dirname "${BASH_SOURCE[0]}" )/.." && pwd )"
source "${PROJECT_ROOT}/scripts/helpers/load_config.sh"
CONFIG_FILE="$PROJECT_ROOT/config/project.conf"

echo -e "${BLUE}╔════════════════════════════════════════════════════════════════╗${NC}"
echo -e "${BLUE}║         AWS Credentials Setup Helper - Hospital Backup          ║${NC}"
echo -e "${BLUE}╚════════════════════════════════════════════════════════════════╝${NC}"
echo ""

# Shared helper: prompt and validate AWS keys
read_and_validate_keys() {
    read -p "Enter AWS Access Key ID (AKIA...): " ACCESS_KEY
    read -sp "Enter AWS Secret Access Key: " SECRET_KEY
    echo ""
    echo ""

    if [ -z "$ACCESS_KEY" ] || [ -z "$SECRET_KEY" ]; then
        echo -e "${RED}✗ Error: Credentials cannot be empty${NC}"
        return 1
    fi
    return 0
}

# Function to prompt user
prompt_credentials() {
    local method=$1

    case $method in
        "env")
            echo -e "${BLUE}Setting credentials via environment variables...${NC}"
            echo ""
            read_and_validate_keys || return 1

            export S3_ACCESS_KEY_ID="$ACCESS_KEY"
            export S3_SECRET_ACCESS_KEY="$SECRET_KEY"

            echo -e "${GREEN}✓ Credentials loaded to environment${NC}"
            echo -e "${YELLOW}Note: These are only set for this session. Use .env file for persistence.${NC}"
            ;;

        "config")
            echo -e "${BLUE}Setting credentials in config file...${NC}"
            echo ""
            read_and_validate_keys || return 1

            cp "$CONFIG_FILE" "$CONFIG_FILE.backup.$(date +%s)"
            sed -i "s/^S3_ACCESS_KEY_ID=\"\"/S3_ACCESS_KEY_ID=\"$ACCESS_KEY\"/" "$CONFIG_FILE"
            sed -i "s/^S3_SECRET_ACCESS_KEY=\"\"/S3_SECRET_ACCESS_KEY=\"$SECRET_KEY\"/" "$CONFIG_FILE"
            chmod 600 "$CONFIG_FILE"

            echo -e "${GREEN}✓ Credentials saved to config file${NC}"
            echo -e "${YELLOW}⚠ Remember: config/project.conf now contains secrets. Never commit to Git!${NC}"

            if ! grep -q "^config/project.conf$" "$PROJECT_ROOT/.gitignore" 2>/dev/null; then
                echo "config/project.conf" >> "$PROJECT_ROOT/.gitignore"
                echo -e "${GREEN}✓ Added config/project.conf to .gitignore${NC}"
            fi
            ;;

        "awscreds")
            echo -e "${BLUE}Setting credentials via ~/.aws/credentials file...${NC}"
            echo ""
            mkdir -p ~/.aws
            read_and_validate_keys || return 1

            cat > ~/.aws/credentials << EOF
[default]
aws_access_key_id = $ACCESS_KEY
aws_secret_access_key = $SECRET_KEY
EOF
            chmod 600 ~/.aws/credentials

            if [ ! -f ~/.aws/config ]; then
                cat > ~/.aws/config << EOF
[default]
region = ap-southeast-1
output = json
EOF
                chmod 600 ~/.aws/config
            fi

            echo -e "${GREEN}✓ Credentials saved to ~/.aws/credentials${NC}"
            echo -e "${GREEN}✓ Config saved to ~/.aws/config${NC}"
            echo -e "${YELLOW}Note: This is the recommended approach for Linux/Mac${NC}"
            ;;

        "envfile")
            echo -e "${BLUE}Creating .env file for credentials...${NC}"
            echo ""
            read_and_validate_keys || return 1

            cat > "$PROJECT_ROOT/.env" << EOF
# AWS S3 Backup Credentials
# DO NOT COMMIT THIS FILE TO GIT!
export S3_ACCESS_KEY_ID="$ACCESS_KEY"
export S3_SECRET_ACCESS_KEY="$SECRET_KEY"
export AWS_DEFAULT_REGION="ap-southeast-1"
EOF
            chmod 600 "$PROJECT_ROOT/.env"

            if ! grep -q "^\.env$" "$PROJECT_ROOT/.gitignore" 2>/dev/null; then
                echo ".env" >> "$PROJECT_ROOT/.gitignore"
                echo -e "${GREEN}✓ Added .env to .gitignore${NC}"
            fi

            echo -e "${GREEN}✓ .env file created${NC}"
            echo -e "${YELLOW}Usage: source .env && bash scripts/runners/run_phase.sh 3${NC}"
            ;;
    esac
}

# Function to test credentials
test_credentials() {
    echo ""
    echo -e "${BLUE}Testing AWS credentials...${NC}"
    echo ""

    if ! command -v aws &> /dev/null; then
        echo -e "${RED}✗ AWS CLI not found. Install it first:${NC}"
        echo "  curl \"https://awscli.amazonaws.com/awscli-exe-linux-x86_64.zip\" -o \"awscliv2.zip\""
        echo "  unzip awscliv2.zip"
        echo "  sudo ./aws/install"
        return 1
    fi

    if [ -z "$S3_ACCESS_KEY_ID" ] || [ -z "$S3_SECRET_ACCESS_KEY" ]; then
        echo -e "${RED}✗ Credentials not set in environment${NC}"
        return 1
    fi

    echo "Testing access to S3 bucket: hospital-backup-prod-lock"

    if aws s3 ls "s3://hospital-backup-prod-lock/" --region ap-southeast-1 &> /dev/null; then
        echo -e "${GREEN}✓ Successfully connected to S3 bucket${NC}"
        return 0
    else
        echo -e "${RED}✗ Failed to access S3 bucket. Check credentials and bucket name.${NC}"
        return 1
    fi
}

show_menu() {
    echo -e "${BLUE}Select credential setup method:${NC}"
    echo ""
    echo "  1) Environment Variables (current session only)"
    echo "  2) Config File (project.conf)"
    echo "  3) AWS Credentials File (~/.aws/credentials) - Recommended"
    echo "  4) Create .env File (for persistence)"
    echo "  5) Test Credentials"
    echo "  6) Show Current Setup"
    echo "  7) Exit"
    echo ""
}

show_current_setup() {
    echo ""
    echo -e "${BLUE}Current Setup:${NC}"
    echo ""

    if [ -n "$S3_ACCESS_KEY_ID" ]; then
        MASKED_KEY="${S3_ACCESS_KEY_ID:0:4}...${S3_ACCESS_KEY_ID: -4}"
        echo -e "  Environment Variable: ${GREEN}SET${NC} ($MASKED_KEY)"
    else
        echo -e "  Environment Variable: ${RED}NOT SET${NC}"
    fi

    if grep -q 'S3_ACCESS_KEY_ID="AKIA' "$CONFIG_FILE" 2>/dev/null; then
        MASKED_KEY=$(grep 'S3_ACCESS_KEY_ID=' "$CONFIG_FILE" | cut -d'"' -f2)
        MASKED="${MASKED_KEY:0:4}...${MASKED_KEY: -4}"
        echo -e "  Config File (project.conf): ${GREEN}SET${NC} ($MASKED)"
    else
        echo -e "  Config File (project.conf): ${RED}NOT SET${NC}"
    fi

    if [ -f ~/.aws/credentials ] && grep -q "aws_access_key_id" ~/.aws/credentials; then
        echo -e "  AWS Credentials File (~/.aws/credentials): ${GREEN}EXISTS${NC}"
    else
        echo -e "  AWS Credentials File (~/.aws/credentials): ${RED}NOT FOUND${NC}"
    fi

    if [ -f "$PROJECT_ROOT/.env" ]; then
        echo -e "  Local .env File: ${GREEN}EXISTS${NC}"
    else
        echo -e "  Local .env File: ${RED}NOT FOUND${NC}"
    fi

    echo ""
}

# Main loop
while true; do
    show_menu
    read -p "Enter your choice (1-7): " choice

    case $choice in
        1) prompt_credentials "env" ;;
        2) prompt_credentials "config" ;;
        3) prompt_credentials "awscreds" ;;
        4) prompt_credentials "envfile" ;;
        5) test_credentials ;;
        6) show_current_setup ;;
        7)
            echo ""
            echo -e "${GREEN}Setup complete!${NC}"
            echo ""
            echo "Next steps:"
            echo "  1. Verify credentials are set: $0 (select option 5)"
            echo "  2. Run Phase 3: bash scripts/runners/run_phase.sh 3"
            echo "  3. Monitor backup: aws s3 ls s3://hospital-backup-prod-lock/ --recursive"
            echo ""
            exit 0
            ;;
        *) echo -e "${RED}Invalid choice. Please try again.${NC}" ;;
    esac

    echo ""
done
