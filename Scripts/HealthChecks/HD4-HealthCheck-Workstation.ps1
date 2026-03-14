<#
Script Name : HD4-HealthCheck-Workstation.ps1
Purpose     : Validation-first workstation baseline checks for HD4 workstations
Scope       : HaleDistrict HD4
Role        : Workstation
Author      : HaleDistrict
Created     : 2026-03-13
Version     : 0.4.0
Dependencies: HD4-HealthCheck-Lib.ps1, domain join completed, DNS resolution available, local administrative rights

Run Context:
- Intended machine(s): HD4 workstations (e.g. STUD01, TEACH01)
- Requires elevation: Yes
- Safe to re-run: Yes

Notes:
- Read-only. Makes no changes to system state.
- Intended to run post-deploy, post-rename, post-networking, and post-domain-join.
- No heavy remediation. No identity binding. No OU moves. No domain join actions.
#>

[CmdletBinding()]
param(
    [string]$OutputPath = "\\HD4-FS01\Scripts$\Logs\WorkstationHealth"
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
    -ScriptName "HD4-HealthCheck-Workstation.ps1" `
    -Scope "HaleDistrict HD4" `
    -Role "Workstation" `
    -Version "0.4.0" `
    -OutputPath $OutputPath

# -------------------------------
# Script metadata / environment
# -------------------------------
$ComputerName = $env:COMPUTERNAME
$DomainJoined = $false
$DomainName   = ""

try {
    $cs = Get-CimInstance Win32_ComputerSystem
    $DomainJoined = [bool]$cs.PartOfDomain
    $DomainName   = $cs.Domain
}
catch { }

$CriticalHosts = @("HD4-DC01", "HD4-FS01", "HD4-RT01")

$PathChecks = [ordered]@{
    "Path-SYSVOL"   = "\\HD4-DC01\SYSVOL"
    "Path-Scripts"  = "\\HD4-FS01\Scripts$"
    "Path-Shares"   = "\\haledistrict.local\Shares"
    "Path-Students" = "\\haledistrict.local\Shares\Students"
    "Path-Teachers" = "\\haledistrict.local\Shares\Teachers"
}

# -------------------------------
# Script-specific helpers
# -------------------------------
function Test-HostReachable {
    param([string]$ComputerName)
    return Test-Connection -ComputerName $ComputerName -Count 1 -Quiet -ErrorAction SilentlyContinue
}

# -------------------------------
# Startup banner
# -------------------------------
Write-HealthCheckHeader

# -------------------------------
# 1) Execution Context
# -------------------------------
Write-Section "1) Execution Context"

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
# 2) Identity & Domain Sanity
# -------------------------------
Write-Section "2) Identity & Domain Sanity"

Safe-Run -CheckName "HostnamePattern" -ScriptBlock {
    Write-Host "  Checking hostname pattern..."
    if ($ComputerName -match "^(STUD|TEACH)\d{2}$") {
        Add-Result -Status "PASS" -Check "HostnamePattern" -Message "Hostname matches expected workstation convention." -Data $ComputerName
    }
    else {
        Add-Result -Status "WARN" -Check "HostnamePattern" -Message "Hostname does not match expected (STUD## / TEACH##). OK during staging or admin testing." -Data $ComputerName
    }
}

Safe-Run -CheckName "DomainJoined" -ScriptBlock {
    Write-Host "  Checking domain join status..."
    if ($DomainJoined) {
        Add-Result -Status "PASS" -Check "DomainJoined" -Message "Machine is joined to a domain." -Data $DomainName
    }
    else {
        Add-Result -Status "FAIL" -Check "DomainJoined" -Message "Machine is NOT domain-joined (validation intended post-join)." -Data $ComputerName
    }
}

Safe-Run -CheckName "ExpectedDomain" -ScriptBlock {
    Write-Host "  Checking expected domain..."
    if (-not $DomainJoined) {
        Add-Result -Status "WARN" -Check "ExpectedDomain" -Message "Skipped expected-domain validation because machine is not domain-joined." -Data $ComputerName
        return
    }

    if ($DomainName -ieq "haledistrict.local") {
        Add-Result -Status "PASS" -Check "ExpectedDomain" -Message "Machine is joined to expected domain." -Data $DomainName
    }
    else {
        Add-Result -Status "FAIL" -Check "ExpectedDomain" -Message "Machine is joined to an unexpected domain." -Data $DomainName
    }
}

Safe-Run -CheckName "SecureChannel" -ScriptBlock {
    Write-Host "  Testing secure channel..."
    if (-not $DomainJoined) {
        Add-Result -Status "WARN" -Check "SecureChannel" -Message "Skipped because machine is not domain-joined." -Data $ComputerName
        return
    }

    $ok = $false
    try { $ok = Test-ComputerSecureChannel -Verbose:$false }
    catch { $ok = $false }

    if ($ok) {
        Add-Result -Status "PASS" -Check "SecureChannel" -Message "Computer secure channel to domain is healthy." -Data $ComputerName
    }
    else {
        Add-Result -Status "FAIL" -Check "SecureChannel" -Message "Computer secure channel appears broken." -Data $ComputerName
    }
}

# -------------------------------
# 3) Networking Fundamentals
# -------------------------------
Write-Section "3) Networking Fundamentals"

Safe-Run -CheckName "ActiveNICIPv4" -ScriptBlock {
    Write-Host "  Checking active NIC and IPv4..."
    $adapters = Get-NetAdapter | Where-Object { $_.Status -eq "Up" }
    if (-not $adapters) {
        Add-Result -Status "FAIL" -Check "ActiveNICIPv4" -Message "No active network adapters found." -Data ""
        return
    }

    $ipInfo = foreach ($a in $adapters) {
        Get-NetIPAddress -InterfaceIndex $a.ifIndex -AddressFamily IPv4 -ErrorAction SilentlyContinue |
            Where-Object { $_.IPAddress -notlike "169.254*" } |
            Select-Object @{n="Interface";e={$a.Name}}, IPAddress, PrefixLength
    }

    if (-not $ipInfo) {
        Add-Result -Status "WARN" -Check "ActiveNICIPv4" -Message "Active NIC found but no usable IPv4 detected (or APIPA)." -Data ($adapters.Name -join ", ")
    }
    else {
        Add-Result -Status "PASS" -Check "ActiveNICIPv4" -Message "Detected active NIC(s) and IPv4 address(es)." -Data (($ipInfo | ForEach-Object { "$($_.Interface):$($_.IPAddress)" }) -join "; ")
    }
}

Safe-Run -CheckName "DefaultGateway" -ScriptBlock {
    Write-Host "  Checking default gateway..."
    $routes = Get-NetRoute -DestinationPrefix "0.0.0.0/0" -ErrorAction SilentlyContinue | Sort-Object -Property RouteMetric
    if ($routes) {
        Add-Result -Status "PASS" -Check "DefaultGateway" -Message "Default route present." -Data $routes[0].NextHop
    }
    else {
        Add-Result -Status "FAIL" -Check "DefaultGateway" -Message "No default route (0.0.0.0/0) found." -Data ""
    }
}

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

foreach ($h in $CriticalHosts) {
    Safe-Run -CheckName "Resolve-$h" -ScriptBlock {
        Write-Host "  Resolving $h..."
        try {
            $res = Resolve-DnsName $h -ErrorAction Stop
            $ips = ($res | Where-Object { $_.IPAddress } | Select-Object -ExpandProperty IPAddress) -join ", "
            Add-Result -Status "PASS" -Check "Resolve-$h" -Message "Name resolves." -Data $ips
        }
        catch {
            Add-Result -Status "WARN" -Check "Resolve-$h" -Message "Name did not resolve (may be expected early or signal only)." -Data $_.Exception.Message
        }
    }
}

foreach ($h in $CriticalHosts) {
    Safe-Run -CheckName "Ping-$h" -ScriptBlock {
        Write-Host "  Pinging $h..."
        $ok = $false
        try { $ok = Test-HostReachable -ComputerName $h }
        catch { $ok = $false }

        if ($ok) {
            Add-Result -Status "PASS" -Check "Ping-$h" -Message "ICMP reachable." -Data $h
        }
        else {
            Add-Result -Status "WARN" -Check "Ping-$h" -Message "ICMP not reachable (may be blocked; signal only)." -Data $h
        }
    }
}

# -------------------------------
# 4) File Services & Automation Paths
# -------------------------------
Write-Section "4) File Services & Automation Paths"

foreach ($label in $PathChecks.Keys) {
    $path = $PathChecks[$label]
    Safe-Run -CheckName $label -ScriptBlock {
        Write-Host "  Testing path: $path..."
        if (Test-Path $path) {
            Add-Result -Status "PASS" -Check $label -Message "Path accessible." -Data $path
        }
        else {
            Add-Result -Status "FAIL" -Check $label -Message "Path not accessible." -Data $path
        }
    }
}

# -------------------------------
# 5) Time & Security Posture (Light)
# -------------------------------
Write-Section "5) Time & Security Posture (Light)"

Safe-Run -CheckName "TimeServiceStatus" -ScriptBlock {
    Write-Host "  Checking w32time service..."
    $svc = Get-Service w32time -ErrorAction SilentlyContinue
    if (-not $svc) {
        Add-Result -Status "FAIL" -Check "TimeServiceStatus" -Message "w32time service not found." -Data ""
        return
    }

    if ($svc.Status -eq "Running") {
        Add-Result -Status "PASS" -Check "TimeServiceStatus" -Message "w32time is running." -Data $svc.Status
    }
    else {
        Add-Result -Status "WARN" -Check "TimeServiceStatus" -Message "w32time is not running." -Data $svc.Status
    }
}

Safe-Run -CheckName "TimeSource" -ScriptBlock {
    Write-Host "  Checking time source..."
    try {
        $src = (w32tm /query /source) 2>$null
        if ($src) {
            if ($DomainJoined -and ($src -match "Local CMOS Clock")) {
                Add-Result -Status "WARN" -Check "TimeSource" -Message "Time source is Local CMOS Clock (unexpected long-term for domain-joined)." -Data $src.Trim()
            }
            else {
                Add-Result -Status "PASS" -Check "TimeSource" -Message "Time source reported." -Data $src.Trim()
            }
        }
        else {
            Add-Result -Status "WARN" -Check "TimeSource" -Message "Unable to query time source." -Data ""
        }
    }
    catch {
        Add-Result -Status "WARN" -Check "TimeSource" -Message "Unable to query time source." -Data $_.Exception.Message
    }
}

Safe-Run -CheckName "FirewallProfiles" -ScriptBlock {
    Write-Host "  Checking firewall profiles..."
    $profiles = Get-NetFirewallProfile -ErrorAction SilentlyContinue
    if (-not $profiles) {
        Add-Result -Status "WARN" -Check "FirewallProfiles" -Message "Unable to read firewall profiles." -Data ""
        return
    }

    $disabled = $profiles | Where-Object { $_.Enabled -ne $true }
    if ($disabled) {
        Add-Result -Status "FAIL" -Check "FirewallProfiles" -Message "One or more firewall profiles are disabled." -Data (($disabled | Select-Object -ExpandProperty Name) -join ", ")
    }
    else {
        Add-Result -Status "PASS" -Check "FirewallProfiles" -Message "All firewall profiles are enabled." -Data (($profiles | Select-Object -ExpandProperty Name) -join ", ")
    }
}

Safe-Run -CheckName "DefenderService" -ScriptBlock {
    Write-Host "  Checking WinDefend..."
    $svc = Get-Service WinDefend -ErrorAction SilentlyContinue
    if (-not $svc) {
        Add-Result -Status "WARN" -Check "DefenderService" -Message "WinDefend not found (may be replaced or disabled by policy)." -Data ""
        return
    }

    if ($svc.Status -eq "Running") {
        Add-Result -Status "PASS" -Check "DefenderService" -Message "WinDefend is running." -Data $svc.Status
    }
    else {
        Add-Result -Status "WARN" -Check "DefenderService" -Message "WinDefend is not running." -Data $svc.Status
    }
}

Safe-Run -CheckName "Smb1Disabled" -ScriptBlock {
    Write-Host "  Checking SMB1 state..."
    $smb1 = $null
    try {
        $smb1 = Get-WindowsOptionalFeature -Online -FeatureName SMB1Protocol -ErrorAction Stop
    }
    catch { }

    if ($smb1) {
        if ($smb1.State -eq "Disabled") {
            Add-Result -Status "PASS" -Check "Smb1Disabled" -Message "SMB1Protocol is disabled." -Data $smb1.State
        }
        else {
            Add-Result -Status "WARN" -Check "Smb1Disabled" -Message "SMB1Protocol is not disabled (recommend disabling)." -Data $smb1.State
        }
    }
    else {
        Add-Result -Status "WARN" -Check "Smb1Disabled" -Message "Unable to query SMB1Protocol feature state." -Data ""
    }
}

# -------------------------------
# 6) Local Privilege Boundary
# -------------------------------
Write-Section "6) Local Privilege Boundary"

Safe-Run -CheckName "LocalAdminsMembership" -ScriptBlock {
    Write-Host "  Enumerating local Administrators group..."
    try {
        $admins = Get-LocalGroupMember -Group "Administrators" -ErrorAction Stop | Select-Object -ExpandProperty Name
        Add-Result -Status "PASS" -Check "LocalAdminsMembership" -Message "Enumerated local Administrators group." -Data ($admins -join ", ")
    }
    catch {
        Add-Result -Status "WARN" -Check "LocalAdminsMembership" -Message "Unable to enumerate local Administrators group." -Data $_.Exception.Message
    }
}

# -------------------------------
# 7) GPO Health Indicators (Light)
# -------------------------------
Write-Section "7) GPO Health Indicators (Light)"

Safe-Run -CheckName "GpResult-Computer" -ScriptBlock {
    Write-Host "  Running gpresult..."
    try {
        $out = (gpresult /r /scope computer) 2>$null
        if ($out) {
            Add-Result -Status "PASS" -Check "GpResult-Computer" -Message "gpresult executed successfully." -Data ""
        }
        else {
            Add-Result -Status "WARN" -Check "GpResult-Computer" -Message "gpresult returned no output." -Data ""
        }
    }
    catch {
        Add-Result -Status "WARN" -Check "GpResult-Computer" -Message "Unable to run gpresult." -Data $_.Exception.Message
    }
}

# -------------------------------
# Summary
# -------------------------------
Write-HealthCheckScorecard -Note "Validation-first. No remediation performed."
Export-HealthCheckResults -OutputPath $OutputPath -BaseName "HD4-HealthCheck-Workstation.ps1"

# -------------------------------
# Exit codes per Charter §4
# -------------------------------
exit (Get-HealthCheckExitCode)
