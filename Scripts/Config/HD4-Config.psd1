@{
  Meta = @{
    Environment = "HD4"
    Version     = "0.1"
    Notes       = "Phase 0 planning config. Values may be placeholders until deployment."
  }

  Domain = @{
    Fqdn = "haledistrict.local"
  }

  Hosts = @{
    DC01  = "HD4-DC01"
    FS01  = "HD4-FS01"
    RT01  = "HD4-RT01"
    ADM01 = "HD4-ADM01"
  }

  VLANs = @{
    Servers  = @{ Id = 10; Subnet = "10.0.10.0/24"; Gateway = "10.0.10.1" }
    Admin    = @{ Id = 20; Subnet = "10.0.20.0/24"; Gateway = "10.0.20.1" }
    Staff    = @{ Id = 30; Subnet = "10.0.30.0/24"; Gateway = "10.0.30.1" }
    Students = @{ Id = 40; Subnet = "10.0.40.0/24"; Gateway = "10.0.40.1" }
    Infra    = @{ Id = 99; Subnet = "10.0.99.0/24"; Gateway = "10.0.99.1" }
  }

  DFS = @{
    NamespaceRoot = "\\haledistrict.local\Shares"
    Folders = @{
      Staff    = "\\FS01\Staff"
      Students = "\\FS01\Students"
      Scripts  = "\\FS01\Dist\Scripts\HD4"
    }
  }

  Shares = @{
    DistScripts = "\\FS01\Dist\Scripts\HD4"
    LogsRoot    = "\\FS01\Logs\Scripts\HD4"
  }
}