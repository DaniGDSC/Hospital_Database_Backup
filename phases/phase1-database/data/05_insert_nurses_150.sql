-- Bulk insert 150 sample Nurses records
USE HospitalBackupDemo;
GO

SET QUOTED_IDENTIFIER ON;
GO

SET NOCOUNT ON;

PRINT '=== Inserting 150 Sample Nurses ===';

DECLARE @Counter INT = 1;
DECLARE @DeptID INT;

WHILE @Counter <= 150
BEGIN
    SET @DeptID = (SELECT TOP 1 DepartmentID FROM Departments ORDER BY NEWID());
    
    INSERT INTO dbo.Nurses 
    (EmployeeCode, FirstName, LastName, DateOfBirth, Gender, NationalID, DepartmentID, 
     NursingDegree, LicenseNumber, Email, Phone, ShiftType, HireDate, BaseSalary, IsActive)
    VALUES
    ('NUR' + RIGHT('00000' + CAST(@Counter AS VARCHAR), 5),
     'Nurse' + CAST(@Counter AS VARCHAR),
     'Last' + CAST(@Counter AS VARCHAR),
     DATEADD(YEAR, -CAST(RAND()*25+20 AS INT), GETDATE()),
     CASE WHEN RAND() > 0.5 THEN 'M' ELSE 'F' END,
     '1' + CAST(1000000000 + @Counter AS VARCHAR),
     @DeptID,
     'BSN',
     'NLIC' + CAST(10000 + @Counter AS VARCHAR),
     'nurse' + CAST(@Counter AS VARCHAR) + '@hospital.test',
     '091234' + RIGHT('0000' + CAST(@Counter AS VARCHAR), 4),
     CASE WHEN @Counter % 4 = 1 THEN 'Day' WHEN @Counter % 4 = 2 THEN 'Night' WHEN @Counter % 4 = 3 THEN 'Rotating' ELSE 'On-Call' END,
     DATEADD(YEAR, -CAST(RAND()*12 AS INT), GETDATE()),
     25000000 + (@Counter * 50000),
     1);
     
    SET @Counter = @Counter + 1;
END

PRINT '✓ 150 Nurses inserted';
GO
