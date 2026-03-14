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

## 2026-03-09 TEACH02 validated

### 2026-03-09 — TEACH02 Deployment and Differencing Disk Permission Fix

Continued workstation deployment for the HD4 environment. The goal of this session was to bring **HD4-TEACH02** online using the established **Golden Image → Differencing Disk → VM pipeline**.

#### Initial VM Creation Issue

During the first attempt to create the VM, Hyper-V returned the following error:

```
The Virtual Machine Management service encountered an error while configuring the hard disk.
User account does not have permission to open attachment.
Access is denied (0x80070005)
```

Investigation revealed that the **NT VIRTUAL MACHINE\Virtual Machines** security principal did not have sufficient permissions on the newly created VM directory and differencing disk.

This prevented Hyper-V from attaching the VHDX during VM creation.

#### Resolution

Permissions were corrected using the following command executed in an elevated PowerShell session on the host:

```
icacls "C:\HyperV\VMs\HD4-TEACH02" /grant "NT VIRTUAL MACHINE\Virtual Machines:(OI)(CI)F" /T
```

This successfully granted the Hyper-V service account full access to the VM directory and disk chain.

Verification confirmed that the differencing disk correctly referenced its parent image:

```
Parent: C:\HyperV\GoldenImages\GOLD-WIN11-BUILD.vhdx
Type: Differencing
```

#### VM Creation Success

After correcting permissions, the **HD4-TEACH02** virtual machine was successfully created using:

* **Generation:** 2
* **Memory:** 4096 MB
* **Network:** HD4-LAN
* **Disk:** Differencing VHDX linked to GOLD-WIN11-BUILD

The VM booted successfully and Windows initialized normally.

#### Hostname Verification

Inside the VM, the workstation name correctly appeared as:

```
HD4-TEACH02
```

No rename operation was required.

#### Current State

HD4 infrastructure now includes:

```
HD4-DC01
HD4-RT01
HD4-FS01
HD4-ADM01
HD4-TEACH01
HD4-TEACH02
```

All core infrastructure machines remain operational, and the workstation provisioning pipeline has now been validated multiple times using the Golden Image + Differencing Disk workflow.

#### Next Session Goals

1. Join **HD4-TEACH02** to `haledistrict.local`.
2. Validate baseline workstation configuration.
3. Begin applying **HD4 workstation GPOs**.
4. Verify **Desktop and Documents redirection to FS01**.
5. Continue scaling the workstation deployment pipeline for additional teacher and student machines.

## 2026-03-10 — HD4-STUD01 and TEACH02 deployment + redirected folder GPO validation

Created HD4-STUD01 and HD4-TEACH02 from GOLD-WIN11-BUILD using differencing disk workflow

Differencing disk stored in C:\HyperV\VMs\HD4-STUD01

VM created with:
-Gen2
-4GB RAM
-Network: HD4-LAN

Post-deployment:
-Renamed workstation → HD4-STUD01
-Joined domain → haledistrict.local
-Moved computer object to HD4 → Computers → Workstations

Infrastructure validation

From STUD01 and TEACH02:
-ping DC01 ✔
-ping FS01 ✔
-ping RT01 ✔
-nslookup confirmed DNS → 10.0.0.10 (HD4-DC01)

Student profile test
-Logged in as Alice Johnson (student) and Tom Smith (teacher)
-gpresult /r confirmed HD4 – Folder Redirection GPO applied

Desktop redirected to:
\\HD4-FS01\Users$\a.johnson\Desktop

Documents redirected to:
\\HD4-FS01\Users$\a.johnson\Documents

Cross-workstation validation:
-Logged into HD4-TEACH01 and HD4-TEACH02 with same teacher account
-Confirmed redirected Desktop/Documents appear identically on both machines
-Verified FS01 automatically creates user directories on first login

Result
Workstation pipeline now confirmed working end-to-end:

Golden image
→ differencing disk
→ VM deployment
→ domain join
→ OU placement
→ GPO application
→ FS01 redirected storage

