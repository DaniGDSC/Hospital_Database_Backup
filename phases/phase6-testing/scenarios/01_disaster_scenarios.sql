-- File: phase6-testing/scenarios/01_disaster_scenarios.sql
-- Purpose: Create realistic disaster scenarios for testing recovery procedures
-- Author: Database Administration Team
-- Date: 2025-01-09

USE HospitalBackupDemo;
GO

PRINT '╔════════════════════════════════════════════════════════════════╗';
PRINT '║   Disaster Recovery Scenarios - Testing Framework             ║';
PRINT '║   Enterprise-Level Disaster Simulation                        ║';
PRINT '╚════════════════════════════════════════════════════════════════╝';
PRINT '';

-- ============================================
-- CREATE DISASTER SCENARIOS TABLE
-- ============================================

IF OBJECT_ID('dbo.DisasterScenarios', 'U') IS NOT NULL
    DROP TABLE dbo.DisasterScenarios;
GO

CREATE TABLE dbo.DisasterScenarios (
    ScenarioID INT IDENTITY(1,1) NOT NULL,
    ScenarioCode NVARCHAR(20) NOT NULL,
    ScenarioName NVARCHAR(200) NOT NULL,
    ScenarioType NVARCHAR(50) CHECK (ScenarioType IN (
        'Ransomware Attack',
        'Hardware Failure',
        'Human Error',
        'Natural Disaster',
        'Cyber Attack',
        'Data Corruption',
        'System Crash',
        'Network Failure'
    )) NOT NULL,
    Severity NVARCHAR(20) CHECK (Severity IN ('Low', 'Medium', 'High', 'Critical')) NOT NULL,
    Description NVARCHAR(MAX),
    ImpactScope NVARCHAR(50) CHECK (ImpactScope IN ('Single Table', 'Multiple Tables', 'Entire Database', 'Server-Wide')),
    EstimatedRTO_Hours INT, -- Recovery Time Objective
    EstimatedRPO_Hours INT, -- Recovery Point Objective
    RecoveryStrategy NVARCHAR(500),
    TestProcedure NVARCHAR(MAX),
    ExpectedOutcome NVARCHAR(MAX),
    IsActive BIT DEFAULT 1,
    CreatedDate DATETIME2 DEFAULT SYSDATETIME(),
    
    CONSTRAINT PK_DisasterScenarios PRIMARY KEY CLUSTERED (ScenarioID),
    CONSTRAINT UK_DisasterScenarios_Code UNIQUE (ScenarioCode)
);
GO

-- ============================================
-- INSERT DISASTER SCENARIOS
-- ============================================

PRINT 'Inserting disaster scenarios...';

INSERT INTO dbo.DisasterScenarios (
    ScenarioCode, ScenarioName, ScenarioType, Severity, Description,
    ImpactScope, EstimatedRTO_Hours, EstimatedRPO_Hours, RecoveryStrategy,
    TestProcedure, ExpectedOutcome
)
VALUES
-- SCENARIO 1: Ransomware Attack
(
    'DS-001',
    'Ransomware Encryption of Production Database',
    'Ransomware Attack',
    'Critical',
    'All database files encrypted by ransomware. Production system completely unavailable. 
    Ransomware demands payment within 72 hours. Backups on same network potentially compromised.',
    'Entire Database',
    4, -- RTO: 4 hours
    1, -- RPO: 1 hour
    'Restore from immutable S3 backup. Verify backup integrity before restore. 
    Restore to clean environment. Update all credentials after recovery.',
    '1. Simulate file encryption by renaming/moving database files
2. Attempt to access database (should fail)
3. Initiate recovery from S3 immutable backup
4. Restore to point before encryption
5. Verify data integrity
6. Document actual RTO/RPO achieved',
    'Database fully restored from S3 backup with maximum 1 hour data loss. 
    System operational within 4 hours. All security credentials rotated.'
),

-- SCENARIO 2: Accidental Table Drop
(
    'DS-002',
    'Accidental DROP TABLE by Administrator',
    'Human Error',
    'High',
    'Database administrator accidentally executes DROP TABLE on critical MedicalRecords table 
    during maintenance. Thousands of patient records lost. Discovered 2 hours after incident.',
    'Single Table',
    2, -- RTO: 2 hours
    2, -- RPO: 2 hours max
    'Point-in-time recovery to moment before DROP TABLE statement. 
    Restore only affected table using log backup chain.',
    '1. Take current full backup as safety net
2. Deliberately drop MedicalRecords table
3. Record exact timestamp
4. Wait 10 minutes to simulate discovery delay
5. Perform point-in-time restore to 1 minute before drop
6. Verify all records recovered
7. Measure actual recovery time',
    'MedicalRecords table fully restored with zero data loss. 
    Recovery completed within 2 hours. All foreign key relationships intact.'
),

