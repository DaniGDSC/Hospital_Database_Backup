-- File: phase1-database/schema/02_create_tables.sql
-- Purpose: Create all tables for Hospital Management System
-- Dependencies: 01_create_database.sql must be run first
-- Author: [Your Name]
-- Date: 2025-01-09

SET QUOTED_IDENTIFIER ON;
GO

USE HospitalBackupDemo;
GO

PRINT '╔════════════════════════════════════════════════════════════════╗';
PRINT '║   Phase 1.2: Table Creation                                    ║';
PRINT '║   Hospital Management System Schema                            ║';
PRINT '╚════════════════════════════════════════════════════════════════╝';
PRINT '';

-- ============================================
-- TABLE 1: Departments (Khoa)
-- ============================================

PRINT 'Creating table: Departments...';

CREATE TABLE dbo.Departments (
    DepartmentID INT IDENTITY(1,1) NOT NULL,
    DepartmentCode NVARCHAR(10) NOT NULL,
    DepartmentName NVARCHAR(100) NOT NULL,
    DepartmentType NVARCHAR(30) CHECK (DepartmentType IN ('Medical', 'Surgical', 'Diagnostic', 'Administrative', 'Support')),
    Location NVARCHAR(100),
    Building NVARCHAR(50),
    FloorNumber INT,
    PhoneExtension NVARCHAR(20),
    Email NVARCHAR(100),
    Budget DECIMAL(15,2) DEFAULT 0,
    HeadDoctorID INT NULL,
    NumberOfBeds INT DEFAULT 0,
    IsActive BIT DEFAULT 1,
    CreatedDate DATETIME2 DEFAULT SYSDATETIME(),
    CreatedBy NVARCHAR(100) DEFAULT SUSER_SNAME(),
    ModifiedDate DATETIME2 DEFAULT SYSDATETIME(),
    ModifiedBy NVARCHAR(100) DEFAULT SUSER_SNAME(),
    
    CONSTRAINT PK_Departments PRIMARY KEY CLUSTERED (DepartmentID),
    CONSTRAINT UK_Departments_Code UNIQUE (DepartmentCode),
    CONSTRAINT CHK_Departments_Budget CHECK (Budget >= 0),
    CONSTRAINT CHK_Departments_Beds CHECK (NumberOfBeds >= 0)
);
GO

PRINT '  ✓ Departments created';

-- ============================================
-- TABLE 2: Doctors (Bác sĩ)
-- ============================================

SET QUOTED_IDENTIFIER ON;
GO

PRINT 'Creating table: Doctors...';

CREATE TABLE dbo.Doctors (
    DoctorID INT IDENTITY(1,1) NOT NULL,
    EmployeeCode NVARCHAR(20) NOT NULL,
    FirstName NVARCHAR(50) NOT NULL,
    LastName NVARCHAR(50) NOT NULL,
    FullName AS (LastName + ' ' + FirstName) PERSISTED,
    DateOfBirth DATE NOT NULL,
    Age AS (DATEDIFF(YEAR, DateOfBirth, GETDATE())),
    Gender CHAR(1) CHECK (Gender IN ('M', 'F', 'O')) NOT NULL,
    NationalID NVARCHAR(20) NOT NULL,
    DepartmentID INT NOT NULL,
    Specialty NVARCHAR(100),
    SubSpecialty NVARCHAR(100),
    MedicalDegree NVARCHAR(50) CHECK (MedicalDegree IN ('MD', 'DO', 'MBBS', 'PhD', 'DM')),
    LicenseNumber NVARCHAR(50) NOT NULL,
    LicenseExpiryDate DATE,
    Email NVARCHAR(100) NOT NULL,
    PersonalEmail NVARCHAR(100),
    Phone NVARCHAR(20) NOT NULL,
    MobilePhone NVARCHAR(20),
    Address NVARCHAR(200),
    City NVARCHAR(50),
    Country NVARCHAR(50) DEFAULT 'Vietnam',
    PostalCode NVARCHAR(10),
    HireDate DATE NOT NULL,
    EmploymentStatus NVARCHAR(20) CHECK (EmploymentStatus IN ('Full-Time', 'Part-Time', 'Contract', 'On-Leave', 'Retired')) DEFAULT 'Full-Time',
    BaseSalary DECIMAL(12,2),
    YearsOfExperience AS (DATEDIFF(YEAR, HireDate, GETDATE())),
    ConsultationFee DECIMAL(10,2) DEFAULT 0,
    IsActive BIT DEFAULT 1,
    CreatedDate DATETIME2 DEFAULT SYSDATETIME(),
    CreatedBy NVARCHAR(100) DEFAULT SUSER_SNAME(),
    ModifiedDate DATETIME2 DEFAULT SYSDATETIME(),
    ModifiedBy NVARCHAR(100) DEFAULT SUSER_SNAME(),
    
    CONSTRAINT PK_Doctors PRIMARY KEY CLUSTERED (DoctorID),
    CONSTRAINT UK_Doctors_EmployeeCode UNIQUE (EmployeeCode),
    CONSTRAINT UK_Doctors_LicenseNumber UNIQUE (LicenseNumber),
    CONSTRAINT UK_Doctors_NationalID UNIQUE (NationalID),
    CONSTRAINT FK_Doctors_Departments FOREIGN KEY (DepartmentID) 
        REFERENCES dbo.Departments(DepartmentID),
    CONSTRAINT CHK_Doctors_Age CHECK (DATEDIFF(YEAR, DateOfBirth, GETDATE()) >= 25),
    CONSTRAINT CHK_Doctors_Salary CHECK (BaseSalary >= 0),
    CONSTRAINT CHK_Doctors_ConsultationFee CHECK (ConsultationFee >= 0)
);
GO

PRINT '  ✓ Doctors created';

-- Add FK for Department Head (circular reference)
ALTER TABLE dbo.Departments
ADD CONSTRAINT FK_Departments_HeadDoctor FOREIGN KEY (HeadDoctorID)
    REFERENCES dbo.Doctors(DoctorID);
GO

PRINT '  ✓ Department Head FK added';

-- ============================================
-- TABLE 3: Nurses (Y tá)
-- ============================================

SET QUOTED_IDENTIFIER ON;
GO

PRINT 'Creating table: Nurses...';

