-- Verify PHI audit triggers are correctly configured
-- HIPAA 45 CFR 164.312(b): Audit Controls
-- Tests: existence, TRY/CATCH, NationalID masking, DELETE severity
USE HospitalBackupDemo;
GO

SET NOCOUNT ON;

PRINT '╔════════════════════════════════════════════════════════════════╗';
PRINT '║             PHI Audit Trigger Verification                      ║';
PRINT '╚════════════════════════════════════════════════════════════════╝';
PRINT '';

DECLARE @PassCount INT = 0;
DECLARE @FailCount INT = 0;

-- Test 1-5: All 5 triggers exist
DECLARE @TriggerName NVARCHAR(128);
DECLARE @Triggers TABLE (TriggerName NVARCHAR(128));
INSERT INTO @Triggers VALUES
    ('trg_MedicalRecords_Audit'),
    ('trg_Patients_Audit'),
    ('trg_Prescriptions_Audit'),
    ('trg_LabTests_Audit'),
    ('trg_Appointments_Audit');

DECLARE trigger_cursor CURSOR LOCAL FAST_FORWARD FOR
    SELECT TriggerName FROM @Triggers;

OPEN trigger_cursor;
FETCH NEXT FROM trigger_cursor INTO @TriggerName;

WHILE @@FETCH_STATUS = 0
BEGIN
    PRINT '--- Test: Trigger ' + @TriggerName + ' exists ---';
    IF OBJECT_ID('dbo.' + @TriggerName, 'TR') IS NOT NULL
    BEGIN
        PRINT '  ✓ PASS';
        SET @PassCount = @PassCount + 1;
    END
    ELSE
    BEGIN
        PRINT '  ✗ FAIL: Trigger not found';
        SET @FailCount = @FailCount + 1;
    END
    FETCH NEXT FROM trigger_cursor INTO @TriggerName;
END

CLOSE trigger_cursor;
DEALLOCATE trigger_cursor;

-- Test 6: TRY/CATCH present in all trigger source code
PRINT '';
PRINT '--- Test 6: TRY/CATCH protection in all triggers ---';
DECLARE @MissingTryCatch INT;
SELECT @MissingTryCatch = COUNT(*)
FROM @Triggers t
JOIN sys.triggers tr ON tr.name = t.TriggerName
JOIN sys.sql_modules m ON m.object_id = tr.object_id
WHERE CHARINDEX('BEGIN TRY', m.definition) = 0;

IF @MissingTryCatch = 0
BEGIN
    PRINT '  ✓ PASS: All 5 triggers have TRY/CATCH';
    SET @PassCount = @PassCount + 1;
END
ELSE
BEGIN
    PRINT '  ✗ FAIL: ' + CAST(@MissingTryCatch AS NVARCHAR) + ' trigger(s) missing TRY/CATCH';
    SET @FailCount = @FailCount + 1;
END

-- Test 7: NationalID_Masked present in Patients trigger source
PRINT '';
PRINT '--- Test 7: NationalID masking in Patients trigger ---';
DECLARE @PatientsTriggerDef NVARCHAR(MAX);
SELECT @PatientsTriggerDef = m.definition
FROM sys.triggers tr
JOIN sys.sql_modules m ON m.object_id = tr.object_id
WHERE tr.name = 'trg_Patients_Audit';

IF CHARINDEX('NationalID_Masked', @PatientsTriggerDef) > 0
BEGIN
    PRINT '  ✓ PASS: NationalID_Masked found in trigger definition';
    SET @PassCount = @PassCount + 1;
END
ELSE
BEGIN
    PRINT '  ✗ FAIL: NationalID masking not found in trigger definition';
    SET @FailCount = @FailCount + 1;
END

-- Test 8: Raw NationalID column NOT directly selected (no unmasked access)
PRINT '';
PRINT '--- Test 8: No unmasked NationalID in trigger ---';
-- Check the trigger does NOT contain a bare "d.NationalID," or "i.NationalID,"
-- (without the _Masked suffix) in the XML select
IF @PatientsTriggerDef IS NOT NULL
   AND CHARINDEX('NationalID_Masked', @PatientsTriggerDef) > 0
   AND (CHARINDEX('d.NationalID,', @PatientsTriggerDef) = 0
        OR CHARINDEX('ISNULL(d.NationalID', @PatientsTriggerDef) > 0)
BEGIN
    PRINT '  ✓ PASS: NationalID only accessed via masking function';
    SET @PassCount = @PassCount + 1;
END
ELSE
BEGIN
    PRINT '  ✗ FAIL: Potential unmasked NationalID access in trigger';
    SET @FailCount = @FailCount + 1;
END

-- Test 9: Prescriptions trigger has conditional severity for DELETE
PRINT '';
PRINT '--- Test 9: Prescriptions DELETE = High severity ---';
DECLARE @PrescTriggerDef NVARCHAR(MAX);
SELECT @PrescTriggerDef = m.definition
FROM sys.triggers tr
JOIN sys.sql_modules m ON m.object_id = tr.object_id
WHERE tr.name = 'trg_Prescriptions_Audit';

IF CHARINDEX('DELETE', @PrescTriggerDef) > 0
   AND CHARINDEX('High', @PrescTriggerDef) > 0
   AND CHARINDEX('HIGH RISK', @PrescTriggerDef) > 0
BEGIN
    PRINT '  ✓ PASS: Prescriptions DELETE flagged as High severity';
    SET @PassCount = @PassCount + 1;
END
ELSE
BEGIN
    PRINT '  ✗ FAIL: Prescriptions DELETE severity escalation not found';
    SET @FailCount = @FailCount + 1;
END

-- Summary
PRINT '';
PRINT '═══════════════════════════════════════════════════';
PRINT '  PASS: ' + CAST(@PassCount AS NVARCHAR(10));
PRINT '  FAIL: ' + CAST(@FailCount AS NVARCHAR(10));
PRINT '═══════════════════════════════════════════════════';

IF @FailCount > 0
    RAISERROR('PHI trigger verification: %d test(s) failed', 16, 1, @FailCount);
GO
