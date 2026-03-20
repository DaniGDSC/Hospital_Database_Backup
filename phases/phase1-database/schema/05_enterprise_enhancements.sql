-- Enterprise enhancements for healthcare-grade compliance
-- Category 1.1: Database Design — Items 1, 4, 5, 6
-- Standards: HL7 FHIR R4, HIPAA 45 CFR 164.312(b), 164.530(j)
--
-- Adds: FHIR resource IDs, soft delete columns, RowVersion,
--        data retention policy table
-- Safe: ALTER TABLE ADD only — no existing columns modified
USE HospitalBackupDemo;
GO

SET NOCOUNT ON;

PRINT '╔════════════════════════════════════════════════════════════════╗';
PRINT '║     Enterprise Healthcare Enhancements                         ║';
PRINT '║     FHIR + Soft Delete + Concurrency + Retention               ║';
PRINT '╚════════════════════════════════════════════════════════════════╝';
PRINT '';

-- ============================================
-- FHIR Resource Columns (Item 1)
-- Enables future FHIR API without schema change
-- ============================================

PRINT '--- Adding FHIR resource columns ---';

IF NOT EXISTS (SELECT 1 FROM sys.columns WHERE object_id = OBJECT_ID('dbo.Patients') AND name = 'FhirResourceId')
    ALTER TABLE dbo.Patients ADD
        FhirResourceId   UNIQUEIDENTIFIER NOT NULL DEFAULT NEWID(),
        FhirResourceType VARCHAR(50)      NOT NULL DEFAULT 'Patient',
        FhirLastUpdated  DATETIME2        NOT NULL DEFAULT SYSDATETIME();
GO

IF NOT EXISTS (SELECT 1 FROM sys.columns WHERE object_id = OBJECT_ID('dbo.MedicalRecords') AND name = 'FhirResourceId')
    ALTER TABLE dbo.MedicalRecords ADD
        FhirResourceId   UNIQUEIDENTIFIER NOT NULL DEFAULT NEWID(),
        FhirResourceType VARCHAR(50)      NOT NULL DEFAULT 'Condition',
        FhirLastUpdated  DATETIME2        NOT NULL DEFAULT SYSDATETIME();
GO

IF NOT EXISTS (SELECT 1 FROM sys.columns WHERE object_id = OBJECT_ID('dbo.Prescriptions') AND name = 'FhirResourceId')
    ALTER TABLE dbo.Prescriptions ADD
        FhirResourceId   UNIQUEIDENTIFIER NOT NULL DEFAULT NEWID(),
        FhirResourceType VARCHAR(50)      NOT NULL DEFAULT 'MedicationRequest',
        FhirLastUpdated  DATETIME2        NOT NULL DEFAULT SYSDATETIME();
GO

IF NOT EXISTS (SELECT 1 FROM sys.columns WHERE object_id = OBJECT_ID('dbo.LabTests') AND name = 'FhirResourceId')
    ALTER TABLE dbo.LabTests ADD
        FhirResourceId   UNIQUEIDENTIFIER NOT NULL DEFAULT NEWID(),
        FhirResourceType VARCHAR(50)      NOT NULL DEFAULT 'DiagnosticReport',
        FhirLastUpdated  DATETIME2        NOT NULL DEFAULT SYSDATETIME();
GO

IF NOT EXISTS (SELECT 1 FROM sys.columns WHERE object_id = OBJECT_ID('dbo.Admissions') AND name = 'FhirResourceId')
    ALTER TABLE dbo.Admissions ADD
        FhirResourceId   UNIQUEIDENTIFIER NOT NULL DEFAULT NEWID(),
        FhirResourceType VARCHAR(50)      NOT NULL DEFAULT 'Encounter',
        FhirLastUpdated  DATETIME2        NOT NULL DEFAULT SYSDATETIME();
GO

