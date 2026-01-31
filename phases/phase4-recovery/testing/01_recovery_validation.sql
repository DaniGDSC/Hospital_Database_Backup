-- Validate restored databases (CHECKDB + smoke tests)
USE master;
GO

SET NOCOUNT ON;

PRINT '=== Running recovery validation ===';

DECLARE @dbs TABLE (DbName SYSNAME);
INSERT INTO @dbs(DbName) VALUES
    ('HospitalBackupDemo_Recovery'),
    ('HospitalBackupDemo_PITR'),
    ('HospitalBackupDemo_FromS3');

DECLARE @db SYSNAME;
DECLARE @sql NVARCHAR(MAX);

DECLARE db_cursor CURSOR FAST_FORWARD FOR
SELECT DbName FROM @dbs;

OPEN db_cursor;
FETCH NEXT FROM db_cursor INTO @db;

WHILE @@FETCH_STATUS = 0
BEGIN
    IF DB_ID(@db) IS NULL
    BEGIN
        PRINT 'Skipping ' + @db + ' (not found).';
        FETCH NEXT FROM db_cursor INTO @db;
        CONTINUE;
    END

    PRINT '--- DBCC CHECKDB on ' + @db;
    SET @sql = N'DBCC CHECKDB(''' + @db + N''') WITH NO_INFOMSGS;';
    EXEC (@sql);

    PRINT '--- Row counts for key tables in ' + @db;
    SET @sql = N'
        SELECT ''Patients'' AS TableName, COUNT(*) AS Rows FROM ' + QUOTENAME(@db) + N'.dbo.Patients
        UNION ALL
        SELECT ''Appointments'', COUNT(*) FROM ' + QUOTENAME(@db) + N'.dbo.Appointments
        UNION ALL
        SELECT ''Billing'', COUNT(*) FROM ' + QUOTENAME(@db) + N'.dbo.Billing;
    ';
    EXEC (@sql);

    FETCH NEXT FROM db_cursor INTO @db;
END

CLOSE db_cursor;
DEALLOCATE db_cursor;

PRINT '✓ Recovery validation completed.';
GO
