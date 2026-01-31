-- Insert sample patients and transactional data
USE HospitalBackupDemo;
GO

SET QUOTED_IDENTIFIER ON;
GO

SET NOCOUNT ON;

PRINT '=== Inserting Patients and Core Transactions ===';

DECLARE @DeptCardiology INT = (SELECT DepartmentID FROM dbo.Departments WHERE DepartmentCode = 'CARD');
DECLARE @DeptER INT = (SELECT DepartmentID FROM dbo.Departments WHERE DepartmentCode = 'ER');
DECLARE @DeptRadiology INT = (SELECT DepartmentID FROM dbo.Departments WHERE DepartmentCode = 'RAD');
DECLARE @DocSmith INT = (SELECT DoctorID FROM dbo.Doctors WHERE EmployeeCode = 'DOC1001');
DECLARE @DocTran INT = (SELECT DoctorID FROM dbo.Doctors WHERE EmployeeCode = 'DOC1002');
DECLARE @DocNguyen INT = (SELECT DoctorID FROM dbo.Doctors WHERE EmployeeCode = 'DOC1003');
DECLARE @NurseAnna INT = (SELECT NurseID FROM dbo.Nurses WHERE EmployeeCode = 'NUR2001');
DECLARE @NurseDavid INT = (SELECT NurseID FROM dbo.Nurses WHERE EmployeeCode = 'NUR2002');
DECLARE @RoomER INT = (SELECT RoomID FROM dbo.Rooms WHERE RoomNumber = 'ER-101');
DECLARE @RoomCard INT = COALESCE(
    (SELECT RoomID FROM dbo.Rooms WHERE RoomNumber = 'CARD-201'),
    (SELECT TOP 1 RoomID FROM dbo.Rooms WHERE Status = 'Available' ORDER BY NEWID()),
    (SELECT TOP 1 RoomID FROM dbo.Rooms ORDER BY NEWID())
);

IF @DeptCardiology IS NULL OR @DeptER IS NULL OR @DeptRadiology IS NULL OR @DocSmith IS NULL OR @DocTran IS NULL OR @DocNguyen IS NULL
BEGIN
    RAISERROR('Staff or department prerequisites missing. Run previous data scripts.', 16, 1);
    RETURN;
END

-- Patients
INSERT INTO dbo.Patients
    (PatientCode, FirstName, LastName, DateOfBirth, Gender, NationalID, BloodType, Email, Phone, AlternatePhone, EmergencyContactName, EmergencyContactPhone, EmergencyContactRelation, Address, City, Country, PostalCode, MaritalStatus, InsuranceNumber, InsuranceProvider, InsuranceExpiryDate, RegistrationDate, IsVIP, IsActive)
VALUES
    ('PAT3001', 'Mai',  'Nguyen', '1992-03-12', 'F', 'PID123456', 'A+', 'mai.nguyen@patient.test', '0911234001', NULL, 'Hoa Nguyen', '0912234001', 'Sister', '12 Green St', 'Hanoi', 'Vietnam', '100010', 'Single', 'INS-3001', 'VietLife', '2027-12-31', CAST(GETDATE() AS DATE), 0, 1),
    ('PAT3002', 'Khanh','Tran',   '1985-09-05', 'M', 'PID223456', 'B+', 'khanh.tran@patient.test', '0911234002', '0933234002', 'Linh Tran', '0933234002', 'Wife', '34 Lake Rd', 'Hanoi', 'Vietnam', '100011', 'Married', 'INS-3002', 'BaoViet', '2026-10-31', CAST(GETDATE() AS DATE), 0, 1),
    ('PAT3003', 'An',   'Le',     '1975-12-22', 'M', 'PID323456', 'O+', 'an.le@patient.test', '0911234003', NULL, 'Tu Le', '0912234003', 'Brother', '56 River Ave', 'Hanoi', 'Vietnam', '100012', 'Married', 'INS-3003', 'Prudential', '2027-05-31', CAST(GETDATE() AS DATE), 1, 1);

DECLARE @Pat1 INT = (SELECT PatientID FROM dbo.Patients WHERE PatientCode = 'PAT3001');
DECLARE @Pat2 INT = (SELECT PatientID FROM dbo.Patients WHERE PatientCode = 'PAT3002');
DECLARE @Pat3 INT = (SELECT PatientID FROM dbo.Patients WHERE PatientCode = 'PAT3003');

