-- File: phase1-database/schema/01_create_database.sql
-- Purpose: Create HospitalBackupDemo database with proper configuration
-- Recovery Model: FULL (required for transaction log backups)
-- Author: [Your Name]
-- Date: 2025-01-09

USE master;
GO

PRINT '╔════════════════════════════════════════════════════════════════╗';
PRINT '║   Phase 1.1: Database Creation                                 ║';
PRINT '║   HospitalBackupDemo - Backup & Recovery Project               ║';
PRINT '╚════════════════════════════════════════════════════════════════╝';
PRINT '';

-- ============================================
-- STEP 1: DROP EXISTING DATABASE IF EXISTS
-- ============================================

PRINT 'Step 1: Checking for existing database...';

IF EXISTS (SELECT name FROM sys.databases WHERE name = 'HospitalBackupDemo')
BEGIN
    PRINT '  ⚠ Database already exists - removing...';
    
    -- Disconnect all users
    ALTER DATABASE HospitalBackupDemo SET SINGLE_USER WITH ROLLBACK IMMEDIATE;
    
    -- Drop database
    DROP DATABASE HospitalBackupDemo;
    
    PRINT '  ✓ Old database removed';
END
ELSE
BEGIN
    PRINT '  ℹ No existing database found';
END
GO

-- ============================================
-- STEP 2: CREATE NEW DATABASE
-- ============================================

PRINT '';
PRINT 'Step 2: Creating new database...';

CREATE DATABASE HospitalBackupDemo
ON PRIMARY
(
    NAME = N'HospitalBackupDemo_Data',
    FILENAME = N'/var/opt/mssql/data/HospitalBackupDemo_Data.mdf',
    SIZE = 100MB,              -- Initial size
    MAXSIZE = UNLIMITED,       -- No size limit
    FILEGROWTH = 50MB          -- Grow by 50MB when full
),
FILEGROUP HospitalBackupDemo_FG1
(
    NAME = N'HospitalBackupDemo_Data2',
    FILENAME = N'/var/opt/mssql/data/HospitalBackupDemo_Data2.ndf',
    SIZE = 50MB,
    MAXSIZE = UNLIMITED,
    FILEGROWTH = 25MB
)
LOG ON
(
    NAME = N'HospitalBackupDemo_Log',
    FILENAME = N'/var/opt/mssql/data/HospitalBackupDemo_Log.ldf',
    SIZE = 50MB,               -- Initial log size
    MAXSIZE = 2GB,             -- Max log size
    FILEGROWTH = 10MB          -- Log growth increment
);
GO

PRINT '  ✓ Database created successfully';

-- ============================================
-- STEP 3: CONFIGURE DATABASE SETTINGS
-- ============================================

PRINT '';
PRINT 'Step 3: Configuring database settings...';

-- Set Recovery Model to FULL (CRITICAL for transaction log backups)
ALTER DATABASE HospitalBackupDemo SET RECOVERY FULL;
PRINT '  ✓ Recovery model: FULL';

-- Disable AUTO_CLOSE (best practice for production)
ALTER DATABASE HospitalBackupDemo SET AUTO_CLOSE OFF;
PRINT '  ✓ AUTO_CLOSE: OFF';

-- Disable AUTO_SHRINK (best practice - manual shrink only)
ALTER DATABASE HospitalBackupDemo SET AUTO_SHRINK OFF;
PRINT '  ✓ AUTO_SHRINK: OFF';

-- Enable AUTO_CREATE_STATISTICS (performance)
ALTER DATABASE HospitalBackupDemo SET AUTO_CREATE_STATISTICS ON;
PRINT '  ✓ AUTO_CREATE_STATISTICS: ON';

-- Enable AUTO_UPDATE_STATISTICS (performance)
ALTER DATABASE HospitalBackupDemo SET AUTO_UPDATE_STATISTICS ON;
PRINT '  ✓ AUTO_UPDATE_STATISTICS: ON';