CREATE TABLE dbo.Nurses (
    NurseID INT IDENTITY(1,1) NOT NULL,
    EmployeeCode NVARCHAR(20) NOT NULL,
    FirstName NVARCHAR(50) NOT NULL,
    LastName NVARCHAR(50) NOT NULL,
    FullName AS (LastName + ' ' + FirstName) PERSISTED,
    DateOfBirth DATE NOT NULL,
    Age AS (DATEDIFF(YEAR, DateOfBirth, GETDATE())),
    Gender CHAR(1) CHECK (Gender IN ('M', 'F', 'O')) NOT NULL,
    NationalID NVARCHAR(20) NOT NULL,
    DepartmentID INT NOT NULL,
    NursingDegree NVARCHAR(50) CHECK (NursingDegree IN ('RN', 'LPN', 'BSN', 'MSN', 'DNP')),
    LicenseNumber NVARCHAR(50) NOT NULL,
    LicenseExpiryDate DATE,
    Email NVARCHAR(100),
    Phone NVARCHAR(20) NOT NULL,
    ShiftType NVARCHAR(20) CHECK (ShiftType IN ('Day', 'Night', 'Rotating', 'On-Call')),
    HireDate DATE NOT NULL,
    BaseSalary DECIMAL(12,2),
    IsActive BIT DEFAULT 1,
    CreatedDate DATETIME2 DEFAULT SYSDATETIME(),
    CreatedBy NVARCHAR(100) DEFAULT SUSER_SNAME(),
    ModifiedDate DATETIME2 DEFAULT SYSDATETIME(),
    ModifiedBy NVARCHAR(100) DEFAULT SUSER_SNAME(),
    
    CONSTRAINT PK_Nurses PRIMARY KEY CLUSTERED (NurseID),
    CONSTRAINT UK_Nurses_EmployeeCode UNIQUE (EmployeeCode),
    CONSTRAINT UK_Nurses_LicenseNumber UNIQUE (LicenseNumber),
    CONSTRAINT UK_Nurses_NationalID UNIQUE (NationalID),
    CONSTRAINT FK_Nurses_Departments FOREIGN KEY (DepartmentID)
        REFERENCES dbo.Departments(DepartmentID),
    CONSTRAINT CHK_Nurses_Age CHECK (DATEDIFF(YEAR, DateOfBirth, GETDATE()) >= 20),
    CONSTRAINT CHK_Nurses_Salary CHECK (BaseSalary >= 0)
);
GO

PRINT '  ✓ Nurses created';

-- ============================================
-- TABLE 4: Patients (Bệnh nhân)
-- ============================================

SET QUOTED_IDENTIFIER ON;
GO

PRINT 'Creating table: Patients...';

CREATE TABLE dbo.Patients (
    PatientID INT IDENTITY(1,1) NOT NULL,
    PatientCode NVARCHAR(20) NOT NULL,
    FirstName NVARCHAR(50) NOT NULL,
    LastName NVARCHAR(50) NOT NULL,
    FullName AS (LastName + ' ' + FirstName) PERSISTED,
    DateOfBirth DATE NOT NULL,
    Age AS (DATEDIFF(YEAR, DateOfBirth, GETDATE())),
    Gender CHAR(1) CHECK (Gender IN ('M', 'F', 'O')) NOT NULL,
    NationalID NVARCHAR(20),
    BloodType NVARCHAR(5) CHECK (BloodType IN ('A+', 'A-', 'B+', 'B-', 'AB+', 'AB-', 'O+', 'O-')),
    Email NVARCHAR(100),
    Phone NVARCHAR(20) NOT NULL,
    AlternatePhone NVARCHAR(20),
    EmergencyContactName NVARCHAR(100),
    EmergencyContactPhone NVARCHAR(20),
    EmergencyContactRelation NVARCHAR(50),
    Address NVARCHAR(200),
    City NVARCHAR(50),
    State NVARCHAR(50),
    Country NVARCHAR(50) DEFAULT 'Vietnam',
    PostalCode NVARCHAR(10),
    Occupation NVARCHAR(100),
    MaritalStatus NVARCHAR(20) CHECK (MaritalStatus IN ('Single', 'Married', 'Divorced', 'Widowed')),
    InsuranceNumber NVARCHAR(50),
    InsuranceProvider NVARCHAR(100),
    InsuranceExpiryDate DATE,
    RegistrationDate DATE DEFAULT CAST(GETDATE() AS DATE),
    LastVisitDate DATE,
    TotalVisits INT DEFAULT 0,
    IsVIP BIT DEFAULT 0,
    IsActive BIT DEFAULT 1,
    Notes NVARCHAR(1000),
    CreatedDate DATETIME2 DEFAULT SYSDATETIME(),
    CreatedBy NVARCHAR(100) DEFAULT SUSER_SNAME(),
    ModifiedDate DATETIME2 DEFAULT SYSDATETIME(),
    ModifiedBy NVARCHAR(100) DEFAULT SUSER_SNAME(),
    
    CONSTRAINT PK_Patients PRIMARY KEY CLUSTERED (PatientID),
    CONSTRAINT UK_Patients_PatientCode UNIQUE (PatientCode),
    CONSTRAINT CHK_Patients_TotalVisits CHECK (TotalVisits >= 0)
);
GO

PRINT '  ✓ Patients created';

-- ============================================
-- TABLE 5: Rooms (Phòng)
-- ============================================

PRINT 'Creating table: Rooms...';

CREATE TABLE dbo.Rooms (
    RoomID INT IDENTITY(1,1) NOT NULL,
    RoomNumber NVARCHAR(10) NOT NULL,
    DepartmentID INT NOT NULL,
    RoomType NVARCHAR(30) CHECK (RoomType IN ('ICU', 'General Ward', 'Private', 'Semi-Private', 'Emergency', 'Operating Theater', 'Recovery')) NOT NULL,
    BedCapacity INT DEFAULT 1,
    CurrentOccupancy INT DEFAULT 0,
    Building NVARCHAR(50),
    FloorNumber INT,
    WingSection NVARCHAR(20),
    DailyRate DECIMAL(10,2) DEFAULT 0,
    HasOxygen BIT DEFAULT 0,
    HasVentilator BIT DEFAULT 0,
    HasMonitoring BIT DEFAULT 0,
    Status NVARCHAR(20) CHECK (Status IN ('Available', 'Occupied', 'Cleaning', 'Maintenance', 'Reserved')) DEFAULT 'Available',
    LastCleaningDate DATETIME2,
    IsActive BIT DEFAULT 1,
    CreatedDate DATETIME2 DEFAULT SYSDATETIME(),
    CreatedBy NVARCHAR(100) DEFAULT SUSER_SNAME(),
    ModifiedDate DATETIME2 DEFAULT SYSDATETIME(),
    ModifiedBy NVARCHAR(100) DEFAULT SUSER_SNAME(),
    
    CONSTRAINT PK_Rooms PRIMARY KEY CLUSTERED (RoomID),
    CONSTRAINT UK_Rooms_RoomNumber UNIQUE (RoomNumber),
    CONSTRAINT FK_Rooms_Departments FOREIGN KEY (DepartmentID)
        REFERENCES dbo.Departments(DepartmentID),
    CONSTRAINT CHK_Rooms_Occupancy CHECK (CurrentOccupancy <= BedCapacity),
    CONSTRAINT CHK_Rooms_BedCapacity CHECK (BedCapacity > 0),
    CONSTRAINT CHK_Rooms_DailyRate CHECK (DailyRate >= 0)
);
GO

PRINT '  ✓ Rooms created';

-- ============================================
-- TABLE 6: Appointments (Lịch hẹn)
-- ============================================

PRINT 'Creating table: Appointments...';

