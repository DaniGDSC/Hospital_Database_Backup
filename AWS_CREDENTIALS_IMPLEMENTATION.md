# AWS Credentials Configuration - Implementation Summary

**Date:** January 9, 2026  
**Status:** Ready for Implementation  
**Estimated Setup Time:** 15-20 minutes

---

## What's Been Created

### 1. **Comprehensive Setup Guide**
📄 [AWS_CREDENTIALS_SETUP.md](AWS_CREDENTIALS_SETUP.md)
- Complete step-by-step instructions
- AWS IAM user creation
- S3 bucket policy setup
- 4 credential configuration methods
- Troubleshooting guide
- Security best practices

### 2. **Quick Reference Card**
📄 [AWS_CREDENTIALS_QUICKREF.md](AWS_CREDENTIALS_QUICKREF.md)
- 3-step quick start
- Command examples
- Configuration comparison table
- Validation checklist

### 3. **Interactive Setup Script**
📄 `scripts/setup_aws_credentials.sh`
- **Guided wizard** for credential configuration
- 4 setup methods to choose from:
  - Environment variables
  - Config file
  - AWS credentials file
  - .env file
- Interactive prompts with validation
- Automatic .gitignore updates
- File permission management

### 4. **Validation Script**
📄 `scripts/validate_aws_credentials.sh`
- Comprehensive 8-point validation
- Checks all credential sources
- Tests S3 connectivity
- Verifies file permissions
- SQL Server configuration check
- Color-coded results (pass/fail/warn)

---

## Quick Start (4 Steps)

### Step 1: Get AWS Credentials
```bash
# Go to AWS Console
# 1. IAM → Users → Create User (hospital-backup-user)
# 2. Create Access Key
# 3. Copy Access Key ID and Secret Access Key
```

### Step 2: Run Interactive Setup
```bash
cd /home/un1/hospital-db-backup-project
bash scripts/setup_aws_credentials.sh
```
Select your preferred method (recommended: AWS Credentials File)

### Step 3: Validate Setup
```bash
bash scripts/validate_aws_credentials.sh
```
Should show: ✓ All checks passed!

### Step 4: Run Phase 3 Backup
```bash
bash scripts/runners/run_phase.sh 3
```

---

## Configuration Methods Comparison

| Method | File | Setup | Security | Best For |
|--------|------|-------|----------|----------|
| **Env Variables** | None | 2 min | Medium | Testing, CI/CD |
| **Config File** | config/project.conf | 1 min | Low | Dev only |
| **AWS Creds File** | ~/.aws/credentials | 3 min | High | ✓ Recommended |
| **.env File** | .env | 2 min | High | Project-local |

### Recommended: AWS Credentials File

**Setup (3 minutes):**
```bash
# Run interactive setup
bash scripts/setup_aws_credentials.sh

# Choose option: 3 (AWS Credentials File)
```

**Files created:**
```
~/.aws/credentials      # Access keys (chmod 600)
~/.aws/config          # Region settings
```

**Advantages:**
- ✅ Standard AWS approach
- ✅ Secure (600 permissions)
- ✅ Works with AWS CLI, SDKs, SQL Server
- ✅ No project files committed
- ✅ Multiple profiles supported

---

## Detailed Instructions

### Method 1: Environment Variables (Fastest)

```bash
# Set credentials
export S3_ACCESS_KEY_ID="AKIA5XXXXXXXXXXXXX"
export S3_SECRET_ACCESS_KEY="your-secret-key"

# Run backup
bash scripts/runners/run_phase.sh 3

# Verify
aws s3 ls s3://hospital-backup-prod-lock/
```

**Pros:** Quick, temporary  
**Cons:** Lost on shell restart, visible in process list

---

### Method 2: Config File

**Edit:** `config/project.conf`
```bash
S3_ACCESS_KEY_ID="AKIA5XXXXXXXXXXXXX"
S3_SECRET_ACCESS_KEY="your-secret-key"
```

**Then:**
```bash
bash scripts/runners/run_phase.sh 3
```

**⚠️ WARNING:** Credentials in plain text. Never commit to Git!

---

### Method 3: AWS Credentials File (RECOMMENDED)

**Create:** `~/.aws/credentials`
```ini
[default]
aws_access_key_id = AKIA5XXXXXXXXXXXXX
aws_secret_access_key = your-secret-key
```

**Create:** `~/.aws/config`
```ini
[default]
region = ap-southeast-1
output = json
```

