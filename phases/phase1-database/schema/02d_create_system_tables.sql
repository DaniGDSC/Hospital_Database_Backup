-- System tables: AuditLog, BackupHistory, SecurityEvents, SystemConfiguration
-- Dependencies: None (these are standalone system tables)

SET QUOTED_IDENTIFIER ON;
GO

USE HospitalBackupDemo;
GO

PRINT '╔════════════════════════════════════════════════════════════════╗';
PRINT '║   Phase 1.2d: System Tables                                    ║';
PRINT '║   AuditLog, BackupHistory, SecurityEvents, SystemConfiguration ║';
PRINT '╚════════════════════════════════════════════════════════════════╝';
PRINT '';

-- ============================================
-- TABLE 15: AuditLog (Nhật ký kiểm toán)
-- ============================================

PRINT 'Creating table: AuditLog...';

IF OBJECT_ID('dbo.AuditLog', 'U') IS NOT NULL
BEGIN
    PRINT '  (already exists — skipping)';
END
ELSE
CREATE TABLE dbo.AuditLog (
    AuditID BIGINT IDENTITY(1,1) NOT NULL,
    AuditDate DATETIME2 DEFAULT SYSDATETIME(),
    TableName NVARCHAR(128) NOT NULL,
    SchemaName NVARCHAR(128) DEFAULT 'dbo',
    RecordID INT NOT NULL,
    Action NVARCHAR(20) CHECK (Action IN ('INSERT', 'UPDATE', 'DELETE', 'SELECT')) NOT NULL,
    ActionType NVARCHAR(50),
    UserName NVARCHAR(128) DEFAULT SUSER_SNAME(),
    DatabaseUser NVARCHAR(128) DEFAULT USER_NAME(),
    HostName NVARCHAR(128) DEFAULT HOST_NAME(),
    ApplicationName NVARCHAR(128) DEFAULT APP_NAME(),
    IPAddress NVARCHAR(50),
    SessionID INT DEFAULT @@SPID,
    TransactionID NVARCHAR(50),
    OldValues NVARCHAR(MAX),
    NewValues NVARCHAR(MAX),
    ChangedColumns NVARCHAR(500),
    SQLStatement NVARCHAR(MAX),
    IsSuccess BIT DEFAULT 1,
    ErrorMessage NVARCHAR(1000),
    Severity NVARCHAR(20) CHECK (Severity IN ('Low', 'Medium', 'High', 'Critical')) DEFAULT 'Low',
    IsSecurityEvent BIT DEFAULT 0,
    RequiresReview BIT DEFAULT 0,
    ReviewedBy NVARCHAR(100),
    ReviewedDate DATETIME2,
    Notes NVARCHAR(1000),

    CONSTRAINT PK_AuditLog PRIMARY KEY CLUSTERED (AuditID)
);
GO

PRINT '  ✓ AuditLog created';

-- ============================================
-- TABLE 16: BackupHistory (Lịch sử sao lưu)
-- ============================================

PRINT 'Creating table: BackupHistory...';

IF OBJECT_ID('dbo.BackupHistory', 'U') IS NOT NULL
BEGIN
    PRINT '  (already exists — skipping)';
END
ELSE
CREATE TABLE dbo.BackupHistory (
    BackupHistoryID INT IDENTITY(1,1) NOT NULL,
    BackupType NVARCHAR(20) CHECK (BackupType IN ('Full', 'Differential', 'Transaction Log')) NOT NULL,
    BackupStartDate DATETIME2 NOT NULL,
    BackupEndDate DATETIME2,
    BackupDuration AS (DATEDIFF(SECOND, BackupStartDate, BackupEndDate)) PERSISTED,
    BackupFileName NVARCHAR(500) NOT NULL,
    BackupFileSize BIGINT, -- in bytes
    BackupFileSizeMB AS (CAST(BackupFileSize AS DECIMAL(18,2)) / 1024 / 1024) PERSISTED,
    BackupLocation NVARCHAR(500) NOT NULL,
    BackupDevice NVARCHAR(20) CHECK (BackupDevice IN ('Local Disk', 'Network Share', 'S3', 'Azure Blob', 'Other')) DEFAULT 'Local Disk',
    S3Bucket NVARCHAR(100),
    S3Key NVARCHAR(500),
    IsEncrypted BIT DEFAULT 1,
    EncryptionAlgorithm NVARCHAR(50),
    CertificateName NVARCHAR(128),
    IsCompressed BIT DEFAULT 1,
    CompressionRatio DECIMAL(5,2),
    BackupStatus NVARCHAR(20) CHECK (BackupStatus IN ('In Progress', 'Completed', 'Failed', 'Cancelled')) NOT NULL,
    ErrorMessage NVARCHAR(1000),
    VerificationStatus NVARCHAR(20) CHECK (VerificationStatus IN ('Not Verified', 'Verified', 'Failed')),
    VerificationDate DATETIME2,
    VerifiedBy NVARCHAR(100),
    RecoveryModel NVARCHAR(20),
    DatabaseSizeMB DECIMAL(18,2),
    LSN NUMERIC(25,0), -- Log Sequence Number
    FirstLSN NUMERIC(25,0),
    LastLSN NUMERIC(25,0),
    CheckpointLSN NUMERIC(25,0),
    IsFullBackupBase BIT DEFAULT 0,
    FullBackupBaseID INT, -- Reference to base full backup
    ExpirationDate DATE,
    RetentionDays INT DEFAULT 30,
    IsDeleted BIT DEFAULT 0,
    DeletedDate DATETIME2,
    BackupUser NVARCHAR(100) DEFAULT SUSER_SNAME(),
    BackupHost NVARCHAR(100) DEFAULT HOST_NAME(),
    BackupSoftware NVARCHAR(100) DEFAULT 'SQL Server',
    BackupVersion NVARCHAR(50),
    Notes NVARCHAR(1000),
    CreatedDate DATETIME2 DEFAULT SYSDATETIME(),

    CONSTRAINT PK_BackupHistory PRIMARY KEY CLUSTERED (BackupHistoryID),
    CONSTRAINT FK_BackupHistory_FullBackupBase FOREIGN KEY (FullBackupBaseID)
        REFERENCES dbo.BackupHistory(BackupHistoryID),
    CONSTRAINT CHK_BackupHistory_FileSize CHECK (BackupFileSize >= 0),
    CONSTRAINT CHK_BackupHistory_RetentionDays CHECK (RetentionDays > 0)
);
GO

