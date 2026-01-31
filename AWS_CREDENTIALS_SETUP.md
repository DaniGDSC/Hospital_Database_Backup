# AWS Credentials Setup Guide

## Overview

This guide walks you through setting up real AWS IAM credentials for S3 backup access with SQL Server.

---

## Step 1: Create AWS IAM User for S3 Backups

### 1.1 In AWS Console

1. Go to **AWS Console** → **IAM** → **Users**
2. Click **Create User**
3. Enter User name: `hospital-backup-user`
4. Click **Create User**

### 1.2 Create Access Key

1. Click the newly created user
2. Go to **Security credentials** tab
3. Under **Access keys**, click **Create access key**
4. Choose **Application running outside AWS**
5. Click **Create access key**
6. **IMPORTANT:** Download the `.csv` file or copy:
   - Access Key ID (starts with `AKIA`)
   - Secret Access Key (long random string)

**⚠️ CRITICAL:** Store these securely. They will not be shown again. If lost, create a new access key.

---

## Step 2: Create S3 Bucket Policy

### 2.1 Create Policy

1. Go to **IAM** → **Policies**
2. Click **Create policy**
3. Use the policy below (replace `hospital-backup-prod-lock` with your bucket name):

```json
{
    "Version": "2012-10-17",
    "Statement": [
        {
            "Sid": "S3BackupFullAccess",
            "Effect": "Allow",
            "Action": [
                "s3:PutObject",
                "s3:GetObject",
                "s3:DeleteObject",
                "s3:ListBucket"
            ],
            "Resource": [
                "arn:aws:s3:::hospital-backup-prod-lock",
                "arn:aws:s3:::hospital-backup-prod-lock/*"
            ]
        },
        {
            "Sid": "ObjectLockBypass",
            "Effect": "Allow",
            "Action": [
                "s3:BypassGovernanceRetention"
            ],
            "Resource": "arn:aws:s3:::hospital-backup-prod-lock/*"
        }
    ]
}
```

4. Click **Next** → **Create policy**
5. Name it: `HospitalBackupS3Policy`

### 2.2 Attach Policy to User

1. Go to **IAM** → **Users** → `hospital-backup-user`
2. Click **Add permissions** → **Attach policies directly**
3. Search for `HospitalBackupS3Policy`
4. Select it and click **Add permissions**

---

## Step 3: Configure Local Credentials

### Option A: Update Configuration File (Simple)

**File:** `config/project.conf`

Replace the empty credentials:

```bash
# AWS S3 Configuration
S3_BUCKET_NAME="hospital-backup-prod-lock"
S3_REGION="ap-southeast-1"
AWS_PROFILE="default"

# AWS IAM Credentials (from Step 1.2)
S3_ACCESS_KEY_ID="AKIA5XXXXXXXXXXXXX"           # Your Access Key ID
S3_SECRET_ACCESS_KEY="AWS_SECRET_ACCESS_KEY_HERE" # Your Secret Key
```

**⚠️ WARNING:** This stores credentials in plain text. Use Option B for production.

### Option B: Use Environment Variables (Recommended)

Set credentials in your shell before running scripts:

```bash
export S3_ACCESS_KEY_ID="AKIA5XXXXXXXXXXXXX"
export S3_SECRET_ACCESS_KEY="your-secret-key"

# Then run your backup scripts
bash scripts/runners/run_phase.sh 3
```

### Option C: Use AWS Credentials File (Best for Linux/Mac)

1. Create `~/.aws/credentials`:
   ```
   [default]
   aws_access_key_id = AKIA5XXXXXXXXXXXXX
   aws_secret_access_key = your-secret-key
   ```

2. Create `~/.aws/config`:
   ```
   [default]
   region = ap-southeast-1
   ```

3. Set permissions:
   ```bash
   chmod 600 ~/.aws/credentials
   chmod 600 ~/.aws/config
   ```

4. Leave `config/project.conf` empty:
   ```bash
   S3_ACCESS_KEY_ID=""
   S3_SECRET_ACCESS_KEY=""
   AWS_PROFILE="default"
   ```

---

## Step 4: Verify Credentials with AWS CLI

### 4.1 Install AWS CLI (if not installed)

```bash
# Linux/Mac
curl "https://awscli.amazonaws.com/awscli-exe-linux-x86_64.zip" -o "awscliv2.zip"
unzip awscliv2.zip
sudo ./aws/install

# Or via package manager
sudo apt-get install awscli          # Debian/Ubuntu
brew install awscli                  # Mac
```

### 4.2 Test Credentials

```bash
# Set credentials (if using environment variables)
export AWS_ACCESS_KEY_ID="AKIA5XXXXXXXXXXXXX"
export AWS_SECRET_ACCESS_KEY="your-secret-key"
export AWS_DEFAULT_REGION="ap-southeast-1"

# List bucket contents
aws s3 ls s3://hospital-backup-prod-lock/

# Upload test file
echo "test backup" > /tmp/test-backup.bak
aws s3 cp /tmp/test-backup.bak s3://hospital-backup-prod-lock/test-backup.bak

# Verify upload
aws s3 ls s3://hospital-backup-prod-lock/

# Delete test file
aws s3 rm s3://hospital-backup-prod-lock/test-backup.bak
```

**Expected Output:**
```
upload: ../../../tmp/test-backup.bak to s3://hospital-backup-prod-lock/test-backup.bak
2025-01-09 10:00:00     11 test-backup.bak
```

---

## Step 5: Test Credentials in SQL Server

### 5.1 Run Helper Script