-- SCENARIO 3: Disk Failure
(
    'DS-003',
    'Production Disk Drive Catastrophic Failure',
    'Hardware Failure',
    'Critical',
    'Main data drive experiences complete mechanical failure. 
    All database files unreadable. No RAID protection in place.',
    'Entire Database',
    3, -- RTO: 3 hours
    1, -- RPO: 1 hour
    'Restore latest full backup + differential + transaction logs. 
    Restore to alternate disk. Verify CHECKSUM integrity.',
    '1. Stop SQL Server service
2. Rename/move database files to simulate disk failure
3. Attempt to start SQL Server (should fail to attach DB)
4. Restore from latest backup chain
5. Apply all transaction logs
6. Verify database consistency with DBCC CHECKDB
7. Measure recovery time',
    'Database restored on new disk. Maximum 1 hour data loss. 
    All integrity checks pass. System operational within 3 hours.'
),

-- SCENARIO 4: Data Corruption
(
    'DS-004',
    'SQL Injection Attack with Mass DELETE',
    'Cyber Attack',
    'Critical',
    'Attacker exploits SQL injection vulnerability. 
    Executes DELETE statement removing 80% of patient records. 
    Discovered during business hours with users actively working.',
    'Multiple Tables',
    3, -- RTO: 3 hours
    4, -- RPO: 4 hours acceptable for this scenario
    'Point-in-time restore to last known good state. 
    Identify exact time of malicious DELETE. Restore database to moment before attack.',
    '1. Create test records with known timestamps
2. Simulate SQL injection by executing mass DELETE
3. Record deletion timestamp
4. Continue adding new records to simulate active users
5. Perform point-in-time restore to before DELETE
6. Verify deleted records restored
7. Confirm new records after attack are lost (expected)
8. Document data loss window',
    'All maliciously deleted records restored. 
    Legitimate transactions after attack replayed from application logs where possible. 
    Maximum 4 hours of legitimate data lost.'
),

-- SCENARIO 5: Database Corruption
(
    'DS-005',
    'Database Corruption Due to Power Failure',
    'System Crash',
    'High',
    'Sudden power outage during heavy write operations. 
    Database marked as SUSPECT. DBCC CHECKDB reports multiple consistency errors.',
    'Entire Database',
    4, -- RTO: 4 hours
    2, -- RPO: 2 hours
    'Attempt emergency repair with DBCC CHECKDB REPAIR_ALLOW_DATA_LOSS. 
    If unsuccessful, restore from backup. Document data loss.',
    '1. Simulate corruption by setting database to EMERGENCY mode
2. Run DBCC CHECKDB to confirm errors
3. Attempt REPAIR_ALLOW_DATA_LOSS (document results)
4. If repair fails, restore from latest backup
5. Verify data integrity post-restore
6. Compare record counts before/after
7. Generate corruption report',
    'Database repaired or restored. Corruption eliminated. 
    Data loss documented and acceptable. DBCC CHECKDB passes all checks.'
),

-- SCENARIO 6: Full Server Failure
(
    'DS-006',
    'Complete Server Hardware Failure',
    'Hardware Failure',
    'Critical',
    'Physical server experiences motherboard failure. 
    Entire server unrecoverable. Must restore to completely different hardware.',
    'Server-Wide',
    6, -- RTO: 6 hours
    1, -- RPO: 1 hour
    'Build new SQL Server instance. Restore master, msdb, and user databases. 
    Recreate logins, jobs, and configurations. Reconfigure application connections.',
    '1. Document current server configuration
2. Prepare alternate server/VM
3. Install SQL Server on new instance
4. Restore system databases (master, msdb)
5. Restore HospitalBackupDemo database
6. Recreate logins and map users
7. Restore SQL Agent jobs
8. Test application connectivity
9. Verify all functionality',
    'Database operational on new server. All logins, jobs, and configurations restored. 
    Applications reconnected successfully. Total downtime under 6 hours.'
),

