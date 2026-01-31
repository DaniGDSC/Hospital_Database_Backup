-- Audit storage for security-related events
USE HospitalBackupDemo;
GO

SET NOCOUNT ON;

PRINT '=== Creating security audit table ===';

IF OBJECT_ID('dbo.SecurityAuditEvents', 'U') IS NULL
BEGIN
    CREATE TABLE dbo.SecurityAuditEvents (
        AuditEventID BIGINT IDENTITY(1,1) PRIMARY KEY,
        EventTime DATETIME2 NOT NULL DEFAULT SYSDATETIME(),
        EventType NVARCHAR(100) NOT NULL,
        LoginName NVARCHAR(128) NULL,
        DatabaseUser NVARCHAR(128) NULL,
        ObjectName NVARCHAR(256) NULL,
        ObjectType NVARCHAR(60) NULL,
        Action NVARCHAR(60) NULL,
        Success BIT NOT NULL DEFAULT 1,
        ClientHost NVARCHAR(128) NULL,
        ApplicationName NVARCHAR(128) NULL,
        Details NVARCHAR(MAX) NULL
    );
    PRINT 'SecurityAuditEvents table created.';
END
ELSE
    PRINT 'SecurityAuditEvents table already exists.';
GO