PRINT '  ✓ BackupHistory created';

-- ============================================
-- TABLE 17: SecurityEvents (Sự kiện bảo mật)
-- ============================================

PRINT 'Creating table: SecurityEvents...';

IF OBJECT_ID('dbo.SecurityEvents', 'U') IS NOT NULL
BEGIN
    PRINT '  (already exists — skipping)';
END
ELSE
CREATE TABLE dbo.SecurityEvents (
    EventID BIGINT IDENTITY(1,1) NOT NULL,
    EventDate DATETIME2 DEFAULT SYSDATETIME(),
    EventType NVARCHAR(50) CHECK (EventType IN ('Login Success', 'Login Failed', 'Logout', 'Permission Denied', 'Unauthorized Access', 'Data Access', 'Data Modification', 'Schema Change', 'User Created', 'User Deleted', 'Role Changed', 'Password Changed', 'Encryption Event', 'Backup Event', 'Restore Event', 'Other')) NOT NULL,
    Severity NVARCHAR(20) CHECK (Severity IN ('Info', 'Warning', 'Error', 'Critical')) NOT NULL,
    LoginName NVARCHAR(128),
    DatabaseUser NVARCHAR(128),
    SourceIP NVARCHAR(50),
    HostName NVARCHAR(128),
    ApplicationName NVARCHAR(128),
    ObjectType NVARCHAR(50),
    ObjectSchema NVARCHAR(128),
    ObjectName NVARCHAR(128),
    ActionPerformed NVARCHAR(200),
    IsSuccessful BIT NOT NULL,
    ErrorNumber INT,
    ErrorMessage NVARCHAR(1000),
    AdditionalInfo NVARCHAR(MAX),
    ThreatLevel NVARCHAR(20) CHECK (ThreatLevel IN ('Low', 'Medium', 'High', 'Critical')) DEFAULT 'Low',
    IsBlocked BIT DEFAULT 0,
    RequiresInvestigation BIT DEFAULT 0,
    InvestigatedBy NVARCHAR(100),
    InvestigatedDate DATETIME2,
    InvestigationNotes NVARCHAR(2000),
    ResolutionStatus NVARCHAR(20) CHECK (ResolutionStatus IN ('Open', 'In Progress', 'Resolved', 'Closed', 'False Positive')),
    ResolvedBy NVARCHAR(100),
    ResolvedDate DATETIME2,

    CONSTRAINT PK_SecurityEvents PRIMARY KEY CLUSTERED (EventID)
);
GO

PRINT '  ✓ SecurityEvents created';

-- ============================================
-- TABLE 18: SystemConfiguration (Cấu hình hệ thống)
-- ============================================

PRINT 'Creating table: SystemConfiguration...';

IF OBJECT_ID('dbo.SystemConfiguration', 'U') IS NOT NULL
BEGIN
    PRINT '  (already exists — skipping)';
