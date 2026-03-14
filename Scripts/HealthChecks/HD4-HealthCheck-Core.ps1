<#
Script Name : HD4-HealthCheck-Core.ps1
Purpose     : High-signal "is HD4 healthy?" checks with evidence across core infrastructure
Scope       : HaleDistrict HD4
Role        : Core
Author      : HaleDistrict
Created     : 2026-03-13
Version     : 0.4.0
Dependencies: HD4-HealthCheck-Lib.ps1, WinRM enabled on target hosts, DNS resolution from ADM01, Security event log access on FS01

Run Context:
- Intended machine(s): HD4-ADM01
- Requires elevation: Yes
- Safe to re-run: Yes

Notes:
- Read-only. Makes no changes to system state.
- $RecentMinutes controls the lookback window for 4663 event evidence (default 30).
- RT01 DNS failures are expected in Phase 0 and will surface as WARN, not FAIL.
#>

[CmdletBinding()]
param(
    [int]$RecentMinutes = 30,
    [string]$OutputPath = "\\HD4-FS01\Scripts$\Logs\HealthCheck"
)

trap {
    Write-Host ""
    Write-Host "FATAL: Unhandled script error: $_" -ForegroundColor Red
    exit 2
}

# ----------------------------
# Import shared HealthCheck library
# ----------------------------
. "\\HD4-FS01\Scripts$\Lib\HD4-HealthCheck-Lib.ps1"

