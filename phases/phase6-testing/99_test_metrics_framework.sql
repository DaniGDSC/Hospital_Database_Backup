-- Phase 6: Test Execution Metrics & Results Tracking
-- Purpose: Track test execution times, results, and performance metrics
-- Date: January 9, 2026

USE HospitalBackupDemo;
GO

SET NOCOUNT ON;

PRINT '╔════════════════════════════════════════════════════════════════╗';
PRINT '║        TEST EXECUTION METRICS & RESULT TRACKING               ║';
PRINT '║              Phase 6 - Testing & Validation                   ║';
PRINT '╚════════════════════════════════════════════════════════════════╝';
PRINT '';

-- ============================================
-- CREATE TEST EXECUTION TRACKING TABLES
-- ============================================

IF OBJECT_ID('dbo.TestExecutions', 'U') IS NOT NULL
    DROP TABLE dbo.TestExecutions;
GO

CREATE TABLE dbo.TestExecutions (
    ExecutionID INT IDENTITY(1,1) NOT NULL,
    TestName NVARCHAR(200) NOT NULL,
    TestCategory NVARCHAR(50) NOT NULL, -- Unit, Integration, Security, Performance, Scenario
    ExecutionDateTime DATETIME2 DEFAULT SYSDATETIME(),
    ExecutionDurationSeconds DECIMAL(10,2),
    Result NVARCHAR(20) CHECK (Result IN ('PASS', 'FAIL', 'WARNING', 'SKIPPED')) NOT NULL,
    ErrorMessage NVARCHAR(MAX),
    Severity NVARCHAR(20) CHECK (Severity IN ('Critical', 'High', 'Medium', 'Low', 'Info')),
    MetricsCaptured BIT DEFAULT 0,
    Notes NVARCHAR(MAX),
    
    CONSTRAINT PK_TestExecutions PRIMARY KEY CLUSTERED (ExecutionID),
    CONSTRAINT CK_TestExecutionDuration CHECK (ExecutionDurationSeconds >= 0)
);
GO

-- ============================================
-- CREATE PERFORMANCE METRICS TRACKING
-- ============================================

IF OBJECT_ID('dbo.PerformanceMetrics', 'U') IS NOT NULL
    DROP TABLE dbo.PerformanceMetrics;
GO

CREATE TABLE dbo.PerformanceMetrics (
    MetricID INT IDENTITY(1,1) NOT NULL,
    ExecutionID INT NOT NULL,
    MetricName NVARCHAR(100) NOT NULL,
    MetricValue DECIMAL(15,2) NOT NULL,
    MetricUnit NVARCHAR(50), -- milliseconds, MB, percentage, etc.
    Baseline DECIMAL(15,2),  -- Expected/baseline value
    PercentageOfBaseline DECIMAL(5,2), -- Actual vs baseline
    IsAbnormal BIT,
    CaptureDateTime DATETIME2 DEFAULT SYSDATETIME(),
    
    CONSTRAINT PK_PerformanceMetrics PRIMARY KEY CLUSTERED (MetricID),
    CONSTRAINT FK_PerformanceMetrics_Execution FOREIGN KEY (ExecutionID) 
        REFERENCES dbo.TestExecutions(ExecutionID)
);
GO

-- ============================================
-- CREATE DISASTER SCENARIO TEST RESULTS
-- ============================================

IF OBJECT_ID('dbo.DisasterScenarioResults', 'U') IS NOT NULL
    DROP TABLE dbo.DisasterScenarioResults;
GO

CREATE TABLE dbo.DisasterScenarioResults (
    ResultID INT IDENTITY(1,1) NOT NULL,
    ScenarioCode NVARCHAR(20) NOT NULL,
    ScenarioName NVARCHAR(200) NOT NULL,
    TestDateTime DATETIME2 DEFAULT SYSDATETIME(),
    RTO_Minutes INT, -- Actual Recovery Time Objective achieved
    RPO_Minutes INT, -- Actual Recovery Point Objective achieved
    DataIntegrityCheck NVARCHAR(20) CHECK (DataIntegrityCheck IN ('PASS', 'FAIL')),
    RecordCount BIGINT, -- Records recovered
    RecordIntegrityPercentage DECIMAL(5,2), -- % of records intact
    FailoverSuccess BIT,
    FailoverDurationSeconds DECIMAL(10,2),
    PreRecoveryStatus NVARCHAR(100),
    PostRecoveryStatus NVARCHAR(100),
    IncidentsEncountered NVARCHAR(MAX),
    ResolutionNotes NVARCHAR(MAX),
    
    CONSTRAINT PK_DisasterScenarioResults PRIMARY KEY CLUSTERED (ResultID)
);
GO

-- ============================================
-- CREATE SECURITY TEST RESULTS
-- ============================================

IF OBJECT_ID('dbo.SecurityTestResults', 'U') IS NOT NULL
    DROP TABLE dbo.SecurityTestResults;
GO

CREATE TABLE dbo.SecurityTestResults (
    ResultID INT IDENTITY(1,1) NOT NULL,
    TestName NVARCHAR(200) NOT NULL,
    TestCategory NVARCHAR(100), -- RBAC, Encryption, Authentication, Audit
    TestDateTime DATETIME2 DEFAULT SYSDATETIME(),
    TestResult NVARCHAR(20) CHECK (TestResult IN ('PASS', 'FAIL', 'WARNING')),
    Severity NVARCHAR(20) CHECK (Severity IN ('Critical', 'High', 'Medium', 'Low')),
    VulnerabilityFound NVARCHAR(MAX),
    Remediation NVARCHAR(MAX),
    FollowUpRequired BIT DEFAULT 0,
    
    CONSTRAINT PK_SecurityTestResults PRIMARY KEY CLUSTERED (ResultID)
);
GO

