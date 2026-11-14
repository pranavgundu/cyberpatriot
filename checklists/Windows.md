# Windows 10 / 11 Checklist

Work top to bottom. Tick a box only after you've checked it on **this** image.

> **Three rules that save you from penalties**
> 1. **The README decides.** If it says a user, app, or service is needed, keep it.
> 2. **Forensics first.** Answer every forensic question before deleting anything.
> 3. **Never lock yourself out.** Keep at least one other working admin account.

---

## Step 1 — Get ready

- [ ] **Take a VM snapshot.**
- [ ] **Write down the starting score and Windows version** (run `winver`).
- [ ] **Open the right PowerShell:** Start → type `Windows PowerShell` → right-click → **Run as administrator**. (Not "PowerShell 7".)
- [ ] **Go to the scripts folder** and allow scripts for this window only:

  ```powershell
  cd PATH\TO\scripts
  Set-ExecutionPolicy -Scope Process -ExecutionPolicy Bypass
  ```

- [ ] **Run the audit script.** It only reads — nothing changes.

  ```powershell
  .\windows.ps1
  ```

  Write down the report folder it prints at the top.

- [ ] **Read the README and write down:**
  - every authorized user, and which ones are admins
  - required apps (browsers, editors, etc.) and services
  - required open ports (e.g. `3389/tcp` for Remote Desktop)
  - any special tasks ("create group X", "add user Y")
- [ ] **Answer every forensic question and save the answers.**

---

## Step 2 — Let the script do the easy fixes

Preview what it would change (changes nothing):

```powershell
.\windows.ps1 -Apply -WhatIf
```

Then run it for real. Type `READY` at the start, then type `YES` (capitals) for each change you want. Anything else skips it.

```powershell
.\windows.ps1 -Apply
```

Want to go slower? Pick modules:

```powershell
.\windows.ps1 -Apply -Modules Base,Passwords,Defender,Audit
```

**How to answer each prompt:**

| Module | Type `YES` when… | Skip when… |
|---|---|---|
| `Base` | Almost always | README needs auto-login or Remote Assistance |
| `Passwords` | README gives no specific values | README gives different values → set them in `secpol.msc` |
| `Firewall` | You're at the VM console. Enter every required port (e.g. `3389/tcp`) | You're connected over Remote Desktop |
| `Defender` | No other antivirus is required | README requires a different antivirus |
| `RDP` — 1st prompt (NLA) | Always | — |
| `RDP` — 2nd prompt (disable RDP) | README does **not** need Remote Desktop | README needs Remote Desktop |
| `SMB` | Almost always | README mentions old devices / SMB1 |
| `Audit` | Always | — |
| `Updates` | Always | — |
| `Users` | Guest prompt: yes. Then type **one** unauthorized user to disable | Blank to skip |
| `Services` | Type **one** forbidden service from the list shown | Blank if unsure |

`Users` and `Services` handle one item per run. Repeat with `-Modules Users` (etc.) for more.

- [ ] **Read the end of the output.** Any `FAILED` warning is **not** done — fix it by hand.
- [ ] **Check the score** went up and required apps still work.

---

## Step 3 — Users and groups

Goal: the accounts on the machine match the README **exactly**.
GUI option: run `lusrmgr.msc` (Pro/Enterprise only).

- [ ] **List all users** (look at disabled ones too):

  ```powershell
  Get-LocalUser
  ```

- [ ] **Delete users not in the README:**

  ```powershell
  Remove-LocalUser -Name USERNAME
  ```

- [ ] **List admins:**

  ```powershell
  Get-LocalGroupMember -Group Administrators
  ```

- [ ] **Remove admin from users who shouldn't have it:**

  ```powershell
  Remove-LocalGroupMember -Group Administrators -Member USERNAME
  ```

- [ ] **Give admin to users who should have it:**

  ```powershell
  Add-LocalGroupMember -Group Administrators -Member USERNAME
  ```

- [ ] **Check Remote Desktop Users the same way:** `Get-LocalGroupMember -Group "Remote Desktop Users"`
- [ ] **Create any users or groups the README asks for:**

  ```powershell
  New-LocalUser -Name USERNAME -Password (Read-Host -AsSecureString)
  New-LocalGroup -Name GROUPNAME
  Add-LocalGroupMember -Group GROUPNAME -Member USERNAME
  ```

- [ ] **Fix weak or blank passwords** for authorized users (it will prompt):

  ```powershell
  net user USERNAME *
  ```

  Use a different strong password for each. Don't change your own unless the README says to.

- [ ] **Turn off "password never expires":**

  ```powershell
  Get-LocalUser | Select-Object Name, PasswordExpires
  Set-LocalUser -Name USERNAME -PasswordNeverExpires $false
  ```

  A blank `PasswordExpires` means it never expires.

- [ ] **Turn off "password not required":**

  ```powershell
  Get-LocalUser | Where-Object PasswordRequired -eq $false
  net user USERNAME /passwordreq:yes
  ```

