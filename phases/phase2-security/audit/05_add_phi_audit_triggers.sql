-- Add audit triggers on all PHI tables
-- HIPAA 45 CFR 164.312(b): Log WHO accessed WHAT PHI and WHEN.
--
-- Covers: MedicalRecords, Patients, Prescriptions, LabTests, Appointments
-- Operations: INSERT, UPDATE, DELETE (full coverage)
-- Features:
--   - TRY/CATCH: audit failure never blocks clinical operations
--   - Multi-row: logs every row in batch operations (not just first)
--   - NationalID masking: Patients trigger masks to last 4 digits
--   - Severity escalation: Prescriptions DELETE = High risk
USE HospitalBackupDemo;
GO

SET NOCOUNT ON;

PRINT '╔════════════════════════════════════════════════════════════════╗';
PRINT '║         PHI Table Audit Triggers (HIPAA 164.312(b))            ║';
PRINT '╚════════════════════════════════════════════════════════════════╝';
PRINT '';

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
    BEGIN TRY
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
        FROM inserted i
        FULL OUTER JOIN deleted d ON i.RecordID = d.RecordID;
    END TRY
    BEGIN CATCH
        -- Audit must never block clinical operations (HIPAA)
        PRINT 'PHI audit trigger failed (non-fatal): ' + ERROR_MESSAGE();
    END CATCH
END
GO

PRINT '  ✓ trg_MedicalRecords_Audit (INSERT/UPDATE/DELETE)';

-- ============================================
-- 2. Patients — NationalID masked, DOB, contact info
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
    BEGIN TRY
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
            -- OldValues: NationalID masked to last 4 digits only
            CASE WHEN d.PatientID IS NOT NULL THEN
                (SELECT d.PatientCode, d.FirstName, d.LastName, d.DateOfBirth, d.Gender,
                        '***' + RIGHT(ISNULL(d.NationalID, ''), 4) AS NationalID_Masked
                 FOR XML RAW('old'), TYPE, ROOT('values'))
            END,
            -- NewValues: NationalID masked to last 4 digits only
            CASE WHEN i.PatientID IS NOT NULL THEN
                (SELECT i.PatientCode, i.FirstName, i.LastName, i.DateOfBirth, i.Gender,
                        '***' + RIGHT(ISNULL(i.NationalID, ''), 4) AS NationalID_Masked
                 FOR XML RAW('new'), TYPE, ROOT('values'))
            END,
            1,
            'High',
            1,
            'PHI audit: Patients ' + @Action
        FROM inserted i
        FULL OUTER JOIN deleted d ON i.PatientID = d.PatientID;
    END TRY
    BEGIN CATCH
        PRINT 'PHI audit trigger failed (non-fatal): ' + ERROR_MESSAGE();
    END CATCH
END
GO

PRINT '  ✓ trg_Patients_Audit (INSERT/UPDATE/DELETE, NationalID masked)';

-- ============================================
-- 3. Prescriptions — DELETE = High risk
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
    BEGIN TRY
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
            -- DELETE on prescriptions = High risk (potential evidence destruction)
            CASE WHEN @Action = 'DELETE' THEN 'High' ELSE 'Medium' END,
            1,
            'PHI audit: Prescriptions ' + @Action
                + CASE WHEN @Action = 'DELETE' THEN ' [HIGH RISK]' ELSE '' END
        FROM inserted i
        FULL OUTER JOIN deleted d ON i.PrescriptionID = d.PrescriptionID;
    END TRY
    BEGIN CATCH
        PRINT 'PHI audit trigger failed (non-fatal): ' + ERROR_MESSAGE();
    END CATCH
END
GO

PRINT '  ✓ trg_Prescriptions_Audit (INSERT/UPDATE/DELETE, DELETE=High)';

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
    BEGIN TRY
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
        FROM inserted i
        FULL OUTER JOIN deleted d ON i.LabTestID = d.LabTestID;
    END TRY
    BEGIN CATCH
        PRINT 'PHI audit trigger failed (non-fatal): ' + ERROR_MESSAGE();
    END CATCH
END
GO

PRINT '  ✓ trg_LabTests_Audit (INSERT/UPDATE/DELETE)';

-- ============================================
-- 5. Appointments — Updated with TRY/CATCH + multi-row
-- ============================================

PRINT '';
PRINT '--- Updating Appointments trigger ---';

IF OBJECT_ID('dbo.trg_Appointments_Audit', 'TR') IS NOT NULL
    DROP TRIGGER dbo.trg_Appointments_Audit;
GO

CREATE TRIGGER dbo.trg_Appointments_Audit
ON dbo.Appointments
AFTER INSERT, UPDATE, DELETE
AS
BEGIN
    SET NOCOUNT ON;
    BEGIN TRY
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
        FROM inserted i
        FULL OUTER JOIN deleted d ON i.AppointmentID = d.AppointmentID;
    END TRY
    BEGIN CATCH
        PRINT 'PHI audit trigger failed (non-fatal): ' + ERROR_MESSAGE();
    END CATCH
END
GO

PRINT '  ✓ trg_Appointments_Audit (INSERT/UPDATE/DELETE)';

-- ============================================
-- Summary
-- ============================================
PRINT '';
PRINT '✓ PHI audit triggers deployed:';
PRINT '  - MedicalRecords  (INSERT/UPDATE/DELETE) — High severity';
PRINT '  - Patients         (INSERT/UPDATE/DELETE) — High severity, NationalID masked';
PRINT '  - Prescriptions    (INSERT/UPDATE/DELETE) — Medium/High on DELETE';
PRINT '  - LabTests         (INSERT/UPDATE/DELETE) — Medium severity';
PRINT '  - Appointments     (INSERT/UPDATE/DELETE) — Low severity';
PRINT '';
PRINT 'All triggers: TRY/CATCH protected, multi-row capable';
PRINT '  WHO:   SUSER_SNAME(), USER_NAME()';
PRINT '  WHAT:  TableName, RecordID, OldValues/NewValues (XML)';
PRINT '  WHEN:  SYSDATETIME()';
PRINT '  WHERE: HOST_NAME(), client_net_address, @@SPID';
GO
