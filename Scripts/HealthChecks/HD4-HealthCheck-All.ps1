<#
Script Name : HD4-HealthCheck-All.ps1
Purpose     : Run the full HaleDistrict HD4 healthcheck suite and summarize results
Scope       : HaleDistrict HD4
Role        : Core
Author      : HaleDistrict
Created     : 2026-03-13
Version     : 0.2.0
Dependencies: Individual HD4 healthcheck scripts must exist in \\HD4-FS01\Scripts$\HealthChecks

Run Context:
- Intended machine(s): HD4-ADM01
- Requires elevation: Yes
- Safe to re-run: Yes

Notes:
- This script is an orchestrator. It does not perform infrastructure checks directly.
- It executes the individual healthcheck scripts in sequence.
- Some scripts run locally; others may run remotely on their intended host.
- Each child script is responsible for its own logging and artifact export.
- This script summarizes pass/fail execution at the suite level.
#>

[CmdletBinding()]
param()

trap {
    Write-Host ""
    Write-Host "FATAL: Unhandled script error: $_" -ForegroundColor Red
    exit 2
}

$HealthCheckRoot = "\\HD4-FS01\Scripts$\HealthChecks"
$PreferredHost   = "HD4-ADM01"

$Suite = @(
    [pscustomobject]@{
        Name          = "Core"
        Path          = Join-Path $HealthCheckRoot "HD4-HealthCheck-Core.ps1"
        ExecutionMode = "Local"
        TargetHost    = $PreferredHost
    },
    [pscustomobject]@{
        Name          = "Workstation"
        Path          = Join-Path $HealthCheckRoot "HD4-HealthCheck-Workstation.ps1"
        ExecutionMode = "Local"
        TargetHost    = $PreferredHost
    },
    [pscustomobject]@{
        Name          = "FS01"
        Path          = Join-Path $HealthCheckRoot "HD4-HealthCheck-FS01.ps1"
        ExecutionMode = "Remote"
        TargetHost    = "HD4-FS01"
    },
    [pscustomobject]@{
        Name          = "DFS"
        Path          = Join-Path $HealthCheckRoot "HD4-HealthCheck-DFS.ps1"
        ExecutionMode = "Local"
        TargetHost    = $PreferredHost
    },
    [pscustomobject]@{
        Name          = "RT01"
        Path          = Join-Path $HealthCheckRoot "HD4-HealthCheck-RT01.ps1"
        ExecutionMode = "Local"
        TargetHost    = $PreferredHost
    }
)

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

function Invoke-LocalHealthCheck {
    param(
        [Parameter(Mandatory)][string]$ScriptPath
    )

    $proc = Start-Process powershell.exe `
        -ArgumentList "-ExecutionPolicy Bypass -File `"$ScriptPath`"" `
        -Wait `
        -PassThru `
        -NoNewWindow

    return $proc.ExitCode
}

function Invoke-RemoteHealthCheck {
    param(
        [Parameter(Mandatory)][string]$ComputerName,
        [Parameter(Mandatory)][string]$ScriptPath
    )

    $remoteExitCode = Invoke-Command -ComputerName $ComputerName -ScriptBlock {
        param($RemoteScriptPath)
        powershell.exe -ExecutionPolicy Bypass -File $RemoteScriptPath
        return $LASTEXITCODE
    } -ArgumentList $ScriptPath -ErrorAction Stop

    if ($remoteExitCode -is [array]) {
        return [int]$remoteExitCode[-1]
    }

    return [int]$remoteExitCode
}

Write-Section "HD4-HealthCheck-All.ps1"
Write-Host "Scope   : HaleDistrict HD4"
Write-Host "Version : 0.2.0"
Write-Host "Host    : $env:COMPUTERNAME"
Write-Host "User    : $([Security.Principal.WindowsIdentity]::GetCurrent().Name)"
Write-Host "Time    : $(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')"
Write-Host "Root    : $HealthCheckRoot"

Write-Section "Preflight"

