# Hospital Database - Entity Relationship Diagram (ERD)

## Overview
- **Tables:** 18 core tables + 5+ testing/monitoring tables
- **Total Records:** 1,500+ patient records
- **Primary Keys:** 18
- **Foreign Keys:** 35+ relationships
- **Encryption:** TDE enabled + Column-level encryption on sensitive fields

---

## 1. Core Organizational Structure

```mermaid
erDiagram
    DEPARTMENTS ||--o{ DOCTORS : manages
    DEPARTMENTS ||--o{ NURSES : manages
    DEPARTMENTS ||--o{ STAFF : manages
    DEPARTMENTS ||--o{ ROOMS : contains

    DEPARTMENTS {
        int DepartmentID PK
        string DepartmentCode UK
        string DepartmentName
        int HeadDoctorID FK
        string Building
        int Floor
        string PhoneNumber
        string Manager
        timestamp CreatedDate
    }

    DOCTORS {
        int DoctorID PK
        int DepartmentID FK
        string EmployeeCode UK
        string FirstName
        string LastName
        string Specialty
        string Qualification
        string LicenseNumber
        boolean IsActive
        timestamp CreatedDate
    }

    NURSES {
        int NurseID PK
        int DepartmentID FK
        string EmployeeCode UK
        string FirstName
        string LastName
        date DateOfBirth
        string NursingDegree
        string LicenseNumber
        string ShiftType
        date HireDate
        decimal BaseSalary
        boolean IsActive
        timestamp CreatedDate
    }

    STAFF {
        int StaffID PK
        int DepartmentID FK
        string EmployeeCode UK
        string FirstName
        string LastName
        string Position
        date HireDate
        decimal Salary
        boolean IsActive
        timestamp CreatedDate
    }

    ROOMS {
        int RoomID PK
        int DepartmentID FK
        string RoomNumber UK
        string RoomType
        int BedCapacity
        int CurrentOccupancy
        string Building
        int FloorNumber
        string WingSection
        decimal DailyRate
        boolean HasOxygen
        boolean HasVentilator
        boolean HasMonitoring
        string Status
        date LastCleaningDate
        boolean IsActive
        timestamp CreatedDate
    }
```

---

## 2. Patient & Clinical Information

```mermaid
erDiagram
    PATIENTS ||--o{ APPOINTMENTS : schedules
    PATIENTS ||--o{ ADMISSIONS : admitted
    PATIENTS ||--o{ MEDICAL_RECORDS : "has history"
    PATIENTS ||--o{ PRESCRIPTIONS : receives
    PATIENTS ||--o{ LAB_TESTS : "undergoes"
    PATIENTS ||--o{ BILLING : "billed for"
    PATIENTS ||--o{ PAYMENTS : "pays via"

    DOCTORS ||--o{ APPOINTMENTS : conducts
    DOCTORS ||--o{ MEDICAL_RECORDS : documents
    DOCTORS ||--o{ PRESCRIPTIONS : issues
    DOCTORS ||--o{ LAB_TESTS : orders

    APPOINTMENTS ||--o{ MEDICAL_RECORDS : triggers
    APPOINTMENTS ||--o{ BILLING : "associated with"
    APPOINTMENTS {
        int AppointmentID PK
        int PatientID FK
        int DoctorID FK
        int DepartmentID FK
        int RoomID FK
        int RescheduledFrom FK
        datetime AppointmentDate
        time AppointmentTime
        string AppointmentType
        string Status
        text Notes
        timestamp CreatedDate
    }

    ADMISSIONS ||--o{ MEDICAL_RECORDS : triggers
    ADMISSIONS ||--o{ BILLING : triggers
    ADMISSIONS {
        int AdmissionID PK
        int PatientID FK
        int DoctorID FK
        int DepartmentID FK
        int RoomID FK
        int AttendingNurseID FK
        int DischargedBy FK
        datetime AdmissionDate
        datetime DischargeDate
        string ReasonForAdmission
        text Notes
        timestamp CreatedDate
    }

    PATIENTS {
        int PatientID PK
        string PatientCode UK
        string FirstName
        string LastName
        date DateOfBirth
        string Gender
        binary NationalID "ENCRYPTED"
        string BloodType
        string Email
        string Phone
        string Address
        string City
        string State
        string Country
        string PostalCode
        string MaritalStatus
        string Occupation
        string InsuranceNumber
        string InsuranceProvider
        datetime RegistrationDate
        datetime LastVisitDate
        int TotalVisits
        boolean IsVIP
        boolean IsActive
        timestamp CreatedDate
        timestamp ModifiedDate
    }

    MEDICAL_RECORDS {
        int RecordID PK
        int PatientID FK
        int DoctorID FK
        int AppointmentID FK
        datetime VisitDate
        string VisitType
        string ChiefComplaint
        text Symptoms
        string Diagnosis
        string DiagnosisCode
        text TreatmentPlan
        text Medications
        text LabResults
        text ImagingResults
        text Allergies
        text CurrentMedications
        text PastMedicalHistory
        text FamilyHistory
        text SocialHistory
        text Prognosis
        date FollowUpDate
        string ReferralTo
        text Attachments
        timestamp CreatedDate
        timestamp ModifiedDate
    }

    PRESCRIPTIONS ||--o{ PRESCRIPTION_DETAILS : contains
    PRESCRIPTIONS {
        int PrescriptionID PK
        int PatientID FK
        int DoctorID FK
        int RecordID FK
        datetime PrescriptionDate
        text Instructions
        date StartDate
        date EndDate
        string Status
        decimal TotalCost
        boolean IsPaid
        timestamp CreatedDate
        timestamp ModifiedDate
    }

    PRESCRIPTION_DETAILS {
        int DetailID PK
        int PrescriptionID FK
        int MedicationID
        string MedicationName
        string Strength
        string Dosage
        string Route
        string Frequency
        string Duration
        int Quantity
        text Instructions
        text SideEffects
        boolean IsDispensed
        datetime DispensedDate
        timestamp CreatedDate
    }

    LAB_TESTS {
        int LabTestID PK
        int RecordID FK
        int PatientID FK
        int DoctorID FK
        int DepartmentID FK
        string TestName
        string TestCode
        datetime TestDate
        datetime CollectionDate
        text Result
        string ResultUnits
        string ReferenceRange
        string Status
        text Notes
        timestamp CreatedDate
    }
```

