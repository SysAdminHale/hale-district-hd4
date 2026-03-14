<#
HD3-HealthCheck.ps1
Run from: HD3-ADM01 (only)
Purpose: High-signal "is HD3 healthy?" checks with evidence
#>

[CmdletBinding()]
param(
    [int]$RecentMinutes = 30
)

# ----------------------------
# Inventory (easy to extend later)
# ----------------------------
$Inventory = @(
    [pscustomobject]@{ Name = "HD3-DC01"; Role="DomainController"; Critical=$true },
    [pscustomobject]@{ Name = "HD3-FS01"; Role="FileServer";       Critical=$true },
    [pscustomobject]@{ Name = "HD3-RT01"; Role="Router";           Critical=$true }
)

# ----------------------------
# Helpers
# ----------------------------
function Write-CheckHeader {
    param([string]$Title)
    Write-Host ""
    Write-Host ("=" * 72)
    Write-Host $Title
    Write-Host ("=" * 72)
}

function Add-Result {
    param(
        [string]$Check,
        [string]$Target,
        [ValidateSet("PASS","WARN","FAIL")] [string]$Status,
        [string]$Evidence
    )
    $script:Results += [pscustomobject]@{
        Time    = (Get-Date)
        Check   = $Check
        Target  = $Target
        Status  = $Status
        Evidence= $Evidence
    }
}

function Test-IsElevated {
    $id = [Security.Principal.WindowsIdentity]::GetCurrent()
    $p  = New-Object Security.Principal.WindowsPrincipal($id)
    return $p.IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)
}

function Test-HostReachable {
    param([string]$ComputerName)
    return Test-Connection -ComputerName $ComputerName -Count 1 -Quiet -ErrorAction SilentlyContinue
}

# Results store
$Results = @()

# ----------------------------
# Check #1 - Running on ADM01 + Elevated
# ----------------------------
Write-CheckHeader "Check #1 - Execution context (ADM01 + Elevated)"

$local = $env:COMPUTERNAME
if ($local -ne "HD3-ADM01") {
    Add-Result -Check "Check #1" -Target $local -Status "FAIL" -Evidence "This must run on HD3-ADM01 (running on $local)."
    throw "Refusing to run on $local. Run this from HD3-ADM01 only."
} else {
    Add-Result -Check "Check #1" -Target $local -Status "PASS" -Evidence "Host is HD3-ADM01."
}

if (-not (Test-IsElevated)) {
    Add-Result -Check "Check #1" -Target $local -Status "FAIL" -Evidence "Not elevated. Run PowerShell as Administrator."
    throw "Not elevated."
} else {
    Add-Result -Check "Check #1" -Target $local -Status "PASS" -Evidence "Elevated session confirmed."
}

# -------------------------------
# Check #2 – DNS resolution sanity
# -------------------------------

Write-CheckHeader "Check #2 - DNS resolution (from ADM01)"

foreach ($t in $Inventory) {
    try {
        $null = Resolve-DnsName -Name $t.Name -ErrorAction Stop
        Add-Result -Check "Check #2" -Target $t.Name -Status "PASS" `
            -Evidence "Resolved via DNS."
    }
    catch {
        if ($t.Name -eq "HD3-RT01") {
            Add-Result -Check "Check #2" -Target $t.Name -Status "WARN" `
                -Evidence "DNS resolve failed (expected in Phase 0 until RT01 is onboarded / registered in DNS)."
        }
        else {
            Add-Result -Check "Check #2" -Target $t.Name -Status "FAIL" `
                -Evidence "DNS resolve failed: $($_.Exception.Message)"
        }
    }
}

# ----------------------------
# Check #3 - Basic reachability
# ----------------------------
Write-CheckHeader "Check #3 - Network reachability"

foreach ($t in $Inventory) {
    $ok = Test-HostReachable -ComputerName $t.Name
    if ($ok) {
        Add-Result -Check "Check #3" -Target $t.Name -Status "PASS" -Evidence "ICMP reachable."
    } else {
        Add-Result -Check "Check #3" -Target $t.Name -Status "WARN" -Evidence "ICMP not reachable (could be blocked)."
    }
}

# ----------------------------
# Check #4 - FS01 remoting + auditing (Success-only)
# ----------------------------
Write-CheckHeader "Check #4 - FS01: WinRM + Audit policy + Evidence events"

$fs01 = "HD3-FS01"

# 4a) WinRM
try {
    Test-WSMan $fs01 -ErrorAction Stop | Out-Null
    Add-Result -Check "Check #4a" -Target $fs01 -Status "PASS" -Evidence "WinRM responsive (Test-WSMan OK)."
} catch {
    Add-Result -Check "Check #4a" -Target $fs01 -Status "FAIL" -Evidence "WinRM failed: $($_.Exception.Message)"
}

# 4b) Audit policy: "Audit File System" must be Success
try {
    $auditpol = Invoke-Command -ComputerName $fs01 -ScriptBlock {
        auditpol /get /subcategory:"File System"
    } -ErrorAction Stop

    $auditText = ($auditpol | Out-String)
    if ($auditText -match "File System\s+Success") {
    Add-Result -Check "Check #4b" -Target $fs01 -Status "PASS" `
        -Evidence "auditpol: File System auditing enabled (Success)."
}
else {
    Add-Result -Check "Check #4b" -Target $fs01 -Status "WARN" `
        -Evidence "auditpol returned no File System success entry; expected during Phase 0."
}
}
catch {
    Add-Result -Check "Check #4b" -Target $fs01 -Status "WARN" `
        -Evidence "auditpol query failed or unavailable; expected during Phase 0 before full auditing scope."
}

# 4c) Evidence: recent 4663 events (Pilot-Shared path)
# NOTE: We are using Success-only. 4663 should show successful object access attempts.
try {
    $since = (Get-Date).AddMinutes(-1 * $RecentMinutes)

    $events = Invoke-Command -ComputerName $fs01 -ScriptBlock {
        param($StartTime)
        Get-WinEvent -FilterHashtable @{
            LogName    = "Security"
            Id         = 4663
            StartTime  = $StartTime
        } -ErrorAction Stop | Select-Object -First 20
    } -ArgumentList $since -ErrorAction Stop

    if ($events.Count -gt 0) {
        Add-Result -Check "Check #4c" -Target $fs01 -Status "PASS" -Evidence "Found $($events.Count) recent 4663 events in last $RecentMinutes minutes."
    } else {
        Add-Result -Check "Check #4c" -Target $fs01 -Status "WARN" -Evidence "No recent 4663 events in last $RecentMinutes minutes (may be idle; run a test file action)."
    }
} catch {
    Add-Result -Check "Check #4c" -Target $fs01 -Status "WARN" `
        -Evidence "Unable to query 4663 events; expected in Phase 0 prior to sustained user activity."
}

# ----------------------------
# Final scorecard
# ----------------------------
Write-CheckHeader "Final scorecard"
$Results | Sort-Object Time | Format-Table -AutoSize

# Output directory: ..\Artifacts\HealthCheck (relative to Scripts)
$outputDir = Join-Path $PSScriptRoot "..\Artifacts\HealthCheck"
New-Item -ItemType Directory -Force -Path $outputDir | Out-Null

$timestamp = Get-Date -Format "yyyyMMdd-HHmmss"
$csvPath = Join-Path $outputDir ("HD3-HealthCheck-{0}.csv" -f $timestamp)

$Results | Export-Csv -Path $csvPath -NoTypeInformation
Write-Host ""
Write-Host ("Saved: {0}" -f $csvPath)