```bash
cd /home/un1/hospital-db-backup-project

# Set credentials in environment
export S3_ACCESS_KEY_ID="AKIA5XXXXXXXXXXXXX"
export S3_SECRET_ACCESS_KEY="your-secret-key"

# Run Phase 3 (includes credential test)
bash scripts/runners/run_phase.sh 3
```

### 5.2 Manual SQL Test

```sql
-- Test S3 credential creation
USE master;
GO

-- Check if credential exists
SELECT * FROM sys.credentials WHERE name LIKE 'S3%';
GO

-- Test backup to S3
DECLARE @backup_path NVARCHAR(MAX) = 
    'https://hospital-backup-prod-lock.s3.ap-southeast-1.amazonaws.com/test-backup.bak';

BACKUP DATABASE HospitalBackupDemo 
    TO URL = @backup_path
    WITH COMPRESSION, ENCRYPTION (ALGORITHM = AES_256);
GO
```

---

## Step 6: Secure Credentials Best Practices

### DO:
- ✅ Use AWS IAM users with minimal permissions
- ✅ Rotate access keys every 90 days
- ✅ Use environment variables in CI/CD pipelines
- ✅ Enable MFA on AWS console account
- ✅ Monitor credential usage in CloudTrail
- ✅ Use S3 bucket policies to restrict access
- ✅ Enable S3 Object Lock for immutability

### DON'T:
- ❌ Never commit credentials to Git
- ❌ Never use root AWS account
- ❌ Never grant `*` (all) permissions to S3
- ❌ Never share credentials in emails or chat
- ❌ Never store credentials in plain text in production
- ❌ Never use same credentials for multiple services

### File Permissions

```bash
# Protect config file
chmod 600 /home/un1/hospital-db-backup-project/config/project.conf

# AWS credentials file
chmod 600 ~/.aws/credentials

# Backup directory
chmod 700 /var/opt/mssql/backup/
```

---

## Step 7: Troubleshooting

### Issue: "Invalid credentials" error

**Solution:**
1. Verify Access Key ID and Secret Key are correct
2. Check AWS IAM policy is attached
3. Verify S3 bucket name is correct
4. Confirm region matches bucket region

```bash
# Debug with AWS CLI
aws s3 ls s3://hospital-backup-prod-lock/ --debug
```

### Issue: "Access Denied" when uploading

**Solution:**
1. Verify IAM user has `s3:PutObject` permission
2. Check bucket policy doesn't block the user
3. Verify access key is active (not deactivated)

```bash
# List user permissions
aws iam list-user-policies --user-name hospital-backup-user
```

### Issue: "Credential not found in SQL Server"

**Solution:**
1. Ensure Phase 3 ran successfully
2. Check credentials table:
   ```sql
   SELECT * FROM sys.credentials;
   ```
3. If missing, run credential creation manually:
   ```bash
   bash scripts/helpers/run_sql.sh \
     phases/phase3-backup/s3-setup/01_create_s3_credential.sql \
     "$S3_ACCESS_KEY_ID" "$S3_SECRET_ACCESS_KEY"
   ```

---

## Step 8: Automate Credential Injection

### Using Environment Variables (Recommended)

Create a `.env` file (add to `.gitignore`):

```bash
# .env file (NEVER commit this!)
export S3_ACCESS_KEY_ID="AKIA5XXXXXXXXXXXXX"
export S3_SECRET_ACCESS_KEY="your-secret-key"
```

Source before running:

```bash
source .env
bash scripts/runners/run_phase.sh 3
```

### Using Secrets Manager (Advanced)

For production, use AWS Secrets Manager:

```bash
# Store secret in AWS
aws secretsmanager create-secret \
  --name hospital/s3/credentials \
  --secret-string '{"username":"AKIA...","password":"..."}'

# Retrieve in script
SECRET=$(aws secretsmanager get-secret-value --secret-id hospital/s3/credentials)
export S3_ACCESS_KEY_ID=$(echo $SECRET | jq -r '.SecretString.username')
export S3_SECRET_ACCESS_KEY=$(echo $SECRET | jq -r '.SecretString.password')
```

---

## Summary Checklist

- [ ] AWS IAM user created (`hospital-backup-user`)
- [ ] Access keys generated and stored securely
- [ ] IAM policy created and attached
- [ ] S3 bucket exists with Object Lock enabled
- [ ] Credentials added to `config/project.conf` OR environment variables
- [ ] AWS CLI installed and credentials verified
- [ ] Test backup to S3 successful
- [ ] File permissions configured (600 for credential files)
- [ ] Credentials rotation schedule documented (every 90 days)

---

## Next Steps

1. **Run Phase 3 with real credentials:**
   ```bash
   export S3_ACCESS_KEY_ID="AKIA5XXXXXXXXXXXXX"
   export S3_SECRET_ACCESS_KEY="your-secret-key"
   bash scripts/runners/run_phase.sh 3
   ```

2. **Verify backup in S3:**
   ```bash
   aws s3 ls s3://hospital-backup-prod-lock/ --recursive
   ```

3. **Test S3 Restore (Phase 4):**
   ```bash
   bash scripts/runners/run_phase.sh 4
   ```

4. **Enable Phase 7 automation (optional):**
   ```bash
   bash scripts/runners/run_phase.sh 7
   ```

---

## Support

For AWS IAM assistance: https://docs.aws.amazon.com/IAM/
For SQL Server S3: https://docs.microsoft.com/sql/relational-databases/backup-restore/sql-server-backup-to-url
