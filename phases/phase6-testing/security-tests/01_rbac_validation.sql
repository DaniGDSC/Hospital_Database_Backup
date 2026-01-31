-- Security test: role-based access expectations
USE HospitalBackupDemo;
GO

SET NOCOUNT ON;

PRINT '=== RBAC validation ===';

-- Expect app_readonly cannot insert into Patients
BEGIN TRY
    EXECUTE AS USER = 'app_ro_user';
    INSERT INTO dbo.Patients (PatientCode, FirstName, LastName, DateOfBirth, Gender, Phone)
    VALUES ('TEST-RO', 'Test', 'RO', '2000-01-01', 'M', '0999999999');
    PRINT 'Unexpected: insert succeeded for app_ro_user';
    REVERT;
    RAISERROR('RBAC validation failed: readonly user can insert.', 16, 1);
END TRY
BEGIN CATCH
    REVERT;
    PRINT 'Insert blocked as expected for app_ro_user.';
END CATCH;
GO
