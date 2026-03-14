<#
Script Name : HD4-HealthCheck-FS01.ps1
Purpose     : Validation-first health checks for HD4-FS01 file services and script repository
Scope       : HaleDistrict HD4
Role        : FS01
Author      : HaleDistrict
Created     : 2026-03-13
Version     : 0.2.0
Dependencies: HD4-HealthCheck-Lib.ps1, domain join completed, local administrative rights

Run Context:
- Intended machine(s): HD4-FS01
- Requires elevation: Yes
- Safe to re-run: Yes

Notes:
- Read-only. Makes no changes to system state.
- Intended to validate FS01 as file server, DFS/script host, and central automation/logging repository.
- No remediation performed.
#>

[CmdletBinding()]
param(
    [string]$OutputPath = "\\HD4-FS01\Scripts$\Logs\FS01Health"
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
    -ScriptName "HD4-HealthCheck-FS01.ps1" `
    -Scope "HaleDistrict HD4" `
    -Role "FS01" `
    -Version "0.2.0" `
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

$ExpectedShares = @(
    "Scripts$",
    "Shares",
    "Users$",
    "Departments"
)

$ExpectedPaths = [ordered]@{
    "Path-DDrive"              = "D:\"
    "Path-ScriptsRoot"         = "D:\Scripts"
    "Path-ScriptsHealthChecks" = "D:\Scripts\HealthChecks"
    "Path-ScriptsLib"          = "D:\Scripts\Lib"
    "Path-ScriptsLogs"         = "D:\Scripts\Logs"
    "Path-UsersRoot"           = "D:\Users"
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
    if ($ComputerName -ieq "HD4-FS01") {
        Add-Result -Status "PASS" -Check "ExecutionHost" -Message "Script is running on HD4-FS01." -Data $ComputerName
    }
    else {
        Add-Result -Status "FAIL" -Check "ExecutionHost" -Message "This script must run on HD4-FS01." -Data $ComputerName
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
# 2) Identity & Domain Sanity
# -------------------------------
Write-Section "2) Identity & Domain Sanity"

Safe-Run -CheckName "DomainJoined" -ScriptBlock {
    Write-Host "  Checking domain join status..."
    if ($DomainJoined) {
        Add-Result -Status "PASS" -Check "DomainJoined" -Message "Machine is joined to a domain." -Data $DomainName
    }
    else {
        Add-Result -Status "FAIL" -Check "DomainJoined" -Message "Machine is NOT domain-joined." -Data $ComputerName
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
# 3) File Services Role Health
# -------------------------------
Write-Section "3) File Services Role Health"

Safe-Run -CheckName "LanmanServer" -ScriptBlock {
    Write-Host "  Checking LanmanServer service..."
    $svc = Get-Service -Name "LanmanServer" -ErrorAction SilentlyContinue
    if (-not $svc) {
        Add-Result -Status "FAIL" -Check "LanmanServer" -Message "LanmanServer service not found." -Data ""
        return
    }

    if ($svc.Status -eq "Running") {
        Add-Result -Status "PASS" -Check "LanmanServer" -Message "LanmanServer service is running." -Data $svc.Status
    }
    else {
        Add-Result -Status "FAIL" -Check "LanmanServer" -Message "LanmanServer service is not running." -Data $svc.Status
    }
}

Safe-Run -CheckName "WinRM" -ScriptBlock {
    Write-Host "  Checking WinRM service..."
    $svc = Get-Service -Name "WinRM" -ErrorAction SilentlyContinue
    if (-not $svc) {
        Add-Result -Status "FAIL" -Check "WinRM" -Message "WinRM service not found." -Data ""
        return
    }

    if ($svc.Status -eq "Running") {
        Add-Result -Status "PASS" -Check "WinRM" -Message "WinRM service is running." -Data $svc.Status
    }
    else {
        Add-Result -Status "WARN" -Check "WinRM" -Message "WinRM service is not running." -Data $svc.Status
    }
}

# -------------------------------
# 4) Shares and Paths
# -------------------------------
Write-Section "4) Shares and Paths"

foreach ($shareName in $ExpectedShares) {
    Safe-Run -CheckName "Share-$shareName" -ScriptBlock {
        Write-Host "  Checking share: $shareName..."
        $share = Get-SmbShare -Name $shareName -ErrorAction SilentlyContinue
        if ($share) {
            Add-Result -Status "PASS" -Check "Share-$shareName" -Message "Expected SMB share exists." -Data $share.Path
        }
        else {
            Add-Result -Status "FAIL" -Check "Share-$shareName" -Message "Expected SMB share not found." -Data $shareName
        }
    }
}

foreach ($label in $ExpectedPaths.Keys) {
    $path = $ExpectedPaths[$label]
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
# 5) Storage Health
# -------------------------------
Write-Section "5) Storage Health"

Safe-Run -CheckName "Volume-D" -ScriptBlock {
    Write-Host "  Checking D: volume..."
    $vol = Get-Volume -DriveLetter D -ErrorAction SilentlyContinue
    if (-not $vol) {
        Add-Result -Status "FAIL" -Check "Volume-D" -Message "D: volume not found." -Data ""
        return
    }

    $freeGB = [math]::Round($vol.SizeRemaining / 1GB, 2)
    $sizeGB = [math]::Round($vol.Size / 1GB, 2)
    Add-Result -Status "PASS" -Check "Volume-D" -Message "D: volume present." -Data "SizeGB=$sizeGB; FreeGB=$freeGB; FileSystem=$($vol.FileSystem)"
}

Safe-Run -CheckName "Volume-D-FreeSpace" -ScriptBlock {
    Write-Host "  Checking D: free space..."
    $vol = Get-Volume -DriveLetter D -ErrorAction SilentlyContinue
    if (-not $vol) {
        Add-Result -Status "FAIL" -Check "Volume-D-FreeSpace" -Message "Cannot evaluate free space because D: volume was not found." -Data ""
        return
    }

    $freeGB = [math]::Round($vol.SizeRemaining / 1GB, 2)
    if ($freeGB -ge 5) {
        Add-Result -Status "PASS" -Check "Volume-D-FreeSpace" -Message "Free space is above minimum threshold." -Data "FreeGB=$freeGB"
    }
    else {
        Add-Result -Status "WARN" -Check "Volume-D-FreeSpace" -Message "Free space is below recommended threshold." -Data "FreeGB=$freeGB"
    }
}

# -------------------------------
# 6) Script Repository Health
# -------------------------------
Write-Section "6) Script Repository Health"

Safe-Run -CheckName "HealthCheckLibFile" -ScriptBlock {
    Write-Host "  Checking library file..."
    $path = "D:\Scripts\Lib\HD4-HealthCheck-Lib.ps1"
    if (Test-Path $path) {
        Add-Result -Status "PASS" -Check "HealthCheckLibFile" -Message "HealthCheck library file exists." -Data $path
    }
    else {
        Add-Result -Status "FAIL" -Check "HealthCheckLibFile" -Message "HealthCheck library file missing." -Data $path
    }
}

# -------------------------------
# 7) Light Security / Network Checks
# -------------------------------
Write-Section "7) Light Security / Network Checks"

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
Export-HealthCheckResults -OutputPath $OutputPath -BaseName "HD4-HealthCheck-FS01.ps1"

# -------------------------------
# Exit codes per Charter §4
# -------------------------------
exit (Get-HealthCheckExitCode)