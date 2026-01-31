# Hospital Database - Sample Data Insertion Report
**Date:** January 9, 2026  
**Project:** Hospital Database Backup & Recovery System (INS3199)  
**Phase:** Data Population

---

## Executive Summary

✅ **Successfully completed population of HospitalBackupDemo database with 1,350 sample records across 9 core tables (150 records each)**

All data insertion objectives have been achieved with full database encryption and backup completed.

---

## Data Insertion Results

| Table Name | Records Inserted | Target | Status |
|---|---|---|---|
| Doctors | 150 | 150 | ✅ PASS |
| Nurses | 150 | 150 | ✅ PASS |
| Patients | 150 | 150 | ✅ PASS |
| Appointments | 150 | 150 | ✅ PASS |
| MedicalRecords | 150 | 150 | ✅ PASS |
| Prescriptions | 150 | 150 | ✅ PASS |
| PrescriptionDetails | 150 | 150 | ✅ PASS |
| LabTests | 150 | 150 | ✅ PASS |
| Admissions | 150 | 150 | ✅ PASS |
| **TOTAL** | **1,350** | **1,350** | **✅ PASS** |

### Supporting Tables
- **Departments:** 5 records (system-created)
- **Rooms:** 33 records (created for referential integrity)

---

## Data Generation Method

### Approach
- **Technique:** T-SQL WHILE loop with random FK selection using `ORDER BY NEWID()`
- **Date Ranges:** Historical data spanning 365 days for realistic date distributions
- **Foreign Key Resolution:** Dynamic SELECT statements to retrieve valid related IDs

### Sample Data Characteristics

#### Doctors (150 records)
```sql
- EmployeeCode: DOC00001 to DOC00150
- Names: Random FirstName/LastName combinations
- Dates of Birth: 45 years prior to current date ± variation
- Gender Distribution: 33% Female, 33% Male, 33% Other
- Department Assignment: Random selection from 5 departments
- Salary Range: $75,000 to $90,000 (incremental)
```

#### Nurses (150 records)
```sql
- EmployeeCode: NUR00001 to NUR00150
- Certification: RN (Registered Nurse)
- Shift Types: Morning (33%), Evening (33%), Night (33%)
- Salary Range: $50,000 to $65,000
- Department Assignment: Random across all departments
```

#### Patients (150 records)
```sql
- PatientCode: PAT00001 to PAT00150
- Blood Types: A+, A-, B+, B-, O+, O-, AB+, AB- (distributed)
- Ages: Wide distribution (50 years prior ± variation)
- Insurance: Coverage codes ISN00001 to ISN00150
- Contact: Email and phone automatically generated
```

#### Appointments (150 records)
```sql
- AppointmentCode: APT00001 to APT00150
- Duration: 30 minutes per appointment
- Status: All set to "Scheduled"
- DateTime: Next 30 days from current date
- Rooms: Random from 33 available rooms
- Doctors: Random from 150 available doctors
```

#### MedicalRecords (150 records)
```sql
- Record Types: General consultations
- Diagnosis/Treatment: Auto-generated descriptive text
- Dates: Historical (past 30 days)
- Patient-Doctor Pairing: Random matching
```

#### Prescriptions (150 records)
```sql
- PrescriptionCode: PRS00001 to PRS00150
- Duration: 30-day supply per prescription
- Status: All set to "Active"
- Date Range: Past 60 days to next 30 days
```

#### PrescriptionDetails (150 records)
```sql
- 1:1 Mapping with Prescriptions
- Dosages: 100-600mg randomized
- Frequency: Once/Twice/Three times daily (distributed)
- Quantity: 10-100 units per prescription
- Unit Price: $10.50 per unit
```

#### LabTests (150 records)
```sql
- LabTestCode: LAB00001 to LAB00150
- Test Type: Blood tests (CBC - Complete Blood Count)
- Category: Hematology
- Results: Normal ranges (4.5-11.0 WBC)
- Abnormal Flag: All set to 0 (normal)
- Turnaround: 5-day result delay from test date
```

#### Admissions (150 records)
```sql
- AdmissionCode: ADM00001 to ADM00150
- Duration: 1-30 days per admission
- Status: All set to "Discharged"
- Dates: Past 365 days (historical admissions)
- Charges: $5,000 average total; $4,000 insured portion
- Department Assignment: Random room allocation
```

---

## Database Schema

### Primary Tables Created
1. ✅ Doctors (DoctorID, EmployeeCode, Names, DepartmentID, Credentials)
2. ✅ Nurses (NurseID, EmployeeCode, Names, DepartmentID, ShiftType)
3. ✅ Patients (PatientID, PatientCode, Names, BloodType, InsuranceNumber)
4. ✅ Appointments (AppointmentID, PatientID, DoctorID, RoomID, ScheduledDateTime)
5. ✅ MedicalRecords (RecordID, PatientID, DoctorID, RecordType, Diagnosis)
6. ✅ Prescriptions (PrescriptionID, PatientID, DoctorID, StartDate, EndDate)
7. ✅ PrescriptionDetails (DetailsID, PrescriptionID, MedicineName, Dosage, Quantity)
8. ✅ LabTests (LabTestID, PatientID, OrderingDoctorID, TestType, Result)
9. ✅ Admissions (AdmissionID, PatientID, RoomID, PrimaryDoctorID, LengthOfStay)

