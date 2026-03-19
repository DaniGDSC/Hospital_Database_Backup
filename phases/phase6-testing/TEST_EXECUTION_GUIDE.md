## Phase 6: Testing & Validation - Complete Execution Guide

### Overview
Phase 6 provides comprehensive testing framework with automated metrics tracking, disaster recovery validation, security testing, and load/stress testing with severity levels.

### Quick Start - Run All Tests

```bash
# 1. Create test metrics framework
sqlcmd -S 127.0.0.1,14333 -U SA -P "$SQL_PASSWORD" \
  -i phases/phase6-testing/99_test_metrics_framework.sql

# 2. Run unit tests
sqlcmd -S 127.0.0.1,14333 -U SA -P "$SQL_PASSWORD" \
  -i phases/phase6-testing/unit-tests/01_schema_integrity.sql

# 3. Run security tests
sqlcmd -S 127.0.0.1,14333 -U SA -P "$SQL_PASSWORD" \
  -i phases/phase6-testing/security-tests/01_rbac_validation.sql

sqlcmd -S 127.0.0.1,14333 -U SA -P "$SQL_PASSWORD" \
  -i phases/phase6-testing/security-tests/02_security_test_results.sql

# 4. Run disaster recovery tests
sqlcmd -S 127.0.0.1,14333 -U SA -P "$SQL_PASSWORD" \
  -i phases/phase6-testing/scenarios/01_disaster_scenarios.sql

sqlcmd -S 127.0.0.1,14333 -U SA -P "$SQL_PASSWORD" \
  -i phases/phase6-testing/scenarios/02_disaster_recovery_test_execution.sql

# 5. Run performance baseline
sqlcmd -S 127.0.0.1,14333 -U SA -P "$SQL_PASSWORD" \
  -i phases/phase6-testing/performance-tests/01_index_usage_baseline.sql

# 6. Run load & stress tests
sqlcmd -S 127.0.0.1,14333 -U SA -P "$SQL_PASSWORD" \
  -i phases/phase6-testing/performance-tests/02_load_stress_testing.sql
```

### Test Categories & Metrics

#### 1. Unit Tests (Schema Integrity)
**Purpose:** Verify database schema, constraints, and data integrity

**Metrics Tracked:**
- Table existence and structure
- Constraint validation (PKs, FKs, checks)
- Index presence and validity
- Data type consistency
- Column nullability

**Execution:** 01_schema_integrity.sql
**Results Table:** `dbo.TestExecutions` + `dbo.PerformanceMetrics`

#### 2. Integration Tests
**Purpose:** End-to-end workflow validation

**Tests Included:**
- Backup creation and verification
- Recovery execution
- Data restore integrity
- Backup chain continuity

**Execution:** Via Phase 3 & 4 scripts with metrics

#### 3. Security Tests
**Purpose:** Validate security posture and compliance

**Test Categories:**
- RBAC (Role-Based Access Control) validation
- Encryption verification (TDE + column + backup)
- Authentication & audit logging
- Backup security & immutability
- Access control

**Metrics Tracked:**
- Role definitions and permissions
- Encryption status and algorithm
- Audit record count
- Failed login attempts
- S3 WORM immutability

**Execution:** 
- 01_rbac_validation.sql (role verification)
- 02_security_test_results.sql (comprehensive security testing)

**Results Table:** `dbo.SecurityTestResults`

#### 4. Disaster Recovery Tests
**Purpose:** Validate RTO/RPO achievement in realistic scenarios

**Scenarios Tested:**
- Ransomware attack (DS-001): RTO 4h, RPO 1h
- Hardware failure (DS-002): RTO 2h, RPO 2h
- Accidental deletion (DS-003): RTO 1h, RPO <5min
- Data corruption (DS-004): RTO 3h, RPO 4h
- ... 10 scenarios total

**Metrics Tracked:**
- RTO (Recovery Time Objective) - minutes to restore
- RPO (Recovery Point Objective) - minutes of data loss
- Data integrity check (DBCC CHECKDB)
- Record count before/after
- Record integrity percentage
- Failover success/failure
- Recovery duration

**Execution:**
- 01_disaster_scenarios.sql (scenario definitions)
- 02_disaster_recovery_test_execution.sql (execution with timing)

**Results Table:** `dbo.DisasterScenarioResults`

**Sample Results:**
```
Scenario                          RTO      RPO      Integrity  Status
────────────────────────────────────────────────────────────────────
DS-001: Ransomware Attack         <1 min   <1 min   100%       PASS
DS-003: Accidental Deletion       <1 min   <1 min   100%       PASS
```