Initialize-HealthCheck `
    -ScriptName "HD4-HealthCheck-Core.ps1" `
    -Scope "HaleDistrict HD4" `
    -Role "Core" `
    -Version "0.4.0" `
    -OutputPath $OutputPath

# ----------------------------
# Inventory (easy to extend later)
# ----------------------------
$Inventory = @(
    [pscustomobject]@{ Name = "HD4-DC01"; Role = "DomainController"; Critical = $true },
    [pscustomobject]@{ Name = "HD4-FS01"; Role = "FileServer";       Critical = $true },
    [pscustomobject]@{ Name = "HD4-RT01"; Role = "Router";           Critical = $true }
)

# ----------------------------
# Paths (easy to extend later)
# ----------------------------
$SysvolPath  = "\\HD4-DC01\SYSVOL"
$ScriptShare = "\\HD4-FS01\Scripts$"
$Fs01        = ($Inventory | Where-Object Role -eq "FileServer").Name
$Local       = $env:COMPUTERNAME

$DfsPaths = @(
    "\\haledistrict.local\Shares",
    "\\haledistrict.local\Shares\Students",
    "\\haledistrict.local\Shares\Teachers"
)

# ----------------------------
# Script-specific helpers
# ----------------------------
function Test-HostReachable {
    param([string]$ComputerName)
    return Test-Connection -ComputerName $ComputerName -Count 1 -Quiet -ErrorAction SilentlyContinue
}

function Test-HD4Fs01WinRM {
    param([string]$ComputerName)

    Write-Host "  Checking WinRM on $ComputerName..."
    try {
        Test-WSMan $ComputerName -ErrorAction Stop | Out-Null
        Add-Result -Status "PASS" -Check "FS01-WinRM" -Message "WinRM responsive (Test-WSMan OK)." -Data $ComputerName
    }
    catch {
        Add-Result -Status "FAIL" -Check "FS01-WinRM" -Message "WinRM failed." -Data $_.Exception.Message
    }
}

function Test-HD4Fs01AuditPolicy {
    param([string]$ComputerName)

    Write-Host "  Checking audit policy on $ComputerName..."
    try {
        $auditpol = Invoke-Command -ComputerName $ComputerName -ScriptBlock {
            auditpol /get /subcategory:"File System"
        } -ErrorAction Stop

        $auditText = ($auditpol | Out-String)
        if ($auditText -match "File System\s+Success") {
            Add-Result -Status "PASS" -Check "FS01-AuditPolicy" -Message "File System auditing enabled (Success)." -Data $ComputerName
        }
        else {
            Add-Result -Status "WARN" -Check "FS01-AuditPolicy" -Message "No File System success entry found; expected during Phase 0." -Data $ComputerName
        }
    }
    catch {
        Add-Result -Status "WARN" -Check "FS01-AuditPolicy" -Message "Audit policy query failed or unavailable; expected during Phase 0 before full auditing scope." -Data $_.Exception.Message
    }
}

function Test-HD4Fs01AuditEvents {
    param(
        [string]$ComputerName,
        [int]$LookbackMinutes
    )

    Write-Host "  Checking 4663 audit events on $ComputerName (last $LookbackMinutes minutes)..."
    try {
        $since = (Get-Date).AddMinutes(-1 * $LookbackMinutes)

        $events = Invoke-Command -ComputerName $ComputerName -ScriptBlock {
            param($StartTime)
            Get-WinEvent -FilterHashtable @{
                LogName   = "Security"
                Id        = 4663
                StartTime = $StartTime
            } -ErrorAction Stop | Select-Object -First 20
        } -ArgumentList $since -ErrorAction Stop

        if ($events.Count -gt 0) {
            Add-Result -Status "PASS" -Check "FS01-AuditEvents" -Message "Recent 4663 events found." -Data "Count=$($events.Count); LookbackMinutes=$LookbackMinutes"
        }
        else {
            Add-Result -Status "WARN" -Check "FS01-AuditEvents" -Message "No recent 4663 events found (may be idle; run a test file action)." -Data "LookbackMinutes=$LookbackMinutes"
        }
    }
    catch {
        Add-Result -Status "WARN" -Check "FS01-AuditEvents" -Message "Unable to query 4663 events; expected in Phase 0 prior to sustained user activity." -Data $_.Exception.Message
    }
}

# ----------------------------
# Startup banner
# ----------------------------
Write-HealthCheckHeader

# ----------------------------
# Check - Execution context (ADM01 + Elevated)
# ----------------------------
Write-Section "Execution context (ADM01 + Elevated)"

Write-Host "  Checking execution host..."
if ($Local -ne "HD4-ADM01") {
    Add-Result -Status "FAIL" -Check "ExecutionContext-Host" -Message "This script must run on HD4-ADM01." -Data "RunningOn=$Local"
    Write-Host "FAIL: Must run on HD4-ADM01. Aborting." -ForegroundColor Red
    exit 2
}
else {
    Add-Result -Status "PASS" -Check "ExecutionContext-Host" -Message "Host is HD4-ADM01." -Data $Local
}

Write-Host "  Checking elevation..."
if (-not (Test-IsElevated)) {
    Add-Result -Status "FAIL" -Check "ExecutionContext-Elevation" -Message "Session is not elevated. Run PowerShell as Administrator." -Data $Local
    Write-Host "FAIL: Session is not elevated. Aborting." -ForegroundColor Red
    exit 2
}
else {
    Add-Result -Status "PASS" -Check "ExecutionContext-Elevation" -Message "Elevated session confirmed." -Data $Local
}

# ----------------------------
# Check - DNS resolution
# ----------------------------
Write-Section "DNS resolution (from ADM01)"

foreach ($t in $Inventory) {
    Safe-Run -CheckName "DnsResolution-$($t.Name)" -ScriptBlock {
        Write-Host "  Resolving $($t.Name)..."
        try {
            $null = Resolve-DnsName -Name $t.Name -ErrorAction Stop
            Add-Result -Status "PASS" -Check "DnsResolution-$($t.Name)" -Message "Resolved via DNS." -Data $t.Name
        }
        catch {
            if ($t.Name -eq "HD4-RT01") {
                Add-Result -Status "WARN" -Check "DnsResolution-$($t.Name)" -Message "DNS resolve failed (expected in Phase 0 until RT01 is onboarded / registered in DNS)." -Data $_.Exception.Message
            }
            else {
                Add-Result -Status "FAIL" -Check "DnsResolution-$($t.Name)" -Message "DNS resolve failed." -Data $_.Exception.Message
            }
        }
    }
}

# ----------------------------
# Check - Network reachability
# ----------------------------
Write-Section "Network reachability"

foreach ($t in $Inventory) {
    Safe-Run -CheckName "NetworkReachability-$($t.Name)" -ScriptBlock {
        Write-Host "  Pinging $($t.Name)..."
        $ok = Test-HostReachable -ComputerName $t.Name
        if ($ok) {
            Add-Result -Status "PASS" -Check "NetworkReachability-$($t.Name)" -Message "ICMP reachable." -Data $t.Name
        }
        else {
            Add-Result -Status "WARN" -Check "NetworkReachability-$($t.Name)" -Message "ICMP not reachable (could be blocked)." -Data $t.Name
        }
    }
}

# ----------------------------
# Check - Secure channel (ADM01)
# ----------------------------
Write-Section "Secure channel (ADM01)"

Safe-Run -CheckName "SecureChannel" -ScriptBlock {
    Write-Host "  Testing secure channel..."
    $secure = Test-ComputerSecureChannel -ErrorAction Stop
    if ($secure) {
        Add-Result -Status "PASS" -Check "SecureChannel" -Message "Secure channel to domain is healthy." -Data $Local
    }
    else {
        Add-Result -Status "FAIL" -Check "SecureChannel" -Message "Secure channel check returned false." -Data $Local
    }
}

# ----------------------------
# Check - SYSVOL access
# ----------------------------
Write-Section "SYSVOL access"

Safe-Run -CheckName "SysvolAccess" -ScriptBlock {
    Write-Host "  Testing path: $SysvolPath..."
    if (Test-Path $SysvolPath) {
        Add-Result -Status "PASS" -Check "SysvolAccess" -Message "SYSVOL path accessible." -Data $SysvolPath
    }
    else {
        Add-Result -Status "FAIL" -Check "SysvolAccess" -Message "SYSVOL path not accessible." -Data $SysvolPath
    }
}

# ----------------------------
# Check - DFS namespace access
# ----------------------------
Write-Section "DFS namespace access"

foreach ($path in $DfsPaths) {
    Safe-Run -CheckName "DfsNamespaceAccess-$path" -ScriptBlock {
        Write-Host "  Testing path: $path..."
        if (Test-Path $path) {
            Add-Result -Status "PASS" -Check "DfsNamespaceAccess" -Message "DFS path accessible." -Data $path
        }
        else {
            Add-Result -Status "FAIL" -Check "DfsNamespaceAccess" -Message "DFS path not accessible." -Data $path
        }
    }
}

# ----------------------------
# Check - Script share access
# ----------------------------
Write-Section "Script share access"

Safe-Run -CheckName "ScriptShareAccess" -ScriptBlock {
    Write-Host "  Testing path: $ScriptShare..."
    if (Test-Path $ScriptShare) {
        Add-Result -Status "PASS" -Check "ScriptShareAccess" -Message "Script share accessible." -Data $ScriptShare
    }
    else {
        Add-Result -Status "FAIL" -Check "ScriptShareAccess" -Message "Script share not accessible." -Data $ScriptShare
    }
}

# ----------------------------
# Check - FS01 remoting + auditing evidence
# ----------------------------
Write-Section "FS01 remoting + auditing evidence"

Test-HD4Fs01WinRM       -ComputerName $Fs01
Test-HD4Fs01AuditPolicy -ComputerName $Fs01
Test-HD4Fs01AuditEvents -ComputerName $Fs01 -LookbackMinutes $RecentMinutes

# ----------------------------
# Summary
# ----------------------------
Write-HealthCheckScorecard -Note "Validation-first. No remediation performed."
Export-HealthCheckResults -OutputPath $OutputPath -BaseName "HD4-HealthCheck-Core.ps1"

# ----------------------------
# Exit codes per Charter §4
# ----------------------------
exit (Get-HealthCheckExitCode)