if ($env:COMPUTERNAME -ne $PreferredHost) {
    Write-Host "WARN: Preferred execution host is $PreferredHost. Current host: $env:COMPUTERNAME" -ForegroundColor Yellow
}
else {
    Write-Host "PASS: Running from preferred host $PreferredHost"
}

if (-not (Test-IsElevated)) {
    Write-Host "FAIL: Run this PowerShell session as Administrator." -ForegroundColor Red
    exit 2
}
else {
    Write-Host "PASS: Elevated session confirmed"
}

$Results = [System.Collections.Generic.List[object]]::new()

Write-Section "Running HD4 HealthCheck Suite"

$index = 0
$total = $Suite.Count

foreach ($check in $Suite) {
    $index++

    Write-Host ""
    Write-Host ("[{0}/{1}] {2}" -f $index, $total, $check.Name) -ForegroundColor Cyan
    Write-Host ("Path: {0}" -f $check.Path)
    Write-Host ("Mode: {0}" -f $check.ExecutionMode)
    Write-Host ("Host: {0}" -f $check.TargetHost)

    if (-not (Test-Path $check.Path)) {
        Write-Host "FAIL: Script not found." -ForegroundColor Red
        $Results.Add([pscustomobject]@{
            Name     = $check.Name
            Path     = $check.Path
            Mode     = $check.ExecutionMode
            Host     = $check.TargetHost
            Status   = "FAIL"
            ExitCode = 99
            Note     = "Script not found"
        }) | Out-Null
        continue
    }

    try {
        if ($check.ExecutionMode -eq "Remote") {
            $exitCode = Invoke-RemoteHealthCheck -ComputerName $check.TargetHost -ScriptPath $check.Path
        }
        else {
            $exitCode = Invoke-LocalHealthCheck -ScriptPath $check.Path
        }

        if ($exitCode -eq 0) {
            Write-Host ("Result: PASS (exit code {0})" -f $exitCode) -ForegroundColor Green
            $status = "PASS"
            $note   = "Healthcheck completed successfully"
        }
        elseif ($exitCode -eq 1) {
            Write-Host ("Result: FAIL (exit code {0})" -f $exitCode) -ForegroundColor Red
            $status = "FAIL"
            $note   = "Healthcheck completed with one or more failures"
        }
        else {
            Write-Host ("Result: ERROR (exit code {0})" -f $exitCode) -ForegroundColor Yellow
            $status = "ERROR"
            $note   = "Healthcheck script encountered runtime or execution error"
        }

        $Results.Add([pscustomobject]@{
            Name     = $check.Name
            Path     = $check.Path
            Mode     = $check.ExecutionMode
            Host     = $check.TargetHost
            Status   = $status
            ExitCode = $exitCode
            Note     = $note
        }) | Out-Null
    }
    catch {
        Write-Host ("ERROR: Failed to execute script: {0}" -f $_.Exception.Message) -ForegroundColor Red
        $Results.Add([pscustomobject]@{
            Name     = $check.Name
            Path     = $check.Path
            Mode     = $check.ExecutionMode
            Host     = $check.TargetHost
            Status   = "ERROR"
            ExitCode = 98
            Note     = $_.Exception.Message
        }) | Out-Null
    }
}

Write-Section "Suite Summary"

$Results |
    Select-Object Name, Mode, Host, Path, Status, ExitCode, Note |
    Format-Table -AutoSize

$passCount  = @($Results | Where-Object Status -eq "PASS").Count
$failCount  = @($Results | Where-Object Status -eq "FAIL").Count
$errorCount = @($Results | Where-Object Status -eq "ERROR").Count

Write-Host ""
Write-Host ("PASS : {0}" -f $passCount)
Write-Host ("FAIL : {0}" -f $failCount)
Write-Host ("ERROR: {0}" -f $errorCount)

Write-Host ""
if ($errorCount -gt 0) {
    Write-Host "HD4 suite result: ERROR" -ForegroundColor Yellow
    exit 2
}
elseif ($failCount -gt 0) {
    Write-Host "HD4 suite result: FAIL" -ForegroundColor Red
    exit 1
}
else {
    Write-Host "HD4 suite result: PASS" -ForegroundColor Green
    exit 0
}