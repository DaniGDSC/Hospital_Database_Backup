-- Capacity tracking and forecast tables for production monitoring
-- Tracks: disk usage, database size, backup sizes, S3 storage
-- Enables: linear forecasting for when thresholds will be hit
USE HospitalBackupDemo;
GO

SET NOCOUNT ON;

PRINT '╔════════════════════════════════════════════════════════════════╗';
PRINT '║          Capacity Planning Tables                               ║';
PRINT '╚════════════════════════════════════════════════════════════════╝';
PRINT '';

-- ============================================
-- Table 1: CapacityHistory (immutable metrics log)
-- ============================================
IF OBJECT_ID('dbo.CapacityHistory', 'U') IS NULL
BEGIN
    CREATE TABLE dbo.CapacityHistory (
        CapacityID      INT IDENTITY(1,1) PRIMARY KEY,
        RecordedAt      DATETIME2 NOT NULL DEFAULT SYSDATETIME(),
        MetricType      VARCHAR(50) NOT NULL
            CHECK (MetricType IN (
                'DISK_DATA', 'DISK_BACKUP', 'DISK_LOG',
                'DB_SIZE_DATA', 'DB_SIZE_LOG',
                'BACKUP_SIZE_FULL', 'BACKUP_SIZE_DIFF', 'BACKUP_SIZE_LOG',
                'S3_TOTAL_SIZE', 'LOG_USED_PCT', 'TABLE_ROW_COUNT'
            )),
        CurrentValueMB  BIGINT NOT NULL,
        MaxValueMB      BIGINT NULL,
        UsedPercent     DECIMAL(5,2) NULL,
        Environment     VARCHAR(20) NOT NULL DEFAULT 'production',
        Notes           NVARCHAR(500) NULL
    );

    CREATE NONCLUSTERED INDEX IX_CapacityHistory_Type_Date
        ON dbo.CapacityHistory (MetricType, RecordedAt)
        INCLUDE (CurrentValueMB, UsedPercent);

    PRINT '✓ Table dbo.CapacityHistory created';
END
ELSE
    PRINT '✓ Table dbo.CapacityHistory already exists';
GO

-- Protect from modification (same as audit tables)
DENY DELETE, UPDATE ON dbo.CapacityHistory TO public;
GO

PRINT '  ✓ DENY DELETE, UPDATE on CapacityHistory';

-- ============================================
-- Table 2: CapacityForecast
-- ============================================
IF OBJECT_ID('dbo.CapacityForecast', 'U') IS NULL
BEGIN
    CREATE TABLE dbo.CapacityForecast (
        ForecastID          INT IDENTITY(1,1) PRIMARY KEY,
        GeneratedAt         DATETIME2 NOT NULL DEFAULT SYSDATETIME(),
        MetricType          VARCHAR(50) NOT NULL,
        CurrentValueMB      BIGINT NOT NULL,
        MaxValueMB          BIGINT NULL,
        GrowthRatePerDayMB  DECIMAL(10,4) NOT NULL DEFAULT 0,
        DaysUntil80Pct      INT NULL,
        DaysUntil90Pct      INT NULL,
        DaysUntil100Pct     INT NULL,
        Projected80PctDate  DATE NULL,
        Projected100PctDate DATE NULL,
        ForecastBasis       VARCHAR(20) NOT NULL DEFAULT '30day',
        AlertLevel          VARCHAR(20) NULL
            CHECK (AlertLevel IN ('OK', 'WARNING', 'HIGH', 'CRITICAL')),
        AlertSent           BIT NOT NULL DEFAULT 0
    );

    CREATE NONCLUSTERED INDEX IX_CapacityForecast_Type_Date
        ON dbo.CapacityForecast (MetricType, GeneratedAt);

    PRINT '✓ Table dbo.CapacityForecast created';
END
ELSE
    PRINT '✓ Table dbo.CapacityForecast already exists';
GO

PRINT '';
PRINT '✓ Capacity planning tables ready';
PRINT '  Next: Run 02_collect_capacity_metrics.sql to start collecting';
GO
