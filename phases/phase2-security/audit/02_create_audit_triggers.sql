-- DDL trigger to capture role/user changes into SecurityAuditEvents
USE HospitalBackupDemo;
GO

SET NOCOUNT ON;

PRINT '=== Creating DDL audit trigger ===';

IF OBJECT_ID('dbo.trg_Audit_DDL_Security', 'TR') IS NOT NULL
    DROP TRIGGER dbo.trg_Audit_DDL_Security ON DATABASE;
GO

CREATE TRIGGER dbo.trg_Audit_DDL_Security
ON DATABASE
FOR CREATE_USER, ALTER_USER, DROP_USER,
    CREATE_ROLE, ALTER_ROLE, DROP_ROLE,
    ADD_ROLE_MEMBER, DROP_ROLE_MEMBER
AS
BEGIN
    SET NOCOUNT ON;

    DECLARE @event XML = EVENTDATA();
    INSERT INTO dbo.SecurityAuditEvents
        (EventTime, EventType, LoginName, DatabaseUser, ObjectName, ObjectType, Action, Success, ClientHost, ApplicationName, Details)
    VALUES
        (SYSDATETIME(),
         @event.value('(/EVENT_INSTANCE/EventType)[1]', 'NVARCHAR(100)'),
         ORIGINAL_LOGIN(),
         USER_NAME(),
         @event.value('(/EVENT_INSTANCE/ObjectName)[1]', 'NVARCHAR(256)'),
         @event.value('(/EVENT_INSTANCE/ObjectType)[1]', 'NVARCHAR(60)'),
         @event.value('(/EVENT_INSTANCE/EventType)[1]', 'NVARCHAR(60)'),
         1,
         HOST_NAME(),
         APP_NAME(),
         CONVERT(NVARCHAR(MAX), @event));
END
GO

PRINT '✓ Audit trigger created.';
GO
