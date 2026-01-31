-- User-defined functions for HospitalBackupDemo
USE HospitalBackupDemo;
GO

SET NOCOUNT ON;

PRINT '=== Creating user-defined functions ===';

-- Calculate age from a date of birth
IF OBJECT_ID('dbo.ufn_GetAgeFromDob', 'FN') IS NOT NULL
    DROP FUNCTION dbo.ufn_GetAgeFromDob;
GO
CREATE FUNCTION dbo.ufn_GetAgeFromDob(@DateOfBirth DATE)
RETURNS INT
AS
BEGIN
    RETURN DATEDIFF(YEAR, @DateOfBirth, CAST(GETDATE() AS DATE)) -
           CASE WHEN DATEADD(YEAR, DATEDIFF(YEAR, @DateOfBirth, CAST(GETDATE() AS DATE)), @DateOfBirth) > CAST(GETDATE() AS DATE) THEN 1 ELSE 0 END;
END
GO

-- Calculate outstanding balance for a patient
IF OBJECT_ID('dbo.ufn_GetPatientOutstanding', 'FN') IS NOT NULL
    DROP FUNCTION dbo.ufn_GetPatientOutstanding;
GO
CREATE FUNCTION dbo.ufn_GetPatientOutstanding(@PatientID INT)
RETURNS DECIMAL(18,2)
AS
BEGIN
    DECLARE @Balance DECIMAL(18,2);
    SELECT @Balance = COALESCE(SUM(Balance), 0)
    FROM dbo.Billing
    WHERE PatientID = @PatientID;
    RETURN @Balance;
END
GO

PRINT '✓ Functions created.';
GO
