# Windows Server — run the helper, then secure the required roles

For an authorized VM only. Use current rules and image README. Commands assume elevated **64-bit Windows PowerShell 5.1**, in `Scripts/`, with **both** `windows-server.ps1` and `windows.ps1` present. Designed for modern standalone/member servers, **not automatic domain-controller hardening**.

## 1. Start here

- [ ] **Run the helper first:** ` .\windows-server.ps1 ` (audit only). Save its printed report directory.
- [ ] Snapshot the VM; record OS version, score and whether this is standalone, a domain member or a **domain controller**.
- [ ] Read README and record authorized admins/users, domain/local identities, required roles, service accounts, apps, shares, ports and special tasks.
- [ ] Complete every forensic question before altering accounts, services, files, scheduled tasks or application data.
- [ ] If this is a domain controller, **stop before apply**. The helper refuses it. Use the role-specific manual/domain policy checklist with your coach/mentor; never attempt to turn the DC into a workstation.

## 2. Apply only role-compatible baseline modules

- [ ] Preview ` .\windows-server.ps1 -Apply -WhatIf -Modules Base,Passwords,Firewall,Audit `.
- [ ] Apply one module at a time, for example ` .\windows-server.ps1 -Apply -Modules Base,Audit `. Review score and required services after each.
- [ ] `Base`: confirm anonymous access restrictions/UAC/autologon/Remote Assistance/AutoRun/session-lock settings fit the server role.
- [ ] `Passwords`: only **local** policy is changed. Generic length/history/age/lockout values must match README; domain policy may override them. No domain passwords/accounts are modified.
- [ ] `Firewall`: use console; preserve required AD/DNS/DHCP/SMB/IIS/SQL/management/other ports **as applicable**, not a universal copied port list. Review overly broad existing allow rules.
- [ ] `RDP`: preserve required admin access and test a fresh login after NLA/TLS changes. Do not disable required RDP/WinRM.
- [ ] `SMB`: preserve required shares/SMB2/3. Confirm client compatibility before requiring signing or disabling SMB1. Encryption/share-level rules remain manual.
- [ ] `Defender`: verify role-compatible antivirus, signatures, exclusions and tamper/central management. Server may have a different approved AV.
- [ ] `Audit`: confirm effective advanced audit settings and log retention. Do not clear logs.
- [ ] Read all failures/skips. A successful script exit does not prove role-specific security or correct GPO precedence.

## 3. Local users, groups and service identities

- [ ] Compare local users, Administrators, Remote Desktop Users and service logon identities with README. Distinguish `SERVER\user` from `DOMAIN\user`.
- [ ] Remove unauthorized memberships; create required local groups/users manually. Do not delete a domain identity or service account based on a local-user finding.
- [ ] Keep another tested administrator and console access. The helper protects current/built-in accounts and the last enabled local admin, but that is not proof another admin can actually log in.
- [ ] Review weak passwords, password-not-required/never-expires flags and specific next-logon requirements without breaking unattended services.
- [ ] If an unauthorized account must be **removed**, understand that the helper only disables it. Preserve forensic evidence and profile/service dependencies before exact manual removal.
- [ ] Review “log on as a service,” “log on as a batch job,” local/RDP logon, backup/debug privileges and deny rights. These are manual/role-specific; broad deny rules can block legitimate domain administrators.

## 4. Required roles — do not skip this section

- [ ] Inventory roles with `Get-WindowsFeature` if available; compare running services/listeners to required roles. **Installed ≠ prohibited.**
- [ ] **File server:** verify each required share path, share and NTFS permissions, authorized groups, no unintended anonymous/guest access, protocol/signing requirements. Test as a normal authorized user.
- [ ] **IIS/web:** verify required sites/app pools/bindings, TLS/certificates, authentication, directory listing, default content and folder permissions. Keep required web functionality.
- [ ] **FTP:** distinguish required secure transfer from prohibited FTP; verify authentication, allowed directories, anonymous access and encryption settings. The helper only offers an explicit service stop, not FTP site security.
- [ ] **DNS/DHCP:** check intended interfaces, scopes, forwarders and access rules; preserve necessary name resolution/address assignment. Do not disable these roles to reduce listeners.
- [ ] **Database:** verify required listeners, credentials, local/remote access, service identity, privileges, updates and backups using the database's own tools. No database hardening is automated here.
- [ ] **AD/domain controller (manual only):** use an authorized lab plan for account policy, privileged groups, delegation, GPO and required AD services. Do not apply this standalone/member-server baseline to a DC.
- [ ] **Routing/RRAS/NPS/printing/other:** apply README-specific rules; these may legitimately require services that a workstation checklist would disable.

## 5. Updates, applications, files and persistence

- [ ] Apply approved OS updates via the required WSUS/management/update channel. The helper preserves domain update policy and does not install updates or reboot.
- [ ] Update required browsers, runtimes, editors and role software manually. Verify role compatibility before major upgrades.
- [ ] Remove only expressly prohibited apps/features after forensics. Do not bulk-remove IIS/FTP/SMB/printing/routing/remote management.
- [ ] Search user and application data locations for prohibited media, insecure credential files and suspicious binaries without deleting evidence or required content blindly.
- [ ] Inspect scheduled tasks, startup paths, services and executable locations for persistence and unexpected identities. The helper only inventories, not fully remediates them.
- [ ] Review Defender/AV findings and exceptions; perform an approved scan if appropriate. Do not disable AV to install an unsigned “fix.”
- [ ] Inspect local security options and GPO effective results (`gpresult /r`; detailed reports as permitted). Local registry writes do not override every domain policy.

## 6. Final verification

- [ ] Re-run ` .\windows-server.ps1 ` (audit). Compare before/after and every recorded requirement.
- [ ] Test required roles **from the expected client**, not only localhost: file share, website, DNS lookup, database, remote admin, etc.
- [ ] Confirm authorized user/service logons and a fresh administrator session. Verify no service was silently broken by credentials/signing/firewall changes.
- [ ] Verify forensic answers, score and penalties; leave scoring engine/services untouched.
- [ ] Reboot only if authorized/required, using console access, then retest all roles and score. Protect report/backups.

**Support and testing limit:** intended for modern standalone/member Server 2016/2019/2022 systems with the required cmdlets. Server 2008 is not supported; domain controllers are audit-only. Syntax/static checks and isolated tests passed, but no Windows Server competition VM has been used to verify apply. Test on a snapshot; this is not a guaranteed full-score solution.
