# Round 2 — Debian 12: Next Checks and Fixes

Run these commands **inside the Debian competition VM**, not on your Mac.
Work through one numbered section at a time. Tell me the section number, output/error, and whether the score changed.

**Starting progress:** 12/19 checks reported complete. Seven remaining checks does not mean seven missing updates. These are targeted checks, not a guaranteed answer key.

## Rules for this image

- Keep **Debian 12 / Bookworm**, **LightDM**, **Chromium**, **UFW**, **SSH**, and the **CCS Client**.
- Every authorized user must retain working SSH access.
- Do not delete authorized users or their home directories.
- Leave the primary `pparker` password alone for now. Do not post passwords or password hashes.
- Keep the VM console and your current administrator session open. Do not reboot or restart LightDM for these checks.
- Do not change the clock/time zone, clear logs, or run an OS release upgrade.
- Follow the competition rules for tools, outside resources, and snapshots. Finish forensics before deleting evidence.
- Check the scoring report after each actual change and allow it to refresh. No points does not necessarily mean a change failed.

---

## 1. Confirm the OS and your administrator access — read only

```bash
grep -E '^(PRETTY_NAME|VERSION_ID|VERSION_CODENAME)=' /etc/os-release
whoami
sudo -v
```

**Expected:** Debian 12, `bookworm`, your account is `pparker`, and sudo succeeds.
**Stop if this is a different image or sudo fails.**

- Result / error:

## 2. Check administrator access — read only

```bash
getent group sudo adm
awk -F: '$3 == 0 {print $1}' /etc/passwd
sudo visudo -c
sudo grep -RnsE '^[[:space:]]*[^#[:space:]]' /etc/sudoers /etc/sudoers.d
```

Authorized administrators:

```text
pparker tstark ppotts hhogan nfury mhill pcoulson
```

- `sudo` and `adm` do **not** have to contain identical people. `adm` mainly grants log access.
- Only `root` should normally have UID 0. If other names appear, report them; do not blindly delete UID-0 accounts.
- Review direct sudo rules as well as group membership. Look for unauthorized grants, unexpected includes, and `NOPASSWD` rules.
- Edit sudo configuration **only with `visudo`**. Do not remove a rule you do not understand or your own working access.

- Result / suspicious rules:

## 3. Check existing passwords and expiration — read only

```bash
sudo passwd -S root
sudo passwd -S hhogan
sudo chage -l hhogan
grep -E '^[[:space:]]*PASS_(MAX_DAYS|MIN_DAYS|WARN_AGE)' /etc/login.defs
```

Interpretation:

- `passwd -S`: `L` means locked, `P` means a password is set, `NP` means no password. `P` does not prove the password is strong.
- A locked root password is appropriate for this image. Root SSH access must also be disabled separately.
- `Account expires: never` is normally appropriate for permanent employee accounts. **Do not expire their accounts.**
- `Password inactive: never` is not automatically a vulnerability.
- `Password expires: never` means password aging is disabled.
- `/etc/login.defs` supplies defaults; changing it does not update existing users.

### Fix 3A — only if root's password is not already locked

After `sudo -v` succeeds:

```bash
sudo passwd -l root
sudo passwd -S root
```

This locks root's password; authorized administrators can still use sudo. It does not by itself block SSH keys for root.

### Fix 3B — only if you have not already replaced hhogan's weak password

```bash
sudo passwd hhogan
```

Choose a unique, strong password and save it securely. Do not change it again merely because the score did not move.

### Optional fix 3C — password aging

The README does not specify numerical aging requirements. The following is a **reasonable example policy, not a confirmed scoring requirement**: maximum 90 days, minimum 1 day, warning 7 days.

Test it on `hhogan` first:

```bash
sudo chage -M 90 -m 1 -W 7 hhogan
sudo chage -l hhogan
```

**Check `Password expires` afterward.** Aging is measured from the last password change; an old password could immediately become expired. If it is expired, set a fresh strong password with `sudo passwd hhogan`, then verify a new login. Do not use `chage -d 0`, which forces a password change at next login.

Do not apply aging blindly to every account. Leave service accounts alone, and leave `pparker` unchanged while troubleshooting. Report the result before expanding the policy.

- Changes made / score difference:

## 4. Check password complexity, history, and lockout — read only

```bash
grep -nE 'pam_(pwquality|pwhistory|faillock|unix|deny|permit)' \
  /etc/pam.d/common-auth \
  /etc/pam.d/common-account \
  /etc/pam.d/common-password
```

```bash
sudo grep -RnsE '^[[:space:]]*[^#[:space:]]' \
  /etc/security/pwquality.conf \
  /etc/security/pwquality.conf.d \
  /etc/security/pwhistory.conf \
  /etc/security/faillock.conf 2>/dev/null
```

```bash
ls /usr/share/pam-configs/
grep -n 'nullok' /etc/pam.d/common-auth
```

**Send back these outputs before changing PAM.** Missing files or no matches are useful information; the last command may simply print nothing.

- Complexity, history, and lockout are separate controls.
- Setting `deny` in `faillock.conf` does nothing unless the PAM stack uses `pam_faillock` correctly.
- A line containing `nullok` may permit blank-password authentication through that PAM path.
- Do not copy the incomplete answer-key snippets, add duplicate PAM modules, or uncheck Unix authentication in `pam-auth-update`.
- Do not deliberately trigger a lockout on your primary administrator account.

- Output / result:

## 5. Check SSH configuration and load valid changes

First inspect the configuration:

