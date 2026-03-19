-- Backup verification tracking table
-- NIST SP 800-34: Document all backup verification results
-- Protected with same DENY/DDL trigger pattern as audit tables
USE HospitalBackupDemo;
GO

SET NOCOUNT ON;

PRINT '=== Creating BackupVerificationLog table ===';

IF OBJECT_ID('dbo.BackupVerificationLog', 'U') IS NULL
BEGIN
    CREATE TABLE dbo.BackupVerificationLog (
        VerificationID INT IDENTITY(1,1) NOT NULL,
        BackupType NVARCHAR(20) NOT NULL,
        FileName NVARCHAR(500) NOT NULL,
        BackupSizeBytes BIGINT NULL,
        VerificationStart DATETIME NOT NULL,
        VerificationEnd DATETIME NULL,
        DurationSeconds INT NULL,
        Status VARCHAR(10) NOT NULL CHECK (Status IN ('PASS', 'FAIL')),
        ErrorMessage NVARCHAR(MAX) NULL,
        VerifiedBy NVARCHAR(128) NOT NULL DEFAULT SUSER_SNAME(),

        CONSTRAINT PK_BackupVerificationLog PRIMARY KEY CLUSTERED (VerificationID)
    );

    -- Index for health check queries
    CREATE NONCLUSTERED INDEX IX_BackupVerificationLog_TypeDateStatus
        ON dbo.BackupVerificationLog (BackupType, VerificationStart DESC, Status);

    PRINT '✓ BackupVerificationLog table created';
END
ELSE
    PRINT 'BackupVerificationLog table already exists';
GO

-- Protect this table the same way as audit tables:
-- No one can delete or modify verification records
DENY DELETE, UPDATE ON dbo.BackupVerificationLog TO public;
PRINT '✓ DENY DELETE/UPDATE applied to BackupVerificationLog';
GO

-- Add to DDL protection trigger if it exists
-- (trg_Protect_AuditTables already blocks DROP/ALTER on audit tables;
--  we update it to also protect BackupVerificationLog)
IF EXISTS (SELECT 1 FROM sys.triggers WHERE name = 'trg_Protect_AuditTables' AND parent_class = 0)
    DROP TRIGGER trg_Protect_AuditTables ON DATABASE;
GO

CREATE TRIGGER trg_Protect_AuditTables
ON DATABASE
FOR DROP_TABLE, ALTER_TABLE
AS
BEGIN
    SET NOCOUNT ON;

    DECLARE @EventData XML = EVENTDATA();
    DECLARE @ObjectName NVARCHAR(256) = @EventData.value('(/EVENT_INSTANCE/ObjectName)[1]', 'NVARCHAR(256)');
    DECLARE @EventType NVARCHAR(100) = @EventData.value('(/EVENT_INSTANCE/EventType)[1]', 'NVARCHAR(100)');

    IF @ObjectName IN ('AuditLog', 'SecurityAuditEvents', 'SecurityEvents', 'BackupVerificationLog')
    BEGIN
        INSERT INTO dbo.SecurityAuditEvents
            (EventTime, EventType, LoginName, DatabaseUser, ObjectName,
             ObjectType, Action, Success, ClientHost, ApplicationName, Details)
        VALUES
            (SYSDATETIME(), 'AUDIT_TABLE_PROTECTION', ORIGINAL_LOGIN(), USER_NAME(),
             @ObjectName, 'TABLE', @EventType, 0, HOST_NAME(), APP_NAME(),
             'BLOCKED: Attempted ' + @EventType + ' on protected table ' + @ObjectName);

        PRINT 'BLOCKED: ' + @EventType + ' on protected table [' + @ObjectName + '] is not permitted.';
        ROLLBACK;
    END
END
GO

PRINT '✓ DDL trigger updated to protect BackupVerificationLog';
GO
