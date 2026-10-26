# Windows 10/11 — run the helper, then finish the image

Use only on an authorized competition/practice VM, under the current rules. Commands assume PowerShell is open in `Scripts/`. **Default audit is not apply.** Check boxes mean “verified on this image,” not “the script ran.” Windows 7/8.1 and old Windows 10 builds are not supported automatically.

## 1. Start here

- [ ] **Run the helper first:** in elevated **64-bit Windows PowerShell 5.1**, run ` .\windows.ps1 ` (audit only). Keep the printed private report directory.
- [ ] Take a VM snapshot; record the starting score and OS version (`winver`). Do not auto-reboot.
- [ ] Read the desktop README. Record authorized users/admins, required apps, services, inbound ports and any special tasks. Never use a past year's username blacklist.
- [ ] Open **every forensic question**. Save your evidence/answers before uninstalling, changing accounts/passwords or removing files.
- [ ] Check whether domain/organization policy manages the system. Do not disable policy or antivirus to make a script work.

## 2. Let the helper do the applicable easy fixes

- [ ] Preview: ` .\windows.ps1 -Apply -WhatIf -Modules Base,Passwords,Defender,Audit `.
- [ ] Run ` .\windows.ps1 -Apply `, answering each prompt against the README. Decline anything uncertain; use `-Modules` for one module at a time.
- [ ] `Base`: verify UAC/secure desktop, blank-password restrictions, anonymous SAM restriction, autologon off, AutoRun/Remote Assistance restrictions, and screen inactivity policy are appropriate.
- [ ] `Passwords`: confirm exact length, history, age and lockout values before accepting the generic proposed values. Existing passwords are **not** changed by policy configuration.
- [ ] `Firewall`: use the VM console, supply required ports and verify all profiles. Existing broad allow rules are **not** removed automatically.
- [ ] `Defender`: verify real-time protection/signatures. If another required antivirus is installed, do not enable a competing product blindly. Inspect exclusions manually.
- [ ] `RDP`: keep required remote access; NLA/TLS are opt-in. Disable RDP only if explicitly not required.
- [ ] `SMB`: confirm signing/SMB1 compatibility before applying. Preserve required shares and SMB2/3.
- [ ] `Audit`: check success/failure audit policy and retained Security log. Do not clear logs.
- [ ] Read `session.log`: any **FAILED**, skipped or unavailable setting remains unfinished. Recheck score and required functions after each module.

## 3. Users and groups — still needs your decisions

- [ ] Compare `Get-LocalUser` with the README. Inspect disabled as well as enabled accounts and suspicious extra accounts.
- [ ] Compare local Administrators (`S-1-5-32-544`) and Remote Desktop Users (`S-1-5-32-555`) memberships. Use SID-based tools on localized Windows; do not assume English group names.
- [ ] Remove unauthorized **admin/group memberships**, preserving another tested administrator. The helper does not demote admins automatically.
- [ ] Create any missing authorized users/groups and required memberships. These are never inferred by the script.
- [ ] Change weak/blank passwords only for authorized accounts that need it; do not reuse one published password for everyone. Preserve required service credentials.
- [ ] Review password-never-expires/password-not-required flags and required next-login password changes.
- [ ] Confirm Guest disabled if prohibited; do not arbitrarily disable built-in Administrator or the current user.
- [ ] **Account disable ≠ account deletion.** The helper disables selected users, preserving evidence. If the README/scored outcome requires actual removal, complete forensics, validate another login and remove the exact account manually with an appropriate backup. Do not assume disabling earns removal points.

## 4. Applications, updates and prohibited files

- [ ] Install approved Windows updates, then check again. The Windows helper configures/checks updates but does **not** install missing OS updates.
- [ ] Update every required browser, office/editor tool and other app (for example Chrome/Firefox/Notepad++ when required). These third-party updates are manual.
- [ ] Use Settings → Apps / Programs and Features to review installed apps. Remove only prohibited tools/games/scareware after checking forensics and dependencies. “Security tool” does not automatically mean prohibited.
- [ ] Review optional features: SMB1 client, Telnet, FTP, IIS and legacy components. Remove/disable only if not required; the helper does not uninstall these features.
- [ ] Search user folders for prohibited media/archives and credentials, with hidden files visible. **Review first; do not recursively delete by extension.** Example filename-only search:

```powershell
Get-ChildItem C:\Users -Recurse -Force -File -ErrorAction SilentlyContinue |
    Where-Object Extension -in '.mp3','.mp4','.avi','.torrent' |
    Select-Object FullName,Length
```

- [ ] Review shared folders and NTFS/share permissions. Remove unintended broad access without breaking required shares.
- [ ] Configure required browser protections, proxy settings and app-specific security according to README. The helper does not secure every app.

## 5. Services, persistence and local policy

- [ ] Match running/listening services to the README. Check owning process and path, not just the displayed name.
- [ ] Only after confirming they are unnecessary, use `Services` or Services.msc for specific FTP/Telnet/Remote Registry/SSDP/etc. Do not disable networking, DNS, firewall, Defender, update or scoring services generically.
- [ ] Inspect scheduled tasks, startup entries, Run keys, Startup folders, unusual service executables and remote-control software. Preserve evidence before removal.
- [ ] Review local user-right assignments (who can log on locally/RDP, back up, debug, act as OS). These are **manual** and role-specific.
- [ ] Review Security Options not handled by the baseline: LAN Manager/NTLM compatibility, anonymous shares, session/security signing requirements and required network authentication. Do not break legacy/required clients for a guessed point.
- [ ] Run an approved antivirus scan when permitted; review findings and exclusions. The helper does not perform a full malware investigation or guarantee cleanup.

## 6. Final verification

- [ ] Re-run ` .\windows.ps1 ` in audit mode; compare with the first report and exact README requirements.
- [ ] Confirm all forensic answers are saved, required apps open, authorized users can log in and required ports/services work.
- [ ] Test a **new** RDP/other remote session before closing an existing one.
- [ ] Check score, penalties and any failed module. Fix the actual evidence; never modify scoring internals.
- [ ] Reboot only if allowed/needed, from the console, then repeat login/service/firewall/score checks. Preserve private logs securely.

**Testing limit:** the helper passed syntax/static checks and isolated tests, but has not been tested inside a Windows competition VM. Test apply on a snapshot; it is not a guaranteed full-score solution.
