<#
Script Name : HD4-HealthCheck-DFS.ps1
Purpose     : Validation-first health checks for the HD4 DFS namespace and client-facing DFS paths
Scope       : HaleDistrict HD4
Role        : DFS
Author      : HaleDistrict
Created     : 2026-03-13
Version     : 0.1.0
Dependencies: HD4-HealthCheck-Lib.ps1, DFS namespace already deployed, DNS resolution available, local administrative rights

Run Context:
- Intended machine(s): HD4-ADM01
- Requires elevation: Yes
- Safe to re-run: Yes

Notes:
- Read-only. Makes no changes to system state.
- Validates the DFS namespace abstraction layer used by HD4 clients.
- Focuses on namespace availability and path accessibility, not remediation.
#>

[CmdletBinding()]
param(
    [string]$OutputPath = "\\HD4-FS01\Scripts$\Logs\DFSHealth"
)

trap {
    Write-Host ""
    Write-Host "FATAL: Unhandled script error: $_" -ForegroundColor Red
    exit 2
}

# -------------------------------
# Import shared HealthCheck library
# -------------------------------
. "\\HD4-FS01\Scripts$\Lib\HD4-HealthCheck-Lib.ps1"

Initialize-HealthCheck `
    -ScriptName "HD4-HealthCheck-DFS.ps1" `
    -Scope "HaleDistrict HD4" `
    -Role "DFS" `
    -Version "0.1.0" `
    -OutputPath $OutputPath

# -------------------------------
# Script metadata / environment
# -------------------------------
$ComputerName = $env:COMPUTERNAME

$DfsNamespaceRoot = "\\haledistrict.local\Shares"
$DfsPaths = [ordered]@{
    "DFS-Root"     = "\\haledistrict.local\Shares"
    "DFS-Students" = "\\haledistrict.local\Shares\Students"
    "DFS-Teachers" = "\\haledistrict.local\Shares\Teachers"
}

$BackendPaths = [ordered]@{
    "Backend-DFSRoot" = "\\HD4-FS01\Shares"
    "Backend-Users$"  = "\\HD4-FS01\Users$"
}

# -------------------------------
# Startup banner
# -------------------------------
Write-HealthCheckHeader

# -------------------------------
# 1) Execution Context
# -------------------------------
Write-Section "1) Execution Context"

Safe-Run -CheckName "ExecutionHost" -ScriptBlock {
    Write-Host "  Checking execution host..."
    if ($ComputerName -ieq "HD4-ADM01") {
        Add-Result -Status "PASS" -Check "ExecutionHost" -Message "Script is running on HD4-ADM01." -Data $ComputerName
    }
    else {
        Add-Result -Status "WARN" -Check "ExecutionHost" -Message "Script is not running on HD4-ADM01. This is allowed, but ADM01 is the preferred control point." -Data $ComputerName
    }
}

Safe-Run -CheckName "Elevation" -ScriptBlock {
    Write-Host "  Checking elevation..."
    if (Test-IsElevated) {
        Add-Result -Status "PASS" -Check "Elevation" -Message "Session is elevated." -Data $ComputerName
    }
    else {
        Add-Result -Status "FAIL" -Check "Elevation" -Message "Session is not elevated. Run PowerShell as Administrator." -Data $ComputerName
    }
}

# -------------------------------
# 2) Namespace Resolution
# -------------------------------
Write-Section "2) Namespace Resolution"

Safe-Run -CheckName "Resolve-DFSNamespaceHost" -ScriptBlock {
    Write-Host "  Resolving haledistrict.local..."
    try {
        $res = Resolve-DnsName "haledistrict.local" -ErrorAction Stop
        $ips = ($res | Where-Object { $_.IPAddress } | Select-Object -ExpandProperty IPAddress) -join ", "
        Add-Result -Status "PASS" -Check "Resolve-DFSNamespaceHost" -Message "Domain name resolves." -Data $ips
    }
    catch {
        Add-Result -Status "FAIL" -Check "Resolve-DFSNamespaceHost" -Message "Unable to resolve haledistrict.local." -Data $_.Exception.Message
    }
}

Safe-Run -CheckName "Resolve-FS01" -ScriptBlock {
    Write-Host "  Resolving HD4-FS01..."
    try {
        $res = Resolve-DnsName "HD4-FS01" -ErrorAction Stop
        $ips = ($res | Where-Object { $_.IPAddress } | Select-Object -ExpandProperty IPAddress) -join ", "
        Add-Result -Status "PASS" -Check "Resolve-FS01" -Message "HD4-FS01 resolves." -Data $ips
    }
    catch {
        Add-Result -Status "FAIL" -Check "Resolve-FS01" -Message "Unable to resolve HD4-FS01." -Data $_.Exception.Message
    }
}

# -------------------------------
# 3) DFS Namespace Paths
# -------------------------------
Write-Section "3) DFS Namespace Paths"

foreach ($label in $DfsPaths.Keys) {
    $path = $DfsPaths[$label]
    Safe-Run -CheckName $label -ScriptBlock {
        Write-Host "  Testing path: $path..."
        if (Test-Path $path) {
            Add-Result -Status "PASS" -Check $label -Message "DFS path accessible." -Data $path
        }
        else {
            Add-Result -Status "FAIL" -Check $label -Message "DFS path not accessible." -Data $path
        }
    }
}

# -------------------------------
# 4) Backend Share Reachability
# -------------------------------
Write-Section "4) Backend Share Reachability"

foreach ($label in $BackendPaths.Keys) {
    $path = $BackendPaths[$label]
    Safe-Run -CheckName $label -ScriptBlock {
        Write-Host "  Testing backend path: $path..."
        if (Test-Path $path) {
            Add-Result -Status "PASS" -Check $label -Message "Backend share path accessible." -Data $path
        }
        else {
            Add-Result -Status "FAIL" -Check $label -Message "Backend share path not accessible." -Data $path
        }
    }
}

# -------------------------------
# 5) Namespace Server Sanity
# -------------------------------
Write-Section "5) Namespace Server Sanity"

Safe-Run -CheckName "Ping-FS01" -ScriptBlock {
    Write-Host "  Pinging HD4-FS01..."
    $ok = $false
    try { $ok = Test-Connection -ComputerName "HD4-FS01" -Count 1 -Quiet -ErrorAction Stop }
    catch { $ok = $false }

    if ($ok) {
        Add-Result -Status "PASS" -Check "Ping-FS01" -Message "HD4-FS01 is ICMP reachable." -Data "HD4-FS01"
    }
    else {
        Add-Result -Status "WARN" -Check "Ping-FS01" -Message "HD4-FS01 is not ICMP reachable (may be blocked; signal only)." -Data "HD4-FS01"
    }
}

Safe-Run -CheckName "ScriptShareAccess" -ScriptBlock {
    Write-Host "  Testing script share path..."
    $path = "\\HD4-FS01\Scripts$"
    if (Test-Path $path) {
        Add-Result -Status "PASS" -Check "ScriptShareAccess" -Message "Script share accessible." -Data $path
    }
    else {
        Add-Result -Status "FAIL" -Check "ScriptShareAccess" -Message "Script share not accessible." -Data $path
    }
}

# -------------------------------
# 6) DFS Root Structure
# -------------------------------
Write-Section "6) DFS Root Structure"

Safe-Run -CheckName "DFSRootChildren" -ScriptBlock {
    Write-Host "  Enumerating DFS root children..."
    try {
        $items = Get-ChildItem -Path $DfsNamespaceRoot -ErrorAction Stop | Select-Object -ExpandProperty Name
        if ($items) {
            Add-Result -Status "PASS" -Check "DFSRootChildren" -Message "DFS root contents enumerated." -Data ($items -join ", ")
        }
        else {
            Add-Result -Status "WARN" -Check "DFSRootChildren" -Message "DFS root is reachable but no child items were returned." -Data $DfsNamespaceRoot
        }
    }
    catch {
        Add-Result -Status "WARN" -Check "DFSRootChildren" -Message "Unable to enumerate DFS root contents." -Data $_.Exception.Message
    }
}

# -------------------------------
# Summary
# -------------------------------
Write-HealthCheckScorecard -Note "Validation-first. No remediation performed."
Export-HealthCheckResults -OutputPath $OutputPath -BaseName "HD4-HealthCheck-DFS.ps1"

# -------------------------------
# Exit codes per Charter §4
# -------------------------------
exit (Get-HealthCheckExitCode)