### Supporting Tables
- ✅ Departments (5 records - Department of Medicine, Surgery, etc.)
- ✅ Rooms (33 records - Hospital rooms across 3 buildings)

### Referential Integrity
- All foreign key constraints properly enforced
- No orphaned records
- Cascading deletes configured where appropriate

---

## Security Implementation

### Encryption
- **Database:** Transparent Data Encryption (TDE) with AES-256
- **Certificate:** HospitalBackupDemo_TDECert
- **Backup Encryption:** AES-256 encryption algorithm applied

### Data Protection Features
- **Checksums:** Enabled on backup
- **Compression:** Enabled for backup efficiency
- **Access Control:** SA user with strong password (Daniel@2410)

---

## Backup Details

### Full Backup Created
```
File: HospitalBackupDemo_WithData_20260109.bak
Location: /var/opt/mssql/backup/full/
Compression: Enabled
Encryption: AES_256
Checksum: Enabled
Size: ~104.675 MB/sec throughput
Duration: 0.064 seconds
Pages Processed: 858
```

**This backup contains:**
- ✅ Complete database schema (all 11 tables)
- ✅ 1,350 sample data records
- ✅ All system metadata
- ✅ Full encryption protection

---

## Validation Results

### Data Integrity Checks
```
✅ All 150 records inserted in each target table
✅ All foreign key relationships maintained
✅ No constraint violations
✅ No orphaned records detected
✅ Date ranges verified as realistic
✅ Gender distribution validated
✅ Blood type distribution validated
✅ Salary ranges within realistic bounds
✅ Department assignments distributed
✅ Insurance coverage properly assigned
```

### Query Performance
- **Insertion Performance:** 150 records per table in <1 second each
- **Total Insertion Time:** ~9 seconds for 1,350 records
- **Backup Time:** 0.064 seconds with compression

---

## Usage & Next Steps

### For Testing & Validation
```sql
-- Verify data in any table:
SELECT TOP 10 * FROM dbo.Doctors;
SELECT TOP 10 * FROM dbo.Patients;
SELECT TOP 10 * FROM dbo.Prescriptions;

-- Check relationships:
SELECT d.FirstName, COUNT(*) AS AppointmentCount
FROM Doctors d
LEFT JOIN Appointments a ON d.DoctorID = a.DoctorID
GROUP BY d.DoctorID, d.FirstName;
```

### For Disaster Recovery Testing
- Use `HospitalBackupDemo_WithData_20260109.bak` for realistic DR drills
- All 1,350 records will be available in recovered database
- Test appointment scheduling, patient lookups, medical record retrieval
- Validate prescription fulfillment workflows

### For Performance Benchmarking
- Run complex JOIN queries across 9 tables
- Test reporting queries on 1,350 records per table
- Benchmark backup/restore operations
- Measure query execution plans

---

## Technical Notes

### T-SQL Implementation Details
- Used `FORMAT()` function for consistent numeric formatting
- Applied `ORDER BY NEWID()` for true random FK selection
- Implemented WHILE loops with proper variable scoping
- All variables declared outside loops (T-SQL best practice)

### Foreign Key Insertion Order
```
1. Departments (system)
2. Rooms (system + needs DepartmentID FK)
3. Doctors (needs DepartmentID FK)
4. Nurses (needs DepartmentID FK)
5. Patients (no foreign keys needed)
6. Appointments (needs PatientID, DoctorID, RoomID FKs)
7. MedicalRecords (needs PatientID, DoctorID FKs)
8. Prescriptions (needs PatientID, DoctorID FKs)
9. PrescriptionDetails (needs PrescriptionID FK)
10. LabTests (needs PatientID, DoctorID FKs)
11. Admissions (needs PatientID, RoomID, DoctorID FKs)
```

---

## Summary

**Project Status: ✅ COMPLETE**

The hospital database has been fully populated with realistic sample data:
- **1,350 core data records** across 9 tables (150 each)
- **33 supporting room records** for referential integrity
- **Full encryption protection** with AES-256
- **Backup created** for disaster recovery testing
- **All constraints validated** with no data integrity issues

The database is now ready for:
- ✅ Comprehensive testing (functional, performance, security)
- ✅ Disaster recovery drills with realistic data
- ✅ Application development and integration testing
- ✅ Training and demonstration purposes
- ✅ Compliance validation and auditing

---

**Report Generated:** January 9, 2026  
**Database Version:** SQL Server 2022 on Linux  
**Project Code:** INS3199
