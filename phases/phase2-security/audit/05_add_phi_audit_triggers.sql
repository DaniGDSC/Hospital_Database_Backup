-- Add audit triggers on all PHI tables
-- HIPAA 45 CFR 164.312(b): Log WHO accessed WHAT PHI and WHEN.
--
-- Currently audited: Appointments only (INSERT/UPDATE)
-- This script adds: MedicalRecords, Patients, Prescriptions, LabTests
-- Operations: INSERT, UPDATE, DELETE (full coverage)
-- Captures: OldValues, NewValues, ClientIP, SessionID
USE HospitalBackupDemo;
GO

SET NOCOUNT ON;

PRINT '╔════════════════════════════════════════════════════════════════╗';
PRINT '║         PHI Table Audit Triggers (HIPAA 164.312(b))            ║';
PRINT '╚════════════════════════════════════════════════════════════════╝';
PRINT '';

-- ============================================
-- Helper: Reusable pattern for each PHI table
-- Each trigger logs INSERT/UPDATE/DELETE with:
--   - TableName, RecordID (PK), Action type
--   - WHO: SUSER_SNAME(), USER_NAME()
--   - WHEN: SYSDATETIME()
--   - WHERE FROM: HOST_NAME(), CONNECTIONPROPERTY('client_net_address')
--   - WHAT CHANGED: OldValues/NewValues as XML
-- ============================================

-- ============================================
-- 1. MedicalRecords — Most sensitive PHI
-- ============================================

PRINT '--- Creating audit trigger: MedicalRecords ---';

IF OBJECT_ID('dbo.trg_MedicalRecords_Audit', 'TR') IS NOT NULL
    DROP TRIGGER dbo.trg_MedicalRecords_Audit;
GO

CREATE TRIGGER dbo.trg_MedicalRecords_Audit
ON dbo.MedicalRecords
AFTER INSERT, UPDATE, DELETE
AS
BEGIN
    SET NOCOUNT ON;

    DECLARE @Action NVARCHAR(20);
    IF EXISTS (SELECT 1 FROM inserted) AND EXISTS (SELECT 1 FROM deleted)
        SET @Action = 'UPDATE';
    ELSE IF EXISTS (SELECT 1 FROM inserted)
        SET @Action = 'INSERT';
    ELSE
        SET @Action = 'DELETE';

    -- Log from inserted (INSERT/UPDATE) or deleted (DELETE)
    INSERT INTO dbo.AuditLog
        (AuditDate, TableName, SchemaName, RecordID, Action, ActionType,
         UserName, DatabaseUser, HostName, ApplicationName, IPAddress, SessionID,
         OldValues, NewValues, IsSuccess, Severity, IsSecurityEvent, Notes)
    SELECT
        SYSDATETIME(),
        'MedicalRecords',
        'dbo',
        COALESCE(i.RecordID, d.RecordID),
        @Action,
        'PHI_ACCESS',
        SUSER_SNAME(),
        USER_NAME(),
        HOST_NAME(),
        APP_NAME(),
        CONVERT(NVARCHAR(50), CONNECTIONPROPERTY('client_net_address')),
        @@SPID,
        CASE WHEN d.RecordID IS NOT NULL THEN
            (SELECT d.RecordNumber, d.PatientID, d.DoctorID, d.Diagnosis, d.VisitType
             FOR XML RAW('old'), TYPE, ROOT('values'))
        END,
        CASE WHEN i.RecordID IS NOT NULL THEN
            (SELECT i.RecordNumber, i.PatientID, i.DoctorID, i.Diagnosis, i.VisitType
             FOR XML RAW('new'), TYPE, ROOT('values'))
        END,
        1,
        'High',
        1,
        'PHI audit: MedicalRecords ' + @Action
    FROM (SELECT TOP 1 * FROM inserted) i
    FULL OUTER JOIN (SELECT TOP 1 * FROM deleted) d ON 1=1;
END
GO

PRINT '  ✓ trg_MedicalRecords_Audit (INSERT/UPDATE/DELETE)';

-- ============================================
-- 2. Patients — NationalID, DOB, contact info
-- ============================================

PRINT '--- Creating audit trigger: Patients ---';

IF OBJECT_ID('dbo.trg_Patients_Audit', 'TR') IS NOT NULL
    DROP TRIGGER dbo.trg_Patients_Audit;
GO

