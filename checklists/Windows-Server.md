# Windows Server Checklist

Work top to bottom. Tick a box only after you've checked it on **this** image.
Built for Server 2016 / 2019 / 2022 (standalone or domain member). Server 2008 isn't supported.

> **Three rules that save you from penalties**
> 1. **The README decides.** Servers run roles (web, file, DNS, etc.) on purpose. Installed does not mean forbidden.
> 2. **Forensics first.** Answer every forensic question before deleting anything.
> 3. **Never lock yourself out.** Keep the VM console and at least one other working admin.

---

## Step 1: Get ready

- [ ] **Take a VM snapshot.**
- [ ] **Write down the starting score and Windows version** (run `winver`).
- [ ] **Find out if this is a domain controller:** open Server Manager > Local Server and check the server's role. On a DC, the script only audits. Skip Step 2 and make changes by hand.
- [ ] **Open Windows PowerShell as administrator:** open Start, type `Windows PowerShell`, right-click it, and select **Run as administrator**.
- [ ] **Download both scripts from GitHub.** No Git or clone is needed. Keep both files in the same folder:

  ```powershell
  New-Item -ItemType Directory -Force -Path "$HOME\cyberpatriot-scripts" | Out-Null
  Set-Location "$HOME\cyberpatriot-scripts"
  $base = 'https://raw.githubusercontent.com/pranavgundu/cyberpatriot/main/scripts'
  Invoke-WebRequest -UseBasicParsing -Uri "$base/windows.ps1" -OutFile windows.ps1
  Invoke-WebRequest -UseBasicParsing -Uri "$base/windows-server.ps1" -OutFile windows-server.ps1
  ```

  If a download returns `404`, use the [private repository download instructions](README.md#private-repository-downloads) instead. Review both files before running them as administrator. Use this folder for all script commands below.

- [ ] **Allow scripts for this PowerShell window only:**

  ```powershell
  Set-ExecutionPolicy -Scope Process -ExecutionPolicy Bypass
  ```

- [ ] **Run the audit script.** It reads system settings and saves a report without changing those settings.

  ```powershell
  .\windows-server.ps1
  ```

  Write down the report folder it prints at the top.

- [ ] **Read the README and write down:**
  - every authorized user, and which ones are admins
  - required **roles** (file server, IIS, FTP, DNS, DHCP, database, printing, etc.)
  - required open ports (see the table below)
  - service accounts that must keep working
  - any special tasks
- [ ] **Answer every forensic question and save the answers.**

**Common ports for required roles:**

| Role | Ports to allow |
|---|---|
| Remote Desktop | `3389/tcp` |
| File sharing (SMB) | `445/tcp` |
| Web (IIS) | `80/tcp 443/tcp` |
| FTP | `21/tcp` |
| DNS | `53/tcp 53/udp` |
| DHCP | `67/udp` |
| SQL Server | `1433/tcp` |

---

## Step 2: Run the script fixes

Skip this step on a domain controller.

Preview what it would change (changes nothing):

```powershell
.\windows-server.ps1 -Apply -WhatIf
```

Then run it **a few modules at a time**, checking the score and roles after each. Type `READY` at the start, then `YES` (capitals) for each change you want.

```powershell
.\windows-server.ps1 -Apply -Modules Base,Audit
.\windows-server.ps1 -Apply -Modules Passwords,Defender
.\windows-server.ps1 -Apply -Modules Firewall,RDP,SMB
.\windows-server.ps1 -Apply -Modules Updates,Users,Services
```

**How to answer each prompt:**

| Module | Type `YES` when | Skip when |
|---|---|---|
| `Base` | Almost always | README needs auto-login or Remote Assistance |
| `Passwords` | README gives no specific values | README gives different values; set them in `secpol.msc` |
| `Firewall` | You're at the VM console. Enter **every** port your roles need (table above) | You're connected over Remote Desktop |
| `Defender` | No other antivirus is required | README requires a different antivirus |
| `RDP`, first prompt (NLA) | Always | No usual reason to skip |
| `RDP`, second prompt (disable RDP) | README does **not** need Remote Desktop | README needs Remote Desktop (most servers do) |
| `SMB` | No old clients need SMB1 | README mentions old devices / SMB1 |
| `Audit` | Always | No usual reason to skip |
| `Updates` | Always | No usual reason to skip |
| `Users` | Guest prompt: yes. Then type **one** unauthorized user to disable | Blank to skip |
| `Services` | Type **one** forbidden service from the list | It belongs to a required role (e.g. `W3SVC` for IIS, `Spooler` for printing) |

- [ ] **Read the end of each run.** Any `FAILED` warning is **not** done. Fix it by hand.
- [ ] **After each run, check the score** and that every required role still works.

---

## Step 3: Users and groups

Goal: the accounts on the machine match the README **exactly**.
On a domain controller, use **`dsa.msc`** (Active Directory Users and Computers) instead of the commands below.

- [ ] **List all users** (look at disabled ones too): `Get-LocalUser`
- [ ] **Delete users not in the README:**

  ```powershell
  Remove-LocalUser -Name USERNAME
  ```

  Don't delete a **service account** that a role runs as. Check the Log On As column in `services.msc` first.

- [ ] **List admins:** `Get-LocalGroupMember -Group Administrators`
- [ ] **Remove admin from users who shouldn't have it:**

  ```powershell
  Remove-LocalGroupMember -Group Administrators -Member USERNAME
  ```

- [ ] **Give admin to users who should have it:**

  ```powershell
  Add-LocalGroupMember -Group Administrators -Member USERNAME
  ```

- [ ] **Check Remote Desktop Users the same way:** `Get-LocalGroupMember -Group "Remote Desktop Users"`
- [ ] **`SERVER\user` and `DOMAIN\user` are different accounts.** Don't delete a domain account because of a local finding.
- [ ] **Create any users or groups the README asks for:**

  ```powershell
  New-LocalUser -Name USERNAME -Password (Read-Host -AsSecureString)
  New-LocalGroup -Name GROUPNAME
  Add-LocalGroupMember -Group GROUPNAME -Member USERNAME
  ```

- [ ] **Fix weak or blank passwords** for authorized users: `net user USERNAME *`. Don't change a service account's password unless you also update the service.
- [ ] **Turn off "password never expires"** (except service accounts the README says to leave):

  ```powershell
  Get-LocalUser | Select-Object Name, PasswordExpires
  Set-LocalUser -Name USERNAME -PasswordNeverExpires $false
  ```

- [ ] **Turn off "password not required":** `net user USERNAME /passwordreq:yes`

---

## Step 4: Policies

Open `secpol.msc`. On a domain controller or domain member, also check `gpmc.msc`. Domain policy overrides local policy.

- [ ] **Account Policies > Password Policy / Account Lockout Policy:** match the README.
- [ ] **Local Policies > User Rights Assignment.** Check who's listed for:
  - Allow log on through Remote Desktop Services
  - Log on as a service / Log on as a batch job: **keep** role service accounts here
  - Act as part of the operating system: should be **empty**
  - Debug programs: **Administrators** only

  Remove `Everyone`, `Guest`, or unauthorized users. Don't add broad "Deny" rules.

- [ ] **Local Policies > Security Options:** same as Windows 10 (don't show last user name, NTLMv2 only, no anonymous SAM enumeration). Check that required clients still connect afterward.
- [ ] **Check what policy is actually applied:** `gpresult /r`

---

## Step 5: Roles (don't skip this)

- [ ] **List installed roles:**

  ```powershell
  Get-WindowsFeature | Where-Object Installed
  ```

- [ ] **Remove roles the README doesn't need** via Server Manager > Manage > Remove Roles and Features.

For each role you **keep**, go through its box:

- [ ] **File server:** for each share, check share permissions **and** NTFS permissions (right-click folder > Properties > Security). No `Everyone` full control. No guest/anonymous access. Test with a normal user.
- [ ] **IIS (web):** open `inetmgr`. Turn off Directory Browsing. Remove default/sample sites if not needed. Check authentication (no anonymous on admin pages) and HTTPS bindings.
- [ ] **FTP:** in `inetmgr`, turn off anonymous authentication, require SSL if possible, check which folders are exposed.
- [ ] **DNS:** open `dnsmgmt.msc`. Turn off zone transfers or limit them to listed servers. Check forwarders.
- [ ] **DHCP:** open `dhcpmgmt.msc`. Check scopes and that it only serves the right network.
- [ ] **Database (SQL Server, MySQL):** strong `sa`/root password, no blank passwords, remote access only if needed, update it.
- [ ] **Print server:** keep the Spooler running; remove unknown printers/drivers.
- [ ] **Domain controller:** check password policy in `gpmc.msc` > Default Domain Policy; check Domain Admins / Enterprise Admins / Schema Admins membership in `dsa.msc`.

---

## Step 6: Apps, services and files

### Software

- [ ] **Install Windows updates:** Settings > **Windows Update** > Check for updates (or `sconfig` > option 6 on Server Core). Repeat until nothing is left.
- [ ] **Update required apps** (browsers, runtimes, role software).
- [ ] **Uninstall prohibited apps:** run `appwiz.cpl`. Check forensics first.

### Services

- [ ] **Open `services.msc`.** Stop and disable services that **no required role** needs (Telnet, Remote Registry, SNMP, SSDP, UPnP, etc.).
- [ ] **Don't touch** networking, DNS Client, Firewall, Defender, Windows Update, the scoring service, or anything a required role uses.
- [ ] **Look for odd services:** strange names, or a path pointing at a user folder or `Temp`.

### Files

- [ ] **Find media files** (lists them, doesn't delete):

  ```powershell
  Get-ChildItem C:\Users, C:\inetpub -Recurse -Force -File -ErrorAction SilentlyContinue |
      Where-Object Extension -in '.mp3', '.mp4', '.avi', '.mov', '.wav', '.flac', '.torrent' |
      Select-Object FullName, Length
  ```

  Check forensics, then delete each file. Don't delete real website content.

- [ ] **Look for plaintext password files** and odd `.exe`/`.bat`/`.ps1` files in user and share folders.

### Backdoors

- [ ] **Scheduled tasks:** open `taskschd.msc` and look for tasks running scripts from user folders or `Temp`.
- [ ] **Startup:** Task Manager > Startup, `shell:startup`, `shell:common startup`.
- [ ] **Hosts file:** `notepad C:\Windows\System32\drivers\etc\hosts`
- [ ] **Uninstall remote-control software** (TeamViewer, VNC, AnyDesk, etc.) the README doesn't need.
- [ ] **Run a Defender scan:** `Start-MpScan -ScanType QuickScan`, then check Exclusions in Windows Security.

---

## Step 7: Finish

- [ ] **Re-run the audit** and compare: `.\windows-server.ps1`
- [ ] **Test every required role from a client**, not just the server itself (open the website or share, run a DNS lookup, etc.).
- [ ] **Test a new Remote Desktop session** before closing the current one.
- [ ] **Authorized users and service accounts still log in.**
- [ ] **Forensic answers are saved.**
- [ ] **Score is up and there are no penalties.**
- [ ] **Reboot only if needed**, then retest roles and score.

---

**The script doesn't do these for you:** decide who's authorized, delete users, create users, remove admins, configure roles, install updates, uninstall apps, delete files, or set user rights. Domain controllers are audit-only.

**Testing limit:** passed syntax/static checks and isolated tests, but not run inside a Windows Server competition VM. Snapshot first.