-- Appointments
DECLARE @Appt1 INT;
DECLARE @Appt2 INT;
DECLARE @Appt3 INT;

INSERT INTO dbo.Appointments
    (AppointmentNumber, PatientID, DoctorID, DepartmentID, AppointmentDate, AppointmentEndTime, AppointmentType, Priority, Status, ReasonForVisit, EstimatedDuration, RoomID, ConsultationFee, IsPaid)
VALUES
    ('APT-5001', @Pat1, @DocSmith, @DeptCardiology, DATEADD(DAY, 1, GETDATE()), DATEADD(MINUTE, 30, DATEADD(DAY, 1, GETDATE())), 'New Consultation', 'Normal', 'Scheduled', 'Chest discomfort', 30, @RoomCard, 800000, 0);
SET @Appt1 = SCOPE_IDENTITY();

INSERT INTO dbo.Appointments
    (AppointmentNumber, PatientID, DoctorID, DepartmentID, AppointmentDate, AppointmentEndTime, AppointmentType, Priority, Status, ReasonForVisit, EstimatedDuration, RoomID, ConsultationFee, IsPaid)
VALUES
    ('APT-5002', @Pat2, @DocTran, @DeptER, DATEADD(HOUR, -2, GETDATE()), DATEADD(MINUTE, 20, DATEADD(HOUR, -2, GETDATE())), 'Emergency', 'Emergency', 'Completed', 'Severe headache', 20, @RoomER, 600000, 1);
SET @Appt2 = SCOPE_IDENTITY();

INSERT INTO dbo.Appointments
    (AppointmentNumber, PatientID, DoctorID, DepartmentID, AppointmentDate, AppointmentEndTime, AppointmentType, Priority, Status, ReasonForVisit, EstimatedDuration, RoomID, ConsultationFee, IsPaid)
VALUES
    ('APT-5003', @Pat3, @DocNguyen, @DeptRadiology, DATEADD(DAY, -1, GETDATE()), DATEADD(MINUTE, 45, DATEADD(DAY, -1, GETDATE())), 'Lab Test', 'Urgent', 'Completed', 'MRI follow-up', 45, NULL, 700000, 1);
SET @Appt3 = SCOPE_IDENTITY();

-- Medical Records
DECLARE @Rec1 INT;
DECLARE @Rec2 INT;
DECLARE @Rec3 INT;

INSERT INTO dbo.MedicalRecords
    (RecordNumber, PatientID, DoctorID, AppointmentID, VisitDate, VisitType, ChiefComplaint, PresentIllness, Symptoms, PhysicalExamination, VitalSigns, Diagnosis, DiagnosisCode, TreatmentPlan, Medications, Allergies, FollowUpInstructions, FollowUpDate, IsConfidential, IsEmergency, AdmissionRequired, Notes)
VALUES
    ('MR-7001', @Pat1, @DocSmith, @Appt1, SYSDATETIME(), 'Outpatient', 'Chest pain on exertion', 'Pain for 1 week', 'Chest tightness', 'Normal', 'BP:120/80;HR:72;Temp:37', 'Stable angina', 'I20.9', 'Start beta-blocker, schedule stress test', 'Metoprolol 25mg daily', 'No known allergies', 'Return if pain worsens', DATEADD(DAY, 14, GETDATE()), 1, 0, 0, 'Initial visit');
SET @Rec1 = SCOPE_IDENTITY();

INSERT INTO dbo.MedicalRecords
    (RecordNumber, PatientID, DoctorID, AppointmentID, VisitDate, VisitType, ChiefComplaint, PresentIllness, Symptoms, PhysicalExamination, VitalSigns, Diagnosis, DiagnosisCode, TreatmentPlan, Medications, Allergies, FollowUpInstructions, FollowUpDate, IsConfidential, IsEmergency, AdmissionRequired, Notes)