CREATE TRIGGER dbo.trg_Patients_Audit
ON dbo.Patients
AFTER INSERT, UPDATE, DELETE
AS
BEGIN
    SET NOCOUNT ON;

    DECLARE @Action NVARCHAR(20);
    IF EXISTS (SELECT 1 FROM inserted) AND EXISTS (SELECT 1 FROM deleted)
        SET @Action = 'UPDATE';
    ELSE IF EXISTS (SELECT 1 FROM inserted)
        SET @Action = 'INSERT';
    ELSE
        SET @Action = 'DELETE';

    INSERT INTO dbo.AuditLog
        (AuditDate, TableName, SchemaName, RecordID, Action, ActionType,
         UserName, DatabaseUser, HostName, ApplicationName, IPAddress, SessionID,
         OldValues, NewValues, IsSuccess, Severity, IsSecurityEvent, Notes)
    SELECT
        SYSDATETIME(),
        'Patients',
        'dbo',
        COALESCE(i.PatientID, d.PatientID),
        @Action,
        'PHI_ACCESS',
        SUSER_SNAME(),
        USER_NAME(),
        HOST_NAME(),
        APP_NAME(),
        CONVERT(NVARCHAR(50), CONNECTIONPROPERTY('client_net_address')),
        @@SPID,
        CASE WHEN d.PatientID IS NOT NULL THEN
            (SELECT d.PatientCode, d.FirstName, d.LastName, d.DateOfBirth, d.Gender
             FOR XML RAW('old'), TYPE, ROOT('values'))
        END,
        CASE WHEN i.PatientID IS NOT NULL THEN
            (SELECT i.PatientCode, i.FirstName, i.LastName, i.DateOfBirth, i.Gender
             FOR XML RAW('new'), TYPE, ROOT('values'))
        END,
        1,
        'High',
        1,
        'PHI audit: Patients ' + @Action
    FROM (SELECT TOP 1 * FROM inserted) i
    FULL OUTER JOIN (SELECT TOP 1 * FROM deleted) d ON 1=1;
END
GO

PRINT '  ✓ trg_Patients_Audit (INSERT/UPDATE/DELETE)';

-- ============================================
-- 3. Prescriptions — Medication data
-- ============================================

PRINT '--- Creating audit trigger: Prescriptions ---';

IF OBJECT_ID('dbo.trg_Prescriptions_Audit', 'TR') IS NOT NULL
    DROP TRIGGER dbo.trg_Prescriptions_Audit;
GO

CREATE TRIGGER dbo.trg_Prescriptions_Audit
ON dbo.Prescriptions
AFTER INSERT, UPDATE, DELETE
AS
BEGIN
    SET NOCOUNT ON;

    DECLARE @Action NVARCHAR(20);
    IF EXISTS (SELECT 1 FROM inserted) AND EXISTS (SELECT 1 FROM deleted)
        SET @Action = 'UPDATE';
    ELSE IF EXISTS (SELECT 1 FROM inserted)
        SET @Action = 'INSERT';
    ELSE
        SET @Action = 'DELETE';

    INSERT INTO dbo.AuditLog
        (AuditDate, TableName, SchemaName, RecordID, Action, ActionType,
         UserName, DatabaseUser, HostName, ApplicationName, IPAddress, SessionID,
         OldValues, NewValues, IsSuccess, Severity, IsSecurityEvent, Notes)
    SELECT
        SYSDATETIME(),
        'Prescriptions',
        'dbo',
        COALESCE(i.PrescriptionID, d.PrescriptionID),
        @Action,
        'PHI_ACCESS',
        SUSER_SNAME(),
        USER_NAME(),
        HOST_NAME(),
        APP_NAME(),
        CONVERT(NVARCHAR(50), CONNECTIONPROPERTY('client_net_address')),
        @@SPID,
        CASE WHEN d.PrescriptionID IS NOT NULL THEN
            (SELECT d.PrescriptionNumber, d.PatientID, d.DoctorID, d.Status
             FOR XML RAW('old'), TYPE, ROOT('values'))
        END,
        CASE WHEN i.PrescriptionID IS NOT NULL THEN
            (SELECT i.PrescriptionNumber, i.PatientID, i.DoctorID, i.Status
             FOR XML RAW('new'), TYPE, ROOT('values'))
        END,
        1,
        'Medium',
        1,
        'PHI audit: Prescriptions ' + @Action
    FROM (SELECT TOP 1 * FROM inserted) i
    FULL OUTER JOIN (SELECT TOP 1 * FROM deleted) d ON 1=1;
END
GO

PRINT '  ✓ trg_Prescriptions_Audit (INSERT/UPDATE/DELETE)';

-- ============================================
-- 4. LabTests — Diagnostic data
-- ============================================

PRINT '--- Creating audit trigger: LabTests ---';

IF OBJECT_ID('dbo.trg_LabTests_Audit', 'TR') IS NOT NULL
    DROP TRIGGER dbo.trg_LabTests_Audit;
GO