-- ============================================
-- CREATE LOAD & STRESS TEST RESULTS
-- ============================================

IF OBJECT_ID('dbo.LoadStressTestResults', 'U') IS NOT NULL
    DROP TABLE dbo.LoadStressTestResults;
GO

CREATE TABLE dbo.LoadStressTestResults (
    ResultID INT IDENTITY(1,1) NOT NULL,
    TestName NVARCHAR(200) NOT NULL,
    LoadLevel NVARCHAR(50), -- Light, Moderate, Heavy, Extreme
    Severity NVARCHAR(20) CHECK (Severity IN ('Low', 'Medium', 'High', 'Critical')),
    TestDateTime DATETIME2 DEFAULT SYSDATETIME(),
    ConnectionCount INT,
    TransactionsPerSecond DECIMAL(10,2),
    AverageResponseTimeMS DECIMAL(10,2),
    MaxResponseTimeMS DECIMAL(10,2),
    ErrorRate DECIMAL(5,2), -- Percentage
    CPUUsagePercent DECIMAL(5,2),
    MemoryUsageMB INT,
    DiskIOWaitsPercent DECIMAL(5,2),
    SystemStable BIT, -- Whether system remained stable
    BreakingPoint NVARCHAR(MAX), -- Where system failed/degraded
    Recommendations NVARCHAR(MAX),
    
    CONSTRAINT PK_LoadStressTestResults PRIMARY KEY CLUSTERED (ResultID)
);
GO

-- ============================================
-- VIEWS FOR TEST RESULT ANALYSIS
-- ============================================

CREATE OR ALTER VIEW vw_TestExecutionSummary AS
SELECT
    TestCategory,
    COUNT(*) AS TotalTests,
    SUM(CASE WHEN Result = 'PASS' THEN 1 ELSE 0 END) AS PassedTests,
    SUM(CASE WHEN Result = 'FAIL' THEN 1 ELSE 0 END) AS FailedTests,
    SUM(CASE WHEN Result = 'WARNING' THEN 1 ELSE 0 END) AS WarningTests,
    CAST(
        SUM(CASE WHEN Result = 'PASS' THEN 1 ELSE 0 END) * 100.0 / COUNT(*)
        AS DECIMAL(5,2)
    ) AS PassPercentage,
    AVG(ExecutionDurationSeconds) AS AvgDurationSeconds,
    MAX(ExecutionDateTime) AS LastExecutionTime
FROM dbo.TestExecutions
GROUP BY TestCategory;
GO

CREATE OR ALTER VIEW vw_DisasterRecoveryPerformance AS
SELECT
    ScenarioCode,
    ScenarioName,
    COUNT(*) AS TestCount,
    AVG(RTO_Minutes) AS AvgRTO_Minutes,
    MIN(RTO_Minutes) AS BestRTO_Minutes,
    MAX(RTO_Minutes) AS WorstRTO_Minutes,
    AVG(RPO_Minutes) AS AvgRPO_Minutes,
    SUM(CASE WHEN DataIntegrityCheck = 'PASS' THEN 1 ELSE 0 END) AS DataIntegrityPassCount,
    AVG(CAST(RecordIntegrityPercentage AS FLOAT)) AS AvgRecordIntegrity,
    SUM(CASE WHEN FailoverSuccess = 1 THEN 1 ELSE 0 END) AS SuccessfulFailovers,
    MAX(TestDateTime) AS LastTestDate
FROM dbo.DisasterScenarioResults
GROUP BY ScenarioCode, ScenarioName;
GO

CREATE OR ALTER VIEW vw_SecurityTestCoverage AS
SELECT
    TestCategory,
    COUNT(*) AS TestsRun,
    SUM(CASE WHEN TestResult = 'PASS' THEN 1 ELSE 0 END) AS PassedTests,
    SUM(CASE WHEN TestResult = 'FAIL' THEN 1 ELSE 0 END) AS FailedTests,
    SUM(CASE WHEN TestResult = 'WARNING' THEN 1 ELSE 0 END) AS WarningTests,
    SUM(CASE WHEN FollowUpRequired = 1 THEN 1 ELSE 0 END) AS RequiresFollowUp,
    MAX(TestDateTime) AS LastTestDate
FROM dbo.SecurityTestResults
GROUP BY TestCategory;
GO

PRINT '✓ Test execution tracking tables created successfully';
PRINT '';
PRINT 'Tables created:';
PRINT '  - dbo.TestExecutions (overall test execution tracking)';
PRINT '  - dbo.PerformanceMetrics (performance data capture)';
PRINT '  - dbo.DisasterScenarioResults (recovery testing results)';
PRINT '  - dbo.SecurityTestResults (security validation results)';
PRINT '  - dbo.LoadStressTestResults (load/stress testing results)';
PRINT '';
PRINT 'Views created:';
PRINT '  - vw_TestExecutionSummary (summary by category)';
PRINT '  - vw_DisasterRecoveryPerformance (disaster scenario performance)';
PRINT '  - vw_SecurityTestCoverage (security test results)';
PRINT '';
PRINT 'Next steps:';
PRINT '  1. Run test scripts with output inserted into these tables';
PRINT '  2. Query views for test result analysis';
PRINT '  3. Track metrics over time for trend analysis';
GO