VALUES
    ('MR-7002', @Pat2, @DocTran, @Appt2, DATEADD(HOUR, -2, SYSDATETIME()), 'Emergency', 'Sudden severe headache', 'Acute onset 1 hour prior', 'Headache, nausea', 'Alert, photophobia', 'BP:140/90;HR:88;Temp:37.2', 'Migraine, rule out SAH', 'G43.9', 'CT scan, analgesia, monitor', 'Triptan as needed', 'No known allergies', 'Follow up with neurology', DATEADD(DAY, 7, GETDATE()), 1, 1, 0, 'Emergency visit completed');
SET @Rec2 = SCOPE_IDENTITY();

INSERT INTO dbo.MedicalRecords
    (RecordNumber, PatientID, DoctorID, AppointmentID, VisitDate, VisitType, ChiefComplaint, PresentIllness, Symptoms, PhysicalExamination, VitalSigns, Diagnosis, DiagnosisCode, TreatmentPlan, Medications, Allergies, FollowUpInstructions, FollowUpDate, IsConfidential, IsEmergency, AdmissionRequired, Notes)
VALUES
    ('MR-7003', @Pat3, @DocNguyen, @Appt3, DATEADD(DAY, -1, SYSDATETIME()), 'Outpatient', 'MRI follow-up', 'Post MRI review', 'None', 'Normal', 'BP:118/78;HR:70;Temp:36.8', 'No acute findings', 'Z00.0', 'Routine follow-up', 'None', 'Penicillin', 'Return in 6 months', DATEADD(MONTH, 6, GETDATE()), 0, 0, 0, 'Review visit');
SET @Rec3 = SCOPE_IDENTITY();

-- Prescriptions
DECLARE @Rx1 INT;
DECLARE @Rx2 INT;

INSERT INTO dbo.Prescriptions
    (PrescriptionNumber, RecordID, PatientID, DoctorID, PrescriptionDate, Instructions, StartDate, EndDate, RefillsAllowed, RefillsRemaining, Status, PharmacyName, TotalCost, IsPaid)
VALUES
    ('RX-9001', @Rec1, @Pat1, @DocSmith, SYSDATETIME(), 'Take with food', CAST(GETDATE() AS DATE), DATEADD(DAY, 30, CAST(GETDATE() AS DATE)), 2, 2, 'Active', 'Main Pharmacy', 500000, 0);
SET @Rx1 = SCOPE_IDENTITY();

INSERT INTO dbo.Prescriptions
    (PrescriptionNumber, RecordID, PatientID, DoctorID, PrescriptionDate, Instructions, StartDate, EndDate, RefillsAllowed, RefillsRemaining, Status, PharmacyName, TotalCost, IsPaid)
VALUES
    ('RX-9002', @Rec2, @Pat2, @DocTran, SYSDATETIME(), 'Use as needed', CAST(GETDATE() AS DATE), DATEADD(DAY, 14, CAST(GETDATE() AS DATE)), 1, 1, 'Active', 'Main Pharmacy', 300000, 1);
SET @Rx2 = SCOPE_IDENTITY();

-- Prescription Details
INSERT INTO dbo.PrescriptionDetails
    (PrescriptionID, MedicationID, MedicationName, GenericName, MedicationType, Strength, Dosage, Route, Frequency, FrequencyCode, Duration, Quantity, UnitOfMeasure, UnitPrice, Instructions, Warnings, SideEffects, StartDate, EndDate, IsDispensed, DispensedQuantity, DispensedDate, Notes)
VALUES
    (@Rx1, 'MED-01', 'Metoprolol', 'Metoprolol', 'Tablet', '25mg', '1 tablet', 'Oral', 'Once daily', 'QD', '30 days', 30, 'Tablet', 15000, 'Take in morning', 'Check pulse', 'Bradycardia, fatigue', CAST(GETDATE() AS DATE), DATEADD(DAY, 30, CAST(GETDATE() AS DATE)), 0, 0, NULL, 'Initial prescription'),
    (@Rx2, 'MED-02', 'Sumatriptan', 'Sumatriptan', 'Tablet', '50mg', '1 tablet', 'Oral', 'At onset, may repeat after 2 hours', 'PRN', '7 days', 6, 'Tablet', 40000, 'Do not exceed 200mg/day', 'Avoid with MAOIs', 'Dizziness, tingling', CAST(GETDATE() AS DATE), DATEADD(DAY, 7, CAST(GETDATE() AS DATE)), 1, 2, SYSDATETIME(), 'Dispensed at visit');

