-- Daily capacity metrics collection and forecasting
-- Collects: disk usage, DB size, backup sizes, log usage
-- Forecasts: linear projection of when thresholds will be hit
-- Alerts: CRITICAL / HIGH / WARNING based on projected dates
USE HospitalBackupDemo;
GO

SET NOCOUNT ON;

-- ============================================
-- Procedure 1: Collect capacity metrics
-- ============================================
IF OBJECT_ID('dbo.usp_CollectCapacityMetrics', 'P') IS NOT NULL
    DROP PROCEDURE dbo.usp_CollectCapacityMetrics;
GO

CREATE PROCEDURE dbo.usp_CollectCapacityMetrics
AS
BEGIN
    SET NOCOUNT ON;

    PRINT '--- Collecting capacity metrics ---';

    -- Metric 1: Database data file size
    INSERT INTO dbo.CapacityHistory (MetricType, CurrentValueMB, MaxValueMB, UsedPercent)
    SELECT
        'DB_SIZE_DATA',
        SUM(CAST(size AS BIGINT) * 8 / 1024),
        SUM(CAST(max_size AS BIGINT) * 8 / 1024),
        CASE WHEN SUM(CAST(max_size AS BIGINT)) > 0
            THEN CAST(SUM(CAST(size AS BIGINT)) * 100.0 / NULLIF(SUM(CAST(max_size AS BIGINT)), 0) AS DECIMAL(5,2))
            ELSE NULL
        END
    FROM sys.master_files
    WHERE database_id = DB_ID('HospitalBackupDemo')
      AND type = 0; -- DATA files

    -- Metric 2: Database log file size
    INSERT INTO dbo.CapacityHistory (MetricType, CurrentValueMB, MaxValueMB, UsedPercent)
    SELECT
        'DB_SIZE_LOG',
        SUM(CAST(size AS BIGINT) * 8 / 1024),
        SUM(CAST(max_size AS BIGINT) * 8 / 1024),
        NULL
    FROM sys.master_files
    WHERE database_id = DB_ID('HospitalBackupDemo')
      AND type = 1; -- LOG files

    -- Metric 3: Transaction log used percentage
    CREATE TABLE #LogSpace (
        DatabaseName NVARCHAR(128),
        LogSizeMB DECIMAL(18,2),
        LogSpaceUsedPct DECIMAL(5,2),
        Status INT
    );
    INSERT INTO #LogSpace EXEC('DBCC SQLPERF(LOGSPACE) WITH NO_INFOMSGS');

    INSERT INTO dbo.CapacityHistory (MetricType, CurrentValueMB, MaxValueMB, UsedPercent)
    SELECT
        'LOG_USED_PCT',
        CAST(LogSizeMB * LogSpaceUsedPct / 100 AS BIGINT),
        CAST(LogSizeMB AS BIGINT),
        LogSpaceUsedPct
    FROM #LogSpace
    WHERE DatabaseName = 'HospitalBackupDemo';

    DROP TABLE #LogSpace;

    -- Metric 4: Disk space via volume stats
    INSERT INTO dbo.CapacityHistory (MetricType, CurrentValueMB, MaxValueMB, UsedPercent, Notes)
    SELECT DISTINCT
        'DISK_DATA',
        CAST((vs.total_bytes - vs.available_bytes) / 1048576 AS BIGINT),
        CAST(vs.total_bytes / 1048576 AS BIGINT),
        CAST((vs.total_bytes - vs.available_bytes) * 100.0 / vs.total_bytes AS DECIMAL(5,2)),
        vs.volume_mount_point
    FROM sys.master_files mf
    CROSS APPLY sys.dm_os_volume_stats(mf.database_id, mf.file_id) vs
    WHERE mf.database_id = DB_ID('HospitalBackupDemo')
      AND mf.type = 0;

    -- Metric 5: Latest backup sizes (from backupset)
    INSERT INTO dbo.CapacityHistory (MetricType, CurrentValueMB)
    SELECT
        CASE bs.type
            WHEN 'D' THEN 'BACKUP_SIZE_FULL'
            WHEN 'I' THEN 'BACKUP_SIZE_DIFF'
            WHEN 'L' THEN 'BACKUP_SIZE_LOG'
        END,
        CAST(bs.compressed_backup_size / 1048576 AS BIGINT)
    FROM msdb.dbo.backupset bs
    WHERE bs.database_name = 'HospitalBackupDemo'
      AND bs.type IN ('D', 'I', 'L')
      AND bs.backup_finish_date = (
          SELECT MAX(b2.backup_finish_date)
          FROM msdb.dbo.backupset b2
          WHERE b2.database_name = bs.database_name
            AND b2.type = bs.type
      );

    -- Metric 6: Total row count across PHI tables
    DECLARE @TotalRows BIGINT;
    SELECT @TotalRows = SUM(p.rows)
    FROM sys.tables t
    JOIN sys.partitions p ON t.object_id = p.object_id AND p.index_id IN (0, 1)
    WHERE t.name IN ('Patients', 'MedicalRecords', 'Prescriptions', 'LabTests', 'Appointments');

    INSERT INTO dbo.CapacityHistory (MetricType, CurrentValueMB, Notes)
    VALUES ('TABLE_ROW_COUNT', ISNULL(@TotalRows, 0), 'Total rows across 5 PHI tables');

    PRINT '✓ Capacity metrics collected';