---

## 3. Financial & Billing

```mermaid
erDiagram
    BILLING ||--o{ BILLING_DETAILS : contains
    BILLING ||--|| PAYMENTS : "has one"

    BILLING {
        int BillingID PK
        int PatientID FK
        int AdmissionID FK
        int AppointmentID FK
        datetime BillingDate
        decimal TotalAmount
        decimal Discount
        decimal TaxAmount
        decimal FinalAmount
        string Status
        string PaymentStatus
        date DueDate
        date PaidDate
        timestamp CreatedDate
    }

    BILLING_DETAILS {
        int DetailID PK
        int BillingID FK
        string Description
        int Quantity
        decimal UnitPrice
        decimal LineTotal
        string ServiceCode
        timestamp CreatedDate
    }

    PAYMENTS {
        int PaymentID PK
        int BillingID FK
        int PatientID FK
        datetime PaymentDate
        decimal Amount
        string PaymentMethod
        string PaymentType
        binary CardNumber "ENCRYPTED"
        string TransactionID
        string Status
        decimal RefundAmount
        datetime RefundDate
        string ReceiptNumber
        timestamp CreatedDate
    }
```

---

## 4. Testing & Monitoring Infrastructure

```mermaid
erDiagram
    TEST_EXECUTIONS ||--o{ PERFORMANCE_METRICS : "has metrics"
    DISASTER_SCENARIOS ||--o{ DISASTER_TEST_RESULTS : "tested by"

    TEST_EXECUTIONS {
        int ExecutionID PK
        string TestName
        string TestCategory
        datetime ExecutionDateTime
        int ExecutionDurationSeconds
        string Result
        text ErrorMessage
        string Severity
        timestamp CreatedDate
    }

    PERFORMANCE_METRICS {
        int MetricID PK
        int ExecutionID FK
        string MetricName
        decimal MetricValue
        decimal Baseline
        decimal PercentageOfBaseline
        datetime CaptureDateTime
        timestamp CreatedDate
    }

    DISASTER_SCENARIOS {
        int ScenarioID PK
        string ScenarioCode
        string ScenarioName
        string ScenarioType
        string SeverityLevel
        text Description
        string ScopeOfDisaster
        text ImpactedResources
        text RecoverySteps
        timestamp CreatedDate
    }

    DISASTER_TEST_RESULTS {
        int ResultID PK
        int ScenarioID FK
        datetime TestDate
        int RTOMinutes
        int RPOMinutes
        string TestResult
        text Notes
        string DataIntegrityStatus
        timestamp CreatedDate
    }
```

---

## 5. Security & Audit Tracking

