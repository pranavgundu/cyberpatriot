# Linux Mint — run linux.sh, then finish the README-specific work

For an authorized practice/competition VM only. Commands assume a terminal in `Scripts/`. The script is not a verified Mint answer key.

## 1. Start here

- [ ] **Run the helper first:** `sudo bash linux.sh --audit`. Save the printed private report path. This audits; it does not apply fixes.
- [ ] Snapshot the VM, record the score and check OS/version with `cat /etc/os-release`.
- [ ] Read the image README; record authorized users/admins/groups, required apps, services, ports and special tasks.
- [ ] Complete all forensic questions before removing files/users/packages, changing browser history or passwords, or stopping suspect processes. Hidden files and Trash may matter.
- [ ] Keep console access and another tested administrator. Never paste usernames, paths or passwords from a different image.

## 2. Run the applicable easy-fix modules

- [ ] Run `sudo bash linux.sh --apply`; accept modules only when they match README. Or start small: `sudo bash linux.sh --apply --modules permissions,sysctl,passwords,ssh`.
- [ ] `permissions`: verify account database and sudoers modes/owners. Do not recursively chmod/chown `/etc`, `/home` or application directories.
- [ ] `sysctl`: accept workstation/member-server protections only if the image is not a router/debugging host requiring different behavior. Verify effective values and later config overrides.
- [ ] `passwords`: verify exact required aging and complexity. Defaults affect **new** accounts; existing aging/passwords remain manual. `pwquality.conf` only matters if PAM actually invokes pwquality, and PAM arguments may override it.
- [ ] `ssh`: if SSH exists, preserve required access; only disable root/X11 if not required. Check config validity and a new authorized login.
- [ ] `firewall`: choose **UFW or firewalld**, not both. On a normal Mint image UFW may already be installed, but inspect before choosing. Supply **all** required inbound ports, including non-default SSH/X2Go/web/file-sharing ports as applicable. Use console.
- [ ] `security`: verify AppArmor and installed audit/logging services. Do not remove profiles, logs or rules; do not force SELinux changes on a different distro.
- [ ] `updates`: inspect trusted repositories; apply approved APT updates and confirm security-update configuration. Do not blindly accept added PPAs or untrusted packages.
- [ ] Read all FAILED/skipped messages and recheck score after each module. Backups do not provide full rollback.

## 3. Users, groups and existing passwords

- [ ] Compare `/etc/passwd`, `getent passwd`, user home directories and `id USER` with README. Do not assume every system/service account is unauthorized.
- [ ] Check all UID 0 accounts and membership in `sudo`, `adm`, `shadow`, `docker`, `lxd` or other powerful groups. Remove only unauthorized memberships with the correct group tool.
- [ ] Confirm another working admin before demotion. The helper refuses automatic locking of sudo/wheel members; review these manually.
- [ ] Create required users/groups and memberships from README. Example pattern **only for specifically authorized names**: `sudo useradd -m NAME`, `sudo usermod -aG GROUP NAME`. Never omit `-a` when preserving supplementary groups.
- [ ] Change only the required authorized users' weak/blank passwords with `sudo passwd USER`; do not distribute a universal shared password.
- [ ] Check existing account aging with `sudo chage -l USER`. Set exact required values manually; `/etc/login.defs` alone does not update existing users.
- [ ] Use `sudo chage -d 0 USER` only when that exact user must change password at next login, not blindly on service/current accounts.
- [ ] If an account must be **removed**, note that the helper only locks/expires selected non-privileged local accounts. Locking does not remove the account or guarantee removal points. Preserve forensics/home contents and confirm requirements before exact manual removal.
- [ ] Review service-account password state and shells. Never “fix” a service account by deleting its password hash; that may create an empty password.

## 4. PAM, login, sudo and desktop gaps

- [ ] Inspect active PAM password/auth stack (`/etc/pam.d/common-password`, `common-auth`, related files) and pwquality settings. Use Mint/Ubuntu-supported PAM management, not a pasted RHEL/authselect stack.
- [ ] Confirm empty-password authentication is not allowed and lockout works as README requires. The script intentionally does not rewrite PAM/nullok/lockout because errors can lock out everyone. Test safely from console with a snapshot.
- [ ] Inspect sudo rules with `sudo visudo -c` and authorized rules in `/etc/sudoers.d/`. Remove inappropriate NOPASSWD/privilege grants only after review; edit with `visudo`, not an unchecked overwrite.
- [ ] Verify Mint login/display-manager behavior: no prohibited autologin/guest session, correct screen-lock/password behavior. Mint's LightDM/Cinnamon settings are **not** the same as Ubuntu GDM/GNOME settings; the script does not configure either automatically.
- [ ] Review file-sharing/proxy/browser settings and required SSH options beyond the helper's limited baseline, including authorized keys and any explicitly required authentication method.

## 5. Apps, services, media and persistence

- [ ] Verify installed applications with package tools, Mint Software Manager, Flatpak and any other actual installed channel. APT does not necessarily update Flatpak/Snap/manual browser installations.
- [ ] Update required browsers/apps and OpenSSH. Keep required remote management (for example X2Go if the README requires it).
- [ ] Remove explicitly prohibited packages using an interactive dependency preview. The helper has a small candidate list, not an exhaustive blacklist; no blanket purge/autoremove.
- [ ] Check listening ports and service owners (`sudo ss -lntup`). Disable only non-required web/FTP/proxy/other services. A service such as Apache or Squid may be either required or prohibited depending on the image.
- [ ] Search `/home` and required data paths for prohibited media/archives, hidden credential files and suspicious executables. The helper reports some filenames but does not delete them. Review Trash/browser history first if needed for forensics.
- [ ] Inspect `/etc/hosts`, resolver settings, APT sources/keys, crontabs, systemd services/timers, autostart files and SSH authorized keys for malicious changes. Do not delete everything unfamiliar.
- [ ] Review unusual SUID/SGID binaries, world-writable config/data and insecure ownership. Preserve legitimate package permissions; directories need appropriate **execute/traversal** bits, not a copied file mode like 640.
- [ ] Audit application-specific configuration (Samba, SSH, Apache/Nginx, database, Squid, etc.) against the README. Enabling a firewall is not a substitute for service-level access control.

## 6. Finish and verify

- [ ] Re-run `sudo bash linux.sh --audit`. Compare with the first report; read remaining failures/skips.
- [ ] Verify all forensic answers, authorized logins/admin access, required apps, services and inbound ports. Test a **new** SSH/X2Go session before closing existing access.
- [ ] Confirm firewall status/rules (`sudo ufw status verbose` if UFW selected), actual update settings and scoring/penalties.
- [ ] Reboot only if needed/allowed, from console; recheck persistence of settings, required services and score afterward. Store logs/backups privately.

**Remaining manual work:** authorized-user/group decisions and actual removal, new-account creation, required next-login password change, exact policy values, forensic answers, prohibited-file removal, and app/config details not in the baseline.

**Testing limit:** syntax/static checks and isolated tests passed, but apply has not been tested inside a Mint competition VM. Use a snapshot; there is no full-score guarantee or complete automated rollback.
