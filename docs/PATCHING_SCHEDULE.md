# Patching Schedule

**Version source of truth**: `config/versions.conf`

---

## SQL Server Patching Policy

| Patch Type | Description | Apply Within |
|---|---|---|
| **Critical Security (GDR)** | Zero-day / CVE fixes | 7 days |
| **Cumulative Update (CU)** | All fixes bundled | 90 days |
| **Service Pack** | Major updates | 180 days |

### Promotion Path

```
Dev (immediate) → Staging (1 week) → Production (2 weeks)
```

| Environment | When to Apply | Approval | Test After |
|---|---|---|---|
| **Development** | Immediately | None | Basic smoke test |
| **Staging** | After 1 week on dev | IT Manager | Full DR test suite |
| **Production** | After 2 weeks on staging | Senior DBA + IT Manager | All 10 DR scenarios |

### Production Patching Procedure

1. Schedule maintenance window: **Sunday 02:00-06:00**
2. Take full backup before patching
3. Apply patch
4. Run `verify_versions.sh` — all checks PASS
5. Run `04_sqlserver_patch_check.sql` — build meets minimum
6. Run DR drill — verify backup/restore still works
7. Update `config/versions.conf` with new minimum build
8. Commit change to Git

---

## AWS CLI Update Policy

| Check Frequency | Test Path | Approval |
|---|---|---|
| Monthly | Dev → Staging → Production | Senior DBA for production |

**Breaking change handling**: If AWS CLI syntax changes affect S3 backup scripts:
1. Test all S3 upload/download scripts on dev
2. Verify backup integrity on staging
3. Update scripts if needed
4. Full regression test before production

---

## Tool Version Change Process

1. Developer creates Git PR updating `config/versions.conf`
2. PR includes: reason for change, tested on dev
3. CI runs `verify_versions.sh` on staging
4. Senior DBA reviews and approves
5. Schedule maintenance window for production
6. Deploy with `scripts/deploy_production.sh` (includes version check gate)
7. Post-deploy: `verify_versions.sh` confirms versions match

---

## Monitoring

- **Automated check**: `HospitalBackup_Monthly_Patch_Check` SQL Agent job
- **Manual check**: `./scripts/utilities/verify_versions.sh`
- **Update check**: `./scripts/utilities/check_for_updates.sh`
