<#
Script Name : HD4-HealthCheck-Lib.ps1
Purpose     : Shared framework functions for HaleDistrict HD4 healthcheck scripts
Scope       : HaleDistrict HD4
Role        : Core
Author      : HaleDistrict
Created     : 2026-03-13
Version     : 0.1.0
Dependencies: PowerShell 5.1+, access to FS01 Scripts$ share for central logging

Run Context:
- Intended machine(s): Any HD4 machine running a healthcheck script
- Requires elevation: No
- Safe to re-run: Yes

Notes:
- This file is a shared library and is not intended to be run directly.
- Healthcheck scripts should dot-source this file.
- Provides shared result handling, console formatting, scorecard output, and artifact export.
#>

Set-StrictMode -Version Latest

# -------------------------------
# Script-scoped framework state
# -------------------------------
$script:Results          = [System.Collections.Generic.List[object]]::new()
$script:HealthCheckName  = ""
$script:HealthCheckScope = "HaleDistrict HD4"
$script:HealthCheckRole  = ""
$script:HealthCheckHost  = $env:COMPUTERNAME
$script:HealthCheckTime  = Get-Date
$script:HealthCheckPath  = ""
$script:HealthCheckVersion = ""
$script:HealthCheckOutputPath = ""
$script:HealthCheckUser  = [System.Security.Principal.WindowsIdentity]::GetCurrent().Name
$script:HealthCheckIsAdmin = $false

# -------------------------------
# Helpers
# -------------------------------
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

function Write-Section {
    param(
        [Parameter(Mandatory)][string]$Title
    )

    Write-Host ""
    Write-Host ("=" * 72)
    Write-Host $Title
    Write-Host ("=" * 72)
}

function Initialize-HealthCheck {
    param(
        [Parameter(Mandatory)][string]$ScriptName,
        [string]$Scope = "HaleDistrict HD4",
        [string]$Role = "Core",
        [string]$Version = "0.1.0",
        [string]$OutputPath = "\\HD4-FS01\Scripts$\Logs\HealthCheck"
    )

    $script:Results = [System.Collections.Generic.List[object]]::new()
    $script:HealthCheckName = $ScriptName
    $script:HealthCheckScope = $Scope
    $script:HealthCheckRole = $Role
    $script:HealthCheckHost = $env:COMPUTERNAME
    $script:HealthCheckTime = Get-Date
    $script:HealthCheckPath = $PSCommandPath
    $script:HealthCheckVersion = $Version
    $script:HealthCheckOutputPath = $OutputPath
    $script:HealthCheckUser = [System.Security.Principal.WindowsIdentity]::GetCurrent().Name
    $script:HealthCheckIsAdmin = Test-IsElevated
}

function Write-HealthCheckHeader {
    Write-Section $script:HealthCheckName
    Write-Host "Scope   : $script:HealthCheckScope"
    Write-Host "Role    : $script:HealthCheckRole"
    Write-Host "Version : $script:HealthCheckVersion"
    Write-Host "Host    : $script:HealthCheckHost"
    Write-Host "User    : $script:HealthCheckUser"
    Write-Host "Time    : $($script:HealthCheckTime.ToString('yyyy-MM-dd HH:mm:ss'))"
    Write-Host "Admin   : $script:HealthCheckIsAdmin"
    Write-Host "Output  : $script:HealthCheckOutputPath"
}

function Add-Result {
    param(
        [Parameter(Mandatory)]
        [ValidateSet("PASS","WARN","FAIL")]
        [string]$Status,

        [Parameter(Mandatory)]
        [string]$Check,

        [Parameter(Mandatory)]
        [string]$Message,

        $Data = ""
    )

    $dataText = ""
    if ($null -ne $Data) {
        if ($Data -is [string]) {
            $dataText = $Data
        }
        else {
            $dataText = ($Data | Out-String).Trim()
        }
    }

    $script:Results.Add([pscustomobject]@{
        Time    = (Get-Date).ToString("s")
        Status  = $Status
        Check   = $Check
        Message = $Message
        Data    = $dataText
    }) | Out-Null
}

function Safe-Run {
    param(
        [Parameter(Mandatory)][string]$CheckName,
        [Parameter(Mandatory)][scriptblock]$ScriptBlock,
        [switch]$VerboseOutput
    )

    try {
        & $ScriptBlock
    }
    catch {
        Add-Result -Status "FAIL" -Check $CheckName -Message "Unhandled exception" -Data $_.Exception.Message
        if ($VerboseOutput) {
            Write-Host "[FAIL] $CheckName :: $($_.Exception.Message)" -ForegroundColor Red
        }
    }
}

function Get-HealthCheckResults {
    return $script:Results.ToArray()
}

function Write-HealthCheckScorecard {
    param(
        [string]$Note = ""
    )

    $results = Get-HealthCheckResults

    Write-Section "Scorecard"

    $pass = @($results | Where-Object Status -eq "PASS").Count
    $warn = @($results | Where-Object Status -eq "WARN").Count
    $fail = @($results | Where-Object Status -eq "FAIL").Count

    Write-Host ("PASS: {0}  |  WARN: {1}  |  FAIL: {2}" -f $pass, $warn, $fail)

    if ($Note -and $Note.Trim() -ne "") {
        Write-Host ""
        Write-Host "NOTE: $Note"
    }

    Write-Host ""

    $results |
        Sort-Object Time |
        Select-Object Time, Status, Check, Message, Data |
        Format-Table -AutoSize

    Write-Section "Summary by status"
    $results |
        Group-Object Status |
        Sort-Object Name |
        Format-Table @{Label="Status";Expression={$_.Name}}, Count -AutoSize
}

function Export-HealthCheckResults {
    param(
        [string]$OutputPath = $script:HealthCheckOutputPath,
        [string]$BaseName = $script:HealthCheckName
    )

    $results = Get-HealthCheckResults

    if (-not $BaseName -or $BaseName.Trim() -eq "") {
        $BaseName = "HD4-HealthCheck"
    }

    $safeBaseName = [System.IO.Path]::GetFileNameWithoutExtension($BaseName)
    $timestamp = Get-Date -Format "yyyyMMdd-HHmmss"

    try {
        New-Item -ItemType Directory -Force -Path $OutputPath | Out-Null

        $csvPath = Join-Path $OutputPath ("{0}-{1}.csv" -f $safeBaseName, $timestamp)
        $txtPath = Join-Path $OutputPath ("{0}-{1}.txt" -f $safeBaseName, $timestamp)

        $results | Export-Csv -NoTypeInformation -Path $csvPath

        $results |
            Sort-Object Time |
            Select-Object Time, Status, Check, Message, Data |
            Out-String | Set-Content -Path $txtPath -Encoding UTF8

        Write-Host ""
        Write-Host "Saved CSV : $csvPath"
        Write-Host "Saved TXT : $txtPath"
    }
    catch {
        Write-Host ""
        Write-Host ("WARN: Unable to write output file(s): {0}" -f $_.Exception.Message) -ForegroundColor Yellow
    }
}

function Get-HealthCheckExitCode {
    $results = Get-HealthCheckResults
    $fail = @($results | Where-Object Status -eq "FAIL").Count

    if ($fail -gt 0) {
        return 1
    }

    return 0
}