END;
GO

-- ============================================
-- Procedure 2: Forecast capacity
-- ============================================
IF OBJECT_ID('dbo.usp_ForecastCapacity', 'P') IS NOT NULL
    DROP PROCEDURE dbo.usp_ForecastCapacity;
GO

CREATE PROCEDURE dbo.usp_ForecastCapacity
    @BasisDays INT = 30
AS
BEGIN
    SET NOCOUNT ON;

    PRINT '--- Forecasting capacity ---';

    DECLARE @MetricType VARCHAR(50);
    DECLARE @CurrentMB BIGINT, @MaxMB BIGINT;
    DECLARE @OldestMB BIGINT, @DayCount INT;
    DECLARE @GrowthRate DECIMAL(10,4);
    DECLARE @Days80 INT, @Days90 INT, @Days100 INT;
    DECLARE @AlertLevel VARCHAR(20);

    -- Forecast for disk and database metrics that have max values
    DECLARE metric_cursor CURSOR LOCAL FAST_FORWARD FOR
        SELECT DISTINCT MetricType FROM dbo.CapacityHistory
        WHERE MetricType IN ('DISK_DATA', 'DB_SIZE_DATA', 'DB_SIZE_LOG')
          AND RecordedAt >= DATEADD(DAY, -@BasisDays, SYSDATETIME());

    OPEN metric_cursor;
    FETCH NEXT FROM metric_cursor INTO @MetricType;

    WHILE @@FETCH_STATUS = 0
    BEGIN
        -- Get current and oldest values in the window
        SELECT TOP 1 @CurrentMB = CurrentValueMB, @MaxMB = MaxValueMB
        FROM dbo.CapacityHistory
        WHERE MetricType = @MetricType
        ORDER BY RecordedAt DESC;

        SELECT TOP 1 @OldestMB = CurrentValueMB
        FROM dbo.CapacityHistory
        WHERE MetricType = @MetricType
          AND RecordedAt >= DATEADD(DAY, -@BasisDays, SYSDATETIME())
        ORDER BY RecordedAt ASC;

        SET @DayCount = (SELECT DATEDIFF(DAY,
            MIN(RecordedAt), MAX(RecordedAt))
            FROM dbo.CapacityHistory
            WHERE MetricType = @MetricType
              AND RecordedAt >= DATEADD(DAY, -@BasisDays, SYSDATETIME()));

        -- Calculate growth rate (handle zero/null)
        IF @DayCount > 0 AND @OldestMB IS NOT NULL
            SET @GrowthRate = CAST((@CurrentMB - @OldestMB) AS DECIMAL(10,4)) / @DayCount;
        ELSE
            SET @GrowthRate = 0;

        -- Project days until thresholds (handle zero growth)
        IF @GrowthRate > 0 AND @MaxMB > 0
        BEGIN
            SET @Days80  = CAST((@MaxMB * 0.80 - @CurrentMB) / @GrowthRate AS INT);
            SET @Days90  = CAST((@MaxMB * 0.90 - @CurrentMB) / @GrowthRate AS INT);
            SET @Days100 = CAST((@MaxMB - @CurrentMB) / @GrowthRate AS INT);
            IF @Days80 < 0 SET @Days80 = 0;
            IF @Days90 < 0 SET @Days90 = 0;
            IF @Days100 < 0 SET @Days100 = 0;
        END
        ELSE
        BEGIN
            SET @Days80 = 9999;
            SET @Days90 = 9999;
            SET @Days100 = 9999;
        END

        -- Determine alert level
        SET @AlertLevel = CASE
            WHEN @Days100 < 14 OR (@MaxMB > 0 AND @CurrentMB * 100 / @MaxMB > 90) THEN 'CRITICAL'
            WHEN @Days80 < 30 OR (@MaxMB > 0 AND @CurrentMB * 100 / @MaxMB > 80) THEN 'HIGH'
            WHEN @Days80 < 60 THEN 'WARNING'
            ELSE 'OK'
        END;

        -- Store forecast
        INSERT INTO dbo.CapacityForecast
            (MetricType, CurrentValueMB, MaxValueMB, GrowthRatePerDayMB,
             DaysUntil80Pct, DaysUntil90Pct, DaysUntil100Pct,
             Projected80PctDate, Projected100PctDate, ForecastBasis, AlertLevel)
        VALUES
            (@MetricType, @CurrentMB, @MaxMB, @GrowthRate,
             @Days80, @Days90, @Days100,
             CASE WHEN @Days80 < 9999 THEN DATEADD(DAY, @Days80, GETDATE()) ELSE NULL END,
             CASE WHEN @Days100 < 9999 THEN DATEADD(DAY, @Days100, GETDATE()) ELSE NULL END,
             CAST(@BasisDays AS VARCHAR) + 'day', @AlertLevel);

        PRINT '  ' + @MetricType + ': growth=' + CAST(@GrowthRate AS NVARCHAR) + ' MB/day'
            + ', days to 80%=' + CAST(@Days80 AS NVARCHAR)
            + ' [' + @AlertLevel + ']';

        FETCH NEXT FROM metric_cursor INTO @MetricType;
    END

    CLOSE metric_cursor;
    DEALLOCATE metric_cursor;

    PRINT '✓ Capacity forecast generated';
