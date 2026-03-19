-- Billing tables: Billing, BillingDetails, Payments
-- Dependencies: 02b_create_clinical_tables.sql must be run first

SET QUOTED_IDENTIFIER ON;
GO

USE HospitalBackupDemo;
GO

PRINT '╔════════════════════════════════════════════════════════════════╗';
PRINT '║   Phase 1.2c: Billing Tables                                   ║';
PRINT '║   Billing, BillingDetails, Payments                            ║';
PRINT '╚════════════════════════════════════════════════════════════════╝';
PRINT '';

-- ============================================
-- TABLE 12: Billing (Hóa đơn)
-- ============================================

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

PRINT '';
PRINT '✓ Billing tables created (3 tables)';
GO
