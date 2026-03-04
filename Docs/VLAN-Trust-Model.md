\# HaleDistrict HD4 – VLAN Trust Model



\## Purpose



HD4 introduces VLAN segmentation to improve security, isolation, and realism within the HaleDistrict homelab.



The guiding principle is:



\*\*Default deny between VLANs. Allow only required traffic.\*\*



Segmentation should prevent unnecessary lateral movement while still allowing normal Active Directory and file services.



Network enforcement will occur primarily on \*\*RT01\*\*, with additional security controls applied through \*\*Windows Firewall via GPO\*\*.



---



\## Planned VLAN Layout



| VLAN | Name | Purpose | Typical Systems |

|-----|-----|-----|-----|

| 10 | Servers | Core infrastructure services | DC01, FS01 |

| 20 | Admin | Administrative workstation network | ADM01 |

| 30 | Staff | Staff workstations | TEACH01+ |

| 40 | Students | Student workstations | STUD01+ |

| 99 | Infrastructure | Router and network infrastructure | RT01 |



---



\## Subnet Plan (Initial)



| VLAN | Subnet | Gateway |

|-----|-----|-----|

| Servers | 10.0.10.0/24 | 10.0.10.1 |

| Admin | 10.0.20.0/24 | 10.0.20.1 |

| Staff | 10.0.30.0/24 | 10.0.30.1 |

| Students | 10.0.40.0/24 | 10.0.40.1 |

| Infrastructure | 10.0.99.0/24 | 10.0.99.1 |



Routing between VLANs will be handled by \*\*RT01\*\*.



---



\## Trust Relationships



\### Admin VLAN

Administrative systems may reach all other VLANs for management purposes.



Typical traffic:



\- RDP

\- WinRM / PowerShell remoting

\- SMB administrative shares

\- Remote management tools



---



\### Staff VLAN



Staff machines may access:



\- Active Directory services (DC01)

\- File shares (FS01)

\- DFS namespace



Staff machines \*\*may not initiate connections to student machines\*\*.



---



\### Student VLAN



Student machines have the most restricted access.



Allowed services:



\- DNS (DC01)

\- Kerberos / AD authentication

\- DFS/File access (FS01)



Denied services:



\- RDP to servers

\- direct server management

\- lateral communication with other student machines (future rule)



---



\### Server VLAN



Servers should communicate only where necessary.



Typical allowed traffic:



\- AD replication

\- DNS

\- SMB for DFS

\- management from Admin VLAN



---



\## Security Philosophy



HD4 emphasizes:



\* Least privilege network communication

\* Explicit trust relationships

\* Clear separation of management and client networks

\* Defense in depth (router firewall + Windows firewall)



VLAN segmentation is designed to support these goals while remaining understandable and maintainable.