Next step:
Deploy HD4-STUD02 to confirm repeatability of the student workstation pipeline.

## 2026-03-10 HD4 STUD02 validated

• STUD02 workstation deployed from golden image using differencing disk
• Computer renamed and domain joined
• Machine moved to HD4 → Computers → Workstations
• Student login successful
• Folder redirection validated for Desktop and Documents
• Storage confirmed on \\HD4-FS01\Users$
• Cross-machine file visibility confirmed between STUD01 and STUD02
• gpresult confirmed application of HD4 – Folder Redirection GPO

## 2026-03-11 DFS Namespace and Storage Quotas implemented for user shares

Implemented a DFS Namespace to provide a unified logical access path for user folder shares hosted on FS01.
Installed DFS Namespace role service on HD4-FS01.

Created domain-based namespace:
\\haledistrict.local\Shares

Added namespace folders:
-Students
-Teachers

Linked namespace folders to underlying SMB shares on FS01:
\\HD4-FS01\Students
\\HD4-FS01\Teachers

Purpose of DFS in HD4:
-Abstracts the physical file server location from clients.
-Allows future server migrations or additional file servers without changing user paths.
-Provides a single consistent UNC path for GPO folder redirection.

Folder redirection policies now reference:
\\haledistrict.local\Shares\Students
\\haledistrict.local\Shares\Teachers
instead of direct server paths.

Verified:
-Namespace resolves correctly from domain clients.
-Student and teacher redirected folders resolve through DFS.
-Access and permissions function normally through the namespace.

-This establishes the DFS abstraction layer for HD4 file services.

Installed File Server Resource Manager (FSRM) on HD4-FS01 to enforce storage quotas for redirected user folders.

Created quota template:
Student Home Folder 2GB

Configured Auto-Apply quota on:
D:\Users\*

Result:
-All user folders created under D:\Users automatically receive a 2 GB hard quota.

Created quota template:
Teacher Home Folder 10GB

Applied manual quota override to teacher user folder:
D:\Users\t.smith

Verified storage quotas:
-D:\Users\a.johnson → 2 GB
-D:\Users\t.smith → 10 GB

Purpose of quota enforcement in HD4:
-Prevents uncontrolled growth of user storage.
-Provides consistent storage limits for student accounts.
-Allows larger storage allocations for teacher accounts.

-This establishes centralized storage quota enforcement for HD4 file services.

-This milestone establishes the core HD4 file services architecture: DFS namespace abstraction, centralized user storage, and FSRM quota enforcement on FS01.

## 2026-03-2026 — Pilot Ring GPO Deployment (Student CMD Restriction)

Phase: HD4 — Group Policy Pilot Ring Implementation

Objective:
Implement a pilot-ring deployment model to safely test a student restriction GPO before broader rollout.

Actions Completed:

• Created new security group:
  HD4-GPO-PilotRing

• Added pilot members to the group:
  - Alice Johnson
  - HD4-STUD01
  - HD4-TEACH01
  - HD4-ADM01

• Created new Group Policy Object:
  HD4-STUDENTS-BlockCMD-Pilot

• Configured policy setting:
  User Configuration
  → Administrative Templates
  → System
  → Prevent access to the command prompt = Enabled

• Linked GPO to:
  HD4 → Users → Students OU

• Configured Security Filtering for staged deployment:
  - Authenticated Users
  - HD4-GPO-PilotRing

• Performed validation and troubleshooting using:
  gpupdate /force
  gpresult /r
  whoami /groups

• Confirmed successful policy application:
  Alice Johnson logged into HD4-STUD01 and received the expected restriction.

Observed system message:
"The command prompt has been disabled by your administrator."

Key Concepts Reinforced:

• Security filtering for controlled GPO deployment
• Difference between user policy evaluation and computer policy evaluation
• Importance of logon token refresh when group membership changes
• Pilot-ring strategy for safe staged policy rollout
• Use of gpresult and whoami for Group Policy troubleshooting