IF NOT EXISTS (SELECT 1 FROM sys.columns WHERE object_id = OBJECT_ID('dbo.Appointments') AND name = 'FhirResourceId')
    ALTER TABLE dbo.Appointments ADD
        FhirResourceId   UNIQUEIDENTIFIER NOT NULL DEFAULT NEWID(),
        FhirResourceType VARCHAR(50)      NOT NULL DEFAULT 'Appointment',
        FhirLastUpdated  DATETIME2        NOT NULL DEFAULT SYSDATETIME();
GO

PRINT '  ✓ FHIR resource columns added to 6 tables';

-- ============================================
-- Soft Delete + RowVersion Columns (Items 4, 5)
-- HIPAA: PHI retained 6 years minimum — never hard delete
-- ============================================

PRINT '';
PRINT '--- Adding soft delete + concurrency columns ---';

-- Patients
IF NOT EXISTS (SELECT 1 FROM sys.columns WHERE object_id = OBJECT_ID('dbo.Patients') AND name = 'IsDeleted')
    ALTER TABLE dbo.Patients ADD
        IsDeleted  BIT           NOT NULL DEFAULT 0,
        DeletedAt  DATETIME2     NULL,
        DeletedBy  NVARCHAR(128) NULL,
        RowVersion ROWVERSION    NOT NULL;
GO

-- MedicalRecords
IF NOT EXISTS (SELECT 1 FROM sys.columns WHERE object_id = OBJECT_ID('dbo.MedicalRecords') AND name = 'IsDeleted')
    ALTER TABLE dbo.MedicalRecords ADD
        IsDeleted  BIT           NOT NULL DEFAULT 0,
        DeletedAt  DATETIME2     NULL,
        DeletedBy  NVARCHAR(128) NULL,
        RowVersion ROWVERSION    NOT NULL;
GO

-- Prescriptions
IF NOT EXISTS (SELECT 1 FROM sys.columns WHERE object_id = OBJECT_ID('dbo.Prescriptions') AND name = 'IsDeleted')
    ALTER TABLE dbo.Prescriptions ADD
        IsDeleted  BIT           NOT NULL DEFAULT 0,
        DeletedAt  DATETIME2     NULL,
        DeletedBy  NVARCHAR(128) NULL,
        RowVersion ROWVERSION    NOT NULL;
GO

-- PrescriptionDetails (also add missing ModifiedDate/ModifiedBy)
IF NOT EXISTS (SELECT 1 FROM sys.columns WHERE object_id = OBJECT_ID('dbo.PrescriptionDetails') AND name = 'IsDeleted')
    ALTER TABLE dbo.PrescriptionDetails ADD
        ModifiedDate DATETIME2     NULL,
        ModifiedBy   NVARCHAR(100) NULL,
        IsDeleted    BIT           NOT NULL DEFAULT 0,
        DeletedAt    DATETIME2     NULL,
        DeletedBy    NVARCHAR(128) NULL,
        RowVersion   ROWVERSION    NOT NULL;
GO

-- LabTests
IF NOT EXISTS (SELECT 1 FROM sys.columns WHERE object_id = OBJECT_ID('dbo.LabTests') AND name = 'IsDeleted')
    ALTER TABLE dbo.LabTests ADD
        IsDeleted  BIT           NOT NULL DEFAULT 0,
        DeletedAt  DATETIME2     NULL,
        DeletedBy  NVARCHAR(128) NULL,
        RowVersion ROWVERSION    NOT NULL;
GO

-- Admissions
IF NOT EXISTS (SELECT 1 FROM sys.columns WHERE object_id = OBJECT_ID('dbo.Admissions') AND name = 'IsDeleted')
    ALTER TABLE dbo.Admissions ADD
        IsDeleted  BIT           NOT NULL DEFAULT 0,
        DeletedAt  DATETIME2     NULL,
        DeletedBy  NVARCHAR(128) NULL,
        RowVersion ROWVERSION    NOT NULL;
GO

-- Appointments
IF NOT EXISTS (SELECT 1 FROM sys.columns WHERE object_id = OBJECT_ID('dbo.Appointments') AND name = 'IsDeleted')
    ALTER TABLE dbo.Appointments ADD
        IsDeleted  BIT           NOT NULL DEFAULT 0,
        DeletedAt  DATETIME2     NULL,
        DeletedBy  NVARCHAR(128) NULL,
        RowVersion ROWVERSION    NOT NULL;
