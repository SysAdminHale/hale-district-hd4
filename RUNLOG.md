\# HD4 RUNLOG



---



\## 2026-03-02 – Phase 0: Repository Initialization



\- Created local repository: C:\\Hale-district-HD4

\- Initialized Git repository

\- Linked remote origin (GitHub)

\- Established initial folder structure:

&nbsp;   - Assets

&nbsp;   - Docs

&nbsp;   - Scripts

&nbsp;   - Templates

\- Defined script governance standard (see Scripts/README.md)



HD4 remains in planning mode. No infrastructure deployed yet.

## 2026-03-04 — HD4 Phase 1: Forest Root Domain Controller Established

Tonight the initial infrastructure deployment for HaleDistrict HD4 began with the creation of the first domain controller.

Work started with a newly created VM **HD4-DC01**, cloned from the Windows Server template. During initial configuration it was discovered that the template still contained residual domain membership from the previous HD3 environment. The server was removed from the stale domain configuration and reset to a clean **WORKGROUP** state before continuing the build.

After sanitizing the system identity, the server was configured with a static infrastructure address:

* **Hostname:** HD4-DC01  
* **IP:** 10.0.0.10 /24  
* **Gateway:** 10.0.0.1  
* **DNS:** 127.0.0.1  

The **Active Directory Domain Services** role was then installed along with required management tools (Group Policy Management and AD administrative utilities).

After installation completed, the server was promoted to the **forest root domain controller** for a new forest:

**Domain:** `haledistrict.local`

Promotion completed successfully and the server rebooted automatically. After reboot the system was verified operational by launching **Active Directory Users and Computers**, confirming the new domain structure was present and functioning.

This marks the successful establishment of the **HD4 Active Directory forest**, providing the core directory, authentication, DNS, and Group Policy infrastructure for the environment.

### Current HD4 Infrastructure State

* **HD4-DC01**

  * Forest Root Domain Controller
  * DNS Server
  * Global Catalog
  * Domain: `haledistrict.local`

### Notes / Observations

The cloning issue revealed that the current Windows Server template was captured after domain membership had already been established. In a future session the golden image will be rebuilt using **Sysprep /generalize** to ensure templates remain fully pristine before deployment.

### Next Planned Steps

1. Validate DNS zones and run **dcdiag** health checks
2. Establish the baseline **HaleDistrict OU structure**
3. Build **HD4-RT01** (router / gateway infrastructure)
4. Build **HD4-FS01** (file services and script repository)

HD4 infrastructure foundation is now operational.

## 2026-03-05 DC01 final validation

Validated health of HD4-DC01 using dcdiag, DNS resolution tests, SYSVOL verification, and NETLOGON share confirmation. All core Active Directory services are operating normally for a single-domain-controller forest.

## 2026-03-05 — FS01 Domain Join and File Server Role Installation

Objective

Bring HD4-FS01 online as the first member server in the HD4 environment and prepare it to host shared resources for the HaleDistrict domain.

Actions Completed

Verified network connectivity and DNS resolution from FS01 to the domain controller.

ping 10.0.0.10

ping HD4-DC01

ping haledistrict.local

Successfully joined HD4-FS01 to the haledistrict.local domain.

Confirmed successful domain join with the message:

"Welcome to the haledistrict.local domain."

Logged back in using domain administrator credentials.

Attempted to install the File Server role using Server Manager GUI, but the wizard became blocked at the Features screen with the Next button disabled (same behavior observed previously in HD3).

Switched to PowerShell approach, which bypassed the GUI wizard.

PowerShell Installation

Executed in Windows PowerShell (not PowerShell 7):

Install-WindowsFeature -Name FS-FileServer -IncludeManagementTools

Result:

Success : True
Restart Needed : No
Feature Result : {File and iSCSI Services, File Server}

This confirmed the File Server role installed successfully on HD4-FS01.

Current HD4 Infrastructure State
HD4-DC01   Domain Controller / DNS
HD4-FS01   Domain Member Server / File Server

Network:

10.0.0.10   HD4-DC01
10.0.0.11   HD4-FS01

Domain:

haledistrict.local
Observations

The Server Manager wizard again exhibited the “Next button disabled” issue on the Features page.

Using PowerShell to install roles proved more reliable and repeatable.

This reinforces the practice of preferring PowerShell for infrastructure configuration tasks.

Next Steps (Planned for Next Session)

Add a dedicated data disk to HD4-FS01 in Hyper-V.

Initialize the disk and create a DATA volume (D:).

Create HaleDistrict share structure:

D:\Shares
D:\Shares\Scripts
D:\Shares\Students
D:\Shares\Teachers

Publish first SMB share:

\\HD4-FS01\Scripts

Begin preparing FS01 as the central script repository for workstation baseline automation.

Status

HD4-FS01 is now fully domain-joined and operating as a File Server. Core infrastructure for HD4 is functioning normally and ready for the storage configuration phase in the next session.

## 2026-03-06 FS01 Storage Layer complete

FS01 Storage Layer Completed

Initialized DATA disk (D:) for HD4-FS01 and created the HaleDistrict folder hierarchy.
Established root NTFS permission baseline on D:\HaleDistrict using domain-based access control:
- Domain Admins: Full Control
- Domain Users: Read & Execute
- SYSTEM and Administrators retained for local control
- CREATOR OWNER retained for object ownership behavior