-- Set PAGE_VERIFY to CHECKSUM (data integrity)
ALTER DATABASE HospitalBackupDemo SET PAGE_VERIFY CHECKSUM;
PRINT '  ✓ PAGE_VERIFY: CHECKSUM';

-- Enable READ_COMMITTED_SNAPSHOT (reduce blocking)
ALTER DATABASE HospitalBackupDemo SET READ_COMMITTED_SNAPSHOT ON;
PRINT '  ✓ READ_COMMITTED_SNAPSHOT: ON';

-- Set compatibility level to SQL Server 2022
ALTER DATABASE HospitalBackupDemo SET COMPATIBILITY_LEVEL = 160;
PRINT '  ✓ Compatibility level: 160 (SQL Server 2022)';

GO

-- ============================================
-- STEP 4: VERIFY DATABASE CREATION
-- ============================================

PRINT '';
PRINT 'Step 4: Verifying database creation...';
PRINT '';

SELECT 
    'Database Name' AS Property,
    name AS Value
FROM sys.databases 
WHERE name = 'HospitalBackupDemo'

UNION ALL

SELECT 
    'Recovery Model',
    recovery_model_desc
FROM sys.databases 
WHERE name = 'HospitalBackupDemo'

UNION ALL

SELECT 
    'State',
    state_desc
FROM sys.databases 
WHERE name = 'HospitalBackupDemo'

UNION ALL

SELECT 
    'Compatibility Level',
    CAST(compatibility_level AS VARCHAR)
FROM sys.databases 
WHERE name = 'HospitalBackupDemo'

UNION ALL

SELECT 
    'Collation',
    collation_name
FROM sys.databases 
WHERE name = 'HospitalBackupDemo'

UNION ALL

SELECT 
    'Page Verify Option',
    page_verify_option_desc
FROM sys.databases 
WHERE name = 'HospitalBackupDemo';

GO

-- ============================================
-- STEP 5: DISPLAY FILE INFORMATION
-- ============================================

PRINT '';
PRINT 'Database Files:';

SELECT 
    file_id AS FileID,
    name AS LogicalName,
    type_desc AS FileType,
    physical_name AS PhysicalPath,
    CAST(size * 8.0 / 1024 AS DECIMAL(10,2)) AS SizeMB,
    CAST(max_size * 8.0 / 1024 AS DECIMAL(10,2)) AS MaxSizeMB,
    CAST(growth * 8.0 / 1024 AS DECIMAL(10,2)) AS GrowthMB,
    is_percent_growth AS IsPercentGrowth
FROM sys.master_files
WHERE database_id = DB_ID('HospitalBackupDemo')
ORDER BY file_id;
GO

-- ============================================
-- STEP 6: TAKE INITIAL BACKUP
-- ============================================

PRINT '';
PRINT 'Step 5: Creating initial full backup...';
PRINT '  (Required to establish backup chain for log backups)';

-- This backup establishes the backup chain
BACKUP DATABASE HospitalBackupDemo
TO DISK = '/var/opt/mssql/backup/full/HospitalBackupDemo_Initial.bak'
WITH 
    INIT,                      -- Overwrite existing backup
    COMPRESSION,               -- Compress backup
    STATS = 10,                -- Show progress every 10%
    DESCRIPTION = 'Initial full backup after database creation',
    NAME = 'HospitalBackupDemo-Initial-Full';
GO

PRINT '  ✓ Initial backup created';

-- ============================================
-- COMPLETION MESSAGE
-- ============================================

PRINT '';
PRINT '╔════════════════════════════════════════════════════════════════╗';
PRINT '║   ✓ Database Creation Completed Successfully                   ║';
PRINT '╚════════════════════════════════════════════════════════════════╝';
PRINT '';
PRINT 'Database: HospitalBackupDemo';
PRINT 'Recovery Model: FULL';
PRINT 'Initial Backup: Created';
PRINT 'Status: Ready for table creation';
PRINT '';
PRINT 'Next Step: Run 02_create_tables.sql';
PRINT '';

GO
