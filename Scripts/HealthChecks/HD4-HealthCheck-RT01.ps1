<#
Script Name : HD4-HealthCheck-RT01.ps1
Purpose     : Validation-first health checks for HD4-RT01 routing, gateway reachability, and DNS forwarding signals
Scope       : HaleDistrict HD4
Role        : RT01
Author      : HaleDistrict
Created     : 2026-03-13
Version     : 0.1.0
Dependencies: HD4-HealthCheck-Lib.ps1, DNS resolution available, network connectivity to RT01, local administrative rights

Run Context:
- Intended machine(s): HD4-ADM01
- Requires elevation: Yes
- Safe to re-run: Yes

Notes:
- Read-only. Makes no changes to system state.
- Designed to validate RT01 from the client/admin perspective.
- Focuses on host reachability and name-resolution behavior rather than router-side reconfiguration.
- If RT01 is intentionally not fully onboarded to DNS yet, DNS-related findings may appear as WARN rather than FAIL.
#>

[CmdletBinding()]
param(
    [string]$OutputPath = "\\HD4-FS01\Scripts$\Logs\RT01Health"
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
    -ScriptName "HD4-HealthCheck-RT01.ps1" `
    -Scope "HaleDistrict HD4" `
    -Role "RT01" `
    -Version "0.1.0" `
    -OutputPath $OutputPath

# -------------------------------
# Script metadata / environment
# -------------------------------
$ComputerName = $env:COMPUTERNAME
$PreferredHost = "HD4-ADM01"
$Rt01Name = "HD4-RT01"
$Fs01Name = "HD4-FS01"
$Dc01Name = "HD4-DC01"

# -------------------------------
# Script-specific helpers
# -------------------------------
function Test-HostReachable {
    param([string]$ComputerName)
    return Test-Connection -ComputerName $ComputerName -Count 1 -Quiet -ErrorAction SilentlyContinue
}

function Get-PreferredIPv4Gateway {
    try {
        $route = Get-NetRoute -DestinationPrefix "0.0.0.0/0" -AddressFamily IPv4 -ErrorAction Stop |
            Sort-Object RouteMetric |
            Select-Object -First 1
        return $route
    }
    catch {
        return $null
    }
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
    if ($ComputerName -ieq $PreferredHost) {
        Add-Result -Status "PASS" -Check "ExecutionHost" -Message "Script is running on preferred host HD4-ADM01." -Data $ComputerName
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
# 2) RT01 Name Resolution
# -------------------------------
Write-Section "2) RT01 Name Resolution"

Safe-Run -CheckName "Resolve-RT01" -ScriptBlock {
    Write-Host "  Resolving $Rt01Name..."
    try {
        $res = Resolve-DnsName $Rt01Name -ErrorAction Stop
        $ips = ($res | Where-Object { $_.IPAddress } | Select-Object -ExpandProperty IPAddress) -join ", "
        Add-Result -Status "PASS" -Check "Resolve-RT01" -Message "RT01 resolves in DNS." -Data $ips
    }
    catch {
        Add-Result -Status "WARN" -Check "Resolve-RT01" -Message "Unable to resolve RT01 by name. This may be expected if RT01 is not fully onboarded to DNS yet." -Data $_.Exception.Message
    }
}

Safe-Run -CheckName "Resolve-DC01" -ScriptBlock {
    Write-Host "  Resolving $Dc01Name..."
    try {
        $res = Resolve-DnsName $Dc01Name -ErrorAction Stop
        $ips = ($res | Where-Object { $_.IPAddress } | Select-Object -ExpandProperty IPAddress) -join ", "
        Add-Result -Status "PASS" -Check "Resolve-DC01" -Message "DC01 resolves in DNS." -Data $ips
    }
    catch {
        Add-Result -Status "FAIL" -Check "Resolve-DC01" -Message "Unable to resolve DC01 by name." -Data $_.Exception.Message
    }
}

Safe-Run -CheckName "Resolve-FS01" -ScriptBlock {
    Write-Host "  Resolving $Fs01Name..."
    try {
        $res = Resolve-DnsName $Fs01Name -ErrorAction Stop
        $ips = ($res | Where-Object { $_.IPAddress } | Select-Object -ExpandProperty IPAddress) -join ", "
        Add-Result -Status "PASS" -Check "Resolve-FS01" -Message "FS01 resolves in DNS." -Data $ips
    }
    catch {
        Add-Result -Status "FAIL" -Check "Resolve-FS01" -Message "Unable to resolve FS01 by name." -Data $_.Exception.Message
    }
}

# -------------------------------
# 3) Gateway and Routing Signals
# -------------------------------
Write-Section "3) Gateway and Routing Signals"

Safe-Run -CheckName "DefaultGatewayPresent" -ScriptBlock {
    Write-Host "  Checking default gateway..."
    $route = Get-PreferredIPv4Gateway
    if ($route) {
        Add-Result -Status "PASS" -Check "DefaultGatewayPresent" -Message "Default route is present." -Data "NextHop=$($route.NextHop); InterfaceIndex=$($route.InterfaceIndex); Metric=$($route.RouteMetric)"
    }
    else {
        Add-Result -Status "FAIL" -Check "DefaultGatewayPresent" -Message "No default IPv4 route found." -Data ""
    }
}

Safe-Run -CheckName "DefaultGatewayReachable" -ScriptBlock {
    Write-Host "  Testing default gateway reachability..."
    $route = Get-PreferredIPv4Gateway
    if (-not $route) {
        Add-Result -Status "FAIL" -Check "DefaultGatewayReachable" -Message "Cannot test gateway reachability because no default route was found." -Data ""
        return
    }

    $gateway = $route.NextHop
    if (-not $gateway -or $gateway -eq "0.0.0.0") {
        Add-Result -Status "WARN" -Check "DefaultGatewayReachable" -Message "Default route exists but gateway next hop is not usable for ICMP validation." -Data $gateway
        return
    }

    $ok = $false
    try { $ok = Test-Connection -ComputerName $gateway -Count 1 -Quiet -ErrorAction Stop }
    catch { $ok = $false }

    if ($ok) {
        Add-Result -Status "PASS" -Check "DefaultGatewayReachable" -Message "Default gateway is ICMP reachable." -Data $gateway
    }
    else {
        Add-Result -Status "WARN" -Check "DefaultGatewayReachable" -Message "Default gateway is not ICMP reachable (may still be functioning)." -Data $gateway
    }
}

# -------------------------------
# 4) RT01 Reachability
# -------------------------------
Write-Section "4) RT01 Reachability"

Safe-Run -CheckName "Ping-RT01" -ScriptBlock {
    Write-Host "  Pinging $Rt01Name..."
    $ok = $false
    try { $ok = Test-HostReachable -ComputerName $Rt01Name }
    catch { $ok = $false }

    if ($ok) {
        Add-Result -Status "PASS" -Check "Ping-RT01" -Message "RT01 is ICMP reachable by name." -Data $Rt01Name
    }
    else {
        Add-Result -Status "WARN" -Check "Ping-RT01" -Message "RT01 is not ICMP reachable by name (may be blocked or not in DNS)." -Data $Rt01Name
    }
}

Safe-Run -CheckName "Ping-DC01" -ScriptBlock {
    Write-Host "  Pinging $Dc01Name..."
    $ok = $false
    try { $ok = Test-HostReachable -ComputerName $Dc01Name }
    catch { $ok = $false }

    if ($ok) {
        Add-Result -Status "PASS" -Check "Ping-DC01" -Message "DC01 is ICMP reachable." -Data $Dc01Name
    }
    else {
        Add-Result -Status "WARN" -Check "Ping-DC01" -Message "DC01 is not ICMP reachable (may be blocked; signal only)." -Data $Dc01Name
    }
}

Safe-Run -CheckName "Ping-FS01" -ScriptBlock {
    Write-Host "  Pinging $Fs01Name..."
    $ok = $false
    try { $ok = Test-HostReachable -ComputerName $Fs01Name }
    catch { $ok = $false }

    if ($ok) {
        Add-Result -Status "PASS" -Check "Ping-FS01" -Message "FS01 is ICMP reachable." -Data $Fs01Name
    }
    else {
        Add-Result -Status "WARN" -Check "Ping-FS01" -Message "FS01 is not ICMP reachable (may be blocked; signal only)." -Data $Fs01Name
    }
}

# -------------------------------
# 5) Core Path Sanity
# -------------------------------
Write-Section "5) Core Path Sanity"

Safe-Run -CheckName "Path-Scripts" -ScriptBlock {
    Write-Host "  Testing script share path..."
    $path = "\\HD4-FS01\Scripts$"
    if (Test-Path $path) {
        Add-Result -Status "PASS" -Check "Path-Scripts" -Message "Script share accessible." -Data $path
    }
    else {
        Add-Result -Status "FAIL" -Check "Path-Scripts" -Message "Script share not accessible." -Data $path
    }
}

Safe-Run -CheckName "Path-DFSRoot" -ScriptBlock {
    Write-Host "  Testing DFS root path..."
    $path = "\\haledistrict.local\Shares"
    if (Test-Path $path) {
        Add-Result -Status "PASS" -Check "Path-DFSRoot" -Message "DFS root accessible." -Data $path
    }
    else {
        Add-Result -Status "FAIL" -Check "Path-DFSRoot" -Message "DFS root not accessible." -Data $path
    }
}

# -------------------------------
# 6) DNS Client Configuration
# -------------------------------
Write-Section "6) DNS Client Configuration"

Safe-Run -CheckName "DnsServers" -ScriptBlock {
    Write-Host "  Checking DNS server configuration..."
    $dns = Get-DnsClientServerAddress -AddressFamily IPv4 -ErrorAction SilentlyContinue |
        Where-Object { $_.ServerAddresses -and $_.ServerAddresses.Count -gt 0 } |
        Select-Object -ExpandProperty ServerAddresses

    if ($dns) {
        Add-Result -Status "PASS" -Check "DnsServers" -Message "DNS servers configured." -Data ($dns -join ", ")
    }
    else {
        Add-Result -Status "FAIL" -Check "DnsServers" -Message "No IPv4 DNS servers configured." -Data ""
    }
}

# -------------------------------
# Summary
# -------------------------------
Write-HealthCheckScorecard -Note "Validation-first. No remediation performed."
Export-HealthCheckResults -OutputPath $OutputPath -BaseName "HD4-HealthCheck-RT01.ps1"

# -------------------------------
# Exit codes per Charter §4
# -------------------------------
exit (Get-HealthCheckExitCode)