CREATE TABLE dbo.Appointments (
    AppointmentID INT IDENTITY(1,1) NOT NULL,
    AppointmentNumber NVARCHAR(20) NOT NULL,
    PatientID INT NOT NULL,
    DoctorID INT NOT NULL,
    DepartmentID INT NOT NULL,
    AppointmentDate DATETIME2 NOT NULL,
    AppointmentEndTime DATETIME2,
    AppointmentType NVARCHAR(50) CHECK (AppointmentType IN ('New Consultation', 'Follow-up', 'Emergency', 'Surgery', 'General Checkup', 'Vaccination', 'Lab Test')) NOT NULL,
    Priority NVARCHAR(20) CHECK (Priority IN ('Normal', 'Urgent', 'Emergency')) DEFAULT 'Normal',
    Status NVARCHAR(20) CHECK (Status IN ('Scheduled', 'Confirmed', 'In Progress', 'Completed', 'Cancelled', 'No Show', 'Rescheduled')) DEFAULT 'Scheduled',
    ReasonForVisit NVARCHAR(500),
    Symptoms NVARCHAR(1000),
    Notes NVARCHAR(1000),
    EstimatedDuration INT DEFAULT 30, -- minutes
    ActualStartTime DATETIME2,
    ActualEndTime DATETIME2,
    ActualDuration AS (DATEDIFF(MINUTE, ActualStartTime, ActualEndTime)),
    RoomID INT,
    ConsultationFee DECIMAL(10,2) DEFAULT 0,
    IsPaid BIT DEFAULT 0,
    CancellationReason NVARCHAR(500),
    CancelledBy NVARCHAR(100),
    CancelledDate DATETIME2,
    RescheduledFrom INT, -- Reference to original appointment
    CreatedDate DATETIME2 DEFAULT SYSDATETIME(),
    CreatedBy NVARCHAR(100) DEFAULT SUSER_SNAME(),
    ModifiedDate DATETIME2 DEFAULT SYSDATETIME(),
    ModifiedBy NVARCHAR(100) DEFAULT SUSER_SNAME(),
    
    CONSTRAINT PK_Appointments PRIMARY KEY CLUSTERED (AppointmentID),
    CONSTRAINT UK_Appointments_Number UNIQUE (AppointmentNumber),
    CONSTRAINT FK_Appointments_Patients FOREIGN KEY (PatientID)
        REFERENCES dbo.Patients(PatientID),
    CONSTRAINT FK_Appointments_Doctors FOREIGN KEY (DoctorID)
        REFERENCES dbo.Doctors(DoctorID),
    CONSTRAINT FK_Appointments_Departments FOREIGN KEY (DepartmentID)
        REFERENCES dbo.Departments(DepartmentID),
    CONSTRAINT FK_Appointments_Rooms FOREIGN KEY (RoomID)
        REFERENCES dbo.Rooms(RoomID),
    CONSTRAINT FK_Appointments_Rescheduled FOREIGN KEY (RescheduledFrom)
        REFERENCES dbo.Appointments(AppointmentID),
    CONSTRAINT CHK_Appointments_Duration CHECK (EstimatedDuration > 0),
    CONSTRAINT CHK_Appointments_Fee CHECK (ConsultationFee >= 0)
);
GO

PRINT '  ✓ Appointments created';

-- ============================================
-- TABLE 7: MedicalRecords (Hồ sơ bệnh án - SENSITIVE DATA)
-- ============================================

PRINT 'Creating table: MedicalRecords...';

CREATE TABLE dbo.MedicalRecords (
    RecordID INT IDENTITY(1,1) NOT NULL,
    RecordNumber NVARCHAR(20) NOT NULL,
    PatientID INT NOT NULL,
    DoctorID INT NOT NULL,
    AppointmentID INT NULL,
    VisitDate DATETIME2 NOT NULL DEFAULT SYSDATETIME(),
    VisitType NVARCHAR(50) CHECK (VisitType IN ('Outpatient', 'Inpatient', 'Emergency', 'Follow-up')),
    ChiefComplaint NVARCHAR(500),
    PresentIllness NVARCHAR(2000),
    Symptoms NVARCHAR(MAX),
    PhysicalExamination NVARCHAR(MAX),
    VitalSigns NVARCHAR(500), -- JSON: {"BP":"120/80", "Temp":"37.2", "HR":"72", "RR":"18", "SPO2":"98"}
    Diagnosis NVARCHAR(MAX) NOT NULL,
    DiagnosisCode NVARCHAR(20), -- ICD-10 code
    DifferentialDiagnosis NVARCHAR(1000),
    TreatmentPlan NVARCHAR(MAX),
    Medications NVARCHAR(MAX),
    LabResults NVARCHAR(MAX),
    ImagingResults NVARCHAR(MAX),
    Allergies NVARCHAR(1000),
    CurrentMedications NVARCHAR(2000),
    PastMedicalHistory NVARCHAR(2000),
    FamilyHistory NVARCHAR(2000),
    SocialHistory NVARCHAR(1000),
    Prognosis NVARCHAR(500),
    FollowUpInstructions NVARCHAR(1000),
    FollowUpDate DATETIME2,
    ReferralTo NVARCHAR(200),
    IsConfidential BIT DEFAULT 1,
    IsEmergency BIT DEFAULT 0,
    AdmissionRequired BIT DEFAULT 0,
    Notes NVARCHAR(MAX),
    AttachmentsPath NVARCHAR(500),
    CreatedDate DATETIME2 DEFAULT SYSDATETIME(),
    CreatedBy NVARCHAR(100) DEFAULT SUSER_SNAME(),
    ModifiedDate DATETIME2 DEFAULT SYSDATETIME(),
    ModifiedBy NVARCHAR(100) DEFAULT SUSER_SNAME(),
    
    CONSTRAINT PK_MedicalRecords PRIMARY KEY CLUSTERED (RecordID),
    CONSTRAINT UK_MedicalRecords_Number UNIQUE (RecordNumber),
    CONSTRAINT FK_MedicalRecords_Patients FOREIGN KEY (PatientID)
        REFERENCES dbo.Patients(PatientID),
    CONSTRAINT FK_MedicalRecords_Doctors FOREIGN KEY (DoctorID)
        REFERENCES dbo.Doctors(DoctorID),
    CONSTRAINT FK_MedicalRecords_Appointments FOREIGN KEY (AppointmentID)
        REFERENCES dbo.Appointments(AppointmentID)
);
GO

PRINT '  ✓ MedicalRecords created';

-- ============================================
-- TABLE 8: Prescriptions (Đơn thuốc)
-- ============================================

SET QUOTED_IDENTIFIER ON;
GO

PRINT 'Creating table: Prescriptions...';

