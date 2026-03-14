<#
Script Name : HD4-DIAGNOSE.ps1
Purpose     : Operator-facing HD4 diagnostic command that runs the full healthcheck suite and prints a final district status
Scope       : HaleDistrict HD4
Role        : Core
Author      : HaleDistrict
Created     : 2026-03-13
Version     : 0.1.0
Dependencies: HD4-HealthCheck-All.ps1 must exist in \\HD4-FS01\Scripts$\HealthChecks

Run Context:
- Intended machine(s): HD4-ADM01
- Requires elevation: Yes
- Safe to re-run: Yes

Notes:
- This script is a top-level operator command.
- It does not perform direct infrastructure validation itself.
- It runs HD4-HealthCheck-All.ps1 and interprets the suite-level result.
- Use this when you want a fast answer to: "Is HaleDistrict healthy right now?"
#>

[CmdletBinding()]
param()

trap {
    Write-Host ""
    Write-Host "FATAL: Unhandled diagnostic error: $_" -ForegroundColor Red
    exit 2
}

function Write-Section {
    param([string]$Title)
    Write-Host ""
    Write-Host ("=" * 72)
    Write-Host $Title
    Write-Host ("=" * 72)
}

function Test-IsElevated {
    try {
        $identity  = [Security.Principal.WindowsIdentity]::GetCurrent()
        $principal = New-Object Security.Principal.WindowsPrincipal($identity)
        return $principal.IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)
    }
    catch {
        return $false
    }
}

$PreferredHost = "HD4-ADM01"
$HealthCheckRoot = "\\HD4-FS01\Scripts$\HealthChecks"
$SuiteScript = Join-Path $HealthCheckRoot "HD4-HealthCheck-All.ps1"

Write-Section "HD4-DIAGNOSE.ps1"
Write-Host "Scope   : HaleDistrict HD4"
Write-Host "Version : 0.1.0"
Write-Host "Host    : $env:COMPUTERNAME"
Write-Host "User    : $([Security.Principal.WindowsIdentity]::GetCurrent().Name)"
Write-Host "Time    : $(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')"
Write-Host "Suite   : $SuiteScript"

Write-Section "Preflight"

if ($env:COMPUTERNAME -eq $PreferredHost) {
    Write-Host "PASS: Running from preferred host $PreferredHost" -ForegroundColor Green
}
else {
    Write-Host "WARN: Preferred host is $PreferredHost. Current host: $env:COMPUTERNAME" -ForegroundColor Yellow
}

if (Test-IsElevated) {
    Write-Host "PASS: Elevated session confirmed" -ForegroundColor Green
}
else {
    Write-Host "FAIL: Run this PowerShell session as Administrator." -ForegroundColor Red
    exit 2
}

if (-not (Test-Path $SuiteScript)) {
    Write-Host "FAIL: Suite script not found: $SuiteScript" -ForegroundColor Red
    exit 2
}
else {
    Write-Host "PASS: Suite script found" -ForegroundColor Green
}

Write-Section "Running HD4 HealthCheck Suite"

$proc = Start-Process powershell.exe `
    -ArgumentList "-ExecutionPolicy Bypass -File `"$SuiteScript`"" `
    -Wait `
    -PassThru `
    -NoNewWindow

$SuiteExitCode = $proc.ExitCode

Write-Section "District Diagnostic Summary"

switch ($SuiteExitCode) {
    0 {
        Write-Host "District Status : HEALTHY" -ForegroundColor Green
        Write-Host "Interpretation  : All healthcheck modules completed successfully."
        Write-Host "Exit Code       : 0"
    }
    1 {
        Write-Host "District Status : DEGRADED" -ForegroundColor Red
        Write-Host "Interpretation  : One or more healthcheck modules reported failures."
        Write-Host "Exit Code       : 1"
    }
    default {
        Write-Host "District Status : ERROR" -ForegroundColor Yellow
        Write-Host "Interpretation  : The suite encountered an execution or runtime problem."
        Write-Host "Exit Code       : $SuiteExitCode"
    }
}

Write-Host ""
Write-Host "Recommended operator reading:"
Write-Host "  - HEALTHY  = core district services validated successfully"
Write-Host "  - DEGRADED = infrastructure responded, but one or more checks failed"
Write-Host "  - ERROR    = orchestration or execution issue; inspect suite output first"

Write-Section "Operator Verdict"

if ($SuiteExitCode -eq 0) {
    Write-Host "HALEDISTRICT HD4 IS OPERATIONAL." -ForegroundColor Green
    exit 0
}
elseif ($SuiteExitCode -eq 1) {
    Write-Host "HALEDISTRICT HD4 IS REACHABLE BUT DEGRADED." -ForegroundColor Red
    exit 1
}
else {
    Write-Host "HALEDISTRICT HD4 DIAGNOSTIC ENCOUNTERED AN ERROR." -ForegroundColor Yellow
    exit 2
}