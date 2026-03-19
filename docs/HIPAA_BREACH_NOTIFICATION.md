# HIPAA Breach Notification Procedure

**Regulatory basis:**
- 45 CFR 164.402 — Breach definition and risk assessment
- 45 CFR 164.404 — Notification to individuals (60 days)
- 45 CFR 164.406 — Notification to media (>=500 in one state)
- 45 CFR 164.408 — Notification to HHS Secretary

---

## Step 1: Determine if a Breach Occurred

A "breach" is unauthorized acquisition, access, use, or disclosure of PHI that compromises its security or privacy.

### 4-Factor Risk Assessment (45 CFR 164.402)

| Factor | Question | Assessment |
|---|---|---|
| **1. Nature of PHI** | What type of PHI was involved? (NationalID, DOB, medical records, billing) | |
| **2. Unauthorized person** | Who accessed/received the PHI? (known/unknown, internal/external) | |
| **3. Was PHI actually viewed?** | Was the PHI actually acquired or only potentially accessed? | |
| **4. Extent of risk mitigation** | What steps were taken to reduce the risk? (data encrypted, access revoked, etc.) | |

**Decision**: If the risk assessment shows **low probability** that PHI was compromised → **not a reportable breach**. Document the assessment and reasoning.

### Exceptions (NOT a breach)
- PHI was encrypted per NIST standards (TDE AES-256 qualifies)
- Unintentional access by workforce member acting in good faith
- Inadvertent disclosure between authorized persons

---

## Step 2: Classify Breach Size

| Size | Requirement | Timeline |
|---|---|---|
| **< 500 individuals** | Log breach; report to HHS annually | Within 60 days of calendar year end |
| **>= 500 individuals** | Immediate HHS notification + media notification | Within 60 days of discovery |

---

## Step 3: Notification Timeline

| Day | Action | Responsible |
|---|---|---|
| **Day 0** | Breach discovered | IT / DBA |
| **Day 1** | Legal team notified | IT Manager |
| **Day 1-3** | Investigation and risk assessment started | DBA + Legal |
| **Day 7** | Internal breach report completed | Compliance Officer |
| **Day 14** | Risk assessment finalized | Legal + Compliance |
| **Day 30** | Patient notification letters drafted | Legal |
| **Day 45** | Notification letters reviewed and approved | Hospital Director |
| **Day 60** | **DEADLINE: All notifications sent** | Legal + Admin |

---

## Step 4: Required Notifications

### To Patients (45 CFR 164.404)

**Method**: First-class mail (or email if patient previously agreed)
**Timing**: Without unreasonable delay, no later than 60 days

**Letter must include:**
1. Brief description of what happened and dates
2. Types of PHI involved (e.g., name, NationalID, medical records)
3. Steps the individual should take to protect themselves
4. What the organization is doing in response
5. Contact information for questions

### To HHS Secretary (45 CFR 164.408)

**Portal**: https://ocrportal.hhs.gov/ocr/breach/wizard_breach.jsf
**Method**: Online submission via HHS breach reporting portal

**Information required:**
- Covered entity name and contact
- Business associate involvement (if any)
- Date of breach and date of discovery
- Type of breach (theft, unauthorized access, etc.)
- Type of PHI involved
- Number of individuals affected
- Safeguards in place (encryption, access controls)
- Actions taken in response
- Whether individual notification was provided

### To Media (45 CFR 164.406)

**Required only if**: >= 500 individuals in a single state or jurisdiction
**Method**: Press release to prominent media outlets in the affected area
**Timing**: Without unreasonable delay, no later than 60 days

---

## Step 5: Breach Notification Letter Template

```
[Hospital Letterhead]
[Date]

Dear [Patient Name],

We are writing to inform you of a data security incident that
may have affected your protected health information.

WHAT HAPPENED
On [date], we discovered that [brief description of incident].
The incident occurred on [date(s)] and was discovered on [date].

WHAT INFORMATION WAS INVOLVED
The following types of your information may have been affected:
- [List: name, date of birth, National ID, medical records, etc.]

WHAT WE ARE DOING
Upon discovering this incident, we immediately:
- [Steps taken: investigation, access revocation, system hardening]
- [Engagement of forensic experts if applicable]
- [Notification to law enforcement if applicable]

WHAT YOU CAN DO
We recommend that you:
- Monitor your financial accounts for unusual activity
- Review your medical records for accuracy
- Consider placing a fraud alert on your credit files

CONTACT INFORMATION
If you have questions, please contact:
  [Name], [Title]
  [Phone number]
  [Email address]
  [Mailing address]

We sincerely apologize for any concern this may cause.

Sincerely,
[Name]
[Title]
[Hospital Name]
```

---

## Automated Assessment

Run the breach assessment script for preliminary analysis:
```bash
./scripts/utilities/breach_assessment.sh
```

This queries AuditLog for unauthorized PHI access, counts affected records, and generates a preliminary report.

**⚠️ MANUAL STEP**: Legal review is required before any notifications are sent.

---

## Documentation Requirements

All breach-related documents must be retained for **6 years** (HIPAA 164.530(j)):
- Risk assessment worksheet
- Investigation notes
- Notification letters (copies)
- HHS submission confirmation
- Remediation evidence
