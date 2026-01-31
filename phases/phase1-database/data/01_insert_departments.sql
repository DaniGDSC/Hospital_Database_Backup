-- Insert sample departments for HospitalBackupDemo
USE HospitalBackupDemo;
GO

SET NOCOUNT ON;

PRINT '=== Inserting Departments ===';

INSERT INTO dbo.Departments
    (DepartmentCode, DepartmentName, DepartmentType, Location, Building, FloorNumber, PhoneExtension, Email, Budget, NumberOfBeds, IsActive)
VALUES
    ('CARD', 'Cardiology', 'Medical', 'Building A', 'A', 2, '2001', 'cardiology@hospital.test', 200000000, 40, 1),
    ('ER',   'Emergency',  'Medical', 'Building A', 'A', 1, '1001', 'er@hospital.test',         150000000, 25, 1),
    ('RAD',  'Radiology',  'Diagnostic', 'Building B', 'B', 1, '3001', 'radiology@hospital.test', 120000000, 15, 1),
    ('PHAR', 'Pharmacy',   'Support', 'Building C', 'C', 1, '4001', 'pharmacy@hospital.test',   80000000,  10, 1),
    ('ADMIN','Administration', 'Administrative', 'Building D', 'D', 3, '5001', 'admin@hospital.test', 50000000, 0, 1);

PRINT '✓ Departments inserted.';
GO
