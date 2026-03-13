# HaleDistrict HD4 — Script Charter

This document defines standards for all PowerShell scripts used in HaleDistrict HD4.

Its purpose is to ensure scripts are predictable, auditable, safe to run repeatedly, and easy to reason about months or years later.

---

## 1. Script Categories

HD4 scripts fall into clearly separated categories.

### A) Build / Configuration Scripts

Purpose  
Bring a freshly built machine to a known-good standard state.

Characteristics
- Intended to run once (or rarely).
- May configure settings, roles, services, or files.
- Must be idempotent where possible.

Location  
Scripts/Baseline/

Naming  
HD4-<ROLE>-Baseline.ps1

Examples
- HD4-RT01-Baseline.ps1
- HD4-DC01-Baseline.ps1
- HD4-FS01-Baseline.ps1
- HD4-ADM01-Baseline.ps1
- HD4-Workstation-Baseline.ps1

---

### B) HealthCheck Scripts

Purpose  
Validate system and environment state, detect configuration drift, and provide confidence without modifying system state.

Characteristics
- Safe to run repeatedly.
- Read-only by default.
- Must never change system state unless explicitly instructed.

Location  
Scripts/HealthChecks/

Naming
- HD4-HealthCheck-Core.ps1
- HD4-HealthCheck-<ROLE>.ps1

---

### C) Remediation Scripts (Optional / Controlled)

Purpose  
Correct issues identified by HealthCheck scripts.

Characteristics
- Never run implicitly.
- Must be clearly separated or gated behind an explicit switch.

Execution Model
- Either separate Fix-* scripts
- Or explicit `-Remediate` parameter on a HealthCheck script

---

### D) Feature-Specific Scripts

Purpose  
Deploy or validate major architectural features (for example DFS Namespace).

Location  
Scripts/<Feature>/

Examples
- HD4-DFS-DeployNamespace.ps1
- HD4-DFS-Validate.ps1

---

## 2. Required Script Header

Every script must begin with a standardized header.

```powershell
<#
Script Name : HD4-<NAME>.ps1
Purpose     : <What this script does>
Scope       : HaleDistrict HD4
Role        : <RT01 | DC01 | FS01 | ADM01 | Workstation | Core>
Author      : HaleDistrict
Created     : YYYY-MM-DD
Version     : 0.1.0
Dependencies: <Modules / roles / services / paths>

Run Context:
- Intended machine(s):
- Requires elevation: Yes/No
- Safe to re-run: Yes/No

Notes:
- Any important assumptions or constraints
#>

## 3. Output and Logging Standards

All scripts should produce clear, human-readable output.

Standards
- Use consistent section headers for major phases.
- Clearly label PASS / WARN / FAIL conditions.
- Avoid noisy or ambiguous output.
- Prefer explicit messages over silent success.

Where appropriate, scripts should support:
- Console output for immediate review
- Optional transcript or log file output for archival purposes

HealthCheck scripts should summarize results at the end in a compact form.

---

## 4. Result and Exit Code Philosophy

Scripts should communicate success or failure clearly.

Guidance
- Exit 0 = Success / expected state
- Exit 1 = Validation failure or unhealthy state detected
- Exit 2+ = Script or runtime execution error

HealthCheck scripts should distinguish between:
- Script failed to run
- Script ran successfully but detected problems

---

## 5. Safety Rules

Scripts must be designed to minimize accidental change.

Rules
- HealthCheck scripts are read-only by default.
- Remediation must never occur unless explicitly requested.
- Destructive actions require clear confirmation or a dedicated remediation script.
- Scripts should validate prerequisites before making changes.
- Where possible, use -WhatIf / -Confirm style behavior for change-making actions.

---

## 6. Ownership Boundaries

To prevent overlap, each script should have a narrow and clear responsibility.

Examples
- Build / Configuration scripts establish machine baseline state.
- HealthCheck scripts validate system state only.
- Remediation scripts correct a specific failed condition.
- Feature scripts deploy or validate one architectural feature.

Avoid
- Giant multi-purpose scripts
- Mixing baseline deployment with broad health validation
- Embedding unrelated fixes inside validation logic