Outcome:

Successfully implemented and validated a pilot-ring deployment model for Group Policy in HaleDistrict HD4.  
This pattern will be reused for future policy testing and expanded in HD5 for more advanced staged deployment strategies.

Future Considerations (HD5+):

• Separate pilot groups for clarity:
  HDx-GPO-PilotUsers
  HDx-GPO-PilotComputers

• Introduce multi-stage rollout rings:
  Ring 0 — IT
  Ring 1 — Pilot
  Ring 2 — Early adopters
  Ring 3 — District-wide deployment

• Evaluate Group Policy Loopback Processing for student workstation environments.

## 2026-03-2026 Loopback GPO Implementation (Student Workstation Environment)

Phase: HD4 — Advanced Group Policy Architecture

Objective:
Implement and validate Group Policy Loopback Processing to ensure workstation-based control of the user environment.

Actions Completed:

• Created new GPO:
  HD4-STUDENT-WORKSTATION-LOOPBACK

• Configured loopback processing:
  Computer Configuration
  → Administrative Templates
  → System
  → Group Policy
  → Configure user Group Policy loopback processing mode = Enabled
  Mode: Replace

• Added user-environment restriction for testing loopback behavior:
  User Configuration
  → Administrative Templates
  → Start Menu and Taskbar
  → Remove Run menu from Start Menu = Enabled

• Linked GPO to workstation OU:
  HD4 → Computers → Workstations

• Forced policy refresh on test machines:
  gpupdate /force

Validation Tests:

• Logged into TEACH01 as Administrator
  Result: Run command blocked

• Logged into STUD01 as Alice Johnson
  Result: Run command blocked

Observed system message:
"This operation has been cancelled due to restrictions in effect on this computer."

Interpretation:

Loopback processing (Replace mode) is functioning correctly.
User policies are now determined by the computer OU rather than the user OU.

Key Concepts Reinforced:

• Difference between User Configuration and Computer Configuration policies
• Loopback Merge vs Replace behavior
• Workstation-driven user environment enforcement
• GPO processing behavior during user logon
• Importance of OU design in policy architecture

Outcome:

Successfully implemented loopback-based workstation control of user environment in HaleDistrict HD4.  
The environment now mirrors real-world school district lab policy architecture.

Next Planned Focus:

• Resume HD4 scripting development
• Expand workstation baseline automation
• Integrate healthcheck and validation scripts across HD4 infrastructure

## 2026-03-13 — HD4 HealthCheck Suite completed and operator diagnostic command established

Completed the first full HealthCheck framework for HaleDistrict HD4.

Created shared HealthCheck library:
- HD4-HealthCheck-Lib.ps1

Refactored HealthCheck scripts to use shared library functions for:
- standardized headers
- section formatting
- PASS / WARN / FAIL result collection
- scorecard generation
- CSV / TXT artifact export
- consistent exit code handling

Validated and stabilized the following HealthCheck scripts:
- HD4-HealthCheck-Core.ps1
- HD4-HealthCheck-Workstation.ps1
- HD4-HealthCheck-FS01.ps1
- HD4-HealthCheck-DFS.ps1
- HD4-HealthCheck-RT01.ps1

Built centralized script share on FS01:
- \\HD4-FS01\Scripts$
- Confirmed access from ADM01 and other HD4 systems
- Established shared folder structure for Baseline, HealthChecks, Lib, Remediation, Features, Config, and Logs

Built orchestrator script:
- HD4-HealthCheck-All.ps1

Initial orchestrator run exposed an important execution-model issue:
- FS01 HealthCheck was being launched from ADM01 instead of running on FS01
- This caused false failures for host-local checks such as D:\ paths, SMB shares, and local storage validation

Reworked HD4-HealthCheck-All.ps1 to support host-aware execution:
- Core, Workstation, DFS, and RT01 HealthChecks run locally from ADM01
- FS01 HealthCheck runs remotely on HD4-FS01
- Corrected process exit code capture for local child PowerShell executions
- Re-tested suite successfully

