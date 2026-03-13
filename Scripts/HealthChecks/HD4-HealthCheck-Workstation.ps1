<#
Script Name : HD4-HealthCheck-Workstation.ps1
Purpose     : Validation-first workstation baseline checks for HD4 workstations
Scope       : HaleDistrict HD4
Role        : Workstation
Author      : HaleDistrict
Created     : 2026-03-13
Version     : 0.3.0
Dependencies: Domain join completed, DNS resolution available, local administrative rights

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
    [string]$OutputPath = "\\HD4-FS01\Scripts$\Logs\WorkstationHealth",
    [switch]$VerboseOutput
)

Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

trap {
    Write-Host ""
    Write-Host "FATAL: Unhandled script error: $_" -ForegroundColor Red
    exit 2
}

# -------------------------------
# Result store
# -------------------------------
$script:Results = [System.Collections.Generic.List[object]]::new()

# -------------------------------
# Helpers
# -------------------------------
function Add-Result {
    param(
        [Parameter(Mandatory)][ValidateSet("PASS","WARN","FAIL")] [string]$Status,
        [Parameter(Mandatory)][string]$Check,
        [Parameter(Mandatory)][string]$Message,
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
        [Parameter(Mandatory)][scriptblock]$ScriptBlock
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

function Write-Section {
    param([Parameter(Mandatory)][string]$Title)
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

# -------------------------------
# Header / Metadata
# -------------------------------
$ScriptName    = "HD4-HealthCheck-Workstation.ps1"
$ScriptVersion = "0.3.0"
$Now           = Get-Date

$ComputerName = $env:COMPUTERNAME
$UserName     = [System.Security.Principal.WindowsIdentity]::GetCurrent().Name
$IsAdmin      = Test-IsElevated

$DomainJoined = $false
$DomainName   = ""
try {
    $cs = Get-CimInstance Win32_ComputerSystem
    $DomainJoined = [bool]$cs.PartOfDomain
    $DomainName   = $cs.Domain
}
catch { }

Write-Section $ScriptName
Write-Host "Scope   : HaleDistrict HD4"
Write-Host "Version : $ScriptVersion"
Write-Host "Host    : $ComputerName"
Write-Host "User    : $UserName"
Write-Host "Time    : $($Now.ToString('yyyy-MM-dd HH:mm:ss'))"
Write-Host "Admin   : $IsAdmin"
Write-Host "Joined  : $DomainJoined"
Write-Host "Domain  : $DomainName"
Write-Host "Output  : $OutputPath"

# -------------------------------
# 1) Execution Context
# -------------------------------
Write-Section "1) Execution Context"

Safe-Run -CheckName "Elevation" -ScriptBlock {
    Write-Host "  Checking elevation..."
    if ($IsAdmin) {
        Add-Result PASS "Elevation" "Session is elevated" ""
    }
    else {
        Add-Result FAIL "Elevation" "Session is not elevated. Run PowerShell as Administrator." ""
    }
}

# -------------------------------
# 2) Identity & Domain Sanity
# -------------------------------
Write-Section "2) Identity & Domain Sanity"

Safe-Run -CheckName "HostnamePattern" -ScriptBlock {
    Write-Host "  Checking hostname pattern..."
    if ($ComputerName -match "^(STUD|TEACH)\d{2}$") {
        Add-Result PASS "HostnamePattern" "Hostname matches expected workstation convention" $ComputerName
    }
    else {
        Add-Result WARN "HostnamePattern" "Hostname does not match expected (STUD## / TEACH##). OK during staging." $ComputerName
    }
}

Safe-Run -CheckName "DomainJoined" -ScriptBlock {
    Write-Host "  Checking domain join status..."
    if ($DomainJoined) {
        Add-Result PASS "DomainJoined" "Machine is joined to a domain" $DomainName
    }
    else {
        Add-Result FAIL "DomainJoined" "Machine is NOT domain-joined (validation intended post-join)" ""
    }
}

Safe-Run -CheckName "ExpectedDomain" -ScriptBlock {
    Write-Host "  Checking expected domain..."
    if (-not $DomainJoined) {
        Add-Result WARN "ExpectedDomain" "Skipped expected-domain validation because machine is not domain-joined" ""
        return
    }

    if ($DomainName -ieq "haledistrict.local") {
        Add-Result PASS "ExpectedDomain" "Machine is joined to expected domain" $DomainName
    }
    else {
        Add-Result FAIL "ExpectedDomain" "Machine is joined to an unexpected domain" $DomainName
    }
}

Safe-Run -CheckName "SecureChannel" -ScriptBlock {
    Write-Host "  Testing secure channel..."
    if (-not $DomainJoined) {
        Add-Result WARN "SecureChannel" "Skipped (not domain-joined)" ""
        return
    }

    $ok = $false
    try { $ok = Test-ComputerSecureChannel -Verbose:$false }
    catch { $ok = $false }

    if ($ok) {
        Add-Result PASS "SecureChannel" "Computer secure channel to domain is healthy" ""
    }
    else {
        Add-Result FAIL "SecureChannel" "Computer secure channel appears broken" ""
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
        Add-Result FAIL "ActiveNICIPv4" "No active network adapters found" ""
        return
    }

    $ipInfo = foreach ($a in $adapters) {
        Get-NetIPAddress -InterfaceIndex $a.ifIndex -AddressFamily IPv4 -ErrorAction SilentlyContinue |
            Where-Object { $_.IPAddress -notlike "169.254*" } |
            Select-Object @{n="Interface";e={$a.Name}}, IPAddress, PrefixLength
    }

    if (-not $ipInfo) {
        Add-Result WARN "ActiveNICIPv4" "Active NIC found but no usable IPv4 detected (or APIPA)" ($adapters.Name -join ", ")
    }
    else {
        Add-Result PASS "ActiveNICIPv4" "Detected active NIC(s) and IPv4 address(es)" (($ipInfo | ForEach-Object { "$($_.Interface):$($_.IPAddress)" }) -join "; ")
    }
}

Safe-Run -CheckName "DefaultGateway" -ScriptBlock {
    Write-Host "  Checking default gateway..."
    $routes = Get-NetRoute -DestinationPrefix "0.0.0.0/0" -ErrorAction SilentlyContinue | Sort-Object -Property RouteMetric
    if ($routes) {
        Add-Result PASS "DefaultGateway" "Default route present" $routes[0].NextHop
    }
    else {
        Add-Result FAIL "DefaultGateway" "No default route (0.0.0.0/0) found" ""
    }
}

Safe-Run -CheckName "DnsServers" -ScriptBlock {
    Write-Host "  Checking DNS server configuration..."
    $dns = Get-DnsClientServerAddress -AddressFamily IPv4 -ErrorAction SilentlyContinue |
        Where-Object { $_.ServerAddresses -and $_.ServerAddresses.Count -gt 0 } |
        Select-Object -ExpandProperty ServerAddresses

    if ($dns) {
        Add-Result PASS "DnsServers" "DNS servers configured" ($dns -join ", ")
    }
    else {
        Add-Result FAIL "DnsServers" "No IPv4 DNS servers configured" ""
    }
}

$CriticalHosts = @("HD4-DC01", "HD4-FS01", "HD4-RT01")

foreach ($h in $CriticalHosts) {
    Safe-Run -CheckName "Resolve-$h" -ScriptBlock {
        Write-Host "  Resolving $h..."
        try {
            $res = Resolve-DnsName $h -ErrorAction Stop
            $ips = ($res | Where-Object { $_.IPAddress } | Select-Object -ExpandProperty IPAddress) -join ", "
            Add-Result PASS "Resolve-$h" "Name resolves" $ips
        }
        catch {
            Add-Result WARN "Resolve-$h" "Name did not resolve (may be expected early)" $_.Exception.Message
        }
    }
}

foreach ($h in $CriticalHosts) {
    Safe-Run -CheckName "Ping-$h" -ScriptBlock {
        Write-Host "  Pinging $h..."
        $ok = $false
        try { $ok = Test-Connection -ComputerName $h -Count 1 -Quiet -ErrorAction Stop }
        catch { $ok = $false }

        if ($ok) {
            Add-Result PASS "Ping-$h" "ICMP reachable" ""
        }
        else {
            Add-Result WARN "Ping-$h" "ICMP not reachable (may be blocked; signal only)" ""
        }
    }
}

# -------------------------------
# 4) File Services & Automation Paths
# -------------------------------
Write-Section "4) File Services & Automation Paths"

$PathChecks = [ordered]@{
    "Path-SYSVOL"   = "\\HD4-DC01\SYSVOL"
    "Path-Scripts"  = "\\HD4-FS01\Scripts$"
    "Path-Shares"   = "\\haledistrict.local\Shares"
    "Path-Students" = "\\haledistrict.local\Shares\Students"
    "Path-Teachers" = "\\haledistrict.local\Shares\Teachers"
}

foreach ($label in $PathChecks.Keys) {
    $path = $PathChecks[$label]
    Safe-Run -CheckName $label -ScriptBlock {
        Write-Host "  Testing path: $path..."
        if (Test-Path $path) {
            Add-Result PASS $label "Path accessible" $path
        }
        else {
            Add-Result FAIL $label "Path not accessible" $path
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
        Add-Result FAIL "TimeServiceStatus" "w32time service not found" ""
        return
    }

    if ($svc.Status -eq "Running") {
        Add-Result PASS "TimeServiceStatus" "w32time is running" ""
    }
    else {
        Add-Result WARN "TimeServiceStatus" "w32time is not running" $svc.Status
    }
}

Safe-Run -CheckName "TimeSource" -ScriptBlock {
    Write-Host "  Checking time source..."
    try {
        $src = (w32tm /query /source) 2>$null
        if ($src) {
            if ($DomainJoined -and ($src -match "Local CMOS Clock")) {
                Add-Result WARN "TimeSource" "Time source is Local CMOS Clock (unexpected long-term for domain-joined)" $src.Trim()
            }
            else {
                Add-Result PASS "TimeSource" "Time source reported" $src.Trim()
            }
        }
        else {
            Add-Result WARN "TimeSource" "Unable to query time source" ""
        }
    }
    catch {
        Add-Result WARN "TimeSource" "Unable to query time source" $_.Exception.Message
    }
}

Safe-Run -CheckName "FirewallProfiles" -ScriptBlock {
    Write-Host "  Checking firewall profiles..."
    $profiles = Get-NetFirewallProfile -ErrorAction SilentlyContinue
    if (-not $profiles) {
        Add-Result WARN "FirewallProfiles" "Unable to read firewall profiles" ""
        return
    }

    $disabled = $profiles | Where-Object { $_.Enabled -ne $true }
    if ($disabled) {
        Add-Result FAIL "FirewallProfiles" "One or more firewall profiles are disabled" (($disabled | Select-Object -ExpandProperty Name) -join ", ")
    }
    else {
        Add-Result PASS "FirewallProfiles" "All firewall profiles are enabled" (($profiles | Select-Object -ExpandProperty Name) -join ", ")
    }
}

Safe-Run -CheckName "DefenderService" -ScriptBlock {
    Write-Host "  Checking WinDefend..."
    $svc = Get-Service WinDefend -ErrorAction SilentlyContinue
    if (-not $svc) {
        Add-Result WARN "DefenderService" "WinDefend not found (may be replaced or disabled by policy)" ""
        return
    }

    if ($svc.Status -eq "Running") {
        Add-Result PASS "DefenderService" "WinDefend is running" ""
    }
    else {
        Add-Result WARN "DefenderService" "WinDefend is not running" $svc.Status
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
            Add-Result PASS "Smb1Disabled" "SMB1Protocol is disabled" ""
        }
        else {
            Add-Result WARN "Smb1Disabled" "SMB1Protocol is not disabled (recommend disabling)" $smb1.State
        }
    }
    else {
        Add-Result WARN "Smb1Disabled" "Unable to query SMB1Protocol feature state" ""
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
        Add-Result PASS "LocalAdminsMembership" "Enumerated local Administrators group" ($admins -join ", ")
    }
    catch {
        Add-Result WARN "LocalAdminsMembership" "Unable to enumerate local Administrators group" $_.Exception.Message
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
            Add-Result PASS "GpResult-Computer" "gpresult executed successfully" ""
        }
        else {
            Add-Result WARN "GpResult-Computer" "gpresult returned no output" ""
        }
    }
    catch {
        Add-Result WARN "GpResult-Computer" "Unable to run gpresult" $_.Exception.Message
    }
}

# -------------------------------
# Scorecard & Output
# -------------------------------
$Results = $script:Results.ToArray()

Write-Section "Scorecard"

$pass = @($Results | Where-Object Status -eq "PASS").Count
$warn = @($Results | Where-Object Status -eq "WARN").Count
$fail = @($Results | Where-Object Status -eq "FAIL").Count

Write-Host ("PASS: {0}  |  WARN: {1}  |  FAIL: {2}" -f $pass, $warn, $fail)
Write-Host ""
Write-Host "NOTE: This script is validation-first. Remediation is deferred unless explicitly approved."
Write-Host ""

$Results |
    Sort-Object Time |
    Select-Object Time, Status, Check, Message, Data |
    Format-Table -AutoSize

Write-Section "Summary by status"
$Results |
    Group-Object Status |
    Sort-Object Name |
    Format-Table @{Label="Status";Expression={$_.Name}}, Count -AutoSize

# -------------------------------
# Save artifacts
# -------------------------------
try {
    New-Item -ItemType Directory -Force -Path $OutputPath | Out-Null

    $timestamp = Get-Date -Format "yyyyMMdd-HHmmss"
    $csvPath   = Join-Path $OutputPath ("HD4-HealthCheck-Workstation-{0}.csv" -f $timestamp)
    $txtPath   = Join-Path $OutputPath ("HD4-HealthCheck-Workstation-{0}.txt" -f $timestamp)

    $Results | Export-Csv -NoTypeInformation -Path $csvPath

    $Results |
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

if ($fail -gt 0) { exit 1 }
exit 0