END
ELSE
CREATE TABLE dbo.SystemConfiguration (
    ConfigID INT IDENTITY(1,1) NOT NULL,
    ConfigKey NVARCHAR(100) NOT NULL,
    ConfigValue NVARCHAR(1000),
    ConfigCategory NVARCHAR(50) CHECK (ConfigCategory IN ('General', 'Security', 'Backup', 'Performance', 'Notification', 'Integration', 'Other')) NOT NULL,
    DataType NVARCHAR(20) CHECK (DataType IN ('String', 'Integer', 'Decimal', 'Boolean', 'Date', 'JSON')) DEFAULT 'String',
    Description NVARCHAR(500),
    DefaultValue NVARCHAR(1000),
    IsEncrypted BIT DEFAULT 0,
    IsActive BIT DEFAULT 1,
    AllowUserModification BIT DEFAULT 0,
    LastModifiedDate DATETIME2 DEFAULT SYSDATETIME(),
    ModifiedBy NVARCHAR(100) DEFAULT SUSER_SNAME(),
    CreatedDate DATETIME2 DEFAULT SYSDATETIME(),
    CreatedBy NVARCHAR(100) DEFAULT SUSER_SNAME(),

    CONSTRAINT PK_SystemConfiguration PRIMARY KEY CLUSTERED (ConfigID),
    CONSTRAINT UK_SystemConfiguration_Key UNIQUE (ConfigKey)
);
GO

PRINT '  ✓ SystemConfiguration created';

-- ============================================
-- INSERT DEFAULT CONFIGURATION VALUES
-- ============================================

PRINT '';
PRINT 'Inserting default configuration values...';

INSERT INTO dbo.SystemConfiguration (ConfigKey, ConfigValue, ConfigCategory, DataType, Description, DefaultValue)
VALUES
    ('BackupRetentionDays', '30', 'Backup', 'Integer', 'Number of days to retain local backups', '30'),
    ('S3RetentionDays', '90', 'Backup', 'Integer', 'Number of days to retain S3 backups', '90'),
    ('EnableTDE', 'true', 'Security', 'Boolean', 'Enable Transparent Data Encryption', 'true'),
    ('EnableAudit', 'true', 'Security', 'Boolean', 'Enable database auditing', 'true'),
    ('MaxFailedLoginAttempts', '5', 'Security', 'Integer', 'Maximum failed login attempts before lockout', '5'),
    ('SessionTimeoutMinutes', '30', 'Security', 'Integer', 'Session timeout in minutes', '30'),
    ('BackupCompressionEnabled', 'true', 'Backup', 'Boolean', 'Enable backup compression', 'true'),
    ('BackupEncryptionEnabled', 'true', 'Backup', 'Boolean', 'Enable backup encryption', 'true'),
    ('EmailNotificationEnabled', 'true', 'Notification', 'Boolean', 'Enable email notifications', 'true'),
    ('NotificationEmail', 'admin@hospital.com', 'Notification', 'String', 'Default notification email', 'admin@hospital.com'),
    ('DatabaseVersion', '1.0.0', 'General', 'String', 'Database schema version', '1.0.0'),
    ('MaintenanceWindow', '02:00-04:00', 'General', 'String', 'Maintenance window time range', '02:00-04:00');
GO

PRINT '  ✓ Default configuration inserted';

-- ============================================
-- SUMMARY OF ALL CREATED TABLES
-- ============================================

PRINT '';
PRINT '╔════════════════════════════════════════════════════════════════╗';
PRINT '║   ✓ All Tables Created Successfully                            ║';
PRINT '╚════════════════════════════════════════════════════════════════╝';
PRINT '';

-- Display table count and summary
SELECT
    'Total Tables' AS Metric,
    CAST(COUNT(*) AS NVARCHAR) AS Value
FROM sys.tables
WHERE schema_id = SCHEMA_ID('dbo')

UNION ALL

SELECT
    'Total Columns',
    CAST(SUM(column_count) AS NVARCHAR)
FROM (
    SELECT COUNT(*) as column_count
    FROM sys.columns c
    INNER JOIN sys.tables t ON c.object_id = t.object_id
    WHERE t.schema_id = SCHEMA_ID('dbo')
    GROUP BY t.object_id
) AS col_counts

UNION ALL

SELECT
    'Total Foreign Keys',
    CAST(COUNT(*) AS NVARCHAR)
FROM sys.foreign_keys
WHERE schema_id = SCHEMA_ID('dbo')

UNION ALL

SELECT
    'Total Check Constraints',
    CAST(COUNT(*) AS NVARCHAR)
FROM sys.check_constraints
WHERE schema_id = SCHEMA_ID('dbo');

GO

PRINT '';
PRINT 'Created Tables:';
PRINT '─────────────────────────────────────────────────────────────────';

SELECT
    ROW_NUMBER() OVER (ORDER BY t.name) AS [#],
    t.name AS TableName,
    (SELECT COUNT(*) FROM sys.columns c WHERE c.object_id = t.object_id) AS Columns,
    (SELECT COUNT(*) FROM sys.foreign_keys fk WHERE fk.parent_object_id = t.object_id) AS ForeignKeys,
    (SELECT COUNT(*) FROM sys.check_constraints cc WHERE cc.parent_object_id = t.object_id) AS CheckConstraints
FROM sys.tables t
WHERE t.schema_id = SCHEMA_ID('dbo')
ORDER BY t.name;

GO

PRINT '';
PRINT '✓ System tables created (4 tables + default config)';
GO