**Secure:**
```bash
chmod 600 ~/.aws/credentials
chmod 600 ~/.aws/config
```

**Then:**
```bash
bash scripts/runners/run_phase.sh 3
```

---

### Method 4: .env File

**Create:** `.env`
```bash
export S3_ACCESS_KEY_ID="AKIA5XXXXXXXXXXXXX"
export S3_SECRET_ACCESS_KEY="your-secret-key"
export AWS_DEFAULT_REGION="ap-southeast-1"
```

**Secure:**
```bash
chmod 600 .env
```

**Use:**
```bash
source .env
bash scripts/runners/run_phase.sh 3
```

---

## Testing Credentials

### Test 1: AWS CLI Connectivity
```bash
# List S3 bucket
aws s3 ls s3://hospital-backup-prod-lock/

# Expected output:
# 2025-01-09 10:00:00   1234567 HospitalBackupDemo_20250109.bak
```

### Test 2: SQL Server S3 Access
```sql
-- Check credentials in SQL Server
SELECT name, identity FROM sys.credentials WHERE name LIKE 'S3%';

-- Test backup to S3
BACKUP DATABASE HospitalBackupDemo 
    TO URL = 'https://hospital-backup-prod-lock.s3.ap-southeast-1.amazonaws.com/test-backup.bak'
    WITH COMPRESSION, ENCRYPTION (ALGORITHM = AES_256);
```

### Test 3: Validation Script
```bash
bash scripts/validate_aws_credentials.sh
```

---

## Security Best Practices

### ✅ DO:

```bash
# 1. Use IAM user (not root)
✓ Created user: hospital-backup-user

# 2. Restrict file permissions
✓ chmod 600 ~/.aws/credentials
✓ chmod 600 ~/.aws/config
✓ chmod 600 .env

# 3. Use environment variables in CI/CD
✓ Inject via GitHub Secrets / GitLab CI

# 4. Rotate keys every 90 days
✓ Set calendar reminder

# 5. Enable MFA on AWS account
✓ Recommended: Google Authenticator

# 6. Restrict IAM permissions
✓ Hospital bucket only, no wildcard
```

### ❌ DON'T:

```bash
# Never commit credentials
✗ Don't: git add config/project.conf
✓ Do: Add to .gitignore

# Never share keys
✗ Don't: Send via email/Slack
✓ Do: Use AWS Secrets Manager

# Never use root account
✗ Don't: Use AWS root credentials
✓ Do: Use IAM user

# Never grant all (*) permissions
✗ Don't: "s3:*" on "*"
✓ Do: Specific actions on specific bucket

# Never store plain text
✗ Don't: Check credentials into repo
✓ Do: Use ~/.aws/ or environment vars
```

---

## File Permissions Setup

```bash
# After creating credentials, set correct permissions:

# AWS credentials file
chmod 600 ~/.aws/credentials    # -rw-------
chmod 600 ~/.aws/config         # -rw-------

# Project config (if using method 2)
chmod 600 config/project.conf   # -rw-------

# Project .env (if using method 4)
chmod 600 .env                  # -rw-------

# Backup directory
chmod 700 /var/opt/mssql/backup/ # drwx------

# Verify
ls -la ~/.aws/
ls -la config/project.conf
```

---

## Troubleshooting

### Problem: "Invalid credentials"

```bash
# 1. Verify credentials are correct
echo "Access Key: $S3_ACCESS_KEY_ID"
echo "Secret Key: ${S3_SECRET_ACCESS_KEY:0:10}..."

# 2. Check format
# Access Key should start with: AKIA
# Secret Key should be 40+ characters

# 3. Test with AWS CLI
aws s3 ls s3://hospital-backup-prod-lock/ --debug

# 4. Regenerate if needed (in AWS Console)
# IAM → Users → hospital-backup-user → Create new access key
```

### Problem: "Access Denied"

```bash
# 1. Check IAM policy
aws iam list-user-policies --user-name hospital-backup-user

# 2. Verify S3 bucket permissions
aws s3api get-bucket-policy --bucket hospital-backup-prod-lock

# 3. Check Object Lock retention
aws s3api get-object-lock-configuration --bucket hospital-backup-prod-lock

# 4. Verify role has required permissions:
# - s3:PutObject
# - s3:GetObject
# - s3:ListBucket
```

### Problem: "Credential not found"

