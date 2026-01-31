-- Triggers for HospitalBackupDemo
USE HospitalBackupDemo;
GO

SET NOCOUNT ON;

PRINT '=== Creating triggers ===';

-- Audit trigger for Appointments
IF OBJECT_ID('dbo.trg_Appointments_Audit', 'TR') IS NOT NULL
    DROP TRIGGER dbo.trg_Appointments_Audit;
GO
CREATE TRIGGER dbo.trg_Appointments_Audit
ON dbo.Appointments
AFTER INSERT, UPDATE
AS
BEGIN
    SET NOCOUNT ON;

    INSERT INTO dbo.AuditLog
        (AuditDate, TableName, SchemaName, RecordID, Action, UserName, HostName, ApplicationName, SQLStatement, IsSuccess, Severity, IsSecurityEvent, RequiresReview, Notes)
    SELECT
        SYSDATETIME(),
        'Appointments',
        'dbo',
        i.AppointmentID,
        CASE WHEN EXISTS (SELECT 1 FROM deleted) THEN 'UPDATE' ELSE 'INSERT' END,
        SUSER_SNAME(),
        HOST_NAME(),
        APP_NAME(),
        'Appointment change',
        1,
        'Low',
        0,
        0,
        'Auto audit trigger'
    FROM inserted i;
END
GO

PRINT '✓ Triggers created.';
GO