Built operator-facing top-level diagnostic command:
- HD4-DIAGNOSE.ps1

Purpose of HD4-DIAGNOSE:
- run the full HealthCheck suite
- interpret the suite-level result
- present a clean district-level status message for operator use

Final successful district-level result:
- PASS: 5
- FAIL: 0
- ERROR: 0
- HD4 suite result: PASS
- District Status: HEALTHY
- HALEDISTRICT HD4 IS OPERATIONAL.

Key architectural outcome:
- HD4 now has a modular HealthCheck framework with shared library logic, role-based validation, centralized logging, host-aware orchestration, and an operator-facing diagnostic command.
- This establishes the first real operations / monitoring layer for HaleDistrict.

## 2026-03-13 Phase: HD4 Final Infrastructure Layer — RT01 Network Segmentation + Firewall

Objective
Implement routed network segmentation on RT01 and enforce inter-subnet policy using iptables. Ensure rules persist across reboot.

Subnet Design
- Servers / Core LAN: 10.0.0.0/24 (Gateway: 10.0.0.1)
- Admin:              10.0.10.0/24 (Gateway: 10.0.10.1)
- Teachers:           10.0.20.0/24 (Gateway: 10.0.20.1)
- Students:           10.0.30.0/24 (Gateway: 10.0.30.1)

RT01 Configuration
Configured RT01 as the Layer-3 gateway for all internal subnets.

Key configuration steps:
- Assigned gateway IP addresses to RT01 interfaces
- Enabled IPv4 forwarding (net.ipv4.ip_forward=1)
- Configured NAT (MASQUERADE) on WAN interface for internet access
- Implemented firewall policy using iptables
- Set default FORWARD policy to DROP

Firewall Policy Implemented
Traffic control rules implemented to simulate a district-style segmented network:

- Admin subnet (10.0.10.0/24): full access to all networks
- Teachers subnet (10.0.20.0/24): access to Servers + Internet
- Students subnet (10.0.30.0/24): Internet access only
- Students blocked from Servers subnet (10.0.0.0/24)

Persistence
Installed iptables-persistent and saved active rules to:
/etc/iptables/rules.v4

Reload verified using:
sudo netfilter-persistent reload

Active rule set confirmed via:
sudo iptables -S

Validation
Connectivity testing performed:

- Internal routing between subnets verified
- Internet access verified through RT01 NAT
- Firewall policy validated through expected allow/deny behavior

Outcome
RT01 now functions as:

- Layer-3 router for HaleDistrict internal networks
- Stateful firewall enforcing network segmentation
- NAT gateway providing outbound internet access

HD4 Infrastructure Status
- DC01 Active Directory: operational
- FS01 file services and shares: operational
- ADM01 administrative workstation: operational
- Workstation baseline scripting: operational
- Golden image + differencing disk workflow: operational
- Baseline GPO configuration: operational
- RT01 routing + firewall: operational
- Segmented network architecture: operational

HD4 core infrastructure build completed.
HaleDistrict now operates with routed subnet segmentation, NAT internet access, and enforced traffic policy.

HD4 Closure — 2026-03-14

All planned HD4 infrastructure components are now operational.
RT01 provides routed subnet segmentation, NAT internet access, and enforced firewall policy.
Active Directory, file services, workstation baseline configuration, and network routing are fully functional.
Firewall rules are persisted using iptables-persistent and validated after reload.
HaleDistrict HD4 now operates as a segmented district-style lab network.
HD4 development phase concluded; preparation for HD5 architecture planning begins.

## 2026-03-14 — HD4 Environment Archived

• Completed HD4 infrastructure build.
• Implemented VLAN segmentation and firewall rules on RT01.
• Finalized workstation baseline scripts and healthcheck automation.
• Copied full VM environment and project documentation to T7 archive.
• HD4 frozen as a reproducible infrastructure snapshot.
• Preparing to begin HD5 architecture planning.