-- SCENARIO 7: Ransomware with Backup Contamination
(
    'DS-007',
    'Ransomware Attack Affecting Local Backups',
    'Ransomware Attack',
    'Critical',
    'Ransomware encrypts both production database AND local backup files. 
    Only S3 immutable backups remain safe. Local backup chain broken.',
    'Entire Database',
    5, -- RTO: 5 hours (S3 download takes time)
    12, -- RPO: 12 hours (last S3 upload)
    'Download latest backup from S3. Restore to clean environment. 
    Verify integrity. Rebuild backup chain. Implement better backup isolation.',
    '1. Encrypt/move production DB and local backups
2. Verify only S3 backups accessible
3. Download backup from S3 to clean environment
4. Restore database from S3 backup
5. Verify data integrity
6. Rebuild local backup chain
7. Measure S3 download and restore time
8. Document lessons learned',
    'Database restored from S3 with 12-hour data loss (acceptable for this scenario). 
    Local backup chain rebuilt. Recommendations for improved backup isolation implemented.'
),

-- SCENARIO 8: Logical Data Corruption
(
    'DS-008',
    'Application Bug Causing Data Inconsistency',
    'Human Error',
    'Medium',
    'Application bug updates patient billing records with incorrect values. 
    Affects 5,000+ records. Discovered 6 hours after deployment. 
    Database physically intact but data logically corrupted.',
    'Single Table',
    3, -- RTO: 3 hours
    6, -- RPO: 6 hours
    'Export current corrupt data for analysis. 
    Point-in-time restore to temporary database. 
    Extract correct data. Update production with corrected values.',
    '1. Deliberately update billing records with wrong values
2. Record timestamp of corruption
3. Wait to simulate discovery delay
4. Restore database to point before corruption (in temp DB)
5. Compare corrupt vs. correct data
6. Generate UPDATE scripts to fix production
7. Validate corrected data
8. Document correction process',
    'All 5,000+ records corrected with accurate data. 
    No data loss. Corruption identified and fixed. Process documented for future incidents.'
),

-- SCENARIO 9: Multi-Region Disaster
(
    'DS-009',
    'Regional Datacenter Outage (Natural Disaster)',
    'Natural Disaster',
    'Critical',
    'Earthquake destroys entire datacenter. 
    Primary site completely offline. Must failover to disaster recovery site in different region.',
    'Server-Wide',
    8, -- RTO: 8 hours
    4, -- RPO: 4 hours
    'Activate DR site. Restore latest backup from geo-replicated S3. 
    Update DNS/load balancers. Notify all stakeholders. Test full functionality.',
    '1. Simulate primary site failure
2. Activate DR runbook
3. Spin up DR environment
4. Download latest backup from geo-replicated S3
5. Restore database in DR region
6. Reconfigure application connection strings
7. Perform smoke tests
8. Measure total failover time
9. Document DR process improvements',
    'DR site activated successfully. Database operational in alternate region. 
    Maximum 4 hours data loss. Applications reconnected. Full functionality verified within 8 hours.'
),

-- SCENARIO 10: Insider Threat
(
    'DS-010',
    'Malicious Insider Deletes Critical Data',
    'Cyber Attack',
    'Critical',
    'Disgruntled employee with elevated privileges deliberately deletes 
    patient medical records and covers tracks by deleting backup files. 
    Discovered after employee has left.',
    'Multiple Tables',
    6, -- RTO: 6 hours
    24, -- RPO: 24 hours
    'Restore from off-site immutable S3 backups. 
    Perform forensic analysis. Restore to point before malicious activity. 
    Review and revoke insider access.',
    '1. Simulate deletion of critical tables
2. Delete recent local backup files
3. Modify audit logs (attempt to cover tracks)
4. Restore from S3 immutable backup
5. Perform forensic analysis on audit logs
6. Identify scope of damage
7. Restore data from last clean backup
8. Document security improvements needed',
    'Data restored from immutable backups. Malicious activity identified through audit logs. 
    Security policies updated. Access controls strengthened. Maximum 24 hours data loss.'
);

GO

PRINT '  ✓ 10 disaster scenarios created';

-- ============================================
-- CREATE TEST RESULTS TABLE
-- ============================================

PRINT '';
PRINT 'Creating disaster test results table...';

IF OBJECT_ID('dbo.DisasterTestResults', 'U') IS NOT NULL
    DROP TABLE dbo.DisasterTestResults;
GO

