-- HL7 FHIR R4 mapping views
-- Category 1.1 Item 1: FHIR Schema Compliance
-- Maps hospital tables to FHIR resource structure
-- Enables future FHIR REST API without schema change
USE HospitalBackupDemo;
GO

SET NOCOUNT ON;

PRINT '--- Creating FHIR mapping views ---';

-- ============================================
-- FHIR Patient (from Patients)
-- https://hl7.org/fhir/R4/patient.html
-- ============================================

IF OBJECT_ID('dbo.vw_FHIR_Patient', 'V') IS NOT NULL
    DROP VIEW dbo.vw_FHIR_Patient;
GO

CREATE VIEW dbo.vw_FHIR_Patient AS
SELECT
    FhirResourceId              AS [id],
    FhirResourceType            AS [resourceType],
    PatientCode                 AS [identifier_value],
    'MR'                        AS [identifier_type],
    FirstName                   AS [name_given],
    LastName                    AS [name_family],
    FullName                    AS [name_text],
    DateOfBirth                 AS [birthDate],
    CASE Gender
        WHEN 'M' THEN 'male'
        WHEN 'F' THEN 'female'
        ELSE 'other'
    END                         AS [gender],
    Phone                       AS [telecom_phone],
    Email                       AS [telecom_email],
    Address                     AS [address_line],
    City                        AS [address_city],
    State                       AS [address_state],
    Country                     AS [address_country],
    PostalCode                  AS [address_postalCode],
    CASE WHEN IsActive = 1 AND IsDeleted = 0
         THEN 'true' ELSE 'false'
    END                         AS [active],
    InsuranceNumber             AS [identifier_insurance],
    InsuranceProvider           AS [insurance_display],
    MaritalStatus               AS [maritalStatus],
    FhirLastUpdated             AS [meta_lastUpdated],
    PatientID                   AS [_internalId]
FROM dbo.Patients
WHERE IsDeleted = 0;
GO

PRINT '  ✓ vw_FHIR_Patient';

-- ============================================
-- FHIR Condition (from MedicalRecords)
-- https://hl7.org/fhir/R4/condition.html
-- ============================================

IF OBJECT_ID('dbo.vw_FHIR_Condition', 'V') IS NOT NULL
    DROP VIEW dbo.vw_FHIR_Condition;
GO

CREATE VIEW dbo.vw_FHIR_Condition AS
SELECT
    mr.FhirResourceId           AS [id],
    mr.FhirResourceType         AS [resourceType],
    mr.RecordNumber              AS [identifier_value],
    p.FhirResourceId            AS [subject_reference],
    d.FullName                  AS [recorder_display],
    mr.VisitDate                AS [recordedDate],
    mr.Diagnosis                AS [code_text],
    mr.DiagnosisCode            AS [code_coding_code],
    'ICD-10'                    AS [code_coding_system],
    CASE mr.VisitType
        WHEN 'Emergency' THEN 'active'
        ELSE 'resolved'
    END                         AS [clinicalStatus],
    mr.Prognosis                AS [note],
    mr.FhirLastUpdated          AS [meta_lastUpdated],
    mr.RecordID                 AS [_internalId]
FROM dbo.MedicalRecords mr
JOIN dbo.Patients p ON mr.PatientID = p.PatientID
JOIN dbo.Doctors d ON mr.DoctorID = d.DoctorID
WHERE mr.IsDeleted = 0;
GO

PRINT '  ✓ vw_FHIR_Condition';

-- ============================================
-- FHIR MedicationRequest (from Prescriptions)
-- https://hl7.org/fhir/R4/medicationrequest.html
-- ============================================

IF OBJECT_ID('dbo.vw_FHIR_MedicationRequest', 'V') IS NOT NULL
    DROP VIEW dbo.vw_FHIR_MedicationRequest;
GO

CREATE VIEW dbo.vw_FHIR_MedicationRequest AS
SELECT
    rx.FhirResourceId           AS [id],
    rx.FhirResourceType         AS [resourceType],
    rx.PrescriptionNumber       AS [identifier_value],
    p.FhirResourceId            AS [subject_reference],
    d.FullName                  AS [requester_display],
    rx.PrescriptionDate         AS [authoredOn],
    CASE rx.Status
        WHEN 'Active'    THEN 'active'
        WHEN 'Completed' THEN 'completed'
        WHEN 'Cancelled' THEN 'cancelled'
        ELSE 'unknown'
    END                         AS [status],
    rx.Instructions             AS [dosageInstruction_text],
    rx.StartDate                AS [dispenseRequest_validityPeriod_start],
    rx.EndDate                  AS [dispenseRequest_validityPeriod_end],
    rx.RefillsAllowed           AS [dispenseRequest_numberOfRepeatsAllowed],
    rx.FhirLastUpdated          AS [meta_lastUpdated],
    rx.PrescriptionID           AS [_internalId]
