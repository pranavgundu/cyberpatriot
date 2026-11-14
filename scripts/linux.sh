#!/usr/bin/env bash

set -u
set -o pipefail

export LC_ALL=C
PATH=/usr/sbin:/usr/bin:/sbin:/bin
export PATH
umask 077

MODE=audit
MODULES=inventory,permissions,sysctl,passwords,ssh,firewall,security,updates,users,services,packages
OUT=""


usage() {
  printf '%s\n' \
    'Usage: bash linux.sh [--audit|--apply] [--modules comma,list] [--output DIR]' \
    'Modules: inventory permissions sysctl passwords ssh firewall security updates users services packages' \
    'Default: read-only audit. Apply requires root, a terminal, and per-module confirmation.' \
    'Backups are NOT a complete rollback. Take a VM snapshot; read the image README first.'
}


while (($#)); do
  case "$1" in
    --audit)
      MODE=audit
      ;;

    --apply)
      MODE=apply
      ;;

    --modules|--output)
      (($# >= 2)) || { usage; exit 2; }
      key=$1
      shift

      if [[ $key == --modules ]]; then
        MODULES=$1
      else
        OUT=$1
      fi
      ;;

    -h|--help)
      usage
      exit 0
      ;;

    *)
      usage
      exit 2
      ;;
  esac

  shift
done


if [[ $(uname -s) != Linux ]]; then
  echo 'Linux only. No changes made.'
  exit 2
fi

IFS=',' read -r -a SELECTED <<< "$MODULES"

for m in "${SELECTED[@]}"; do
  case "$m" in
    inventory|permissions|sysctl|passwords|ssh|firewall|security|updates|users|services|packages)
      ;;

    *)
      echo "Unknown module: $m"
      exit 2
      ;;
  esac
done

if [[ $MODE == apply ]]; then
  if ((EUID != 0)); then
    echo 'Apply requires sudo/root.'
    exit 2
  fi

  if [[ ! -t 0 ]]; then
    echo 'Interactive terminal required; unattended apply is deliberately disabled.'
    exit 2
  fi
fi


