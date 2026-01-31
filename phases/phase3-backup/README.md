# Phase 3: Backup Configuration

## Purpose
Configure automated backup system following 3-2-1 rule with ransomware protection.

## Directory Structure
```
phase3-backup/
├── full/            # Full backup scripts
├── differential/    # Differential backup scripts
├── log/             # Transaction log backup scripts
├── verification/    # Backup verification scripts
└── s3-setup/        # AWS S3 configuration
```

## Backup Strategy
- **Full Backup**: Weekly (Sunday 2:00 AM)
- **Differential Backup**: Daily (Monday-Saturday 2:00 AM)
- **Log Backup**: Hourly

## 3-2-1 Rule Implementation
- **3 Copies**: 1 production + 2 backups (local + S3)
- **2 Media Types**: Local disk + S3 cloud
- **1 Off-site**: S3 with WORM protection (Object Lock)

### Backup Encryption
- All backups are encrypted with AES-256 using a server certificate (`HospitalBackupDemo_TDECert`).
- Implemented via `WITH ENCRYPTION (ALGORITHM = AES_256, SERVER CERTIFICATE = HospitalBackupDemo_TDECert)`.
- Applies to Full, Differential, and Log backups (local and S3).

### S3 Immutability (WORM)
- Use S3 Object Lock in COMPLIANCE mode with bucket versioning enabled.
- Create an Object Lock-enabled bucket:
	- `scripts/utilities/configure_s3_object_lock.sh hospital-backup-prod-lock ap-southeast-1 30`
- Update `config/project.conf` `S3_BUCKET_NAME` to the new bucket.
- Backups sent to S3 inherit default retention and cannot be deleted/overwritten until expiry.

## How to Run
```bash
cd phase3-backup
../scripts/run_phase.sh 3
```