CREATE TABLE dbo.Prescriptions (
    PrescriptionID INT IDENTITY(1,1) NOT NULL,
    PrescriptionNumber NVARCHAR(20) NOT NULL,
    RecordID INT NOT NULL,
    PatientID INT NOT NULL,
    DoctorID INT NOT NULL,
    PrescriptionDate DATETIME2 DEFAULT SYSDATETIME(),
    Instructions NVARCHAR(2000),
    StartDate DATE NOT NULL,
    EndDate DATE,
    Duration AS (DATEDIFF(DAY, StartDate, EndDate)),
    RefillsAllowed INT DEFAULT 0,
    RefillsRemaining INT,
    Status NVARCHAR(20) CHECK (Status IN ('Active', 'Completed', 'Cancelled', 'Expired')) DEFAULT 'Active',
    PharmacyName NVARCHAR(100),
    PharmacistName NVARCHAR(100),
    DispensedDate DATETIME2,
    TotalCost DECIMAL(10,2) DEFAULT 0,
    IsPaid BIT DEFAULT 0,
    Notes NVARCHAR(1000),
    CreatedDate DATETIME2 DEFAULT SYSDATETIME(),
    CreatedBy NVARCHAR(100) DEFAULT SUSER_SNAME(),
    ModifiedDate DATETIME2 DEFAULT SYSDATETIME(),
    ModifiedBy NVARCHAR(100) DEFAULT SUSER_SNAME(),
    
    CONSTRAINT PK_Prescriptions PRIMARY KEY CLUSTERED (PrescriptionID),
    CONSTRAINT UK_Prescriptions_Number UNIQUE (PrescriptionNumber),
    CONSTRAINT FK_Prescriptions_MedicalRecords FOREIGN KEY (RecordID)
        REFERENCES dbo.MedicalRecords(RecordID),
    CONSTRAINT FK_Prescriptions_Patients FOREIGN KEY (PatientID)
        REFERENCES dbo.Patients(PatientID),
    CONSTRAINT FK_Prescriptions_Doctors FOREIGN KEY (DoctorID)
        REFERENCES dbo.Doctors(DoctorID),
    CONSTRAINT CHK_Prescriptions_Refills CHECK (RefillsAllowed >= 0),
    CONSTRAINT CHK_Prescriptions_Cost CHECK (TotalCost >= 0)
);
GO

PRINT '  ✓ Prescriptions created';


-- File: phase1-database/schema/02_create_tables.sql (PART 2)
-- Continuation from Part 1

-- ============================================
-- TABLE 9: PrescriptionDetails (Chi tiết đơn thuốc)
-- ============================================

SET QUOTED_IDENTIFIER ON;
GO

PRINT 'Creating table: PrescriptionDetails...';

CREATE TABLE dbo.PrescriptionDetails (
    DetailID INT IDENTITY(1,1) NOT NULL,
    PrescriptionID INT NOT NULL,
    MedicationID NVARCHAR(20),
    MedicationName NVARCHAR(200) NOT NULL,
    GenericName NVARCHAR(200),
    MedicationType NVARCHAR(50) CHECK (MedicationType IN ('Tablet', 'Capsule', 'Syrup', 'Injection', 'Ointment', 'Drops', 'Inhaler', 'Patch')),
    Strength NVARCHAR(50) NOT NULL,
    Dosage NVARCHAR(50) NOT NULL,
    Route NVARCHAR(30) CHECK (Route IN ('Oral', 'Topical', 'Intravenous', 'Intramuscular', 'Subcutaneous', 'Inhalation', 'Rectal', 'Ophthalmic')),
    Frequency NVARCHAR(100) NOT NULL, -- e.g., "3 times daily", "Every 8 hours", "Once daily"
    FrequencyCode NVARCHAR(10), -- e.g., "TID", "QID", "BID"
    Duration NVARCHAR(50), -- e.g., "7 days", "2 weeks", "1 month"
    Quantity INT NOT NULL,
    UnitOfMeasure NVARCHAR(20),
    UnitPrice DECIMAL(10,2),
    TotalPrice AS (Quantity * UnitPrice) PERSISTED,
    Instructions NVARCHAR(1000),
    Warnings NVARCHAR(1000),
    SideEffects NVARCHAR(1000),
    StartDate DATE,
    EndDate DATE,
    IsDispensed BIT DEFAULT 0,
    DispensedQuantity INT DEFAULT 0,
    DispensedDate DATETIME2,
    Notes NVARCHAR(500),
    CreatedDate DATETIME2 DEFAULT SYSDATETIME(),
    CreatedBy NVARCHAR(100) DEFAULT SUSER_SNAME(),
    
    CONSTRAINT PK_PrescriptionDetails PRIMARY KEY CLUSTERED (DetailID),
    CONSTRAINT FK_PrescriptionDetails_Prescriptions FOREIGN KEY (PrescriptionID)
        REFERENCES dbo.Prescriptions(PrescriptionID) ON DELETE CASCADE,
    CONSTRAINT CHK_PrescriptionDetails_Quantity CHECK (Quantity > 0),
    CONSTRAINT CHK_PrescriptionDetails_UnitPrice CHECK (UnitPrice >= 0),
    CONSTRAINT CHK_PrescriptionDetails_DispensedQty CHECK (DispensedQuantity <= Quantity)
);
GO

PRINT '  ✓ PrescriptionDetails created';

-- ============================================
-- TABLE 10: LabTests (Xét nghiệm)
-- ============================================

PRINT 'Creating table: LabTests...';

CREATE TABLE dbo.LabTests (
    LabTestID INT IDENTITY(1,1) NOT NULL,
    TestNumber NVARCHAR(20) NOT NULL,
    PatientID INT NOT NULL,
    DoctorID INT NOT NULL,
    RecordID INT NULL,
    TestName NVARCHAR(200) NOT NULL,
    TestCode NVARCHAR(20),
    TestCategory NVARCHAR(50) CHECK (TestCategory IN ('Blood', 'Urine', 'Stool', 'Imaging', 'Biopsy', 'Culture', 'Genetic', 'Other')) NOT NULL,
    TestType NVARCHAR(100),
    DepartmentID INT,
    OrderDate DATETIME2 DEFAULT SYSDATETIME(),
    SampleCollectionDate DATETIME2,
    SampleType NVARCHAR(50),
    SampleID NVARCHAR(20),
    CollectedBy NVARCHAR(100),
    ResultDate DATETIME2,
    ReportDate DATETIME2,
    Results NVARCHAR(MAX),
    ResultValue NVARCHAR(200),
    ResultUnit NVARCHAR(50),
    NormalRange NVARCHAR(200),
    IsAbnormal BIT DEFAULT 0,
    AbnormalityFlag NVARCHAR(10) CHECK (AbnormalityFlag IN ('H', 'L', 'N', 'C')), -- High, Low, Normal, Critical
    Interpretation NVARCHAR(1000),
    ResultsFile VARBINARY(MAX), -- Store PDF/Image
    ResultsFilePath NVARCHAR(500),
    Status NVARCHAR(20) CHECK (Status IN ('Ordered', 'Sample Collected', 'In Progress', 'Completed', 'Cancelled', 'Failed')) DEFAULT 'Ordered',
    Priority NVARCHAR(20) CHECK (Priority IN ('Routine', 'Urgent', 'STAT', 'ASAP')) DEFAULT 'Routine',
    PerformedBy NVARCHAR(100),
    VerifiedBy NVARCHAR(100),
    VerifiedDate DATETIME2,
    Cost DECIMAL(10,2) DEFAULT 0,
    IsPaid BIT DEFAULT 0,
    Notes NVARCHAR(1000),
    TechnicalNotes NVARCHAR(1000),
    CreatedDate DATETIME2 DEFAULT SYSDATETIME(),
    CreatedBy NVARCHAR(100) DEFAULT SUSER_SNAME(),
    ModifiedDate DATETIME2 DEFAULT SYSDATETIME(),
    ModifiedBy NVARCHAR(100) DEFAULT SUSER_SNAME(),
    
    CONSTRAINT PK_LabTests PRIMARY KEY CLUSTERED (LabTestID),
    CONSTRAINT UK_LabTests_Number UNIQUE (TestNumber),
    CONSTRAINT FK_LabTests_Patients FOREIGN KEY (PatientID)
        REFERENCES dbo.Patients(PatientID),
    CONSTRAINT FK_LabTests_Doctors FOREIGN KEY (DoctorID)
        REFERENCES dbo.Doctors(DoctorID),
    CONSTRAINT FK_LabTests_MedicalRecords FOREIGN KEY (RecordID)
        REFERENCES dbo.MedicalRecords(RecordID),
    CONSTRAINT FK_LabTests_Departments FOREIGN KEY (DepartmentID)
        REFERENCES dbo.Departments(DepartmentID),
    CONSTRAINT CHK_LabTests_Cost CHECK (Cost >= 0)
);
GO