FROM dbo.Prescriptions rx
JOIN dbo.Patients p ON rx.PatientID = p.PatientID
JOIN dbo.Doctors d ON rx.DoctorID = d.DoctorID
WHERE rx.IsDeleted = 0;
GO

PRINT '  ✓ vw_FHIR_MedicationRequest';

-- ============================================
-- FHIR DiagnosticReport (from LabTests)
-- https://hl7.org/fhir/R4/diagnosticreport.html
-- ============================================

IF OBJECT_ID('dbo.vw_FHIR_DiagnosticReport', 'V') IS NOT NULL
    DROP VIEW dbo.vw_FHIR_DiagnosticReport;
GO

CREATE VIEW dbo.vw_FHIR_DiagnosticReport AS
SELECT
    lt.FhirResourceId           AS [id],
    lt.FhirResourceType         AS [resourceType],
    lt.TestNumber               AS [identifier_value],
    p.FhirResourceId            AS [subject_reference],
    d.FullName                  AS [performer_display],
    lt.OrderDate                AS [effectiveDateTime],
    lt.ResultDate               AS [issued],
    lt.TestName                 AS [code_text],
    lt.TestCode                 AS [code_coding_code],
    lt.TestCategory             AS [category_text],
    CASE lt.Status
        WHEN 'Completed' THEN 'final'
        WHEN 'In Progress' THEN 'preliminary'
        WHEN 'Cancelled' THEN 'cancelled'
        ELSE 'registered'
    END                         AS [status],
    lt.ResultValue              AS [result_value],
    lt.ResultUnit               AS [result_unit],
    lt.NormalRange              AS [result_referenceRange],
    lt.IsAbnormal               AS [result_interpretation_abnormal],
    lt.Interpretation           AS [conclusion],
    lt.FhirLastUpdated          AS [meta_lastUpdated],
    lt.LabTestID                AS [_internalId]
FROM dbo.LabTests lt
JOIN dbo.Patients p ON lt.PatientID = p.PatientID
JOIN dbo.Doctors d ON lt.DoctorID = d.DoctorID
WHERE lt.IsDeleted = 0;
GO

PRINT '  ✓ vw_FHIR_DiagnosticReport';

-- ============================================
-- FHIR Encounter (from Admissions)
-- https://hl7.org/fhir/R4/encounter.html
-- ============================================

IF OBJECT_ID('dbo.vw_FHIR_Encounter', 'V') IS NOT NULL
    DROP VIEW dbo.vw_FHIR_Encounter;
GO

CREATE VIEW dbo.vw_FHIR_Encounter AS
SELECT
    a.FhirResourceId            AS [id],
    a.FhirResourceType          AS [resourceType],
    a.AdmissionNumber           AS [identifier_value],
    p.FhirResourceId            AS [subject_reference],
    d.FullName                  AS [participant_display],
    dep.DepartmentName          AS [serviceProvider_display],
    CASE a.Status
        WHEN 'Active'      THEN 'in-progress'
        WHEN 'Discharged'  THEN 'finished'
        WHEN 'Transferred' THEN 'finished'
        WHEN 'Deceased'    THEN 'finished'
        ELSE 'planned'
    END                         AS [status],
    CASE a.AdmissionType
        WHEN 'Emergency' THEN 'emergency'
        WHEN 'Elective'  THEN 'elective'
        ELSE 'other'
    END                         AS [class],
    a.AdmissionDate             AS [period_start],
    a.DischargeDate             AS [period_end],
    a.AdmissionReason           AS [reasonCode_text],
    a.FinalDiagnosis            AS [diagnosis_text],
    a.FhirLastUpdated           AS [meta_lastUpdated],
    a.AdmissionID               AS [_internalId]
FROM dbo.Admissions a
JOIN dbo.Patients p ON a.PatientID = p.PatientID
JOIN dbo.Doctors d ON a.DoctorID = d.DoctorID
JOIN dbo.Departments dep ON a.DepartmentID = dep.DepartmentID
WHERE a.IsDeleted = 0;
GO

PRINT '  ✓ vw_FHIR_Encounter';

PRINT '';
PRINT '✓ 5 FHIR mapping views created';
PRINT '  vw_FHIR_Patient, vw_FHIR_Condition, vw_FHIR_MedicationRequest,';
PRINT '  vw_FHIR_DiagnosticReport, vw_FHIR_Encounter';
GO
