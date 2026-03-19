-- TDE Certificate Rotation Script
-- REQUIRES MANUAL APPROVAL: This changes the encryption key protecting all patient data.
-- Must be run by a member of app_security_admin role or sysadmin.
-- Passwords sourced via sqlcmd variables:
--   sqlcmd -v CERT_BACKUP_PASSWORD="..." NEW_CERT_SUFFIX="2026"
--
-- IMPORTANT: Take a full backup BEFORE running this script.
-- IMPORTANT: Test on staging environment first.

USE master;
GO

SET NOCOUNT ON;

DECLARE @NewCertName NVARCHAR(128);
DECLARE @NewCertSuffix NVARCHAR(20) = '$(NEW_CERT_SUFFIX)';
DECLARE @CertBackupPassword NVARCHAR(128) = '$(CERT_BACKUP_PASSWORD)';
DECLARE @OldCertName NVARCHAR(128) = 'HospitalBackupDemo_TDECert';
DECLARE @CertBackupDir NVARCHAR(260) = '/var/opt/mssql/backup/certificates';
DECLARE @ErrorMessage NVARCHAR(MAX);

-- Validate inputs
IF @NewCertSuffix = '$(NEW_CERT_SUFFIX)' OR LEN(@NewCertSuffix) = 0
BEGIN
    RAISERROR('NEW_CERT_SUFFIX must be provided (e.g., "2026", "v2"). Usage: sqlcmd -v NEW_CERT_SUFFIX="2026"', 16, 1);
    RETURN;
END

IF @CertBackupPassword = '$(CERT_BACKUP_PASSWORD)' OR LEN(@CertBackupPassword) < 12
BEGIN
    RAISERROR('CERT_BACKUP_PASSWORD must be provided via sqlcmd -v and be at least 12 characters.', 16, 1);
    RETURN;
END

SET @NewCertName = 'HospitalBackupDemo_TDECert_' + @NewCertSuffix;

PRINT '╔════════════════════════════════════════════════════════════════╗';
PRINT '║         TDE Certificate Rotation                               ║';
PRINT '╚════════════════════════════════════════════════════════════════╝';
PRINT '';
PRINT 'Old certificate: ' + @OldCertName;
PRINT 'New certificate: ' + @NewCertName;
PRINT '';

-- Step 1: Verify old certificate exists
PRINT '--- Step 1: Verify current certificate ---';
IF NOT EXISTS (SELECT 1 FROM sys.certificates WHERE name = @OldCertName)
BEGIN
    RAISERROR('Current TDE certificate not found: %s', 16, 1, @OldCertName);
    RETURN;
END
PRINT '  ✓ Current certificate verified';

-- Step 2: Create new certificate
PRINT '';
PRINT '--- Step 2: Create new certificate ---';
IF EXISTS (SELECT 1 FROM sys.certificates WHERE name = @NewCertName)
BEGIN
    PRINT '  Certificate ' + @NewCertName + ' already exists — skipping creation';
