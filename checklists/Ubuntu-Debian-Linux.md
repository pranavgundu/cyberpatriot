# Ubuntu / Debian Linux — script first, then the manual checklist

For an authorized VM only. Commands assume a terminal in `Scripts/`. The helper supports common APT/systemd workflows, not every old release or service role. **Ubuntu 14/Upstart and EOL repositories need manual handling; do not assume a modern script works unchanged.**

## 1. Start with the audit

- [ ] **Run the helper first:** `sudo bash linux.sh --audit`. Keep the printed report directory.
- [ ] Snapshot the VM, record starting score/OS, read README, record authorized users/admins, required services/apps/ports and special tasks.
- [ ] Complete all forensic questions before altering evidence, accounts, packages, browser history or services.
- [ ] Identify OS/version, package channels, init system and display manager. A Debian server, Ubuntu GNOME desktop and Mint Cinnamon desktop are not interchangeable.

## 2. Apply only compatible easy fixes

- [ ] Run `sudo bash linux.sh --apply`, or one group at a time: `sudo bash linux.sh --apply --modules permissions,sysctl,passwords,ssh`.
- [ ] Review exact password/aging defaults before accepting; they are not a past-year answer key. Existing account aging remains manual.
- [ ] Choose **UFW or firewalld** in the firewall module. Use console and allow every required port before restrictive rules. Never flush unknown existing rules to “start clean.”
- [ ] Confirm required SSH behavior and test a new login after changes. The helper requires systemd for its SSH reload path; manage older init systems manually.
- [ ] Verify AppArmor/SELinux and installed logging/auditing services. Missing tools are not proof a security control is unnecessary.
- [ ] Review trusted repositories before interactive updates. EOL releases may need an approved archive mirror or offline study approach, not random added repositories. Do not perform a major distro upgrade as a generic fix.
- [ ] Read skipped/failed modules and check score/functionality after each. No automatic reboot or full rollback is provided.

## 3. Complete the shared Linux manual work

- [ ] Use **Sections 3–6 of `Linux-Mint.md`** for the detailed users/groups/passwords, PAM, sudo, package, service, file, persistence and final-verification checklist. Those shared concepts apply here; substitute the actual distro/desktop configuration.
- [ ] Compare all local/NSS accounts, UID 0 identities and privileged groups against README. Create required groups/users, remove unauthorized memberships and verify another working admin manually.
- [ ] Do not confuse lock/expire with deletion. The helper preserves selected unauthorized accounts; actual account-removal requirements need explicit, evidence-preserving manual action.
- [ ] Review the **active** PAM stack and supported tooling. Ubuntu/Debian commonly use `/etc/pam.d/common-*` and `pam-auth-update`; Fedora/RHEL use different management. Never paste one distro's stack over another.
- [ ] Verify exact existing-user aging (`chage -l USER`), required next-login changes and password flags. Do not clear service-account password hashes.
- [ ] For GNOME/GDM systems, review the correct GDM and desktop screen-lock/autologin settings; for LightDM or another manager, use its actual configuration. The helper does not configure desktop/login-manager policies.
- [ ] Update applications through the channel actually used: APT, Snap, Flatpak or approved manual install. APT upgrades alone may not cover all apps.
- [ ] Match each listener to a required service. Required Apache/Nginx/SSH/database/Samba/Squid servers need **application-level** hardening, not just a service start/stop.
- [ ] Review files, permissions, SUID/SGID, sudoers, cron/systemd persistence, authorized keys, hosts/resolver and APT sources. Do not bulk-delete unfamiliar files or media before forensics.
- [ ] Preserve IPv6/routing/required network function; do not disable features just because a generic checklist says so.

## 4. Verify the result

- [ ] Re-run `sudo bash linux.sh --audit`; resolve actual failures and compare with README, not just script defaults.
- [ ] Test authorized user/admin logins, new remote sessions, required services/ports and required apps; confirm forensic answers and score/penalties.
- [ ] Reboot only if permitted/necessary, using console; recheck settings, services and score afterward.

**Support and testing limit:** modern APT/systemd workflows are the intended target. Old/EOL releases, other init systems and different PAM/application configurations require manual handling. Syntax/static checks and isolated tests passed, but apply has not been tested inside an Ubuntu/Debian competition VM. Use a snapshot; there is no full-score guarantee or complete automated rollback.
