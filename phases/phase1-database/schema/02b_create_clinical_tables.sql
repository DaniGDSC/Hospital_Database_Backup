-- Clinical tables: Appointments, MedicalRecords, Prescriptions, PrescriptionDetails, LabTests, Admissions
-- Dependencies: 02a_create_core_tables.sql must be run first

SET QUOTED_IDENTIFIER ON;
GO

USE HospitalBackupDemo;
GO

PRINT '╔════════════════════════════════════════════════════════════════╗';
PRINT '║   Phase 1.2b: Clinical Tables                                  ║';
PRINT '║   Appointments, Records, Prescriptions, Labs, Admissions       ║';
PRINT '╚════════════════════════════════════════════════════════════════╝';
PRINT '';

-- ============================================
-- TABLE 6: Appointments (Lịch hẹn)
-- ============================================

PRINT 'Creating table: Appointments...';

IF OBJECT_ID('dbo.Appointments', 'U') IS NOT NULL
BEGIN
    PRINT '  (already exists — skipping)';
END
ELSE
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

IF OBJECT_ID('dbo.MedicalRecords', 'U') IS NOT NULL
BEGIN
    PRINT '  (already exists — skipping)';
END
ELSE
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

PRINT 'Creating table: Prescriptions...';

IF OBJECT_ID('dbo.Prescriptions', 'U') IS NOT NULL
BEGIN
    PRINT '  (already exists — skipping)';
END
ELSE
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
    CONSTRAINT CHK_Prescriptions_Cost CHECK (TotalCost >= 0),
    CONSTRAINT CHK_Prescriptions_Dates CHECK (EndDate IS NULL OR EndDate >= StartDate)
);
GO

PRINT '  ✓ Prescriptions created';

-- ============================================
-- TABLE 9: PrescriptionDetails (Chi tiết đơn thuốc)
-- ============================================

PRINT 'Creating table: PrescriptionDetails...';

IF OBJECT_ID('dbo.PrescriptionDetails', 'U') IS NOT NULL
BEGIN
    PRINT '  (already exists — skipping)';
END
ELSE
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

IF OBJECT_ID('dbo.LabTests', 'U') IS NOT NULL
BEGIN
    PRINT '  (already exists — skipping)';
END
ELSE
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

PRINT 'Creating table: Admissions...';

IF OBJECT_ID('dbo.Admissions', 'U') IS NOT NULL
BEGIN
    PRINT '  (already exists — skipping)';
END
ELSE
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

PRINT '';
PRINT '✓ Clinical tables created (6 tables)';
GO