END
ELSE
BEGIN
    DECLARE @CreateSql NVARCHAR(MAX) = N'CREATE CERTIFICATE ' + QUOTENAME(@NewCertName) + N'
        WITH SUBJECT = ''TDE Certificate (Rotated ' + @NewCertSuffix + N') for HospitalBackupDemo'',
             EXPIRY_DATE = ''2099-12-31''';
    EXEC sp_executesql @CreateSql;
    PRINT '  ✓ New certificate created: ' + @NewCertName;
END

-- Step 3: Backup new certificate IMMEDIATELY (before using it)
PRINT '';
PRINT '--- Step 3: Backup new certificate ---';

DECLARE @NewCerFile NVARCHAR(260) = @CertBackupDir + '/' + @NewCertName + '.cer';
DECLARE @NewPvkFile NVARCHAR(260) = @CertBackupDir + '/' + @NewCertName + '.pvk';
DECLARE @BackupSql NVARCHAR(MAX) = N'BACKUP CERTIFICATE ' + QUOTENAME(@NewCertName) + N'
    TO FILE = ''' + @NewCerFile + N'''
    WITH PRIVATE KEY (
        FILE = ''' + @NewPvkFile + N''',
        ENCRYPTION BY PASSWORD = ''' + @CertBackupPassword + N'''
    )';
EXEC sp_executesql @BackupSql;
PRINT '  ✓ New certificate backed up: ' + @NewCerFile;

-- Verify backup files exist
DECLARE @CerExists INT, @PvkExists INT;
EXEC master.dbo.xp_fileexist @NewCerFile, @CerExists OUTPUT;
EXEC master.dbo.xp_fileexist @NewPvkFile, @PvkExists OUTPUT;

IF @CerExists = 0 OR @PvkExists = 0
BEGIN
    RAISERROR('CRITICAL: New certificate backup files not found on disk. ABORTING rotation.', 16, 1);
    RETURN;
END
PRINT '  ✓ Backup files verified on disk';

-- Step 4: Re-encrypt the database encryption key with new certificate
PRINT '';
PRINT '--- Step 4: Re-encrypt database encryption key ---';

USE HospitalBackupDemo;
DECLARE @AlterSql NVARCHAR(MAX) = N'ALTER DATABASE ENCRYPTION KEY
    ENCRYPTION BY SERVER CERTIFICATE ' + QUOTENAME(@NewCertName);
EXEC sp_executesql @AlterSql;
PRINT '  ✓ Database encryption key now uses: ' + @NewCertName;

-- Step 5: Verify encryption with new certificate
PRINT '';
PRINT '--- Step 5: Verify encryption state ---';

USE master;
DECLARE @EncState INT;
SELECT @EncState = dek.encryption_state
FROM sys.dm_database_encryption_keys dek
WHERE dek.database_id = DB_ID('HospitalBackupDemo');

IF @EncState = 3
    PRINT '  ✓ TDE active (encryption_state = 3)';
ELSE
    PRINT '  ⚠ TDE state: ' + CAST(ISNULL(@EncState, -1) AS NVARCHAR) + ' — monitor until state = 3';

-- Step 6: Mark old certificate as deprecated (do NOT drop it)
PRINT '';
PRINT '--- Step 6: Deprecation notice ---';
PRINT '  Old certificate ' + @OldCertName + ' is now deprecated.';
PRINT '  DO NOT DROP IT — existing backups made before this rotation';
PRINT '  can only be restored using the old certificate.';
PRINT '  Retain old certificate + backup for at least ' + CAST(90 AS NVARCHAR) + ' days';
PRINT '  (matching S3 backup retention period).';

-- Step 7: Log rotation event
PRINT '';
PRINT '--- Step 7: Log rotation event ---';

INSERT INTO HospitalBackupDemo.dbo.SecurityAuditEvents
    (EventTime, EventType, LoginName, DatabaseUser, ObjectName, ObjectType,
     Action, Success, ClientHost, ApplicationName, Details)
VALUES
    (SYSDATETIME(), 'Encryption Event', SUSER_SNAME(), USER_NAME(),
     @NewCertName, 'CERTIFICATE', 'TDE_CERT_ROTATION', 1,
     HOST_NAME(), APP_NAME(),
     'Rotated TDE certificate from ' + @OldCertName + ' to ' + @NewCertName);

PRINT '  ✓ Rotation logged to SecurityAuditEvents';

-- Summary
PRINT '';
PRINT '╔════════════════════════════════════════════════════════════════╗';
PRINT '║  ✓ TDE Certificate Rotation Complete                           ║';
PRINT '╚════════════════════════════════════════════════════════════════╝';
PRINT '';
PRINT 'NEXT STEPS (mandatory):';
PRINT '  1. Upload new cert backup to S3: scripts/utilities/backup_cert_to_s3.sh';
PRINT '  2. Take a FULL backup immediately (first backup with new cert)';
PRINT '  3. Verify new backup restores correctly on test environment';
PRINT '  4. Update docs/KEY_ROTATION_RUNBOOK.md with rotation date';
PRINT '  5. Retain old certificate for ' + CAST(90 AS NVARCHAR) + '+ days';
GO