PRINT '  ✓ LabTests created';

-- ============================================
-- TABLE 11: Admissions (Nhập viện)
-- ============================================

SET QUOTED_IDENTIFIER ON;
GO

PRINT 'Creating table: Admissions...';

CREATE TABLE dbo.Admissions (
    AdmissionID INT IDENTITY(1,1) NOT NULL,
    AdmissionNumber NVARCHAR(20) NOT NULL,
    PatientID INT NOT NULL,
    DoctorID INT NOT NULL,
    DepartmentID INT NOT NULL,
    RoomID INT NOT NULL,
    AdmissionDate DATETIME2 DEFAULT SYSDATETIME(),
    DischargeDate DATETIME2,
    LengthOfStay AS (DATEDIFF(DAY, AdmissionDate, COALESCE(DischargeDate, SYSDATETIME()))),
    AdmissionType NVARCHAR(30) CHECK (AdmissionType IN ('Emergency', 'Elective', 'Urgent', 'Observation', 'Transfer')) NOT NULL,
    AdmissionSource NVARCHAR(50) CHECK (AdmissionSource IN ('Emergency Room', 'Outpatient', 'Transfer', 'Direct', 'Referral')),
    AdmissionReason NVARCHAR(500) NOT NULL,
    InitialDiagnosis NVARCHAR(1000),
    FinalDiagnosis NVARCHAR(1000),
    ProceduresPerformed NVARCHAR(2000),
    Complications NVARCHAR(1000),
    DischargeReason NVARCHAR(500),
    DischargeType NVARCHAR(30) CHECK (DischargeType IN ('Home', 'Transfer', 'Against Medical Advice', 'Deceased', 'Other Facility')),
    DischargeInstructions NVARCHAR(MAX),
    DischargedBy INT, -- DoctorID
    FollowUpRequired BIT DEFAULT 0,
    FollowUpDate DATE,
    Status NVARCHAR(20) CHECK (Status IN ('Active', 'Discharged', 'Transferred', 'Deceased')) DEFAULT 'Active',
    BedNumber NVARCHAR(10),
    AttendingNurseID INT,
    IsolationRequired BIT DEFAULT 0,
    IsolationType NVARCHAR(50),
    DietInstructions NVARCHAR(500),
    ActivityRestrictions NVARCHAR(500),
    RoomDailyCost DECIMAL(10,2) DEFAULT 0,
    TreatmentCost DECIMAL(15,2) DEFAULT 0,
    MedicationCost DECIMAL(15,2) DEFAULT 0,
    LabTestCost DECIMAL(15,2) DEFAULT 0,
    TotalCost AS (RoomDailyCost * DATEDIFF(DAY, AdmissionDate, COALESCE(DischargeDate, SYSDATETIME())) + TreatmentCost + MedicationCost + LabTestCost),
    InsuranceCovered DECIMAL(15,2) DEFAULT 0,
    PatientResponsibility AS (RoomDailyCost * DATEDIFF(DAY, AdmissionDate, COALESCE(DischargeDate, SYSDATETIME())) + TreatmentCost + MedicationCost + LabTestCost - InsuranceCovered),
    IsPaid BIT DEFAULT 0,
    Notes NVARCHAR(MAX),
    CreatedDate DATETIME2 DEFAULT SYSDATETIME(),
    CreatedBy NVARCHAR(100) DEFAULT SUSER_SNAME(),
    ModifiedDate DATETIME2 DEFAULT SYSDATETIME(),
    ModifiedBy NVARCHAR(100) DEFAULT SUSER_SNAME(),
    
    CONSTRAINT PK_Admissions PRIMARY KEY CLUSTERED (AdmissionID),
    CONSTRAINT UK_Admissions_Number UNIQUE (AdmissionNumber),
    CONSTRAINT FK_Admissions_Patients FOREIGN KEY (PatientID)
        REFERENCES dbo.Patients(PatientID),
    CONSTRAINT FK_Admissions_Doctors FOREIGN KEY (DoctorID)
        REFERENCES dbo.Doctors(DoctorID),
    CONSTRAINT FK_Admissions_Departments FOREIGN KEY (DepartmentID)
        REFERENCES dbo.Departments(DepartmentID),
    CONSTRAINT FK_Admissions_Rooms FOREIGN KEY (RoomID)
        REFERENCES dbo.Rooms(RoomID),
    CONSTRAINT FK_Admissions_DischargedBy FOREIGN KEY (DischargedBy)
        REFERENCES dbo.Doctors(DoctorID),
    CONSTRAINT FK_Admissions_AttendingNurse FOREIGN KEY (AttendingNurseID)
        REFERENCES dbo.Nurses(NurseID),
    CONSTRAINT CHK_Admissions_Costs CHECK (TreatmentCost >= 0 AND MedicationCost >= 0 AND LabTestCost >= 0),
    CONSTRAINT CHK_Admissions_Insurance CHECK (InsuranceCovered >= 0)
);
GO

PRINT '  ✓ Admissions created';

-- ============================================
-- TABLE 12: Billing (Hóa đơn)
-- ============================================

SET QUOTED_IDENTIFIER ON;
GO

PRINT 'Creating table: Billing...';

