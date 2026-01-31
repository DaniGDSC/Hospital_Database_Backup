-- Unit test: schema integrity
USE HospitalBackupDemo;
GO

SET NOCOUNT ON;

PRINT '=== Schema integrity checks ===';

-- Check all expected tables exist
DECLARE @missing TABLE(TableName SYSNAME);
INSERT INTO @missing(TableName)
SELECT t.Expected
FROM (VALUES
    ('Departments'),('Doctors'),('Nurses'),('Patients'),('Rooms'),('Appointments'),
    ('MedicalRecords'),('Prescriptions'),('PrescriptionDetails'),('LabTests'),('Admissions'),
    ('Billing'),('BillingDetails'),('Payments'),('AuditLog'),('BackupHistory'),('SecurityEvents'),('SystemConfiguration')
) AS t(Expected)
LEFT JOIN sys.tables st ON st.name = t.Expected AND SCHEMA_NAME(st.schema_id) = 'dbo'
WHERE st.name IS NULL;

IF EXISTS (SELECT 1 FROM @missing)
BEGIN
    PRINT 'Missing tables:';
    SELECT * FROM @missing;
    RAISERROR('Schema integrity failed: missing tables.', 16, 1);
END
ELSE
    PRINT 'All expected tables exist.';
GO