CREATE TABLE dbo.DisasterTestResults (
    TestID INT IDENTITY(1,1) NOT NULL,
    ScenarioID INT NOT NULL,
    TestDate DATETIME2 DEFAULT SYSDATETIME(),
    TesterName NVARCHAR(100),
    DisasterInitiatedTime DATETIME2,
    DisasterDetectedTime DATETIME2,
    DetectionDelayMinutes AS (DATEDIFF(MINUTE, DisasterInitiatedTime, DisasterDetectedTime)),
    RecoveryStartTime DATETIME2,
    RecoveryCompletedTime DATETIME2,
    ActualRTO_Minutes AS (DATEDIFF(MINUTE, DisasterInitiatedTime, RecoveryCompletedTime)),
    ActualRPO_Minutes AS (DATEDIFF(MINUTE, DisasterInitiatedTime, DisasterDetectedTime)),
    PlannedRTO_Hours INT,
    PlannedRPO_Hours INT,
    RTO_Met AS (CASE WHEN DATEDIFF(MINUTE, DisasterInitiatedTime, RecoveryCompletedTime) <= PlannedRTO_Hours * 60 THEN 1 ELSE 0 END),
    RPO_Met AS (CASE WHEN DATEDIFF(MINUTE, DisasterInitiatedTime, DisasterDetectedTime) <= PlannedRPO_Hours * 60 THEN 1 ELSE 0 END),
    RecoveryMethod NVARCHAR(500),
    BackupUsed NVARCHAR(500),
    DataLossOccurred BIT DEFAULT 0,
    DataLossDescription NVARCHAR(1000),
    RecordsLost INT DEFAULT 0,
    RecordsRecovered INT DEFAULT 0,
    TestStatus NVARCHAR(20) CHECK (TestStatus IN ('Passed', 'Failed', 'Partial Success')) NOT NULL,
    IssuesEncountered NVARCHAR(MAX),
    LessonsLearned NVARCHAR(MAX),
    Recommendations NVARCHAR(MAX),
    Notes NVARCHAR(MAX),
    CreatedDate DATETIME2 DEFAULT SYSDATETIME(),
    
    CONSTRAINT PK_DisasterTestResults PRIMARY KEY CLUSTERED (TestID),
    CONSTRAINT FK_DisasterTestResults_Scenarios FOREIGN KEY (ScenarioID)
        REFERENCES dbo.DisasterScenarios(ScenarioID)
);
GO

PRINT '  ✓ Test results table created';

-- ============================================
-- CREATE DISASTER SIMULATION PROCEDURES
-- ============================================

PRINT '';
PRINT 'Creating disaster simulation procedures...';

-- Procedure 1: Simulate Ransomware Attack
GO
CREATE OR ALTER PROCEDURE dbo.sp_SimulateRansomware
    @TestDescription NVARCHAR(500) = 'Ransomware simulation test'
AS
BEGIN
    SET NOCOUNT ON;
    
    DECLARE @StartTime DATETIME2 = SYSDATETIME();
    DECLARE @ScenarioID INT = 1; -- DS-001
    DECLARE @TestID INT;
    
    BEGIN TRY
        PRINT '╔════════════════════════════════════════════════════════╗';
        PRINT '║   SIMULATING: Ransomware Attack                        ║';
        PRINT '╚════════════════════════════════════════════════════════╝';
        PRINT '';
        PRINT 'WARNING: This will make the database inaccessible!';
        PRINT 'Ensure you have valid backups before proceeding.';
        PRINT '';
        
        -- Log test start
        INSERT INTO dbo.DisasterTestResults (
            ScenarioID, TesterName, DisasterInitiatedTime, 
            PlannedRTO_Hours, PlannedRPO_Hours, TestStatus, Notes
        )
        VALUES (
            @ScenarioID, SUSER_SNAME(), @StartTime, 
            4, 1, 'Failed', 'Test in progress - ' + @TestDescription
        );
        
        SET @TestID = SCOPE_IDENTITY();
        
        -- Take pre-disaster backup
        PRINT 'Step 1: Taking pre-disaster backup...';
        BACKUP DATABASE HospitalBackupDemo
        TO DISK = '/var/opt/mssql/backup/full/PreRansomware_Test.bak'
        WITH INIT, COMPRESSION;
        PRINT '  ✓ Backup completed';
        
        -- Simulate ransomware by taking database offline
        PRINT '';
        PRINT 'Step 2: Simulating ransomware encryption...';
        PRINT '  (Setting database offline to simulate encrypted files)';
        
        ALTER DATABASE HospitalBackupDemo SET OFFLINE WITH ROLLBACK IMMEDIATE;
        
        PRINT '  ✓ Database is now OFFLINE (simulating encryption)';
        PRINT '';
        PRINT '════════════════════════════════════════════════════════';
        PRINT 'DISASTER SIMULATION COMPLETE';
        PRINT '════════════════════════════════════════════════════════';
        PRINT '';
        PRINT 'Database Status: OFFLINE (encrypted by ransomware)';
        PRINT 'Test ID: ' + CAST(@TestID AS VARCHAR);
        PRINT '';
        PRINT 'NEXT STEPS:';
        PRINT '1. Attempt to access database (should fail)';
        PRINT '2. Run recovery procedure: EXEC dbo.sp_RecoverFromRansomware @TestID = ' + CAST(@TestID AS VARCHAR);
        PRINT '3. Verify recovery success';
        PRINT '4. Document RTO/RPO achieved';
        PRINT '';
        
    END TRY
    BEGIN CATCH
        PRINT 'Error during ransomware simulation:';
        PRINT ERROR_MESSAGE();
        THROW;
    END CATCH