CREATE TRIGGER dbo.trg_LabTests_Audit
ON dbo.LabTests
AFTER INSERT, UPDATE, DELETE
AS
BEGIN
    SET NOCOUNT ON;

    DECLARE @Action NVARCHAR(20);
    IF EXISTS (SELECT 1 FROM inserted) AND EXISTS (SELECT 1 FROM deleted)
        SET @Action = 'UPDATE';
    ELSE IF EXISTS (SELECT 1 FROM inserted)
        SET @Action = 'INSERT';
    ELSE
        SET @Action = 'DELETE';

    INSERT INTO dbo.AuditLog
        (AuditDate, TableName, SchemaName, RecordID, Action, ActionType,
         UserName, DatabaseUser, HostName, ApplicationName, IPAddress, SessionID,
         OldValues, NewValues, IsSuccess, Severity, IsSecurityEvent, Notes)
    SELECT
        SYSDATETIME(),
        'LabTests',
        'dbo',
        COALESCE(i.LabTestID, d.LabTestID),
        @Action,
        'PHI_ACCESS',
        SUSER_SNAME(),
        USER_NAME(),
        HOST_NAME(),
        APP_NAME(),
        CONVERT(NVARCHAR(50), CONNECTIONPROPERTY('client_net_address')),
        @@SPID,
        CASE WHEN d.LabTestID IS NOT NULL THEN
            (SELECT d.TestNumber, d.PatientID, d.DoctorID, d.TestName, d.Status
             FOR XML RAW('old'), TYPE, ROOT('values'))
        END,
        CASE WHEN i.LabTestID IS NOT NULL THEN
            (SELECT i.TestNumber, i.PatientID, i.DoctorID, i.TestName, i.Status
             FOR XML RAW('new'), TYPE, ROOT('values'))
        END,
        1,
        'Medium',
        1,
        'PHI audit: LabTests ' + @Action
    FROM (SELECT TOP 1 * FROM inserted) i
    FULL OUTER JOIN (SELECT TOP 1 * FROM deleted) d ON 1=1;
END
GO

PRINT '  ✓ trg_LabTests_Audit (INSERT/UPDATE/DELETE)';

-- ============================================
-- 5. Update existing Appointments trigger to also cover DELETE
-- ============================================

PRINT '';
PRINT '--- Updating Appointments trigger to include DELETE ---';

IF OBJECT_ID('dbo.trg_Appointments_Audit', 'TR') IS NOT NULL
    DROP TRIGGER dbo.trg_Appointments_Audit;
GO

CREATE TRIGGER dbo.trg_Appointments_Audit
ON dbo.Appointments
AFTER INSERT, UPDATE, DELETE
AS
BEGIN
    SET NOCOUNT ON;

    DECLARE @Action NVARCHAR(20);
    IF EXISTS (SELECT 1 FROM inserted) AND EXISTS (SELECT 1 FROM deleted)
        SET @Action = 'UPDATE';
    ELSE IF EXISTS (SELECT 1 FROM inserted)
        SET @Action = 'INSERT';
    ELSE
        SET @Action = 'DELETE';

    INSERT INTO dbo.AuditLog
        (AuditDate, TableName, SchemaName, RecordID, Action, ActionType,
         UserName, DatabaseUser, HostName, ApplicationName, IPAddress, SessionID,
         OldValues, NewValues, IsSuccess, Severity, IsSecurityEvent, Notes)
    SELECT
        SYSDATETIME(),
        'Appointments',
        'dbo',
        COALESCE(i.AppointmentID, d.AppointmentID),
        @Action,
        'PHI_ACCESS',
        SUSER_SNAME(),
        USER_NAME(),
        HOST_NAME(),
        APP_NAME(),
        CONVERT(NVARCHAR(50), CONNECTIONPROPERTY('client_net_address')),
        @@SPID,
        CASE WHEN d.AppointmentID IS NOT NULL THEN
            (SELECT d.AppointmentNumber, d.PatientID, d.DoctorID, d.Status, d.AppointmentType
             FOR XML RAW('old'), TYPE, ROOT('values'))
        END,
        CASE WHEN i.AppointmentID IS NOT NULL THEN
            (SELECT i.AppointmentNumber, i.PatientID, i.DoctorID, i.Status, i.AppointmentType
             FOR XML RAW('new'), TYPE, ROOT('values'))
        END,
        1,
        'Low',
        0,
        'PHI audit: Appointments ' + @Action
    FROM (SELECT TOP 1 * FROM inserted) i
    FULL OUTER JOIN (SELECT TOP 1 * FROM deleted) d ON 1=1;
END
GO

PRINT '  ✓ trg_Appointments_Audit updated (now includes DELETE + OldValues/NewValues)';

-- ============================================
-- Summary
-- ============================================
PRINT '';
PRINT '✓ PHI audit triggers deployed:';
PRINT '  - MedicalRecords  (INSERT/UPDATE/DELETE) — High severity';
PRINT '  - Patients         (INSERT/UPDATE/DELETE) — High severity';
PRINT '  - Prescriptions    (INSERT/UPDATE/DELETE) — Medium severity';
PRINT '  - LabTests         (INSERT/UPDATE/DELETE) — Medium severity';
PRINT '  - Appointments     (INSERT/UPDATE/DELETE) — Low severity (updated)';
PRINT '';
PRINT 'Each trigger captures:';
PRINT '  WHO:   SUSER_SNAME(), USER_NAME()';
PRINT '  WHAT:  TableName, RecordID, OldValues/NewValues (XML)';
PRINT '  WHEN:  SYSDATETIME()';
PRINT '  WHERE: HOST_NAME(), client_net_address, @@SPID';
GO