```bash
sudo /usr/sbin/sshd -t
sudo /usr/sbin/sshd -T | grep -E '^(permitrootlogin|permitemptypasswords|passwordauthentication|pubkeyauthentication|port|allowusers|allowgroups|denyusers|denygroups|authenticationmethods) '
```

Expected for this scenario:

```text
permitrootlogin no
permitemptypasswords no
```

Keep password authentication available unless **every** authorized user has another working login method. Review any `AllowUsers`, `AllowGroups`, `DenyUsers`, or `DenyGroups` restrictions against the full authorized-user list.

`sshd -T` reads the configuration on disk; it does not prove the running daemon has reloaded it. Conditional `Match` blocks can also change settings for particular connections.

Locate relevant settings if the result is wrong:

```bash
sudo grep -RnsE '^[[:space:]]*(Include|Match|PermitRootLogin|PermitEmptyPasswords|PasswordAuthentication|AllowUsers|AllowGroups|DenyUsers|DenyGroups|AuthenticationMethods)' \
  /etc/ssh/sshd_config /etc/ssh/sshd_config.d
```

**If the effective settings are wrong, send back the output before editing.** Included files, ordering, and `Match` blocks matter; appending another line may not fix it.

If you already edited SSH, validate and reload:

```bash
sudo /usr/sbin/sshd -t && sudo systemctl reload ssh
sudo systemctl is-active ssh
sudo systemctl is-enabled ssh
```

If validation or reload fails, stop and report the error. Do not restart a broken SSH configuration. If SSH is disabled/inactive despite valid configuration, enable and start it:

```bash
sudo /usr/sbin/sshd -t && sudo systemctl enable --now ssh
```

**Important:** `PermitEmptyPasswords no` is already the OpenSSH default. Changing it may earn no points because it was already effectively disabled or is not a scored check. It also does not replace setting actual user passwords or checking PAM.

- Effective settings / reload result / score difference:

## 6. Verify UFW permits the actual SSH port

```bash
sudo ufw status verbose
sudo /usr/sbin/sshd -T | grep '^port '
sudo ss -lntp
```

Only if SSH uses port **22** and no appropriate allow rule exists:

```bash
sudo ufw allow 22/tcp
```

If SSH uses a different port, allow that port instead. Keep any other business-required allow rules. Do not reset UFW or delete rules blindly.

Only if UFW is inactive, and required ports are allowed:

```bash
sudo ufw enable
sudo ufw status verbose
```

Test a **new SSH login** from another machine if available; keep your current connection open. A new console login is also important after any authentication change.

- UFW / listening port / new-login result:

## 7. Check Bookworm repositories and package versions — read only first

```bash
grep -RhnE '^[[:space:]]*(deb |URIs:|Suites:|Components:|Enabled:)' \
  /etc/apt/sources.list /etc/apt/sources.list.d/ 2>/dev/null
apt-cache policy chromium openssh-server
apt-mark showhold
```

Expected release names are generally `bookworm`, `bookworm-updates`, and `bookworm-security`. Confirm official Debian repository origins too; suite names alone do not prove a repository is official.

**If you see `stable`, `trixie`, `testing`, `sid`, unexpected third-party sources, or missing security sources, report the output before upgrading or rewriting sources.** Debian 12 is Bookworm; the moving name `stable` no longer means Debian 12.

With correct official Bookworm repositories:

```bash
sudo apt update
```

If this reports failed downloads, signature errors, or release errors, stop and report them. Do not bypass signature checks. Only after a successful refresh:

```bash
apt list --upgradable
sudo apt upgrade
sudo apt install chromium
```

Review proposed changes before accepting. If packages are kept back, report their names rather than forcing removal or a release upgrade.

- `apt update` refreshes package indexes; it does not install updates.
- `apt upgrade` does not automatically install a missing required application.
- Matching Installed/Candidate versions mean you have what your configured repositories currently offer.
- Zero upgrades and zero update points can be completely normal. Do not downgrade packages to try to score an update.

Set Chromium as the default browser through the desktop's Preferred Applications settings. Check other authorized users' defaults too; changing yours alone does not prove the README's all-users requirement is satisfied.

- APT errors / upgradable packages / Chromium version:

## 8. Check LightDM and unexpected running software — read only

```bash
systemctl status display-manager --no-pager
sudo grep -RnsE '^[[:space:]]*(allow-guest|autologin-user|autologin-user-timeout|greeter-hide-users|greeter-show-manual-login)[[:space:]]*=' \
  /etc/lightdm /usr/share/lightdm/lightdm.conf.d 2>/dev/null
systemctl --type=service --state=running --no-pager
systemctl list-timers --all --no-pager
```

- Keep LightDM. Guest login should be disabled.
- Multiple configuration files may override each other; do not assume the first matching line is effective.
- The company does not use centralized maintenance or polling tools. Report unexpected software, but **do not remove something just because its name is unfamiliar**.
- Keep SSH, networking, the desktop, and the CCS Client working. Do not disable all services absent from the critical-services list; supporting OS services are still needed.

- Unexpected entries / result:

---

## Send back this summary

Copy only relevant outputs; do not share actual passwords, hashes, or private keys.

```text
Current score / checks passed:
1. Debian version and sudo:
2. Unexpected sudo members/rules or extra UID-0 names:
3. Root lock status and hhogan aging result:
4. PAM/password-policy outputs:
5. SSH effective settings and reload errors:
6. Firewall and new SSH-login result:
7. APT errors or upgradable packages:
8. Unexpected LightDM/services entries:
Any score changes and which action preceded them:
```

**Do not keep changing a verified setting just because it earned no points.** Use the evidence above to choose the next fix.
