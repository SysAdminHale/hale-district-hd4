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