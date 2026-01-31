# AWS Credentials Quick Reference

## Quick Start (3 Steps)

### Step 1: Get AWS Credentials
1. Go to AWS Console → IAM → Users
2. Create user: `hospital-backup-user`
3. Create access key → Copy Access Key ID & Secret Key

### Step 2: Run Setup Helper
```bash
cd /home/un1/hospital-db-backup-project
bash scripts/setup_aws_credentials.sh
```

### Step 3: Test & Deploy
```bash
# Test credentials
aws s3 ls s3://hospital-backup-prod-lock/

# Run Phase 3 with S3 backups
bash scripts/runners/run_phase.sh 3
```

---

## Configuration Methods

| Method | Setup Time | Security | Best For |
|--------|-----------|----------|----------|
| **Environment Variables** | 1 min | Medium | Testing, CI/CD |
| **Config File** | 1 min | Low | Development only |
| **AWS Credentials File** | 2 min | High | Linux/Mac local |
| **.env File** | 2 min | High | Project-specific |

---

## Environment Variable Setup (Fastest)

```bash
# Set in current session
export S3_ACCESS_KEY_ID="AKIA5XXXXXXXXXXXXX"
export S3_SECRET_ACCESS_KEY="your-secret-key"

# Run backup
bash scripts/runners/run_phase.sh 3

# Verify
aws s3 ls s3://hospital-backup-prod-lock/
```

---

## Config File Setup

**Edit:** `config/project.conf`

```bash
S3_ACCESS_KEY_ID="AKIA5XXXXXXXXXXXXX"
S3_SECRET_ACCESS_KEY="your-secret-key"
```

Then run:
```bash
bash scripts/runners/run_phase.sh 3
```

---

## AWS Credentials File (Recommended)

**Create:** `~/.aws/credentials`
```
[default]
aws_access_key_id = AKIA5XXXXXXXXXXXXX
aws_secret_access_key = your-secret-key
```

**Create:** `~/.aws/config`
```
[default]
region = ap-southeast-1
```

Then run:
```bash
bash scripts/runners/run_phase.sh 3
```

---

## .env File Setup (Project-Specific)

**Create:** `.env`
```bash
export S3_ACCESS_KEY_ID="AKIA5XXXXXXXXXXXXX"
export S3_SECRET_ACCESS_KEY="your-secret-key"
export AWS_DEFAULT_REGION="ap-southeast-1"
```

**Restrict permissions:**
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

### With AWS CLI
```bash
# List bucket contents
aws s3 ls s3://hospital-backup-prod-lock/

# Upload test file
echo "test" > /tmp/test.txt
aws s3 cp /tmp/test.txt s3://hospital-backup-prod-lock/

# Delete test file
aws s3 rm s3://hospital-backup-prod-lock/test.txt
```

### With SQL Server
```sql
-- Check credentials
SELECT name FROM sys.credentials WHERE name LIKE 'S3%';

-- Test backup
BACKUP DATABASE HospitalBackupDemo 
    TO URL = 'https://hospital-backup-prod-lock.s3.ap-southeast-1.amazonaws.com/test.bak'
    WITH COMPRESSION;
```

---

## Troubleshooting

### "Invalid credentials" error
```bash
# Verify keys
echo $S3_ACCESS_KEY_ID
echo $S3_SECRET_ACCESS_KEY

# AWS CLI debug
aws s3 ls s3://hospital-backup-prod-lock/ --debug
```

### "Access Denied" error
- [ ] Verify IAM policy is attached to user
- [ ] Check S3 bucket policy
- [ ] Confirm access key is active (not deactivated)

### Credentials file not found
- [ ] Run setup script: `bash scripts/setup_aws_credentials.sh`
- [ ] Check file permissions: `ls -la ~/.aws/`
- [ ] Verify environment variables: `env | grep S3_`

---

## Security Best Practices

✅ **DO:**
- Use IAM user (not root account)
- Rotate keys every 90 days
- Restrict file permissions (`chmod 600`)
- Use environment variables
- Enable MFA on AWS account

❌ **DON'T:**
- Never commit credentials to Git
- Never share keys in emails
- Never use root AWS account
- Never grant `*` (all) S3 permissions
- Never store plain text in production

---

## File Permissions

```bash
# Config file
chmod 600 config/project.conf

# AWS credentials
chmod 600 ~/.aws/credentials
chmod 600 ~/.aws/config

# .env file
chmod 600 .env

# Backup directory
chmod 700 /var/opt/mssql/backup/
```

---

## Verify Setup Complete

```bash
# All should show SUCCESS
echo "1. Config file:" && [ -f config/project.conf ] && echo "✓"
echo "2. AWS CLI:" && which aws && echo "✓"
echo "3. S3 access:" && aws s3 ls s3://hospital-backup-prod-lock/ && echo "✓"
echo "4. Credentials:" && [ -n "$S3_ACCESS_KEY_ID" ] && echo "✓"
```

---

## Next Steps

1. **Setup credentials** (5 min)
   ```bash
   bash scripts/setup_aws_credentials.sh
   ```

2. **Test connection** (1 min)
   ```bash
   aws s3 ls s3://hospital-backup-prod-lock/
   ```

3. **Run Phase 3** (10-15 min)
   ```bash
   bash scripts/runners/run_phase.sh 3
   ```

4. **Verify backup in S3** (1 min)
   ```bash
   aws s3 ls s3://hospital-backup-prod-lock/ --recursive
   ```

5. **Test recovery** (optional)
   ```bash
   bash scripts/runners/run_phase.sh 4
   ```

---

## Support & Resources

- **AWS IAM Setup:** https://docs.aws.amazon.com/IAM/
- **S3 Backup Policy:** https://aws.amazon.com/s3/
- **SQL Server S3:** https://docs.microsoft.com/sql/relational-databases/backup-restore/
- **AWS CLI:** https://docs.aws.amazon.com/cli/
- **Local Setup Guide:** See `AWS_CREDENTIALS_SETUP.md`