-- Lab Tests
INSERT INTO dbo.LabTests
    (TestNumber, PatientID, DoctorID, RecordID, TestName, TestCategory, TestType, DepartmentID, OrderDate, SampleCollectionDate, SampleType, SampleID, CollectedBy, ResultDate, ReportDate, Results, ResultValue, ResultUnit, NormalRange, IsAbnormal, AbnormalityFlag, Interpretation, Status, Priority, PerformedBy, VerifiedBy, VerifiedDate, Cost, IsPaid, Notes)
VALUES
    ('LAB-8001', @Pat1, @DocSmith, @Rec1, 'Lipid Panel', 'Blood', 'Panel', @DeptCardiology, SYSDATETIME(), SYSDATETIME(), 'Blood', 'SMP-8001', 'Anna Pham', NULL, NULL, NULL, NULL, NULL, 'Normal', 0, 'N', 'Pending analysis', 'Ordered', 'Routine', 'Lab Team', NULL, NULL, 200000, 0, 'Baseline labs'),
    ('LAB-8002', @Pat2, @DocTran, @Rec2, 'Head CT', 'Imaging', 'CT', @DeptRadiology, DATEADD(HOUR, -1, SYSDATETIME()), DATEADD(HOUR, -1, SYSDATETIME()), 'Imaging', 'SMP-8002', 'David Le', SYSDATETIME(), SYSDATETIME(), 'No bleed detected', NULL, NULL, 'Normal', 0, 'N', 'No acute findings', 'Completed', 'STAT', 'Radiology', 'Liam Nguyen', SYSDATETIME(), 1500000, 1, 'Emergency CT');

-- Admissions
DECLARE @Admission1 INT;
INSERT INTO dbo.Admissions
    (AdmissionNumber, PatientID, DoctorID, DepartmentID, RoomID, AdmissionDate, AdmissionType, AdmissionSource, AdmissionReason, InitialDiagnosis, Status, BedNumber, AttendingNurseID, IsolationRequired, RoomDailyCost, TreatmentCost, MedicationCost, LabTestCost, InsuranceCovered, DischargedBy)
VALUES
    ('ADM-6001', @Pat3, @DocNguyen, @DeptRadiology, @RoomCard, DATEADD(DAY, -1, SYSDATETIME()), 'Observation', 'Outpatient', 'Post-MRI observation', 'Observation only', 'Active', 'B1', @NurseDavid, 0, 2500000, 500000, 300000, 1500000, 1000000, @DocNguyen);
SET @Admission1 = SCOPE_IDENTITY();

-- Billing
DECLARE @Bill1 INT;
INSERT INTO dbo.Billing
    (InvoiceNumber, PatientID, AppointmentID, AdmissionID, BillingType, InvoiceDate, DueDate, ServiceDate, SubTotal, TaxRate, Discount, DiscountReason, AdjustmentAmount, AdjustmentReason, AmountPaid, PaymentStatus, PaymentDueDate, InsuranceClaimNumber, InsuranceClaim, InsuranceApproved, Currency, BilledBy, Notes)
VALUES
    ('INV-4001', @Pat1, @Appt1, NULL, 'Consultation', CAST(GETDATE() AS DATETIME2), DATEADD(DAY, 15, CAST(GETDATE() AS DATETIME2)), CAST(GETDATE() AS DATE), 800000, 10.00, 0, NULL, 0, NULL, 0, 'Pending', DATEADD(DAY, 15, CAST(GETDATE() AS DATE)), 'CLM-4001', 500000, 400000, 'VND', 'Billing Bot', 'Consultation billing');
SET @Bill1 = SCOPE_IDENTITY();

DECLARE @Bill2 INT;
INSERT INTO dbo.Billing
    (InvoiceNumber, PatientID, AppointmentID, AdmissionID, BillingType, InvoiceDate, DueDate, ServiceDate, SubTotal, TaxRate, Discount, DiscountReason, AdjustmentAmount, AdjustmentReason, AmountPaid, PaymentStatus, PaymentDueDate, InsuranceClaimNumber, InsuranceClaim, InsuranceApproved, Currency, BilledBy, Notes)