Configured Scripts$ share for centralized script distribution with:
- Domain Admins: Full Control
- Domain Computers: Read & Execute

This establishes the file server foundation for HD4, enabling centralized script distribution and future departmental share structures while maintaining clean NTFS inheritance from the HaleDistrict root.

## 2026-03-07 RT01 configured and persistent

RT01 Network Persistence Implemented

Configured Netplan to make RT01 interface configuration persistent.

eth0: DHCP from upstream home router (WAN)
eth1: Static 10.0.0.1/24 (HD4 LAN gateway)

Validated configuration by rebooting RT01 and confirming:

- eth1 automatically comes up
- gateway address persists
- routing and NAT remain functional

RT01 now behaves as a persistent router appliance for the HD4 environment.

## 2026-03-07 ADM01 built and joine HD4

Work today focused on completing the initial build and configuration of **HD4-ADM01**, the administrative workstation for the HD4 HaleDistrict environment.

The VM was successfully created and configured from the Windows 11 base image. The machine was renamed **HD4-ADM01**, networking verified, and the system was joined to the **haledistrict.local** domain. After reboot, domain authentication was confirmed by logging in as `haledistrict\administrator` and verifying identity using `whoami`.

Administrative tooling was then installed and verified, including **RSAT components required for Active Directory administration**. This established ADM01 as the primary administrative workstation for managing the HD4 environment.

An attempt was made to convert the system into a reusable **golden image for administrative workstations** using **Sysprep with OOBE + Generalize**. The system was temporarily removed from the domain and Sysprep validation troubleshooting was attempted, including removal of Windows AppX provisioning packages that commonly block Sysprep in Windows 11 environments. Despite remediation attempts, Sysprep continued to fail validation.

At this point a decision was made to **abandon the golden image conversion for this specific VM** and instead keep the system as the operational **HD4-ADM01 administrative workstation**. The machine was successfully rejoined to the domain and domain authentication was again verified via PowerShell.

Key takeaway: administrative workstation golden images should ideally be created **before domain joining and mid-build changes**. A clean golden image for Windows 11 administrative systems may be created later in a dedicated build session.

HD4-ADM01 is now fully operational and serving as the primary management workstation for the HaleDistrict HD4 environment.

Next planned work:
• Continue infrastructure configuration using ADM01
• Begin preparing workstation deployment strategy for TEACH and STUD machines
• Revisit Windows 11 golden image creation in a clean build workflow

## 2026-03-08 — HD4 Workstation Deployment Pipeline Validated (HD4-TEACH01)

### Objective
Validate the HD4 workstation deployment workflow using the Windows 11 golden image and differencing disks.  
The goal was to confirm that new workstations can be rapidly deployed, renamed, domain joined, and placed into the correct OU with minimal manual configuration.

### Steps Performed

1. Created new VM **HD4-TEACH01** on host **HD-WS01** using the Hyper-V New Virtual Machine Wizard.
   - Generation: 2
   - Memory: 4096 MB
   - Network: HD4-LAN
   - Virtual disk: attached later (differencing model)

2. Created a **differencing disk** using the Hyper-V Virtual Hard Disk Wizard:
   - Disk name: `HD4-TEACH01.vhdx`
   - Disk type: Differencing
   - Location: `C:\HyperV\VMs\HD4-TEACH01`
   - Parent disk: `C:\HyperV\GoldenImages\GOLD-WIN11-BUILD.vhdx`

3. Attached the differencing disk to the **SCSI controller** of HD4-TEACH01 and started the VM.

4. Verified that the workstation booted successfully from the golden image.

5. Renamed the workstation using PowerShell:

   Rename-Computer -NewName "HD4-TEACH01" -Restart

6. Joined the workstation to the **haledistrict.local** domain:

   Add-Computer -DomainName "haledistrict.local" -Credential haledistrict\Administrator -Restart

7. Verified the computer object appeared in Active Directory.

8. Moved the computer object to the correct OU:

   HD4
     Computers
       Workstations

### Result

The HD4 workstation provisioning pipeline was successfully validated.

The following architecture is now operational:

Golden Image
    GOLD-WIN11-BUILD.vhdx
        │
        └── HD4-TEACH01.vhdx (differencing disk)

This confirms that HD4 can rapidly deploy new workstations without reinstalling the operating system, while maintaining a clean, immutable golden image.

### Notes

- The workstation automatically synchronized time with the domain after joining Active Directory.
- DNS resolution and domain discovery functioned correctly through the HD4 network stack (RT01 → DC01).
- This workflow will be reused for additional workstations such as **HD4-STUD01**, **HD4-STUD02**, and future teacher machines.

### Next Steps

1. Deploy additional workstations using the golden image pipeline.
2. Begin applying and testing **HD4 workstation GPOs**.
3. Validate baseline workstation configuration and security policies.
4. Continue documenting workstation lifecycle procedures for HD4.

## 2026-03-09 Disk chain repair

RT01 disk chain repair and boot restoration

Recovered HD4-RT01 after Hyper-V differencing disk chain break caused by parent path mismatch. Reconnected parent disk (GOLD-UBUNTU-SRV.vhdx), repaired EFI boot entry, and confirmed successful Ubuntu 24.04 boot.

Current infrastructure state:
HD4-DC01  – Running
HD4-FS01  – Running
HD4-ADM01 – Running
HD4-RT01  – Running

HaleDistrict core services fully restored.