if [[ -n $OUT ]]; then
  [[ $OUT == /* ]] || OUT="$PWD/$OUT"
  mkdir -m 700 -- "$OUT" || exit 2
else
  OUT=$(mktemp -d "${TMPDIR:-/tmp}/cyberpatriot-${MODE}.XXXXXXXX") || exit 2
fi

mkdir -m 700 "$OUT/backups"

exec > >(tee -a "$OUT/session.log") 2>&1

printf 'CyberPatriot helper | %s | %s\nMode: %s\nReport/backups: %s\n' \
  "$(date -Is)" "$(hostname)" "$MODE" "$OUT"

[[ -r /etc/os-release ]] && grep -E '^(NAME|VERSION|ID|ID_LIKE)=' /etc/os-release

FAILURES=0


has() {
  command -v "$1" >/dev/null 2>&1
}


ask() {
  local answer

  read -r -p "$1 [y/N] " answer
  [[ $answer == y || $answer == Y ]]
}


run() {
  printf '\n+ '
  printf '%q ' "$@"
  printf '\n'

  if "$@"; then
    return 0
  else
    local rc=$?
    echo "FAILED (exit $rc); inspect the log."
    FAILURES=$((FAILURES + 1))
    return "$rc"
  fi
}


backup() {
  local f=$1
  local dest="$OUT/backups$1"

  if [[ ! -e $f && ! -L $f ]]; then
    printf 'Originally absent: %s\n' "$f" >> "$OUT/absent-files.txt"
    return 0
  fi

  if [[ -e $dest || -L $dest ]]; then
    return 0
  fi

  mkdir -p -- "$(dirname "$dest")" && cp -a -- "$f" "$dest"
}


set_kv() {
  local file=$1
  local key=$2
  local value=$3
  local sep=$4
  local tmp

  if [[ -L $file ]]; then
    echo "Refusing symlink config: $file"
    return 1
  fi

  backup "$file" || return 1
  tmp=$(mktemp) || return 1

  if [[ -e $file ]]; then
    if ! awk -v k="$key" '$0 !~ "^[[:space:]#]*" k "([[:space:]]|=)" {print}' "$file" > "$tmp"; then
      rm -f "$tmp"
      return 1
    fi

    cat "$tmp" > "$file"
  else
    mkdir -p -- "$(dirname "$file")"
    : > "$file"
    chmod 644 "$file"
  fi

  printf '%s%s%s\n' "$key" "$sep" "$value" >> "$file"
  rm -f "$tmp"
}


inventory() {
  echo '--- Accounts (no password hashes), privileged groups, listeners, services, persistence ---'

  getent passwd | awk -F: '{print $1, "uid=" $3, "gid=" $4, "home=" $6, "shell=" $7}'
  getent group sudo wheel adm shadow docker lxd 2>/dev/null || true
  awk -F: '$3 == 0 {print "UID 0:", $1}' /etc/passwd

  if ((EUID == 0)); then
    awk -F: '$2 == "" {print "EMPTY PASSWORD:", $1}' /etc/shadow
    awk -F: '$3 == 0 || $5 == 0 {print "REVIEW PASSWORD AGING:", $1}' /etc/shadow
  fi

  has ss && run ss -lntup || true

  if has systemctl; then
    run systemctl --no-pager --type=service --state=running || true
    run systemctl --no-pager list-timers --all || true
    run systemctl --no-pager --type=socket || true
  fi

  ls -ld /etc/cron* /etc/systemd/system /etc/sudoers /etc/sudoers.d /etc/ssh/sshd_config* 2>/dev/null || true
  has visudo && run visudo -c || true

  echo 'Review user crontabs, authorized_keys, sudoers, browser settings and forensic files manually.'

  echo 'Media filenames below are leads ONLY. Nothing is deleted.'
  find /home -xdev -type f \
    \( -iname '*.mp3' -o -iname '*.mp4' -o -iname '*.torrent' \) \
    -print 2>/dev/null || true

  echo 'SUID/SGID and world-writable regular files in system binary directories (review; not removed):'
  find /usr/bin /usr/sbin /usr/local/bin /usr/local/sbin -xdev -type f \
    \( -perm /6000 -o -perm -0002 \) \
    -ls 2>/dev/null || true
}


permissions() {
  for f in /etc/passwd /etc/group /etc/shadow /etc/gshadow /etc/sudoers; do
    [[ ! -e $f ]] || stat -c '%a %U:%G %n' "$f"
  done

  [[ $MODE == apply ]] || return 0
  ask 'Set passwd/group root-owned 0644; restrict shadow/gshadow; set sudoers 0440?' || return 0

  for f in /etc/passwd /etc/group; do
    backup "$f" && run chown root "$f" && run chmod 0644 "$f" || return 1
  done

  for f in /etc/shadow /etc/gshadow; do
    [[ -f $f ]] || continue
    backup "$f" && run chown root "$f" && run chmod u=rw,g-wx,o= "$f" || return 1
  done

  if [[ -f /etc/sudoers ]] && has visudo && visudo -c; then
    backup /etc/sudoers && run chown root /etc/sudoers && run chmod 0440 /etc/sudoers
  fi
}


sysctl_module() {
  local pairs=(
    kernel.randomize_va_space=2
    kernel.kptr_restrict=2
    kernel.dmesg_restrict=1
    kernel.yama.ptrace_scope=1
    fs.suid_dumpable=0
    fs.protected_hardlinks=1
    fs.protected_symlinks=1
    net.ipv4.conf.all.accept_redirects=0
    net.ipv4.conf.default.accept_redirects=0
    net.ipv4.conf.all.secure_redirects=0
    net.ipv4.conf.default.secure_redirects=0
    net.ipv4.conf.all.send_redirects=0
    net.ipv4.conf.default.send_redirects=0
    net.ipv4.conf.all.accept_source_route=0
    net.ipv4.conf.default.accept_source_route=0
    net.ipv4.conf.all.log_martians=1
    net.ipv4.tcp_syncookies=1
    net.ipv4.tcp_rfc1337=1
  )
  local p key
  local file=/etc/sysctl.d/60-cyberpatriot.conf

  has sysctl || return 0

  for p in "${pairs[@]}"; do
    sysctl "${p%=*}" 2>/dev/null || true
  done

  [[ $MODE == apply ]] || return 0

  echo 'Sets supported ASLR, kernel visibility, link protections and IPv4 redirect/source-route protections.'
  echo 'Does NOT change IP forwarding, reverse-path filtering, IPv6, kexec or networking services.'
  ask 'Apply this workstation/member-server baseline (not a router/debugging host)?' || return 0

  [[ ! -L $file ]] || return 1
  backup "$file" || return 1

  mkdir -p /etc/sysctl.d
  : > "$file"
  chmod 644 "$file"

  for p in "${pairs[@]}"; do
    key=${p%=*}

    if sysctl "$key" >> "$OUT/sysctl-before.txt" 2>/dev/null; then
      printf '%s\n' "$p" >> "$file"
    fi
  done

  run sysctl -p "$file"
  echo 'Other sysctl files may override this on reboot; inspect effective values and later files.'
}


passwords() {
  grep -E '^[[:space:]]*(PASS_|UMASK)' /etc/login.defs || true

  grep -HnE 'pam_(pwquality|faillock|unix)|nullok' \
    /etc/pam.d/common-password \
    /etc/pam.d/common-auth \
    /etc/pam.d/system-auth \
    /etc/pam.d/password-auth \
    2>/dev/null || true

  [[ $MODE == apply ]] || return 0

  echo 'Proposed defaults for NEW accounts: max age 90, min age 1, warning 7, UMASK 027.'
  echo 'Values are generic practice choices, not verified universal CyberPatriot scoring values.'

  if ask 'Do these defaults match your README? Set them?'; then
    set_kv /etc/login.defs PASS_MAX_DAYS 90 ' ' || return 1
    set_kv /etc/login.defs PASS_MIN_DAYS 1 ' ' || return 1
    set_kv /etc/login.defs PASS_WARN_AGE 7 ' ' || return 1
    set_kv /etc/login.defs UMASK 027 ' ' || return 1
  fi

  if grep -Eq '^[^#]*pam_pwquality\.so' \
    /etc/pam.d/common-password \
    /etc/pam.d/system-auth \
    /etc/pam.d/password-auth \
    2>/dev/null; then

    if ask 'Configure active pwquality: minlen 12, 4 character classes, difok 4 (future password changes only)?'; then
      local pair

      for pair in minlen=12 minclass=4 difok=4; do
        set_kv /etc/security/pwquality.conf "${pair%=*}" "${pair#*=}" ' = ' || return 1
      done

      echo 'Check PAM arguments and pwquality.conf.d for overriding settings. Existing passwords are not changed.'
    fi
  else
    echo 'pwquality is not active. PAM was NOT edited. Use distro-supported pam-auth-update/authselect after reading its documentation.'
  fi

  echo 'Lockout, null-password PAM options, and existing account aging are reported only to avoid lockouts.'
}


ssh_module() {
  local daemon staged saved unit

  daemon=$(command -v sshd || true)

  if [[ -z $daemon || ! -f /etc/ssh/sshd_config ]]; then
    echo 'OpenSSH server not installed.'
    return 0
  fi

  run "$daemon" -t || return 1

  "$daemon" -T 2>/dev/null \
    | grep -E '^(port|permitrootlogin|permitemptypasswords|passwordauthentication|x11forwarding|maxauthtries|logingracetime) ' \
    || true

  [[ $MODE == apply ]] || return 0

  if ! has systemctl; then
    echo 'SSH reload requires systemd in this helper; manage this host manually.'
    return 1
  fi

  echo 'Keeps SSH and password authentication available; no port/key/authentication-method changes.'
  ask 'README does NOT require root SSH or X11? Disable them, empty passwords; set MaxAuthTries 4/LoginGraceTime 30?' || return 0

  if [[ -L /etc/ssh/sshd_config ]]; then
    echo 'Refusing symlink sshd_config'
    return 1
  fi

  backup /etc/ssh/sshd_config || return 1

  staged=$(mktemp)
  saved=$(mktemp)
  cp -p /etc/ssh/sshd_config "$saved"

  {
    printf '%s\n' \
      '# BEGIN CYBERPATRIOT MANAGED' \
      'PermitRootLogin no' \
      'PermitEmptyPasswords no' \
      'X11Forwarding no' \
      'MaxAuthTries 4' \
      'LoginGraceTime 30' \
      '# END CYBERPATRIOT MANAGED'

    awk '
      /^# BEGIN CYBERPATRIOT MANAGED$/ { skip = 1; next }
      /^# END CYBERPATRIOT MANAGED$/   { skip = 0; next }
      !skip                            { print }
    ' /etc/ssh/sshd_config
  } > "$staged"

  cat "$staged" > /etc/ssh/sshd_config
  rm -f "$staged"

  if ! "$daemon" -t; then
    cp -p "$saved" /etc/ssh/sshd_config
    rm -f "$saved"
    echo 'Invalid SSH configuration; restored.'
    return 1
  fi

  "$daemon" -T 2>/dev/null \
    | grep -E '^(permitrootlogin|permitemptypasswords|x11forwarding|maxauthtries|logingracetime) ' \
    || true

  for unit in ssh.service sshd.service; do
    if systemctl is-active --quiet "$unit"; then
      if ! run systemctl reload "$unit"; then
        cp -p "$saved" /etc/ssh/sshd_config
        rm -f "$saved"
        echo 'Reload failed; config restored. Verify daemon state manually.'
        return 1
      fi

      break
    fi
  done

  rm -f "$saved"
  echo 'Verify a NEW SSH session before closing this one. Match blocks may set per-user exceptions.'
}


firewall() {
  local manager ports port zone
  local -a allowed=()

  has ufw && run ufw status verbose || true

  if has firewall-cmd; then
    run firewall-cmd --get-active-zones || true
    run firewall-cmd --list-all-zones || true
  fi

  [[ $MODE == apply ]] || return 0

  echo 'Choose ONE installed manager. No rules are flushed; managers are never switched automatically.'
  read -r -p 'Firewall [ufw/firewalld/skip]: ' manager
  [[ $manager == ufw || $manager == firewalld ]] || return 0

  if [[ -n ${SSH_CONNECTION:-} || -n ${SSH_CLIENT:-} ]]; then
    echo 'Refusing firewall changes from SSH. Use VM console.'
    return 1
  fi

  ask 'Are you using the VM CONSOLE and have you recorded ALL required inbound services/ports?' || return 0

  read -r -p 'Required inbound ports (space-separated N/tcp or N/udp, e.g. 22/tcp 3389/tcp; blank = none): ' ports
  read -r -a allowed <<< "$ports"

  for port in "${allowed[@]}"; do
    [[ $port =~ ^([0-9]{1,5})/(tcp|udp)$ ]] || { echo 'Invalid port specification.'; return 1; }
    ((10#${BASH_REMATCH[1]} >= 1 && 10#${BASH_REMATCH[1]} <= 65535)) || return 1
  done

  if [[ $manager == ufw ]]; then
    if ! has ufw; then
      echo 'Install ufw manually, then rerun.'
      return 1
    fi

    if has systemctl && systemctl is-active --quiet firewalld; then
      echo 'firewalld is active. Resolve manager conflict manually.'
      return 1
    fi

    ask 'Preserve existing UFW rules, set incoming DENY/outgoing ALLOW, add specified ports and enable UFW?' || return 0
    backup /etc/ufw || return 1

    for port in "${allowed[@]}"; do
      run ufw allow "$port" || return 1
    done

    run ufw default deny incoming \
      && run ufw default allow outgoing \
      && run ufw --force enable \
      && run ufw status verbose
  else
    if ! has firewall-cmd; then
      echo 'Install firewalld manually, then rerun.'
      return 1
    fi

    if has ufw && ufw status 2>/dev/null | grep -q '^Status: active'; then
      echo 'UFW is active. Resolve manager conflict manually.'
      return 1
    fi

    echo 'firewalld enables EXISTING zone policy. No zone/interface reassignment; this is not a deny-all reset.'
    ask 'Enable firewalld and add required ports to a reviewed zone?' || return 0

    backup /etc/firewalld || return 1
    run systemctl enable --now firewalld || return 1

    firewall-cmd --get-active-zones
    read -r -p 'Existing zone to add ports to (must cover required interface): ' zone

    [[ $zone =~ ^[a-zA-Z0-9_-]+$ ]] || return 1
    firewall-cmd --get-zones | tr ' ' '\n' | grep -Fxq "$zone" || return 1

    for port in "${allowed[@]}"; do
      run firewall-cmd --permanent --zone="$zone" --add-port="$port" || return 1
      run firewall-cmd --zone="$zone" --add-port="$port" || return 1
    done

    run firewall-cmd --zone="$zone" --list-all
    echo 'Review ALL active zones/targets and allowed services; trusted/ACCEPT zones allow broad inbound traffic.'
  fi
}


security() {
  local unit

  echo 'Mandatory access control and auditing status (no automatic SELinux mode/profile rewrites):'
  has getenforce && run getenforce || true
  has aa-status && run aa-status || true

  has systemctl || return 0

  for unit in apparmor.service auditd.service rsyslog.service; do
    systemctl --no-pager is-active "$unit" || true

    [[ $MODE == apply ]] || continue
    systemctl cat "$unit" >/dev/null 2>&1 || continue
    ask "README permits enabling installed $unit? Enable/start without replacing its configuration?" || continue

    printf '%s: ' "$unit" >> "$OUT/service-state-before.txt"
    systemctl is-enabled "$unit" >> "$OUT/service-state-before.txt" 2>&1 || true
    run systemctl enable --now "$unit" || return 1
  done

  echo 'SELinux policy and audit rules require image-specific review. Existing logs/profiles/rules are never deleted.'
}


updates() {
  if [[ $MODE != apply ]]; then
    echo 'Updates not fetched in audit. Review repositories and update settings manually.'
    return 0
  fi

  echo 'Updates change installed packages and cannot be undone by file backups; no automatic reboot.'

  if has apt-get; then
    if ask 'Refresh APT indexes, then interactively upgrade packages (no full-upgrade/autoremove)?'; then
      run apt-get update && run apt-get upgrade || return 1
    fi

    if [[ -f /etc/apt/apt.conf.d/20auto-upgrades ]] \
      && ask 'Enable APT daily indexes and unattended-upgrades (confirm package is installed)?'; then

      if dpkg-query -W -f='${Status}' unattended-upgrades 2>/dev/null | grep -q 'install ok installed'; then
        backup /etc/apt/apt.conf.d/20auto-upgrades || return 1

        printf '%s\n' \
          'APT::Periodic::Update-Package-Lists "1";' \
          'APT::Periodic::Unattended-Upgrade "1";' \
          > /etc/apt/apt.conf.d/20auto-upgrades
      else
        echo 'unattended-upgrades not installed; skipped.'
      fi
    fi

  elif has dnf; then
    ask 'Interactively run dnf upgrade --refresh (no automatic reboot)?' && run dnf upgrade --refresh || true

  else
    echo 'Unsupported package manager; update manually.'
  fi

  [[ ! -e /var/run/reboot-required ]] || echo 'REBOOT REQUIRED: arrange manually after verifying the image.'
}


users() {
  local user uid
  local current=${SUDO_USER:-root}

  echo 'Users are NEVER inferred from past images. Compare inventory with this image README.'

  [[ $MODE == apply ]] || return 0

  read -r -p 'ONE unauthorized local username to lock/expire (blank = skip): ' user
  [[ -n $user ]] || return 0

  [[ $user =~ ^[a-zA-Z_][a-zA-Z0-9_.-]*\$?$ && $user != "$current" ]] || return 1

  if ! grep -q "^${user}:" /etc/passwd; then
    echo 'Local account not found.'
    return 1
  fi

  uid=$(id -u "$user")

  if ! ((uid >= 1000 && uid != 65534)); then
    echo 'System accounts are review-only.'
    return 1
  fi

  if id -nG "$user" | tr ' ' '\n' | grep -Eq '^(sudo|wheel)$'; then
    echo 'Privileged account: review/demote manually after verifying another working administrator login. Refusing automatic lockout.'
    return 1
  fi

  id "$user"
  ask "README confirms $user is unauthorized? Lock and expire account (no files deleted; active sessions not terminated)?" || return 0

  backup /etc/passwd && backup /etc/shadow && backup /etc/group && backup /etc/gshadow || return 1
  run usermod --lock --expiredate 1 "$user"
}


services() {
  local service

  echo 'Service changes are opt-in. SSH/RDP, database, web, file-sharing and DNS may be required.'

  has systemctl || return 0
  [[ $MODE == apply ]] || return 0

  read -r -p 'ONE README-prohibited service to stop/disable (exact .service name; blank = skip): ' service
  [[ -n $service ]] || return 0
  [[ $service =~ ^[a-zA-Z0-9_.@-]+\.service$ ]] || return 1

  case "$service" in
    ssh.service | sshd.service | dbus.service | systemd-* | \
    NetworkManager.service | networking.service | \
    ufw.service | firewalld.service | \
    *score* | *cyber*)
      echo 'Protected service; review manually.'
      return 1
      ;;
  esac

  run systemctl --no-pager status "$service" || true
  ask "Confirm $service is NOT required by README or scoring? Stop and disable?" || return 0

  systemctl is-enabled "$service" >> "$OUT/service-state-before.txt" 2>&1 || true
  printf '%s\n' "$service" >> "$OUT/service-state-before.txt"
  run systemctl disable --now "$service"
}


packages() {
  local candidates='nmap wireshark john hydra netcat-traditional netcat-openbsd ophcrack aisleriot minetest aircrack-ng kismet'
  local pkg

  echo 'Potentially prohibited packages (some may be REQUIRED; no automatic removal):'

  for pkg in $candidates; do
    if has dpkg-query; then
      dpkg-query -W -f='${binary:Package} ${Status}\n' "$pkg" 2>/dev/null | grep 'install ok installed' || true
    elif has rpm; then
      rpm -q "$pkg" 2>/dev/null || true
    fi
  done

  [[ $MODE == apply ]] || return 0

  read -r -p 'ONE prohibited package from the above candidate list to remove (blank = skip): ' pkg
  [[ -n $pkg ]] || return 0

  if [[ " $candidates " != *" $pkg "* ]]; then
    echo 'Not in candidate list; handle manually.'
    return 1
  fi

  echo 'Read the transaction preview. Cancel if a required dependency would be removed.'
  ask "Forensics complete and README prohibits $pkg? Remove interactively (no purge/autoremove)?" || return 0

  if has apt-get; then
    run apt-get remove "$pkg"
  elif has dnf; then
    run dnf remove "$pkg"
  fi
}


if [[ $MODE == apply ]]; then
  echo 'Read the README, answer forensic questions, record required services/users, and take a snapshot.'
  ask 'Have you done this, and are these scripts permitted by your competition rules?' || exit 0
fi

for m in "${SELECTED[@]}"; do
  printf '\n========== %s ==========\n' "$m"

  case "$m" in
    sysctl) sysctl_module || FAILURES=$((FAILURES + 1)) ;;
    ssh)    ssh_module    || FAILURES=$((FAILURES + 1)) ;;
    *)      "$m"          || FAILURES=$((FAILURES + 1)) ;;
  esac
done

printf '\nFinished with %s recorded failure(s). Log/backups: %s\n' "$FAILURES" "$OUT"
echo 'Verify scoring, required apps, login, firewall and new remote sessions. No reboot was performed.'
echo 'Backups are sensitive. File copies do not roll back packages, users, runtime sysctls or service/firewall state.'

((FAILURES == 0))
