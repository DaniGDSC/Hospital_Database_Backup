-- Create S3 credential for backups (skips if missing values or already exists)
USE master;
GO

SET NOCOUNT ON;

PRINT '=== Ensuring S3 backup credential ===';

-- Replace these placeholder values before enabling S3 backups
-- Injected by sqlcmd: $(S3_IDENTITY) and $(S3_SECRET)
DECLARE @identity NVARCHAR(128) = N'$(S3_IDENTITY)';  -- e.g., 'AKIA...'
DECLARE @secret NVARCHAR(256) = N'$(S3_SECRET)';      -- e.g., 'aws-secret-key'
DECLARE @credName SYSNAME = N'S3_HospitalBackupDemo';

IF EXISTS (SELECT 1 FROM sys.credentials WHERE name = @credName)
BEGIN
    PRINT 'Credential already exists: ' + @credName;
    RETURN;
END

IF @identity IS NULL OR @identity = N'' OR @secret IS NULL OR @secret = N''
BEGIN
    PRINT 'Skipping creation: set @identity and @secret to your AWS credentials before running.';
    RETURN;
END

DECLARE @sql NVARCHAR(MAX) = N'CREATE CREDENTIAL ' + QUOTENAME(@credName) + N'
    WITH IDENTITY = ''' + @identity + N''', SECRET = ''' + @secret + N''';';
EXEC (@sql);
PRINT '✓ S3 credential created: ' + @credName;
GO
