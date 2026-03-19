# Post-Incident Review Template

**HIPAA 45 CFR 164.308(a)(7)**: Contingency Plan — Review and Update

---

## Incident Summary

| Field | Value |
|---|---|
| **Incident ID** | INC-YYYYMMDD-NNN |
| **Date/Time Detected** | |
| **Date/Time Resolved** | |
| **Total Duration** | |
| **Severity** | SEV-1 / SEV-2 / SEV-3 |
| **DR Scenario** | DS-NNN (if applicable) |
| **Affected Systems** | |
| **Affected Database** | |
| **Patients Affected** | Yes / No |
| **PHI Exposed** | Yes / No (if Yes → HIPAA breach assessment) |
| **Incident Commander** | |
| **Report Author** | |

---

## Timeline

| Time (UTC) | Event | Action Taken | By Whom |
|---|---|---|---|
| | Alert received | | Automated |
| | DBA acknowledged | | |
| | Investigation started | | |
| | Root cause identified | | |
| | Recovery initiated | | |
| | Recovery completed | | |
| | Verification passed | | |
| | Incident closed | | |

---

## Root Cause Analysis (5 Whys)

**What happened:**

> _[Describe the incident in factual terms]_

| Why # | Question | Answer |
|---|---|---|
| 1 | Why did the incident occur? | |
| 2 | Why did that happen? | |
| 3 | Why did that happen? | |
| 4 | Why did that happen? | |
| **5** | **Root cause:** | |

---

## Impact Assessment

| Category | Assessment |
|---|---|
| **Systems affected** | |
| **Data affected** | Yes / No |
| **Data loss (records)** | |
| **Data loss (time window)** | |
| **PHI exposed** | Yes / No |
| **Patient care impact** | None / Minimal / Moderate / Severe |
| **Financial impact** | |
| **Reputational impact** | |

---

## Recovery Metrics

| Metric | Target | Actual | Status |
|---|---|---|---|
| **RTO** | _[from DR plan]_ | | PASS / FAIL |
| **RPO** | _[from DR plan]_ | | PASS / FAIL |
| **Detection time** | 15 min | | |
| **Recovery time** | | | |

---

## What Went Well

- _[List things that worked as planned]_

## What Needs Improvement

- _[List gaps discovered during the incident]_

---

## Action Items

| # | Action | Owner | Due Date | Priority | Status |
|---|---|---|---|---|---|
| 1 | | | | High/Med/Low | Open |
| 2 | | | | | |
| 3 | | | | | |

---

## HIPAA Breach Assessment

_Complete this section if PHI was potentially accessed or exposed._

| Question | Answer |
|---|---|
| Was PHI accessed by unauthorized person? | |
| Was PHI exposed due to system failure? | |
| Number of records affected | |
| Type of PHI involved | |
| Risk assessment (4-factor per 164.402) | |
| Breach notification required? | Yes / No |
| Notification deadline (60 days from discovery) | |
| Patient notification method | Mail / Email |
| HHS notification required? | Yes / No |
| Media notification required (>=500)? | Yes / No |
| Legal review completed? | Yes / No |

---

## Approvals

| Role | Name | Date | Signature |
|---|---|---|---|
| Incident Commander | | | |
| IT Manager | | | |
| Compliance Officer | | | |