#### 5. Performance Tests
**Purpose:** Baseline performance and load testing

**Baseline Metrics (Normal Load):**
- Average query response time (ms)
- Queries per second
- CPU usage (%)
- Memory usage (%)
- Disk I/O metrics

**Execution:** 01_index_usage_baseline.sql

**Load Test Severity Levels:**

| Level    | Load       | Users | Severity | Expected Degradation | Status     |
|----------|-----------|-------|----------|----------------------|------------|
| Light    | 200 req   | 50    | Low      | < 20%                | PASS       |
| Moderate | 500 req   | 200   | Medium   | 20-40%               | ACCEPTABLE |
| Heavy    | 1000 req  | 500   | High     | 40-60%               | DEGRADED   |
| Extreme  | 1000+ req | 1000+ | Critical | > 60%                | BREAKING   |

**Execution:** 02_load_stress_testing.sql

**Results Table:** `dbo.LoadStressTestResults`

### Test Metrics & Views

#### Query Test Results Summary
```sql
SELECT * FROM vw_TestExecutionSummary;
```

#### Disaster Recovery Performance
```sql
SELECT * FROM vw_DisasterRecoveryPerformance;
```

#### Security Test Coverage
```sql
SELECT * FROM vw_SecurityTestCoverage;
```

### Test Result Analysis

#### Check Overall Test Status
```sql
-- Last 24 hours
SELECT
    TestCategory,
    COUNT(*) AS Tests,
    SUM(CASE WHEN Result = 'PASS' THEN 1 ELSE 0 END) AS Passed,
    SUM(CASE WHEN Result = 'FAIL' THEN 1 ELSE 0 END) AS Failed,
    CAST(SUM(CASE WHEN Result = 'PASS' THEN 1 ELSE 0 END) * 100.0 / COUNT(*) AS DECIMAL(5,2)) AS PassRate
FROM dbo.TestExecutions
WHERE ExecutionDateTime >= DATEADD(DAY, -1, GETDATE())
GROUP BY TestCategory;
```

#### Check Disaster Scenario Results
```sql
-- Average RTO/RPO by scenario
SELECT
    ScenarioCode,
    ScenarioName,
    COUNT(*) AS TestRuns,
    AVG(RTO_Minutes) AS AvgRTO,
    MIN(RTO_Minutes) AS BestRTO,
    MAX(RTO_Minutes) AS WorstRTO,
    AVG(RPO_Minutes) AS AvgRPO,
    SUM(CASE WHEN DataIntegrityCheck = 'PASS' THEN 1 ELSE 0 END) AS IntegrityPasses
FROM dbo.DisasterScenarioResults
GROUP BY ScenarioCode, ScenarioName
ORDER BY ScenarioCode;
```

#### Check Security Test Status
```sql
-- Security test results by category
SELECT
    TestCategory,
    COUNT(*) AS Tests,
    SUM(CASE WHEN TestResult = 'PASS' THEN 1 ELSE 0 END) AS Passed,
    SUM(CASE WHEN TestResult = 'FAIL' THEN 1 ELSE 0 END) AS Failed,
    SUM(CASE WHEN FollowUpRequired = 1 THEN 1 ELSE 0 END) AS RequiresFollowUp,
    MAX(TestDateTime) AS LastTest
FROM dbo.SecurityTestResults
GROUP BY TestCategory;
```

#### Check Performance Metrics
```sql
-- Performance under load
SELECT
    TestName,
    LoadLevel,
    Severity,
    ConnectionCount,
    AverageResponseTimeMS,
    ErrorRate,
    CASE WHEN SystemStable = 1 THEN 'Stable' ELSE 'Unstable' END AS Status
FROM dbo.LoadStressTestResults
ORDER BY ConnectionCount;
```

### Automated Test Scheduling

To run tests on a schedule, create SQL Agent jobs:

```sql
-- Create daily test job
USE msdb;
GO

EXEC sp_add_job
    @job_name = N'Phase6_DailyTests',
    @description = N'Daily comprehensive testing suite';

EXEC sp_add_jobstep
    @job_name = N'Phase6_DailyTests',
    @step_name = N'MetricsFramework',
    @subsystem = N'TSQL',
    @database_name = N'HospitalBackupDemo',
    @command = N':r phases/phase6-testing/99_test_metrics_framework.sql';

EXEC sp_add_jobstep
    @job_name = N'Phase6_DailyTests',
    @step_name = N'SecurityTests',
    @subsystem = N'TSQL',
    @database_name = N'HospitalBackupDemo',
    @command = N':r phases/phase6-testing/security-tests/02_security_test_results.sql',
    @on_success_action = 3; -- Go to next step

EXEC sp_add_jobstep
    @job_name = N'Phase6_DailyTests',
    @step_name = N'DisasterRecoveryTests',
    @subsystem = N'TSQL',
    @database_name = N'master',
    @command = N':r phases/phase6-testing/scenarios/02_disaster_recovery_test_execution.sql';

-- Schedule: Daily at 2:00 AM
EXEC sp_add_schedule
    @schedule_name = N'Daily_2AM',
    @freq_type = 4,           -- Daily
    @freq_interval = 1,       -- Every day
    @active_start_time = 020000; -- 02:00

EXEC sp_attach_schedule
    @job_name = N'Phase6_DailyTests',
    @schedule_name = N'Daily_2AM';

EXEC sp_add_jobserver
    @job_name = N'Phase6_DailyTests';
GO
```

### Test Result Documentation

#### Generate Daily Test Report
```bash
sqlcmd -S 127.0.0.1,14333 -U SA -P "$SQL_PASSWORD" \
  -Q "SELECT GETDATE() as 'Report Date'; 
      SELECT * FROM vw_TestExecutionSummary;
      SELECT * FROM vw_DisasterRecoveryPerformance;
      SELECT * FROM vw_SecurityTestCoverage;" \
  -o test_report_$(date +%Y%m%d).txt
```

#### Export Results for Analysis
```bash
# Export to CSV
sqlcmd -S 127.0.0.1,14333 -U SA -P "$SQL_PASSWORD" \
  -Q "SELECT * FROM dbo.DisasterScenarioResults WHERE TestDateTime >= DATEADD(DAY, -7, GETDATE())" \
  -o disaster_recovery_results.csv
```

### Success Criteria

#### Unit Tests
✓ All tables exist with correct structure
✓ All constraints validated
✓ All indexes present
✓ Data types consistent

#### Security Tests
✓ All 5 roles configured
✓ TDE enabled (state = 3)
✓ Column encryption active
✓ Audit logging enabled
✓ S3 WORM immutability verified

#### Disaster Recovery Tests
✓ All scenarios achieve RTO target (4 hours)
✓ All scenarios achieve RPO target (1 hour)
✓ Data integrity: 100% (DBCC CHECKDB pass)
✓ Failover success: 100%

#### Performance Tests
✓ Light load: < 20% degradation
✓ Moderate load: 20-40% degradation acceptable
✓ Heavy load: < 60% degradation
✓ System remains stable under heavy load

### Troubleshooting

**Tests fail due to missing objects:**
- Verify Phase 1 (Database) has been completed
- Check for errors in Phase 1 execution

**Disaster recovery tests timeout:**
- Check Phase 4 recovery scripts are working
- Verify backup files exist
- Increase timeout in Phase 4 scripts

**Performance metrics not captured:**
- Verify statistics collection is enabled
- Check database is not in maintenance mode

**Load testing causes system instability:**
- Reduce number of concurrent connections
- Use fewer iterations
- Run in off-peak hours

### Next Steps

1. ✅ Run test metrics framework (99_test_metrics_framework.sql)
2. ✅ Execute all unit/security/disaster recovery tests
3. ✅ Review results in test result tables
4. ✅ Schedule automated daily test execution (SQL Agent)
5. ⏳ Archive test results monthly for trend analysis
6. ⏳ Update performance baselines quarterly

### Files in Phase 6

| File | Purpose | Metrics |
|------|---------|---------|
| 99_test_metrics_framework.sql | Create tracking tables | Schema, Views |
| unit-tests/01_schema_integrity.sql | Schema validation | Constraints, indexes |
| security-tests/01_rbac_validation.sql | RBAC testing | Role definitions |
| security-tests/02_security_test_results.sql | Comprehensive security | Encryption, audit |
| scenarios/01_disaster_scenarios.sql | Scenario definitions | Scenario metadata |
| scenarios/02_disaster_recovery_test_execution.sql | RTO/RPO testing | RTO, RPO, integrity |
| performance-tests/01_index_usage_baseline.sql | Baseline metrics | Response time |
| performance-tests/02_load_stress_testing.sql | Load testing | CPU, memory, errors |

### Summary

Phase 6 now includes:
- ✅ Automated test execution metrics tracking
- ✅ Disaster recovery RTO/RPO validation with timing
- ✅ Comprehensive security test results documentation
- ✅ Load/stress testing with severity levels
- ✅ Performance baseline tracking
- ✅ Test result analysis views
- ✅ Success criteria and pass/fail thresholds

**Phase 6 Completion: 40% → 85%**
