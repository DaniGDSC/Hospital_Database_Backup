-- Insert sample doctors, nurses, and rooms
USE HospitalBackupDemo;
GO

SET QUOTED_IDENTIFIER ON;
GO

SET NOCOUNT ON;

PRINT '=== Inserting Doctors, Nurses, and Rooms ===';

DECLARE @DeptCardiology INT = (SELECT DepartmentID FROM dbo.Departments WHERE DepartmentCode = 'CARD');
DECLARE @DeptER INT = (SELECT DepartmentID FROM dbo.Departments WHERE DepartmentCode = 'ER');
DECLARE @DeptRadiology INT = (SELECT DepartmentID FROM dbo.Departments WHERE DepartmentCode = 'RAD');
DECLARE @DeptPharmacy INT = (SELECT DepartmentID FROM dbo.Departments WHERE DepartmentCode = 'PHAR');

IF @DeptCardiology IS NULL OR @DeptER IS NULL OR @DeptRadiology IS NULL OR @DeptPharmacy IS NULL
BEGIN
    RAISERROR('Required departments are missing. Run 01_insert_departments.sql first.', 16, 1);
    RETURN;
END

-- Doctors
INSERT INTO dbo.Doctors
    (EmployeeCode, FirstName, LastName, DateOfBirth, Gender, NationalID, DepartmentID, Specialty, SubSpecialty, MedicalDegree, LicenseNumber, LicenseExpiryDate, Email, PersonalEmail, Phone, MobilePhone, Address, City, Country, PostalCode, HireDate, EmploymentStatus, BaseSalary, ConsultationFee, IsActive)
VALUES
    ('DOC1001', 'John',  'Smith',  '1980-02-15', 'M', 'ID123456789', @DeptCardiology, 'Cardiology', 'Interventional', 'MD', 'LIC-1001', '2030-12-31', 'john.smith@hospital.test', NULL, '0901234001', '0901234001', '12 Heart St', 'Hanoi', 'Vietnam', '100000', '2010-06-01', 'Full-Time', 60000000, 800000, 1),
    ('DOC1002', 'Emily', 'Tran',   '1985-07-10', 'F', 'ID223456789', @DeptER,         'Emergency Medicine', NULL, 'MD', 'LIC-1002', '2031-05-31', 'emily.tran@hospital.test',  NULL, '0901234002', '0901234002', '34 Relief Ave', 'Hanoi', 'Vietnam', '100001', '2012-08-15', 'Full-Time', 55000000, 600000, 1),
    ('DOC1003', 'Liam',  'Nguyen', '1978-11-20', 'M', 'ID323456789', @DeptRadiology,  'Radiology', 'Imaging', 'MD', 'LIC-1003', '2032-03-15', 'liam.nguyen@hospital.test',   NULL, '0901234003', '0901234003', '56 Scan Rd', 'Hanoi', 'Vietnam', '100002', '2008-04-20', 'Full-Time', 58000000, 700000, 1);

-- Nurses
INSERT INTO dbo.Nurses
    (EmployeeCode, FirstName, LastName, DateOfBirth, Gender, NationalID, DepartmentID, NursingDegree, LicenseNumber, LicenseExpiryDate, Email, Phone, ShiftType, HireDate, BaseSalary, IsActive)
VALUES
    ('NUR2001', 'Anna', 'Pham',  '1990-01-05', 'F', 'NID123456', @DeptER,  'BSN', 'NLIC-2001', '2029-12-31', 'anna.pham@hospital.test',  '0902234001', 'Rotating', '2015-01-10', 22000000, 1),
    ('NUR2002', 'David','Le',    '1988-09-18', 'M', 'NID223456', @DeptCardiology, 'BSN', 'NLIC-2002', '2030-06-30', 'david.le@hospital.test', '0902234002', 'Day', '2014-03-15', 23000000, 1);

-- Rooms
INSERT INTO dbo.Rooms
    (RoomNumber, DepartmentID, RoomType, BedCapacity, CurrentOccupancy, Building, FloorNumber, WingSection, DailyRate, HasOxygen, HasVentilator, HasMonitoring, Status, LastCleaningDate, IsActive)
VALUES
    ('ER-101', @DeptER, 'Emergency', 4, 0, 'A', 1, 'North', 1500000, 1, 1, 1, 'Available', SYSDATETIME(), 1),
    ('CARD-201', @DeptCardiology, 'ICU', 2, 0, 'A', 2, 'East', 2500000, 1, 1, 1, 'Available', SYSDATETIME(), 1),
    ('RAD-301', @DeptRadiology, 'General Ward', 1, 0, 'B', 1, 'Central', 1800000, 0, 0, 1, 'Available', SYSDATETIME(), 1),
    ('PHAR-10', @DeptPharmacy, 'Recovery', 1, 0, 'C', 1, 'West', 900000, 0, 0, 0, 'Available', SYSDATETIME(), 1);

PRINT '✓ Doctors, nurses, and rooms inserted.';
GO