CREATE TABLE dbo.Billing (
    BillingID INT IDENTITY(1,1) NOT NULL,
    InvoiceNumber NVARCHAR(50) NOT NULL,
    PatientID INT NOT NULL,
    AppointmentID INT NULL,
    AdmissionID INT NULL,
    BillingType NVARCHAR(30) CHECK (BillingType IN ('Consultation', 'Admission', 'Procedure', 'Lab Test', 'Medication', 'Other')) NOT NULL,
    InvoiceDate DATETIME2 DEFAULT SYSDATETIME(),
    DueDate DATE,
    ServiceDate DATE NOT NULL,
    SubTotal DECIMAL(15,2) DEFAULT 0,
    TaxRate DECIMAL(5,2) DEFAULT 10.00,
    TaxAmount AS (SubTotal * TaxRate / 100) PERSISTED,
    Discount DECIMAL(15,2) DEFAULT 0,
    DiscountReason NVARCHAR(200),
    AdjustmentAmount DECIMAL(15,2) DEFAULT 0,
    AdjustmentReason NVARCHAR(200),
    TotalAmount AS (SubTotal + (SubTotal * TaxRate / 100) - Discount + AdjustmentAmount) PERSISTED,
    AmountPaid DECIMAL(15,2) DEFAULT 0,
    Balance AS (SubTotal + (SubTotal * TaxRate / 100) - Discount + AdjustmentAmount - AmountPaid),
    PaymentStatus NVARCHAR(20) CHECK (PaymentStatus IN ('Pending', 'Partial', 'Paid', 'Overdue', 'Cancelled', 'Refunded')) DEFAULT 'Pending',
    PaymentDueDate DATE,
    OverdueDays AS (CASE WHEN PaymentStatus IN ('Pending', 'Partial', 'Overdue') 
                         THEN DATEDIFF(DAY, PaymentDueDate, GETDATE()) 
                         ELSE 0 END),
    InsuranceClaimNumber NVARCHAR(50),
    InsuranceClaim DECIMAL(15,2) DEFAULT 0,
    InsuranceApproved DECIMAL(15,2) DEFAULT 0,
    InsurancePending DECIMAL(15,2) DEFAULT 0,
    InsuranceDenied DECIMAL(15,2) DEFAULT 0,
    PatientResponsibility AS (SubTotal + (SubTotal * TaxRate / 100) - Discount + AdjustmentAmount - InsuranceApproved) PERSISTED,
    Currency NVARCHAR(3) DEFAULT 'VND',
    BilledBy NVARCHAR(100),
    ApprovedBy NVARCHAR(100),
    ApprovedDate DATETIME2,
    Notes NVARCHAR(1000),
    CreatedDate DATETIME2 DEFAULT SYSDATETIME(),
    CreatedBy NVARCHAR(100) DEFAULT SUSER_SNAME(),
    ModifiedDate DATETIME2 DEFAULT SYSDATETIME(),
    ModifiedBy NVARCHAR(100) DEFAULT SUSER_SNAME(),
    
    CONSTRAINT PK_Billing PRIMARY KEY CLUSTERED (BillingID),
    CONSTRAINT UK_Billing_InvoiceNumber UNIQUE (InvoiceNumber),
    CONSTRAINT FK_Billing_Patients FOREIGN KEY (PatientID)
        REFERENCES dbo.Patients(PatientID),
    CONSTRAINT FK_Billing_Appointments FOREIGN KEY (AppointmentID)
        REFERENCES dbo.Appointments(AppointmentID),
    CONSTRAINT FK_Billing_Admissions FOREIGN KEY (AdmissionID)
        REFERENCES dbo.Admissions(AdmissionID),
    CONSTRAINT CHK_Billing_SubTotal CHECK (SubTotal >= 0),
    CONSTRAINT CHK_Billing_Discount CHECK (Discount >= 0),
    CONSTRAINT CHK_Billing_AmountPaid CHECK (AmountPaid >= 0),
    CONSTRAINT CHK_Billing_Insurance CHECK (InsuranceClaim >= 0 AND InsuranceApproved >= 0)
);
GO

PRINT '  ✓ Billing created';

-- ============================================
-- TABLE 13: BillingDetails (Chi tiết hóa đơn)
-- ============================================

SET QUOTED_IDENTIFIER ON;
GO

PRINT 'Creating table: BillingDetails...';

CREATE TABLE dbo.BillingDetails (
    DetailID INT IDENTITY(1,1) NOT NULL,
    BillingID INT NOT NULL,
    LineNumber INT NOT NULL,
    ServiceType NVARCHAR(50) CHECK (ServiceType IN ('Consultation', 'Lab Test', 'Imaging', 'Medication', 'Room Charge', 'Surgery', 'Procedure', 'Treatment', 'Other')) NOT NULL,
    ServiceCode NVARCHAR(20),
    Description NVARCHAR(500) NOT NULL,
    ServiceDate DATE NOT NULL,
    ServiceProviderID INT, -- DoctorID or NurseID
    ServiceProviderType NVARCHAR(20) CHECK (ServiceProviderType IN ('Doctor', 'Nurse', 'Technician', 'Other')),
    Quantity INT DEFAULT 1,
    UnitOfMeasure NVARCHAR(20) DEFAULT 'Unit',
    UnitPrice DECIMAL(10,2) NOT NULL,
    SubTotal AS (Quantity * UnitPrice) PERSISTED,
    DiscountPercent DECIMAL(5,2) DEFAULT 0,
    DiscountAmount AS (Quantity * UnitPrice * DiscountPercent / 100) PERSISTED,
    TotalPrice AS (Quantity * UnitPrice - (Quantity * UnitPrice * DiscountPercent / 100)) PERSISTED,
    IsCovered BIT DEFAULT 0, -- Insurance coverage
    Notes NVARCHAR(500),
    CreatedDate DATETIME2 DEFAULT SYSDATETIME(),
    CreatedBy NVARCHAR(100) DEFAULT SUSER_SNAME(),
    
    CONSTRAINT PK_BillingDetails PRIMARY KEY CLUSTERED (DetailID),
    CONSTRAINT FK_BillingDetails_Billing FOREIGN KEY (BillingID)
        REFERENCES dbo.Billing(BillingID) ON DELETE CASCADE,
    CONSTRAINT CHK_BillingDetails_Quantity CHECK (Quantity > 0),
    CONSTRAINT CHK_BillingDetails_UnitPrice CHECK (UnitPrice >= 0),
    CONSTRAINT CHK_BillingDetails_Discount CHECK (DiscountPercent >= 0 AND DiscountPercent <= 100)
);
GO

PRINT '  ✓ BillingDetails created';

-- ============================================
-- TABLE 14: Payments (Thanh toán)
-- ============================================

PRINT 'Creating table: Payments...';

CREATE TABLE dbo.Payments (
    PaymentID INT IDENTITY(1,1) NOT NULL,
    PaymentNumber NVARCHAR(20) NOT NULL,
    BillingID INT NOT NULL,
    PatientID INT NOT NULL,
    PaymentDate DATETIME2 DEFAULT SYSDATETIME(),
    Amount DECIMAL(15,2) NOT NULL,
    Currency NVARCHAR(3) DEFAULT 'VND',
    PaymentMethod NVARCHAR(30) CHECK (PaymentMethod IN ('Cash', 'Credit Card', 'Debit Card', 'Bank Transfer', 'Insurance', 'Mobile Payment', 'Check', 'Other')) NOT NULL,
    PaymentType NVARCHAR(20) CHECK (PaymentType IN ('Full', 'Partial', 'Advance', 'Refund')) DEFAULT 'Full',
    CardNumber NVARCHAR(20), -- Last 4 digits only
    CardType NVARCHAR(20),
    TransactionID NVARCHAR(100),
    ReferenceNumber NVARCHAR(100),
    BankName NVARCHAR(100),
    CheckNumber NVARCHAR(50),
    ProcessedBy NVARCHAR(100),
    ReceivedBy NVARCHAR(100),
    ApprovedBy NVARCHAR(100),
    ApprovedDate DATETIME2,
    Status NVARCHAR(20) CHECK (Status IN ('Completed', 'Pending', 'Processing', 'Failed', 'Cancelled', 'Refunded')) DEFAULT 'Completed',
    FailureReason NVARCHAR(500),
    RefundAmount DECIMAL(15,2) DEFAULT 0,
    RefundDate DATETIME2,
    RefundReason NVARCHAR(500),
    ReceiptNumber NVARCHAR(50),
    ReceiptIssued BIT DEFAULT 0,
    Notes NVARCHAR(1000),
    CreatedDate DATETIME2 DEFAULT SYSDATETIME(),
    CreatedBy NVARCHAR(100) DEFAULT SUSER_SNAME(),
    ModifiedDate DATETIME2 DEFAULT SYSDATETIME(),
    ModifiedBy NVARCHAR(100) DEFAULT SUSER_SNAME(),
    
    CONSTRAINT PK_Payments PRIMARY KEY CLUSTERED (PaymentID),
    CONSTRAINT UK_Payments_Number UNIQUE (PaymentNumber),
    CONSTRAINT FK_Payments_Billing FOREIGN KEY (BillingID)
        REFERENCES dbo.Billing(BillingID),
    CONSTRAINT FK_Payments_Patients FOREIGN KEY (PatientID)
        REFERENCES dbo.Patients(PatientID),
    CONSTRAINT CHK_Payments_Amount CHECK (Amount >= 0),
    CONSTRAINT CHK_Payments_RefundAmount CHECK (RefundAmount >= 0 AND RefundAmount <= Amount)
);
GO

