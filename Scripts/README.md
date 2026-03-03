\# HaleDistrict HD4 — Script Charter



This document defines standards for all PowerShell scripts used in HaleDistrict HD4.

Its purpose is to ensure scripts are predictable, auditable, safe to run repeatedly,

and easy to reason about months or years later.



---



\## 1. Script Categories



HD4 scripts fall into clearly separated categories.



\### A) Baseline Scripts

Purpose:

\- Bring a freshly built machine to a known-good standard state.



Characteristics:

\- Intended to run once (or rarely).

\- May configure settings, roles, services, or files.

\- Must be idempotent where possible.



Location:

Scripts/Baseline/



Naming:

HD4-<ROLE>-Baseline.ps1



Examples:

\- HD4-RT01-Baseline.ps1

\- HD4-DC01-Baseline.ps1

\- HD4-FS01-Baseline.ps1

\- HD4-ADM01-Baseline.ps1

\- HD4-Workstation-Baseline.ps1



---



\### B) HealthCheck Scripts

Purpose:

\- Validate system and environment state.

\- Detect configuration drift.

\- Provide confidence without modifying state.



Characteristics:

\- Safe to run repeatedly.

\- Read-only by default.

\- Must never change system state unless explicitly told to do so.



Location:

Scripts/HealthChecks/



Naming:

\- HD4-HealthCheck-Core.ps1

\- HD4-HealthCheck-<ROLE>.ps1



---



\### C) Remediation Scripts (Optional / Controlled)

Purpose:

\- Correct issues identified by HealthChecks.



Characteristics:

\- Never run implicitly.

\- Must be clearly separated or gated behind an explicit switch.



Execution model:

\- Either separate Fix-\* scripts

\- Or explicit -Remediate parameter on a HealthCheck script



---



\### D) Feature-Specific Scripts

Purpose:

\- Deploy or validate major architectural features (e.g. DFS Namespace).



Location:

Scripts/DFS/



Examples:

\- HD4-DFS-DeployNamespace.ps1

\- HD4-DFS-Validate.ps1



---



\## 2. Required Script Header



Every script must begin with a standardized header.



```powershell

<#

Script Name : HD4-<NAME>.ps1

Purpose     : <What this script does>

Scope       : HaleDistrict HD4

Role        : <RT01 | DC01 | FS01 | ADM01 | Workstation | Core>

Author      : HaleDistrict

Created     : YYYY-MM-DD



Run Context:

\- Intended machine(s):

\- Requires elevation: Yes/No

\- Safe to re-run: Yes/No



Notes:

\- Any important assumptions or constraints

\#>