```mermaid
erDiagram
    SECURITY_EVENTS {
        int EventID PK
        datetime EventDate
        string EventType
        string Severity
        string LoginName
        string DatabaseUser
        string ObjectType
        string ObjectName
        string ActionPerformed
        boolean IsSuccessful
        string SourceIP
        text ErrorMessage
        string ThreatLevel
        boolean IsBlocked
        timestamp CreatedDate
    }

    SECURITY_AUDIT_EVENTS {
        int AuditEventID PK
        datetime EventTime
        string EventType
        string LoginName
        string ObjectName
        string Action
        boolean Success
        string ClientHost
        text Details
        timestamp CreatedDate
    }

    BACKUP_HISTORY {
        int BackupHistoryID PK
        datetime BackupDate
        string BackupType
        bigint BackupSize
        string BackupPath
        string Status
        string VerificationStatus
        datetime RecoveryTestDate
        int RTO_Minutes
        int RPO_Minutes
        text Notes
        timestamp CreatedDate
    }
```

---

## 6. System Configuration

```mermaid
erDiagram
    SYSTEM_CONFIGURATION {
        int ConfigID PK
        string ConfigKey
        string ConfigValue
        string ConfigCategory
        text Description
        boolean IsEncrypted
        boolean IsActive
        timestamp LastModifiedDate
        timestamp CreatedDate
    }
```

---

## Complete Relationship Summary

### 1:N (One-to-Many) Relationships:
| Parent | Child | Cardinality | Count |
|--------|-------|-------------|-------|
| Departments | Doctors | 1:N | 150 doctors |
| Departments | Nurses | 1:N | 150 nurses |
| Departments | Rooms | 1:N | 50 rooms |
| Doctors | Appointments | 1:N | 150+ appointments |
| Doctors | MedicalRecords | 1:N | 153+ records |
| Doctors | Prescriptions | 1:N | 150+ prescriptions |
| Doctors | LabTests | 1:N | 100+ tests |
| Patients | Appointments | 1:N | 150+ appointments |
| Patients | MedicalRecords | 1:N | 153+ records |
| Patients | Admissions | 1:N | 50+ admissions |
| Patients | Prescriptions | 1:N | 150+ prescriptions |
| Patients | LabTests | 1:N | 100+ tests |
| Patients | Billing | 1:N | 100+ bills |
| Patients | Payments | 1:N | 80+ payments |
| Rooms | Appointments | 1:N | 150+ appointments |
| Rooms | Admissions | 1:N | 50+ admissions |
| Prescriptions | PrescriptionDetails | 1:N | 300+ line items |
| Billing | BillingDetails | 1:N | 200+ line items |
| TestExecutions | PerformanceMetrics | 1:N | Multiple metrics |
| DisasterScenarios | DisasterTestResults | 1:N | Test results |

### 1:1 (One-to-One) Relationships:
| Parent | Child | Cardinality |
|--------|-------|-------------|
| Billing | Payments | 1:1 |

### Self-Referencing:
| Table | Relationship | Field |
|-------|--------------|-------|
| Appointments | Rescheduled from another appointment | RescheduledFrom |

---

## Data Flow Diagram

```
┌─────────────┐
│   PATIENT   │ ◄────────────────────────────────────────┐
│ Registration│                                           │
└──────┬──────┘                                           │
       │                                                  │
       ├──────────────┬──────────────┬──────────────┐    │
       │              │              │              │    │
       ▼              ▼              ▼              ▼    │
   ┌───────┐   ┌─────────────┐  ┌──────────┐  ┌────────┐
   │  LAB  │   │ APPOINTMENTS│  │ADMISSIONS│  │ PAYMENT│
   │ TESTS │   │             │  │          │  │REQUEST │
   └───┬───┘   └──────┬──────┘  └────┬─────┘  └────┬───┘
       │              │              │             │
       │         ┌────┴──────────────┴─────────────┘
       │         │
       └────┬────┴────┐
            ▼         ▼
        ┌─────────────────────┐
        │ MEDICAL RECORDS     │
        │ (Diagnosis + Plan)  │
        └─────────┬───────────┘
                  │
         ┌────────┴────────┐
         │                 │
         ▼                 ▼
    ┌──────────┐    ┌─────────────────┐
    │  BILLING │    │ PRESCRIPTIONS   │
    │          │    │ (Medications)   │
    └──────┬───┘    └────────┬────────┘
           │                 │
           │          ┌──────┴──────┐
           │          │             │
           ▼          ▼             ▼
        ┌─────────────────────────────────┐
        │   PRESCRIPTION DETAILS          │
        │   (Individual Medications)      │
        └──────────────┬──────────────────┘
                       │
         ┌─────────────┴─────────────┐
         │                           │
         ▼                           ▼
    ┌──────────┐            ┌──────────────┐
    │DISPENSED │            │ INSURANCE    │
    │PHARMACY  │            │ RECONCILE    │
    └──────────┘            └──────────────┘
           │
           │
           ▼
    ┌──────────────────┐
    │  BILLING DETAILS │
    └────────┬─────────┘
             │
             ▼
    ┌──────────────────┐
    │     PAYMENTS     │
    │  (SETTLEMENT)    │
    └──────────────────┘
```