- [ ] **Guest is disabled** (the script does this if you said `YES`).
- [ ] **Don't disable** the built-in Administrator or your own account unless the README says to.

---

## Step 4 — Policies

Open `secpol.msc` (Local Security Policy).

- [ ] **Account Policies → Password Policy:** match the README. If it gives nothing, the script's values are fine.
- [ ] **Account Policies → Account Lockout Policy:** match the README.
- [ ] **Local Policies → User Rights Assignment.** Check who's listed for:
  - Access this computer from the network
  - Allow log on through Remote Desktop Services
  - Act as part of the operating system → should be **empty**
  - Debug programs → **Administrators** only
  - Back up / restore files and directories → **Administrators** (and Backup Operators)

  Remove `Everyone`, `Guest`, or unauthorized users from these.

- [ ] **Local Policies → Security Options.** Common ones:
  - Accounts: Rename administrator / guest account → only if README asks
  - Interactive logon: Do not display last user name → **Enabled**
  - Network security: LAN Manager authentication level → **Send NTLMv2 response only. Refuse LM & NTLM**
  - Network access: Do not allow anonymous enumeration of SAM accounts and shares → **Enabled**

  Don't change one that would break something the README needs.

---

## Step 5 — Apps, services and files

### Software

- [ ] **Install Windows updates:** Settings → **Windows Update** → Check for updates. Repeat until nothing is left.
- [ ] **Update required apps** (Firefox, Chrome, Notepad++, etc.) from inside each app or its website.
- [ ] **Uninstall prohibited apps** (hacking tools, games, "cleaners", scareware): run `appwiz.cpl`. Check forensics first.
- [ ] **Turn off unneeded Windows features:** run `optionalfeatures.exe` and untick, if not required:
  - SMB 1.0/CIFS File Sharing Support
  - Telnet Client / TFTP Client
  - Internet Information Services (IIS) / FTP Server
- [ ] **Browser settings:** turn on pop-up blocking and SmartScreen / Safe Browsing; check proxy settings.

### Services

- [ ] **Open `services.msc`.** For each service below, if the README doesn't need it: **Stop** it and set Startup type to **Disabled**.
  - Telnet, FTP (Microsoft FTP Service), Remote Registry
  - SSDP Discovery, UPnP Device Host
  - World Wide Web Publishing (IIS), SNMP
  - Remote Access / Routing and Remote Access
- [ ] **Don't touch** networking, DNS Client, Windows Firewall, Defender, Windows Update, or the scoring service.
- [ ] **Look for odd services:** strange names, or a path pointing at a user folder or `Temp`.

### Shares

- [ ] **List shares:** `Get-SmbShare`
- [ ] **Remove shares the README doesn't need:** `Remove-SmbShare -Name SHARENAME`. Leave `ADMIN$`, `C$`, and `IPC$` alone.

### Files

- [ ] **Find media files** (lists them, doesn't delete):

  ```powershell
  Get-ChildItem C:\Users -Recurse -Force -File -ErrorAction SilentlyContinue |
      Where-Object Extension -in '.mp3', '.mp4', '.avi', '.mov', '.wav', '.flac', '.torrent' |
      Select-Object FullName, Length
  ```

  Check forensics, then delete each file.

- [ ] **Look for plaintext password files and odd `.exe`/`.bat`/`.ps1` files** in user folders.

### Backdoors

Check each place. Remove anything malicious; leave anything you don't understand and ask.

- [ ] **Scheduled tasks:** run `taskschd.msc`, look for tasks running scripts or programs from user folders.
- [ ] **Startup apps:** Task Manager → **Startup** tab.
- [ ] **Startup folders:** press Win+R, run `shell:startup`, then `shell:common startup`.
- [ ] **Hosts file:** `notepad C:\Windows\System32\drivers\etc\hosts` — no redirects for real websites.
- [ ] **Remote-control software** (TeamViewer, VNC, AnyDesk, etc.) that the README doesn't need → uninstall.
- [ ] **Run a Defender scan:**

  ```powershell
  Start-MpScan -ScanType QuickScan
  ```

  Then check Windows Security → Virus & threat protection → **Exclusions** and remove ones that look wrong.

---

## Step 6 — Finish

- [ ] **Re-run the audit** and compare it to the first one: `.\windows.ps1`
- [ ] **Authorized users can still log in.**
- [ ] **If Remote Desktop is required**, test a **new** RDP session before closing the current one.
- [ ] **Required apps and services still work.**
- [ ] **Forensic answers are saved.**
- [ ] **Score is up and there are no penalties.**
- [ ] **Reboot only if needed**, then check the score again.

---

**The script doesn't do these for you:** decide who's authorized, delete users, create users, remove admins, install updates, uninstall apps, delete files, or set user rights.

**Testing limit:** passed syntax/static checks and isolated tests, but not run inside a Windows competition VM. Snapshot first. Windows 7/8.1 aren't supported.