PRINT '  ✓ Payments created';

-- ============================================
-- TABLE 15: AuditLog (Nhật ký kiểm toán)
-- ============================================

PRINT 'Creating table: AuditLog...';

CREATE TABLE dbo.AuditLog (
    AuditID BIGINT IDENTITY(1,1) NOT NULL,
    AuditDate DATETIME2 DEFAULT SYSDATETIME(),
    TableName NVARCHAR(128) NOT NULL,
    SchemaName NVARCHAR(128) DEFAULT 'dbo',
    RecordID INT NOT NULL,
    Action NVARCHAR(20) CHECK (Action IN ('INSERT', 'UPDATE', 'DELETE', 'SELECT')) NOT NULL,
    ActionType NVARCHAR(50),
    UserName NVARCHAR(128) DEFAULT SUSER_SNAME(),
    DatabaseUser NVARCHAR(128) DEFAULT USER_NAME(),
    HostName NVARCHAR(128) DEFAULT HOST_NAME(),
    ApplicationName NVARCHAR(128) DEFAULT APP_NAME(),
    IPAddress NVARCHAR(50),
    SessionID INT DEFAULT @@SPID,
    TransactionID NVARCHAR(50),
    OldValues NVARCHAR(MAX),
    NewValues NVARCHAR(MAX),
    ChangedColumns NVARCHAR(500),
    SQLStatement NVARCHAR(MAX),
    IsSuccess BIT DEFAULT 1,
    ErrorMessage NVARCHAR(1000),
    Severity NVARCHAR(20) CHECK (Severity IN ('Low', 'Medium', 'High', 'Critical')) DEFAULT 'Low',
    IsSecurityEvent BIT DEFAULT 0,
    RequiresReview BIT DEFAULT 0,
    ReviewedBy NVARCHAR(100),
    ReviewedDate DATETIME2,
    Notes NVARCHAR(1000),
    
    CONSTRAINT PK_AuditLog PRIMARY KEY CLUSTERED (AuditID)
);
GO

PRINT '  ✓ AuditLog created';

-- ============================================
-- TABLE 16: BackupHistory (Lịch sử sao lưu)
-- ============================================

SET QUOTED_IDENTIFIER ON;
GO

PRINT 'Creating table: BackupHistory...';

CREATE TABLE dbo.BackupHistory (
    BackupHistoryID INT IDENTITY(1,1) NOT NULL,
    BackupType NVARCHAR(20) CHECK (BackupType IN ('Full', 'Differential', 'Transaction Log')) NOT NULL,
    BackupStartDate DATETIME2 NOT NULL,
    BackupEndDate DATETIME2,
    BackupDuration AS (DATEDIFF(SECOND, BackupStartDate, BackupEndDate)) PERSISTED,
    BackupFileName NVARCHAR(500) NOT NULL,
    BackupFileSize BIGINT, -- in bytes
    BackupFileSizeMB AS (CAST(BackupFileSize AS DECIMAL(18,2)) / 1024 / 1024) PERSISTED,
    BackupLocation NVARCHAR(500) NOT NULL,
    BackupDevice NVARCHAR(20) CHECK (BackupDevice IN ('Local Disk', 'Network Share', 'S3', 'Azure Blob', 'Other')) DEFAULT 'Local Disk',
    S3Bucket NVARCHAR(100),
    S3Key NVARCHAR(500),
    IsEncrypted BIT DEFAULT 1,
    EncryptionAlgorithm NVARCHAR(50),
    CertificateName NVARCHAR(128),
    IsCompressed BIT DEFAULT 1,
    CompressionRatio DECIMAL(5,2),
    BackupStatus NVARCHAR(20) CHECK (BackupStatus IN ('In Progress', 'Completed', 'Failed', 'Cancelled')) NOT NULL,
    ErrorMessage NVARCHAR(1000),
    VerificationStatus NVARCHAR(20) CHECK (VerificationStatus IN ('Not Verified', 'Verified', 'Failed')),
    VerificationDate DATETIME2,
    VerifiedBy NVARCHAR(100),
    RecoveryModel NVARCHAR(20),
    DatabaseSizeMB DECIMAL(18,2),
    LSN NUMERIC(25,0), -- Log Sequence Number
    FirstLSN NUMERIC(25,0),
    LastLSN NUMERIC(25,0),
    CheckpointLSN NUMERIC(25,0),
    IsFullBackupBase BIT DEFAULT 0,
    FullBackupBaseID INT, -- Reference to base full backup
    ExpirationDate DATE,
    RetentionDays INT DEFAULT 30,
    IsDeleted BIT DEFAULT 0,
    DeletedDate DATETIME2,
    BackupUser NVARCHAR(100) DEFAULT SUSER_SNAME(),
    BackupHost NVARCHAR(100) DEFAULT HOST_NAME(),
    BackupSoftware NVARCHAR(100) DEFAULT 'SQL Server',
    BackupVersion NVARCHAR(50),
    Notes NVARCHAR(1000),
    CreatedDate DATETIME2 DEFAULT SYSDATETIME(),
    
    CONSTRAINT PK_BackupHistory PRIMARY KEY CLUSTERED (BackupHistoryID),
    CONSTRAINT FK_BackupHistory_FullBackupBase FOREIGN KEY (FullBackupBaseID)
        REFERENCES dbo.BackupHistory(BackupHistoryID),
    CONSTRAINT CHK_BackupHistory_FileSize CHECK (BackupFileSize >= 0),
    CONSTRAINT CHK_BackupHistory_RetentionDays CHECK (RetentionDays > 0)
);
GO

PRINT '  ✓ BackupHistory created';

-- ============================================
-- TABLE 17: SecurityEvents (Sự kiện bảo mật)
-- ============================================

PRINT 'Creating table: SecurityEvents...';

