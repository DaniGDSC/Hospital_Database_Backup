-- Rollback: Billing tables (Phase 1.2c)
-- Drops: Payments, BillingDetails, Billing (reverse FK order)
USE HospitalBackupDemo;
GO

SET NOCOUNT ON;

PRINT '=== Rollback: Billing Tables ===';

IF OBJECT_ID('dbo.Payments', 'U') IS NOT NULL DROP TABLE dbo.Payments;
IF OBJECT_ID('dbo.BillingDetails', 'U') IS NOT NULL DROP TABLE dbo.BillingDetails;
IF OBJECT_ID('dbo.Billing', 'U') IS NOT NULL DROP TABLE dbo.Billing;
GO

PRINT '✓ Billing tables dropped';
GO