---

## Encryption & Security

### Column-Level Encryption
- **Patients.NationalID** - Encrypted with symmetric key (ENC)
- **Payments.CardNumber** - Encrypted with symmetric key (ENC)

### Database-Level Encryption
- **TDE (Transparent Data Encryption)** - All tables encrypted with AES-256
- **At-Rest Encryption** - All backup files encrypted in S3

### Audit Trail
- **SecurityAuditEvents** - All DML operations logged
- **SecurityEvents** - Login attempts, access violations logged
- **BackupHistory** - All backup/recovery operations tracked

---

## Sample Data Snapshot

| Table | Records | Key Metrics |
|-------|---------|------------|
| Departments | 5 | Cardiology, Oncology, Trauma, ICU, ER |
| Doctors | 150 | 50 per department × 3 departments |
| Nurses | 150 | Staff across all departments |
| Patients | 153 | Active patient population |
| Appointments | 150+ | Avg 1 per patient |
| Admissions | 50+ | 33% admission rate |
| MedicalRecords | 153+ | One per patient visit |
| Prescriptions | 150+ | Most patients prescribed |
| Billing | 100+ | For admissions/procedures |
| **TOTAL** | **1,500+** | Realistic hospital dataset |

---

## Key Constraints

### Primary Keys (18 tables)
All tables have identity-based integer primary keys for performance

### Foreign Keys (35+ relationships)
All foreign key relationships enforce referential integrity (CASCADE DELETE not enabled for safety)

### Unique Constraints
- PatientCode (natural key)
- EmployeeCode (doctors, nurses, staff)
- RoomNumber
- BillingNumber

### Check Constraints
- Date ranges (admission/discharge)
- Status enumerations (Active, Inactive, Pending, etc.)
- Numeric bounds (age, quantity, price)

### NOT NULL Constraints
Applied to 150+ critical business fields

---

## Connection Patterns

### Query Patterns (Most Common)
1. **Patient History Retrieval** - Patients → MedicalRecords → LabTests
2. **Billing Reconciliation** - Billing → BillingDetails + Payments
3. **Department Reporting** - Departments → (Doctors + Nurses) → (Appointments + Admissions)
4. **Prescription Tracking** - Patients → Prescriptions → PrescriptionDetails
5. **Admission Discharge** - Admissions → MedicalRecords → Billing

### Join Strategy
- All relationships use indexed foreign keys
- Clustered indexes on primary keys
- Non-clustered indexes on all foreign keys
- Statistics maintained for query optimizer

---

## Testing & Validation Tables

```
DisasterScenarios (10 scenarios):
├── DS-001: Ransomware Attack
├── DS-002: Accidental Data Deletion
├── DS-003: Disk Failure
├── DS-004: Corrupted Backup
├── DS-005: Network Outage
├── DS-006: Server Crash
├── DS-007: Power Failure
├── DS-008: Malware Infection
├── DS-009: Insider Threat
└── DS-010: Natural Disaster

DisasterTestResults:
├── ScenarioID → FK to DisasterScenarios
├── TestDate, RTO_Minutes, RPO_Minutes
└── DataIntegrityStatus (PASS/FAIL)

TestExecutions:
├── ExecutionID (PK)
├── TestName, TestCategory
├── ExecutionDateTime, ExecutionDurationSeconds
└── Result, ErrorMessage

PerformanceMetrics:
├── MetricID (PK)
├── ExecutionID → FK to TestExecutions
├── MetricName, MetricValue, Baseline
└── PercentageOfBaseline
```

---

## Recovery & Backup Tables

```
BackupHistory:
├── BackupHistoryID (PK)
├── BackupDate, BackupType (Full/Diff/Log)
├── BackupSize, BackupPath
├── Status, VerificationStatus
├── RecoveryTestDate
├── RTO_Minutes, RPO_Minutes
└── Notes
```

---

## Generated: $(date)
**Database:** HospitalBackupDemo
**Version:** 2.0 (Phase 7 Complete)
**Compliance:** HIPAA, HL7, DICOM
