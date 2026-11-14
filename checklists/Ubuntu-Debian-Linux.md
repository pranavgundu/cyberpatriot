# Ubuntu / Debian Checklist

Work top to bottom. Tick a box only after you've checked it on **this** image.
Open a terminal. Step 1 downloads the script directly; you do not need Git or a clone.

> **Three rules that save you from penalties**
> 1. **The README decides.** If it says a user, app, or service is needed, keep it.
> 2. **Forensics first.** Answer every forensic question before deleting anything.
> 3. **Never lock yourself out.** Keep the VM console open and at least one other working admin.

> **Old image?** Ubuntu 14 (Upstart) and end-of-life releases aren't supported by the script. Use the manual steps (3 through 6) only.

---

## Step 1: Get ready

- [ ] **Take a VM snapshot.**
- [ ] **Write down the starting score.**
- [ ] **Download the script from GitHub:**

  ```bash
  mkdir -p "$HOME/cyberpatriot-scripts" && cd "$HOME/cyberpatriot-scripts" &&
    curl -fL --output linux.sh https://raw.githubusercontent.com/pranavgundu/cyberpatriot/main/scripts/linux.sh
  ```

  If `curl` is missing, run `sudo apt update && sudo apt install curl`, then retry. If the download returns `404`, use the [private repository download instructions](README.md#private-repository-downloads) instead. Review `linux.sh` before running it as root. Use this folder for all script commands below. Do not pipe the download into Bash; apply mode needs an interactive terminal.

- [ ] **Run the audit script.** It reads system settings and saves a report without changing those settings.

  ```bash
  sudo bash linux.sh --audit
  ```

  Write down the report folder it prints at the top.

- [ ] **Figure out what you're on:**
  - OS version: `cat /etc/os-release`
  - Desktop or server? (Is there a GUI?)
  - Login screen: GDM (Ubuntu desktop) or LightDM (older Ubuntu / other flavors)
- [ ] **Read the README and write down:**
  - every authorized user, and which ones are admins
  - required apps and services (e.g. SSH, Apache, Samba, MySQL)
  - required open ports (e.g. `22/tcp` for SSH)
  - any special tasks ("create group X", "add user Y")
- [ ] **Answer every forensic question and save the answers.**

---

## Step 2: Run the script fixes

Run apply mode. It asks before **every** change. Type `y` only if it fits the README.

```bash
sudo bash linux.sh --apply
```

Want to go slower? Run a few modules at a time:

```bash
sudo bash linux.sh --apply --modules permissions,sysctl,passwords,ssh
```

**How to answer each prompt:**

| Module | Answer `y` when | Answer `N` when |
|---|---|---|
| `permissions` | Always | No usual reason to skip |
| `sysctl` | Normal desktop or server | README says it's a router / needs IP forwarding |
| `passwords` | README gives no specific values | README gives different values; set those by hand |
| `ssh` | README doesn't need root SSH login or X11 | README needs root login or X11 forwarding |
| `firewall` | You're at the VM console. Type `ufw`, then list every required port (e.g. `22/tcp`) | You're connected over SSH |
| `security` | Turning on AppArmor / auditd / rsyslog | README says otherwise |
| `updates` | Always (takes a while) | You're on an end-of-life release with broken repos |
| `users` | Type **one** unauthorized user to lock | Blank to skip |
| `services` | Type **one** service the README forbids | Blank if unsure |
| `packages` | Type **one** hacking tool / game from the list | It's required by the README |

`users`, `services`, and `packages` handle one item per run. Repeat with `--modules users` (etc.) for more.

- [ ] **Read the end of the output.** Anything marked `FAILED` is **not** done. Fix it by hand.
- [ ] **Check the score** went up and required services still work.

---

## Step 3: Users and groups

Goal: the accounts on the machine match the README **exactly**.

- [ ] **List the human users:**

  ```bash
  getent passwd | awk -F: '$3 >= 1000 && $3 < 65534 {print $1}'
  ```

- [ ] **Delete users not in the README** (keeps their home folder):

  ```bash
  sudo deluser USERNAME
  ```

- [ ] **Make sure only `root` has UID 0:** `awk -F: '$3 == 0' /etc/passwd`. Any other name is a hidden root account.
- [ ] **List admins:** `getent group sudo adm`
- [ ] **Remove admin from users who shouldn't have it:**

  ```bash
  sudo gpasswd -d USERNAME sudo
  ```

- [ ] **Give admin to users who should have it:**

  ```bash
  sudo usermod -aG sudo USERNAME
  ```

  Always use `-aG`. Plain `-G` wipes the user's other groups.

- [ ] **Check other powerful groups:** `getent group shadow docker lxd`. Remove anyone unauthorized with `gpasswd -d`.
- [ ] **Create any users or groups the README asks for:**

  ```bash
  sudo useradd -m USERNAME
  sudo groupadd GROUPNAME
  sudo usermod -aG GROUPNAME USERNAME
  ```

- [ ] **Fix weak or blank passwords** for authorized users: `sudo passwd USERNAME`. Use a different strong password for each.
- [ ] **Set password aging on existing users.** The script only covers *new* users.

  ```bash
  sudo chage -M 90 -m 1 -W 7 USERNAME
  sudo chage -l USERNAME
  ```

  Use the README's numbers if it gives any.

- [ ] **Leave service accounts alone** (www-data, mysql, etc.). Never blank their password field.

---

## Step 4: Login, sudo and passwords

- [ ] **Check sudo rules:**

  ```bash
  sudo visudo -c
  sudo cat /etc/sudoers
  sudo ls /etc/sudoers.d
  ```

  Remove any `NOPASSWD` lines and any user/group that shouldn't have sudo. Edit **only** with `sudo visudo` (or `sudo visudo -f /etc/sudoers.d/FILE`).

- [ ] **Block blank-password logins.** Look for `nullok`:

  ```bash
  grep -n nullok /etc/pam.d/common-auth
  ```

  If found, delete just the word `nullok` from that line. Keep a root terminal open and test a login in a second terminal before closing it.

- [ ] **Set account lockout only if the README asks for it.** Snapshot first; a typo in PAM can lock everyone out. Use `pam-auth-update`, never a PAM file copied from another distro.
- [ ] **Turn off auto-login:**
  - **GDM (Ubuntu desktop):** in `/etc/gdm3/custom.conf` set `AutomaticLoginEnable=false`
  - **LightDM:** remove any `autologin-user=` line under `/etc/lightdm/`
- [ ] **Turn off guest login (LightDM only):** add `allow-guest=false` under `[Seat:*]` in `/etc/lightdm/lightdm.conf`
- [ ] **Turn on screen lock:** Settings > **Privacy** > Screen Lock (newer Ubuntu: Settings > **Privacy & Security** > Screen Lock)
- [ ] **If SSH is required**, also check:
  - `~/.ssh/authorized_keys` for every user. Remove keys you don't recognize
  - Test a **new** SSH login before closing your current one

---

## Step 5: Apps, services and files

### Software

- [ ] **Remove hacking tools and games the README doesn't need:**

  ```bash
  apt list --installed 2>/dev/null | grep -Ei 'nmap|wireshark|john|hydra|ophcrack|aircrack|kismet|netcat|nikto|sqlmap|zenmap|aisleriot|minetest'
  sudo apt remove PACKAGE
  ```

  Read the list of what will be removed before typing `Y`.

- [ ] **Check Snap apps too:** list with `snap list`; remove prohibited apps with `sudo snap remove APP`.
- [ ] **Update everything:**

  ```bash
  sudo apt update && sudo apt upgrade
  sudo snap refresh
  ```

  Don't do a full release upgrade (`do-release-upgrade`) unless the README says to.

- [ ] **Turn on automatic updates:** Software & Updates > **Updates** tab > "Automatically check for updates: Daily". On a server: `sudo dpkg-reconfigure unattended-upgrades`.

### Services

- [ ] **See what's listening:** `sudo ss -lntup`
- [ ] **Stop each service the README doesn't need:**

  ```bash
  sudo systemctl disable --now SERVICE
  ```

  Don't touch networking, display manager, or anything the README lists.

- [ ] **Harden the services you keep** (Apache/Nginx, Samba, MySQL, vsftpd, SSH, Squid, etc.) in their own config files. A firewall alone isn't enough.
- [ ] **Don't turn off IPv6 or routing** unless the README says to.

### Files

- [ ] **Find media files:**

  ```bash
  sudo find /home -type f \( -iname '*.mp3' -o -iname '*.mp4' -o -iname '*.avi' -o -iname '*.mov' -o -iname '*.wav' -o -iname '*.flac' -o -iname '*.ogg' \)
  ```

  Check forensics, then delete with `sudo rm FILE`.

- [ ] **Look for plaintext passwords and suspicious scripts** in home folders (`ls -la ~USERNAME`).

### Backdoors

Check each place. Remove anything malicious; leave anything you don't understand and ask.

- [ ] **Cron jobs:**

  ```bash
  sudo ls -la /etc/cron.*
  sudo cat /etc/crontab
  for u in $(cut -d: -f1 /etc/passwd); do sudo crontab -l -u "$u" 2>/dev/null; done
  ```

- [ ] **Timers and services:** `systemctl list-timers --all`
- [ ] **Startup apps:** `/etc/xdg/autostart/` and each user's `~/.config/autostart/`
- [ ] **`/etc/rc.local`:** should be empty or missing
- [ ] **`/etc/hosts`:** no redirects for real websites
- [ ] **APT sources:** check `/etc/apt/sources.list` and `/etc/apt/sources.list.d/` for strange repositories or PPAs.
- [ ] **SUID files that shouldn't be:**

  ```bash
  sudo find / -xdev -perm -4000 -type f 2>/dev/null
  ```

  Red flags: `bash`, `find`, `vim`, `python`, `nano`, `cp`. Fix with `sudo chmod u-s FILE`.

---

## Step 6: Finish

- [ ] **Re-run the audit** and compare it to the first one:

  ```bash
  sudo bash linux.sh --audit
  ```

- [ ] **Firewall is on:** `sudo ufw status verbose`
- [ ] **Authorized users can still log in**, including a **new** SSH session if SSH is required.
- [ ] **Required apps and services still work.**
- [ ] **Forensic answers are saved.**
- [ ] **Score is up and there are no penalties.**
- [ ] **Reboot only if needed**, then check the score again.

---

**The script doesn't do these for you:** decide who's authorized, delete users, create users, set exact README values, answer forensics, delete files, or configure individual apps.

**Testing limit:** passed syntax/static checks and isolated tests, but not run inside an Ubuntu/Debian competition VM. Snapshot first.