END;
GO

-- ============================================
-- Procedure 3: Check capacity alerts
-- ============================================
IF OBJECT_ID('dbo.usp_CheckCapacityAlerts', 'P') IS NOT NULL
    DROP PROCEDURE dbo.usp_CheckCapacityAlerts;
GO

CREATE PROCEDURE dbo.usp_CheckCapacityAlerts
AS
BEGIN
    SET NOCOUNT ON;

    PRINT '--- Checking capacity alerts ---';

    DECLARE @MetricType VARCHAR(50), @AlertLevel VARCHAR(20);
    DECLARE @Days100 INT, @CurrentMB BIGINT, @MaxMB BIGINT;
    DECLARE @Msg NVARCHAR(500);

    -- Get latest forecast for each metric where alert not yet sent
    DECLARE alert_cursor CURSOR LOCAL FAST_FORWARD FOR
        SELECT f.MetricType, f.AlertLevel, f.DaysUntil100Pct, f.CurrentValueMB, f.MaxValueMB
        FROM dbo.CapacityForecast f
        WHERE f.AlertLevel IN ('CRITICAL', 'HIGH', 'WARNING')
          AND f.AlertSent = 0
          AND f.GeneratedAt >= DATEADD(HOUR, -25, SYSDATETIME())
        ORDER BY
            CASE f.AlertLevel
                WHEN 'CRITICAL' THEN 1
                WHEN 'HIGH' THEN 2
                WHEN 'WARNING' THEN 3
            END;

    OPEN alert_cursor;
    FETCH NEXT FROM alert_cursor INTO @MetricType, @AlertLevel, @Days100, @CurrentMB, @MaxMB;

    WHILE @@FETCH_STATUS = 0
    BEGIN
        SET @Msg = @MetricType + ': ' + CAST(@CurrentMB AS NVARCHAR) + '/'
            + CAST(ISNULL(@MaxMB, 0) AS NVARCHAR) + ' MB. '
            + 'Full in ~' + CAST(@Days100 AS NVARCHAR) + ' days.';

        -- Send alert based on level
        IF @AlertLevel = 'CRITICAL' AND OBJECT_ID('dbo.usp_SendTelegramAlert', 'P') IS NOT NULL
            EXEC dbo.usp_SendTelegramAlert @Severity = N'CRITICAL',
                @Title = N'Disk Space Critical', @Message = @Msg;

        IF @AlertLevel IN ('CRITICAL', 'HIGH') AND OBJECT_ID('dbo.usp_SendTelegramAlert', 'P') IS NOT NULL
            EXEC dbo.usp_SendTelegramAlert @Severity = N'WARNING',
                @Title = N'Capacity Alert', @Message = @Msg;

        -- Mark alert as sent
        UPDATE dbo.CapacityForecast SET AlertSent = 1
        WHERE MetricType = @MetricType
          AND GeneratedAt >= DATEADD(HOUR, -25, SYSDATETIME())
          AND AlertSent = 0;

        PRINT '  ALERT [' + @AlertLevel + ']: ' + @Msg;

        FETCH NEXT FROM alert_cursor INTO @MetricType, @AlertLevel, @Days100, @CurrentMB, @MaxMB;
    END

    CLOSE alert_cursor;
    DEALLOCATE alert_cursor;

    PRINT '✓ Capacity alerts checked';
END;
GO

PRINT '✓ Capacity procedures created:';
PRINT '  - usp_CollectCapacityMetrics';
PRINT '  - usp_ForecastCapacity';
PRINT '  - usp_CheckCapacityAlerts';
GO