CREATE TABLE dbo.SecurityEvents (
    EventID BIGINT IDENTITY(1,1) NOT NULL,
    EventDate DATETIME2 DEFAULT SYSDATETIME(),
    EventType NVARCHAR(50) CHECK (EventType IN ('Login Success', 'Login Failed', 'Logout', 'Permission Denied', 'Unauthorized Access', 'Data Access', 'Data Modification', 'Schema Change', 'User Created', 'User Deleted', 'Role Changed', 'Password Changed', 'Encryption Event', 'Backup Event', 'Restore Event', 'Other')) NOT NULL,
    Severity NVARCHAR(20) CHECK (Severity IN ('Info', 'Warning', 'Error', 'Critical')) NOT NULL,
    LoginName NVARCHAR(128),
    DatabaseUser NVARCHAR(128),
    SourceIP NVARCHAR(50),
    HostName NVARCHAR(128),
    ApplicationName NVARCHAR(128),
    ObjectType NVARCHAR(50),
    ObjectSchema NVARCHAR(128),
    ObjectName NVARCHAR(128),
    ActionPerformed NVARCHAR(200),
    IsSuccessful BIT NOT NULL,
    ErrorNumber INT,
    ErrorMessage NVARCHAR(1000),
    AdditionalInfo NVARCHAR(MAX),
    ThreatLevel NVARCHAR(20) CHECK (ThreatLevel IN ('Low', 'Medium', 'High', 'Critical')) DEFAULT 'Low',
    IsBlocked BIT DEFAULT 0,
    RequiresInvestigation BIT DEFAULT 0,
    InvestigatedBy NVARCHAR(100),
    InvestigatedDate DATETIME2,
    InvestigationNotes NVARCHAR(2000),
    ResolutionStatus NVARCHAR(20) CHECK (ResolutionStatus IN ('Open', 'In Progress', 'Resolved', 'Closed', 'False Positive')),
    ResolvedBy NVARCHAR(100),
    ResolvedDate DATETIME2,
    
    CONSTRAINT PK_SecurityEvents PRIMARY KEY CLUSTERED (EventID)
);
GO

PRINT '  ✓ SecurityEvents created';

-- ============================================
-- TABLE 18: SystemConfiguration (Cấu hình hệ thống)
-- ============================================

PRINT 'Creating table: SystemConfiguration...';

CREATE TABLE dbo.SystemConfiguration (
    ConfigID INT IDENTITY(1,1) NOT NULL,
    ConfigKey NVARCHAR(100) NOT NULL,
    ConfigValue NVARCHAR(1000),
    ConfigCategory NVARCHAR(50) CHECK (ConfigCategory IN ('General', 'Security', 'Backup', 'Performance', 'Notification', 'Integration', 'Other')) NOT NULL,
    DataType NVARCHAR(20) CHECK (DataType IN ('String', 'Integer', 'Decimal', 'Boolean', 'Date', 'JSON')) DEFAULT 'String',
    Description NVARCHAR(500),
    DefaultValue NVARCHAR(1000),
    IsEncrypted BIT DEFAULT 0,
    IsActive BIT DEFAULT 1,
    AllowUserModification BIT DEFAULT 0,
    LastModifiedDate DATETIME2 DEFAULT SYSDATETIME(),
    ModifiedBy NVARCHAR(100) DEFAULT SUSER_SNAME(),
    CreatedDate DATETIME2 DEFAULT SYSDATETIME(),
    CreatedBy NVARCHAR(100) DEFAULT SUSER_SNAME(),
    
    CONSTRAINT PK_SystemConfiguration PRIMARY KEY CLUSTERED (ConfigID),
    CONSTRAINT UK_SystemConfiguration_Key UNIQUE (ConfigKey)
);
GO

PRINT '  ✓ SystemConfiguration created';

-- ============================================
-- INSERT DEFAULT CONFIGURATION VALUES
-- ============================================

PRINT '';
PRINT 'Inserting default configuration values...';

INSERT INTO dbo.SystemConfiguration (ConfigKey, ConfigValue, ConfigCategory, DataType, Description, DefaultValue)
VALUES
    ('BackupRetentionDays', '30', 'Backup', 'Integer', 'Number of days to retain local backups', '30'),
    ('S3RetentionDays', '90', 'Backup', 'Integer', 'Number of days to retain S3 backups', '90'),
    ('EnableTDE', 'true', 'Security', 'Boolean', 'Enable Transparent Data Encryption', 'true'),
    ('EnableAudit', 'true', 'Security', 'Boolean', 'Enable database auditing', 'true'),
    ('MaxFailedLoginAttempts', '5', 'Security', 'Integer', 'Maximum failed login attempts before lockout', '5'),
    ('SessionTimeoutMinutes', '30', 'Security', 'Integer', 'Session timeout in minutes', '30'),
    ('BackupCompressionEnabled', 'true', 'Backup', 'Boolean', 'Enable backup compression', 'true'),
    ('BackupEncryptionEnabled', 'true', 'Backup', 'Boolean', 'Enable backup encryption', 'true'),
    ('EmailNotificationEnabled', 'true', 'Notification', 'Boolean', 'Enable email notifications', 'true'),
    ('NotificationEmail', 'admin@hospital.com', 'Notification', 'String', 'Default notification email', 'admin@hospital.com'),
    ('DatabaseVersion', '1.0.0', 'General', 'String', 'Database schema version', '1.0.0'),
    ('MaintenanceWindow', '02:00-04:00', 'General', 'String', 'Maintenance window time range', '02:00-04:00');
GO

PRINT '  ✓ Default configuration inserted';

-- ============================================
-- SUMMARY OF CREATED TABLES
-- ============================================

PRINT '';
PRINT '╔════════════════════════════════════════════════════════════════╗';
PRINT '║   ✓ All Tables Created Successfully                            ║';
PRINT '╚════════════════════════════════════════════════════════════════╝';
PRINT '';

-- Display table count and summary
SELECT 
    'Total Tables' AS Metric,
    CAST(COUNT(*) AS NVARCHAR) AS Value
FROM sys.tables
WHERE schema_id = SCHEMA_ID('dbo')

UNION ALL

SELECT 
    'Total Columns',
    CAST(SUM(column_count) AS NVARCHAR)
FROM (
    SELECT COUNT(*) as column_count
    FROM sys.columns c
    INNER JOIN sys.tables t ON c.object_id = t.object_id
    WHERE t.schema_id = SCHEMA_ID('dbo')
    GROUP BY t.object_id
) AS col_counts

UNION ALL

SELECT 
    'Total Foreign Keys',
    CAST(COUNT(*) AS NVARCHAR)
FROM sys.foreign_keys
WHERE schema_id = SCHEMA_ID('dbo')

UNION ALL

SELECT 
    'Total Check Constraints',
    CAST(COUNT(*) AS NVARCHAR)
FROM sys.check_constraints
WHERE schema_id = SCHEMA_ID('dbo');

GO

-- ============================================
-- LIST ALL CREATED TABLES
-- ============================================

PRINT '';
PRINT 'Created Tables:';
PRINT '─────────────────────────────────────────────────────────────────';

SELECT 
    ROW_NUMBER() OVER (ORDER BY t.name) AS [#],
    t.name AS TableName,
    (SELECT COUNT(*) FROM sys.columns c WHERE c.object_id = t.object_id) AS Columns,
    (SELECT COUNT(*) FROM sys.foreign_keys fk WHERE fk.parent_object_id = t.object_id) AS ForeignKeys,
    (SELECT COUNT(*) FROM sys.check_constraints cc WHERE cc.parent_object_id = t.object_id) AS CheckConstraints
FROM sys.tables t
WHERE t.schema_id = SCHEMA_ID('dbo')
ORDER BY t.name;

GO

