function Get-HD4Config {
  [CmdletBinding()]
  param(
    [Parameter()]
    [string]$Path = (Join-Path $PSScriptRoot "..\Config\HD4-Config.psd1")
  )

  $resolved = Resolve-Path -Path $Path -ErrorAction Stop
  $cfg = Import-PowerShellDataFile -Path $resolved

  # Minimal validation (Phase 0 friendly)
  foreach ($key in @("Domain","Hosts","VLANs","Shares")) {
    if (-not $cfg.ContainsKey($key)) {
      throw "HD4 config missing required section: $key"
    }
  }
  if (-not $cfg.Domain.Fqdn) { throw "HD4 config missing Domain.Fqdn" }

  return $cfg
}