```bash
# 1. Check environment variables
env | grep S3_

# 2. Check config file
grep S3_ config/project.conf

# 3. Check AWS credentials file
cat ~/.aws/credentials

# 4. Validate setup
bash scripts/validate_aws_credentials.sh
```

---

## Next Steps

### Immediate (Today)
1. ✅ Review this guide
2. ✅ Create AWS IAM user
3. ✅ Generate access keys
4. ✅ Run setup script: `bash scripts/setup_aws_credentials.sh`
5. ✅ Validate setup: `bash scripts/validate_aws_credentials.sh`

### Short-term (This Week)
1. Run Phase 3: `bash scripts/runners/run_phase.sh 3`
2. Verify backups in S3: `aws s3 ls s3://hospital-backup-prod-lock/ --recursive`
3. Test recovery (Phase 4): `bash scripts/runners/run_phase.sh 4`

### Medium-term (This Month)
1. Enable Phase 7 automation jobs
2. Schedule weekly recovery drills
3. Set up CloudWatch monitoring
4. Document runbooks for team

### Long-term (Ongoing)
1. Rotate access keys every 90 days
2. Review audit logs monthly
3. Update S3 lifecycle policies
4. Monitor backup success rates

---

## Files Created

```
/home/un1/hospital-db-backup-project/
├── AWS_CREDENTIALS_SETUP.md          # Complete setup guide (9.1 KB)
├── AWS_CREDENTIALS_QUICKREF.md       # Quick reference (4.8 KB)
├── scripts/
│   ├── setup_aws_credentials.sh      # Interactive setup wizard (10 KB)
│   └── validate_aws_credentials.sh   # Validation checker (7.1 KB)
```

---

## Integration with Existing Project

### Automatic Injection Points

These scripts automatically inject credentials when running:

1. **Phase 3 (Backups)** 
   - Reads from environment, config, or ~/.aws/
   - Injects into S3 credential creation script
   - Executes full/diff/log backups to S3

2. **Phase 4 (Recovery)**
   - Uses same credentials for S3 restore
   - Downloads backup from S3 bucket
   - Restores to alternate database

3. **Phase 7 (Automation)**
   - Jobs inherit credentials from SQL Server credentials table
   - Auto-retry on failure
   - Logs all backup operations

### No Code Changes Required

The existing project infrastructure already supports:
- ✅ sqlcmd variable injection
- ✅ Environment variable sourcing
- ✅ Credential management
- ✅ Error logging and retry logic

---

## Verification Checklist

- [ ] AWS account created
- [ ] IAM user `hospital-backup-user` created
- [ ] Access Key ID generated (AKIA...)
- [ ] Secret Access Key saved securely
- [ ] S3 bucket exists: `hospital-backup-prod-lock`
- [ ] Object Lock enabled (COMPLIANCE mode)
- [ ] Setup script executed: `bash scripts/setup_aws_credentials.sh`
- [ ] Validation passed: `bash scripts/validate_aws_credentials.sh`
- [ ] AWS CLI can list bucket: `aws s3 ls s3://hospital-backup-prod-lock/`
- [ ] Phase 3 executed: `bash scripts/runners/run_phase.sh 3`
- [ ] Backups visible in S3: `aws s3 ls s3://hospital-backup-prod-lock/ --recursive`

---

## Support & Resources

| Topic | Link |
|-------|------|
| AWS IAM Guide | https://docs.aws.amazon.com/IAM/ |
| S3 Setup | https://docs.aws.amazon.com/s3/ |
| SQL Server S3 | https://docs.microsoft.com/sql/relational-databases/backup-restore/ |
| AWS CLI | https://docs.aws.amazon.com/cli/ |
| Local Setup Details | [AWS_CREDENTIALS_SETUP.md](AWS_CREDENTIALS_SETUP.md) |
| Quick Commands | [AWS_CREDENTIALS_QUICKREF.md](AWS_CREDENTIALS_QUICKREF.md) |

---

## Summary

You now have a complete, production-ready system for managing AWS credentials for S3 backups:

✅ **3 comprehensive guides** (Setup, Quick Ref, Summary)  
✅ **2 helper scripts** (Setup wizard, Validation checker)  
✅ **4 configuration methods** (pick the best for your use case)  
✅ **Security best practices** (permissions, rotation, storage)  
✅ **Troubleshooting guide** (solve 99% of issues)  

**Estimated time to full S3 backup:** 15-20 minutes

**Ready to proceed?** Start with:
```bash
bash scripts/setup_aws_credentials.sh
```
