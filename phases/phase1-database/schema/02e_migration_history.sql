-- Schema migration tracking table
-- Records every schema change applied to the database
-- HIPAA 164.308(a)(1): Track all system changes for audit
USE HospitalBackupDemo;
GO

SET NOCOUNT ON;

PRINT '=== Creating SchemaVersionHistory table ===';

IF OBJECT_ID('dbo.SchemaVersionHistory', 'U') IS NULL
BEGIN
    CREATE TABLE dbo.SchemaVersionHistory (
        VersionID INT IDENTITY(1,1) NOT NULL,
        Version VARCHAR(20) NOT NULL,
        Description NVARCHAR(500) NOT NULL,
        AppliedAt DATETIME NOT NULL DEFAULT GETUTCDATE(),
        AppliedBy NVARCHAR(128) NOT NULL DEFAULT SUSER_SNAME(),
        ExecutionMs INT NULL,
        Checksum VARCHAR(64) NOT NULL,
        Status VARCHAR(10) NOT NULL CHECK (Status IN ('SUCCESS', 'FAILED')),
        RollbackScript NVARCHAR(500) NULL,
        ErrorMessage NVARCHAR(MAX) NULL,

        CONSTRAINT PK_SchemaVersionHistory PRIMARY KEY CLUSTERED (VersionID),
        CONSTRAINT UK_SchemaVersionHistory_Version UNIQUE (Version)
    );

    CREATE NONCLUSTERED INDEX IX_SchemaVersionHistory_Applied
        ON dbo.SchemaVersionHistory (AppliedAt DESC);

    PRINT '✓ SchemaVersionHistory table created';
END
ELSE
    PRINT 'SchemaVersionHistory table already exists';
GO

-- Protect from modification (same as audit tables)
DENY DELETE, UPDATE ON dbo.SchemaVersionHistory TO public;
PRINT '✓ DENY DELETE/UPDATE applied to SchemaVersionHistory';
GO

-- Seed with initial schema version
IF NOT EXISTS (SELECT 1 FROM dbo.SchemaVersionHistory WHERE Version = 'V001')
BEGIN
    INSERT INTO dbo.SchemaVersionHistory
        (Version, Description, Checksum, Status, RollbackScript)
    VALUES
        ('V001', 'Initial schema: 18 tables, indexes, procedures, functions, views, triggers',
         'initial', 'SUCCESS', 'phases/phase1-database/schema/rollback/');
    PRINT '✓ Initial migration V001 recorded';
END
GO

-- View current schema version
SELECT TOP 5 Version, Description, AppliedAt, AppliedBy, Status
FROM dbo.SchemaVersionHistory
ORDER BY AppliedAt DESC;
GO