GO

PRINT '  ✓ Soft delete + RowVersion added to 7 tables';

-- ============================================
-- Data Retention Policy Table (Item 6)
-- HIPAA 45 CFR 164.530(j): 6-year PHI retention
-- ============================================

PRINT '';
PRINT '--- Creating data retention policy table ---';

IF OBJECT_ID('dbo.DataRetentionPolicy', 'U') IS NULL
BEGIN
    CREATE TABLE dbo.DataRetentionPolicy (
        PolicyID          INT IDENTITY(1,1) PRIMARY KEY,
        TableName         NVARCHAR(128)  NOT NULL,
        SchemaName        NVARCHAR(128)  NOT NULL DEFAULT 'dbo',
        RetentionYears    INT            NOT NULL,
        RetentionType     VARCHAR(20)    NOT NULL
            CHECK (RetentionType IN ('HIPAA_PHI', 'CLINICAL', 'ADMINISTRATIVE', 'AUDIT', 'SYSTEM')),
        ArchiveAfterYears INT            NULL,
        PurgeAfterYears   INT            NULL,
        LastReviewDate    DATE           NOT NULL DEFAULT GETDATE(),
        ReviewedBy        NVARCHAR(128)  NOT NULL DEFAULT SUSER_SNAME(),
        Notes             NVARCHAR(500)  NULL,
        CONSTRAINT UK_RetentionPolicy_Table UNIQUE (SchemaName, TableName)
    );

    INSERT INTO dbo.DataRetentionPolicy
        (TableName, RetentionYears, RetentionType, ArchiveAfterYears, PurgeAfterYears, Notes)
    VALUES
        ('Patients',            6, 'HIPAA_PHI',      3, NULL, 'PHI — never hard delete, archive after 3 years'),
        ('MedicalRecords',      6, 'HIPAA_PHI',      3, NULL, 'PHI — most sensitive clinical data'),
        ('Prescriptions',       6, 'HIPAA_PHI',      3, NULL, 'PHI — medication history'),
        ('PrescriptionDetails', 6, 'HIPAA_PHI',      3, NULL, 'PHI — medication detail'),
        ('LabTests',            6, 'HIPAA_PHI',      3, NULL, 'PHI — diagnostic results'),
        ('Admissions',          6, 'CLINICAL',        3, NULL, 'Clinical — admission history'),
        ('Appointments',        3, 'CLINICAL',        2, NULL, 'Clinical — schedule data'),
        ('Billing',             7, 'ADMINISTRATIVE',  3, NULL, 'Financial — tax/legal retention'),
        ('BillingDetails',      7, 'ADMINISTRATIVE',  3, NULL, 'Financial — line items'),
        ('Payments',            7, 'ADMINISTRATIVE',  3, NULL, 'Financial — payment records'),
        ('AuditLog',            6, 'AUDIT',           3, NULL, 'HIPAA audit — immutable'),
        ('SecurityAuditEvents', 6, 'AUDIT',           3, NULL, 'Security events — immutable'),
        ('SecurityEvents',      6, 'AUDIT',           3, NULL, 'Login/access events'),
        ('BackupHistory',       3, 'SYSTEM',          2,    3, 'Operational — backup tracking'),
        ('SystemConfiguration', 0, 'SYSTEM',       NULL, NULL, 'Config — no retention limit');

    PRINT '  ✓ DataRetentionPolicy created with 15 policies';
END
ELSE
    PRINT '  (DataRetentionPolicy already exists — skipping)';
GO

-- ============================================
-- Summary
-- ============================================
PRINT '';
PRINT '✓ Enterprise enhancements applied:';
PRINT '  - FHIR resource columns (6 tables)';
PRINT '  - Soft delete: IsDeleted, DeletedAt, DeletedBy (7 tables)';
PRINT '  - Concurrency: RowVersion (7 tables)';
PRINT '  - Data retention policy (15 table policies)';
GO
