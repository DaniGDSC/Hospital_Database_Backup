-- Weekly PHI Access Report for HIPAA Compliance
-- HIPAA 45 CFR 164.312(b) + 164.530(j)
-- WHO accessed WHAT PHI, WHEN, and from WHERE
-- Flags: after-hours access, DELETE operations, access spikes
USE HospitalBackupDemo;
GO

SET NOCOUNT ON;

IF OBJECT_ID('dbo.usp_PHIAccessReport', 'P') IS NOT NULL
    DROP PROCEDURE dbo.usp_PHIAccessReport;
GO

CREATE PROCEDURE dbo.usp_PHIAccessReport
    @StartDate DATETIME2 = NULL,
    @EndDate   DATETIME2 = NULL
AS
BEGIN
    SET NOCOUNT ON;

    -- Default to last 7 days
    SET @StartDate = ISNULL(@StartDate, DATEADD(DAY, -7, SYSDATETIME()));
    SET @EndDate   = ISNULL(@EndDate, SYSDATETIME());

    PRINT '╔════════════════════════════════════════════════════════════════╗';
    PRINT '║              Weekly PHI Access Report                           ║';
    PRINT '╚════════════════════════════════════════════════════════════════╝';
    PRINT '';
    PRINT 'Period: ' + CONVERT(NVARCHAR(20), @StartDate, 120)
        + ' to ' + CONVERT(NVARCHAR(20), @EndDate, 120);
    PRINT '';

    -- ============================================
    -- Section 1: PHI Access Summary by Table
    -- ============================================
    PRINT '--- Section 1: PHI Access Summary ---';

    SELECT
        TableName,
        Action,
        COUNT(*) AS AccessCount,
        COUNT(DISTINCT UserName) AS UniqueUsers
    FROM dbo.AuditLog
    WHERE ActionType = 'PHI_ACCESS'
      AND AuditDate BETWEEN @StartDate AND @EndDate
    GROUP BY TableName, Action
    ORDER BY TableName, Action;

    -- ============================================
    -- Section 2: Top 20 Users by PHI Access
    -- ============================================
    PRINT '';
    PRINT '--- Section 2: Top Users by PHI Access ---';

    SELECT TOP 20
        UserName,
        DatabaseUser,
        COUNT(*) AS TotalAccesses,
        SUM(CASE WHEN Action = 'DELETE' THEN 1 ELSE 0 END) AS Deletes,
        SUM(CASE WHEN Severity IN ('High', 'Critical') THEN 1 ELSE 0 END) AS HighSevEvents,
        MIN(AuditDate) AS FirstAccess,
        MAX(AuditDate) AS LastAccess
    FROM dbo.AuditLog
    WHERE ActionType = 'PHI_ACCESS'
      AND AuditDate BETWEEN @StartDate AND @EndDate
    GROUP BY UserName, DatabaseUser
    ORDER BY TotalAccesses DESC;

    -- ============================================
    -- Section 3: After-Hours PHI Access (07:00-19:00 = business hours)
    -- ============================================
    PRINT '';
    PRINT '--- Section 3: After-Hours PHI Access (outside 07:00-19:00) ---';

    SELECT
        UserName,
        TableName,
        Action,
        AuditDate,
        IPAddress,
        HostName,
        Severity
    FROM dbo.AuditLog
    WHERE ActionType = 'PHI_ACCESS'
      AND (DATEPART(HOUR, AuditDate) < 7 OR DATEPART(HOUR, AuditDate) >= 19)
      AND AuditDate BETWEEN @StartDate AND @EndDate
    ORDER BY AuditDate DESC;

    -- ============================================
    -- Section 4: High-Severity Events (DELETEs, Critical)
    -- ============================================
    PRINT '';
    PRINT '--- Section 4: High-Severity PHI Events ---';

    SELECT
        AuditDate,
        UserName,
        TableName,
        Action,
        Severity,
        IPAddress,
        Notes
    FROM dbo.AuditLog
    WHERE ActionType = 'PHI_ACCESS'
      AND (Severity IN ('High', 'Critical') OR Action = 'DELETE')
      AND AuditDate BETWEEN @StartDate AND @EndDate
    ORDER BY AuditDate DESC;

    -- ============================================
    -- Section 5: NationalID Masking Verification
    -- ============================================
    PRINT '';
    PRINT '--- Section 5: NationalID Masking Audit ---';

    DECLARE @UnmaskedCount INT;
    SELECT @UnmaskedCount = COUNT(*)
    FROM dbo.AuditLog
    WHERE TableName = 'Patients'
      AND ActionType = 'PHI_ACCESS'
      AND AuditDate BETWEEN @StartDate AND @EndDate
      AND (CAST(NewValues AS NVARCHAR(MAX)) LIKE '%NationalID=%'
           OR CAST(OldValues AS NVARCHAR(MAX)) LIKE '%NationalID=%')
      AND CAST(NewValues AS NVARCHAR(MAX)) NOT LIKE '%NationalID_Masked%'
      AND CAST(OldValues AS NVARCHAR(MAX)) NOT LIKE '%NationalID_Masked%';

    IF @UnmaskedCount = 0
        PRINT '  ✓ CLEAN: No unmasked NationalID values found in audit logs';
    ELSE
        PRINT '  ✗ ALERT: ' + CAST(@UnmaskedCount AS NVARCHAR)
            + ' audit entries with unmasked NationalID!';

    -- ============================================
    -- Section 6: Daily Access Trend
    -- ============================================
    PRINT '';
    PRINT '--- Section 6: Daily PHI Access Trend ---';

    SELECT
        CAST(AuditDate AS DATE) AS AccessDate,
        TableName,
        COUNT(*) AS DailyCount,
        COUNT(DISTINCT UserName) AS UniqueUsers
    FROM dbo.AuditLog
    WHERE ActionType = 'PHI_ACCESS'
      AND AuditDate BETWEEN @StartDate AND @EndDate
    GROUP BY CAST(AuditDate AS DATE), TableName
    ORDER BY AccessDate DESC, TableName;

    PRINT '';
    PRINT '✓ PHI Access Report complete';
END;
GO

PRINT '✓ Stored procedure usp_PHIAccessReport created';
PRINT '  Usage: EXEC dbo.usp_PHIAccessReport;';
PRINT '  Custom: EXEC dbo.usp_PHIAccessReport @StartDate=''2026-03-01'', @EndDate=''2026-03-19'';';
GO