VALUES
    ('INV-4002', @Pat2, @Appt2, NULL, 'Lab Test', DATEADD(HOUR, -1, SYSDATETIME()), DATEADD(DAY, 7, CAST(GETDATE() AS DATETIME2)), CAST(GETDATE() AS DATE), 1500000, 10.00, 0, NULL, 0, NULL, 1500000, 'Paid', DATEADD(DAY, 7, CAST(GETDATE() AS DATE)), 'CLM-4002', 1000000, 1000000, 'VND', 'Billing Bot', 'CT scan billing');
SET @Bill2 = SCOPE_IDENTITY();

DECLARE @Bill3 INT;
IF @Admission1 IS NOT NULL
BEGIN
    INSERT INTO dbo.Billing
        (InvoiceNumber, PatientID, AppointmentID, AdmissionID, BillingType, InvoiceDate, DueDate, ServiceDate, SubTotal, TaxRate, Discount, DiscountReason, AdjustmentAmount, AdjustmentReason, AmountPaid, PaymentStatus, PaymentDueDate, InsuranceClaimNumber, InsuranceClaim, InsuranceApproved, Currency, BilledBy, Notes)
    VALUES
        ('INV-4003', @Pat3, NULL, @Admission1, 'Admission', DATEADD(DAY, -1, SYSDATETIME()), DATEADD(DAY, 10, CAST(GETDATE() AS DATETIME2)), CAST(GETDATE() AS DATE), 4800000, 10.00, 0, NULL, 0, NULL, 0, 'Pending', DATEADD(DAY, 10, CAST(GETDATE() AS DATE)), 'CLM-4003', 2000000, 1500000, 'VND', 'Billing Bot', 'Admission charges');
    SET @Bill3 = SCOPE_IDENTITY();
END

-- Billing Details
INSERT INTO dbo.BillingDetails
    (BillingID, LineNumber, ServiceType, ServiceCode, Description, ServiceDate, ServiceProviderID, ServiceProviderType, Quantity, UnitOfMeasure, UnitPrice, DiscountPercent, IsCovered, Notes)
VALUES
    (@Bill1, 1, 'Consultation', 'CONS', 'Cardiology consultation', CAST(GETDATE() AS DATE), @DocSmith, 'Doctor', 1, 'Visit', 800000, 0, 1, 'Initial consult'),
    (@Bill2, 1, 'Imaging', 'CT', 'Head CT', CAST(GETDATE() AS DATE), @DocNguyen, 'Doctor', 1, 'Scan', 1500000, 0, 1, 'Emergency CT'),
    (@Bill3, 1, 'Room Charge', 'ROOM', 'ICU bed', CAST(GETDATE() AS DATE), NULL, NULL, 1, 'Day', 2500000, 0, 1, 'Observation'),
    (@Bill3, 2, 'Treatment', 'TREAT', 'Observation care', CAST(GETDATE() AS DATE), @DocNguyen, 'Doctor', 1, 'Day', 500000, 0, 1, 'Treatment fee');

-- Payments
INSERT INTO dbo.Payments
    (PaymentNumber, BillingID, PatientID, PaymentDate, Amount, Currency, PaymentMethod, PaymentType, TransactionID, ReferenceNumber, ProcessedBy, ReceivedBy, ApprovedBy, ApprovedDate, Status, Notes, RefundAmount)
VALUES
    ('PAY-5001', @Bill2, @Pat2, SYSDATETIME(), 1500000, 'VND', 'Cash', 'Full', 'TX-5001', 'REF-5001', 'Cashier', 'Cashier', 'Supervisor', SYSDATETIME(), 'Completed', 'Payment for CT scan', 0),
    ('PAY-5002', @Bill1, @Pat1, SYSDATETIME(), 400000, 'VND', 'Mobile Payment', 'Partial', 'TX-5002', 'REF-5002', 'Cashier', 'Cashier', 'Supervisor', SYSDATETIME(), 'Completed', 'Partial payment for consult', 0);

PRINT '✓ Patients, appointments, records, prescriptions, labs, admissions, billing, and payments inserted.';
GO
