-- Verify TDE certificate exists and backup files are on disk
-- Run after 02_create_certificates.sql to confirm backup integrity
USE master;
GO

SET NOCOUNT ON;

DECLARE @AlertCount INT = 0;
DECLARE @CertFile NVARCHAR(260) = '/var/opt/mssql/backup/certificates/HospitalBackupDemo_TDECert.cer';
DECLARE @KeyFile  NVARCHAR(260) = '/var/opt/mssql/backup/certificates/HospitalBackupDemo_TDECert.pvk';

PRINT '╔════════════════════════════════════════════════════════════════╗';
PRINT '║         TDE Certificate Backup Verification                    ║';
PRINT '╚════════════════════════════════════════════════════════════════╝';
PRINT '';

-- Check 1: Certificate exists in master
PRINT '--- Check 1: Certificate in master DB ---';
IF EXISTS (SELECT 1 FROM sys.certificates WHERE name = 'HospitalBackupDemo_TDECert')
BEGIN
    DECLARE @Subject NVARCHAR(256), @Expiry DATETIME, @Thumbprint VARBINARY(32);
    SELECT @Subject = subject, @Expiry = expiry_date, @Thumbprint = thumbprint
    FROM sys.certificates WHERE name = 'HospitalBackupDemo_TDECert';

    PRINT '  ✓ Certificate exists';
    PRINT '    Subject:     ' + @Subject;
    PRINT '    Expiry:      ' + CONVERT(NVARCHAR(30), @Expiry, 120);
    PRINT '    Thumbprint:  ' + CONVERT(NVARCHAR(64), @Thumbprint, 1);
END
ELSE
BEGIN
    PRINT '  ✗ CRITICAL: TDE certificate NOT FOUND in master';
    SET @AlertCount = @AlertCount + 1;
END

-- Check 2: .cer file exists on disk
PRINT '';
PRINT '--- Check 2: Certificate file on disk ---';

DECLARE @CerExists INT;
EXEC master.dbo.xp_fileexist @CertFile, @CerExists OUTPUT;

IF @CerExists = 1
    PRINT '  ✓ Certificate file exists: ' + @CertFile;
ELSE
BEGIN
    PRINT '  ✗ CRITICAL: Certificate file NOT FOUND: ' + @CertFile;
    SET @AlertCount = @AlertCount + 1;
END

-- Check 3: .pvk file exists on disk
PRINT '';
PRINT '--- Check 3: Private key file on disk ---';

DECLARE @PvkExists INT;
EXEC master.dbo.xp_fileexist @KeyFile, @PvkExists OUTPUT;

IF @PvkExists = 1
    PRINT '  ✓ Private key file exists: ' + @KeyFile;
ELSE
BEGIN
    PRINT '  ✗ CRITICAL: Private key file NOT FOUND: ' + @KeyFile;
    SET @AlertCount = @AlertCount + 1;
END

-- Check 4: TDE is active on the database
PRINT '';
PRINT '--- Check 4: TDE encryption state ---';

DECLARE @EncState INT;
SELECT @EncState = encryption_state
FROM sys.dm_database_encryption_keys
WHERE database_id = DB_ID('HospitalBackupDemo');

IF @EncState = 3
    PRINT '  ✓ TDE is active (encryption_state = 3)';
ELSE IF @EncState IS NULL
BEGIN
    PRINT '  ✗ TDE not initialized on HospitalBackupDemo';
    SET @AlertCount = @AlertCount + 1;
END
ELSE
    PRINT '  ⚠ TDE in transition state: ' + CAST(@EncState AS NVARCHAR);

-- Log result to AuditLog
PRINT '';
PRINT '--- Logging verification result ---';

DECLARE @Status NVARCHAR(20) = CASE WHEN @AlertCount = 0 THEN 'PASS' ELSE 'FAIL' END;
DECLARE @Detail NVARCHAR(500) = CONCAT(
    'Certificate backup verification: ', @Status,
    ' | Alerts: ', @AlertCount,
    ' | CER file: ', CASE WHEN @CerExists = 1 THEN 'OK' ELSE 'MISSING' END,
    ' | PVK file: ', CASE WHEN @PvkExists = 1 THEN 'OK' ELSE 'MISSING' END
);

INSERT INTO HospitalBackupDemo.dbo.AuditLog
    (AuditDate, TableName, SchemaName, RecordID, Action, ActionType,
     UserName, HostName, ApplicationName, IsSuccess, Severity, Notes)
VALUES
    (SYSDATETIME(), 'sys.certificates', 'master', 0, 'SELECT', 'CERT_BACKUP_VERIFY',
     SUSER_SNAME(), HOST_NAME(), APP_NAME(),
     CASE WHEN @AlertCount = 0 THEN 1 ELSE 0 END,
     CASE WHEN @AlertCount = 0 THEN 'Low' ELSE 'Critical' END,
     @Detail);

PRINT '  Logged to AuditLog: ' + @Detail;

-- Summary
PRINT '';
IF @AlertCount = 0
    PRINT '✓ All certificate backup checks PASSED';
ELSE
BEGIN
    PRINT '✗ ' + CAST(@AlertCount AS NVARCHAR) + ' CRITICAL check(s) FAILED';
    RAISERROR('Certificate backup verification failed: %d critical issues', 16, 1, @AlertCount);
END
GO
