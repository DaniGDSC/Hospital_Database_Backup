-- Core entity tables: Departments, Doctors, Nurses, Patients, Rooms
-- Dependencies: 01_create_database.sql must be run first

SET QUOTED_IDENTIFIER ON;
GO

USE HospitalBackupDemo;
GO

PRINT '╔════════════════════════════════════════════════════════════════╗';
PRINT '║   Phase 1.2a: Core Tables                                      ║';
PRINT '║   Departments, Doctors, Nurses, Patients, Rooms                ║';
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

PRINT '';
PRINT '✓ Core tables created (5 tables)';
GO