END;
GO

-- Procedure 2: Simulate Accidental Table Drop
GO
CREATE OR ALTER PROCEDURE dbo.sp_SimulateTableDrop
    @TableName NVARCHAR(128) = 'MedicalRecords',
    @TestDescription NVARCHAR(500) = 'Accidental table drop test'
AS
BEGIN
    SET NOCOUNT ON;
    
    DECLARE @StartTime DATETIME2 = SYSDATETIME();
    DECLARE @ScenarioID INT = 2; -- DS-002
    DECLARE @TestID INT;
    DECLARE @SQL NVARCHAR(MAX);
    DECLARE @RecordCount INT;
    
    BEGIN TRY
        PRINT '╔════════════════════════════════════════════════════════╗';
        PRINT '║   SIMULATING: Accidental Table Drop                   ║';
        PRINT '╚════════════════════════════════════════════════════════╝';
        PRINT '';
        PRINT 'Target Table: ' + @TableName;
        PRINT '';
        
        -- Get record count before drop
        SET @SQL = 'SELECT @Count = COUNT(*) FROM dbo.' + QUOTENAME(@TableName);
        EXEC sp_executesql @SQL, N'@Count INT OUTPUT', @Count = @RecordCount OUTPUT;
        
        PRINT 'Current record count: ' + CAST(@RecordCount AS VARCHAR);
        PRINT '';
        
        -- Log test start
        INSERT INTO dbo.DisasterTestResults (
            ScenarioID, TesterName, DisasterInitiatedTime,
            PlannedRTO_Hours, PlannedRPO_Hours, TestStatus,
            RecordsLost, Notes
        )
        VALUES (
            @ScenarioID, SUSER_SNAME(), @StartTime,
            2, 2, 'Failed',
            @RecordCount, 'Test in progress - ' + @TestDescription
        );
        
        SET @TestID = SCOPE_IDENTITY();
        
        -- Take safety backup
        PRINT 'Step 1: Taking safety backup...';
        DECLARE @BackupFile NVARCHAR(500) = '/var/opt/mssql/backup/full/PreTableDrop_' + 
                                             REPLACE(CONVERT(VARCHAR, @StartTime, 120), ':', '') + '.bak';
        
        SET @SQL = 'BACKUP DATABASE HospitalBackupDemo TO DISK = ''' + @BackupFile + ''' WITH INIT, COMPRESSION';
        EXEC sp_executesql @SQL;
        PRINT '  ✓ Safety backup completed';
        
        -- Wait a moment to ensure different timestamp
        WAITFOR DELAY '00:00:05';
        
        -- Drop the table
        PRINT '';
        PRINT 'Step 2: Dropping table ' + @TableName + '...';
        PRINT '  Timestamp: ' + CONVERT(VARCHAR, SYSDATETIME(), 121);
        
        SET @SQL = 'DROP TABLE dbo.' + QUOTENAME(@TableName);
        EXEC sp_executesql @SQL;
        
        PRINT '  ✓ Table dropped successfully';
        
        -- Update test results
        UPDATE dbo.DisasterTestResults
        SET DisasterDetectedTime = DATEADD(MINUTE, 10, @StartTime), -- Simulate 10min detection delay
            Notes = 'Table ' + @TableName + ' dropped. ' + CAST(@RecordCount AS VARCHAR) + ' records lost.'
        WHERE TestID = @TestID;
        
        PRINT '';
        PRINT '════════════════════════════════════════════════════════';
        PRINT 'DISASTER SIMULATION COMPLETE';
        PRINT '════════════════════════════════════════════════════════';
        PRINT '';
        PRINT 'Table Dropped: ' + @TableName;
        PRINT 'Records Lost: ' + CAST(@RecordCount AS VARCHAR);
        PRINT 'Test ID: ' + CAST(@TestID AS VARCHAR);
        PRINT 'Drop Timestamp: ' + CONVERT(VARCHAR, SYSDATETIME(), 121);
        PRINT '';
        PRINT 'NEXT STEPS:';
        PRINT '1. Verify table no longer exists';
        PRINT '2. Run recovery: EXEC dbo.sp_RecoverDroppedTable @TestID = ' + CAST(@TestID AS VARCHAR) + ', @TableName = ''' + @TableName + '''';
        PRINT '3. Verify all records recovered';
        PRINT '';
        
    END TRY
    BEGIN CATCH
        PRINT 'Error during table drop simulation:';
        PRINT ERROR_MESSAGE();
        THROW;
    END CATCH
END;
GO

PRINT '  ✓ Simulation procedures created';

-- ============================================
-- CREATE SUMMARY VIEW
-- ============================================

PRINT '';
PRINT 'Creating disaster scenarios summary view...';

GO
CREATE OR ALTER VIEW dbo.vw_DisasterScenariosSummary
AS
SELECT 
    ds.ScenarioCode,
    ds.ScenarioName,
    ds.ScenarioType,
    ds.Severity,
    ds.ImpactScope,
    ds.EstimatedRTO_Hours,
    ds.EstimatedRPO_Hours,
    COUNT(dtr.TestID) AS TimesTested,
    MAX(dtr.TestDate) AS LastTestedDate,
    AVG(CAST(dtr.ActualRTO_Minutes AS FLOAT) / 60) AS AvgActualRTO_Hours,
    AVG(CAST(dtr.ActualRPO_Minutes AS FLOAT) / 60) AS AvgActualRPO_Hours,
    SUM(CASE WHEN dtr.RTO_Met = 1 THEN 1 ELSE 0 END) AS TimesRTO_Met,
    SUM(CASE WHEN dtr.RPO_Met = 1 THEN 1 ELSE 0 END) AS TimesRPO_Met,
    SUM(CASE WHEN dtr.TestStatus = 'Passed' THEN 1 ELSE 0 END) AS TimesPassed,
    SUM(CASE WHEN dtr.TestStatus = 'Failed' THEN 1 ELSE 0 END) AS TimesFailed,
    ds.RecoveryStrategy,
    ds.IsActive
FROM dbo.DisasterScenarios ds
LEFT JOIN dbo.DisasterTestResults dtr ON ds.ScenarioID = dtr.ScenarioID
GROUP BY 
    ds.ScenarioCode, ds.ScenarioName, ds.ScenarioType, ds.Severity,
    ds.ImpactScope, ds.EstimatedRTO_Hours, ds.EstimatedRPO_Hours,
    ds.RecoveryStrategy, ds.IsActive;
GO

PRINT '  ✓ Summary view created';

-- ============================================
-- DISPLAY SCENARIOS
-- ============================================

PRINT '';
PRINT '╔════════════════════════════════════════════════════════════════╗';
PRINT '║   ✓ Disaster Scenarios Framework Created                      ║';
PRINT '╚════════════════════════════════════════════════════════════════╝';
PRINT '';
PRINT 'Total Scenarios: 10';
PRINT '';

SELECT 
    ScenarioCode AS Code,
    ScenarioName AS [Disaster Scenario],
    ScenarioType AS Type,
    Severity,
    ImpactScope AS Scope,
    EstimatedRTO_Hours AS [RTO (hrs)],
    EstimatedRPO_Hours AS [RPO (hrs)]
FROM dbo.DisasterScenarios
ORDER BY 
    CASE Severity 
        WHEN 'Critical' THEN 1
        WHEN 'High' THEN 2
        WHEN 'Medium' THEN 3
        WHEN 'Low' THEN 4
    END,
    ScenarioCode;

PRINT '';
PRINT 'Available Simulation Procedures:';
PRINT '  • EXEC dbo.sp_SimulateRansomware';
PRINT '  • EXEC dbo.sp_SimulateTableDrop @TableName = ''MedicalRecords''';
PRINT '';
PRINT 'Next Steps:';
PRINT '1. Review disaster scenarios';
PRINT '2. Create recovery procedures (02_recovery_procedures.sql)';
PRINT '3. Execute test scenarios';
PRINT '4. Document results';
PRINT '';

GO
