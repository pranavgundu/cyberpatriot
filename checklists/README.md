# CyberPatriot Checklists

Pick your machine, open its checklist, and work through it **top to bottom**.

| Machine | Checklist | First thing to run (from `scripts/`) |
|---|---|---|
| Windows 10 / 11 | [Windows.md](Windows.md) | `.\windows.ps1` |
| Windows Server | [Windows-Server.md](Windows-Server.md) | `.\windows-server.ps1` |
| Linux Mint | [Linux-Mint.md](Linux-Mint.md) | `sudo bash linux.sh --audit` |
| Ubuntu / Debian | [Ubuntu-Debian-Linux.md](Ubuntu-Debian-Linux.md) | `sudo bash linux.sh --audit` |

Scripts:

- [linux.sh](../scripts/linux.sh)
- [windows.ps1](../scripts/windows.ps1)
- [windows-server.ps1](../scripts/windows-server.ps1) — needs `windows.ps1` in the same folder

---

## Every checklist follows the same 6 steps

| Step | What you do | Why |
|---|---|---|
| 1. Get ready | Snapshot, read the README, answer forensic questions | Deleting things first can destroy forensic answers |
| 2. Script fixes | Run the script in apply mode, answer each prompt | Knocks out the easy, safe settings fast |
| 3. Users | Make accounts and admins match the README | The script can't know who's authorized |
| 4. Policies | Passwords, login, sudo/UAC, remote access | Settings the script doesn't touch |
| 5. Apps & files | Updates, bad software, media files, backdoors | Needs a human to judge what's allowed |
| 6. Finish | Re-run the audit, test everything, check score | Catch anything you broke |

**Rule for every box:** tick it only after you've checked it on **this** image — not just because the script ran.

---

## What the scripts will and won't do

- **Audit mode (the default) changes nothing.** Run it as often as you like.
- **Apply mode asks before every change.** Windows wants you to type `YES`; Linux wants `y`. Anything else = skip.
- **They never** delete users, delete files, clear logs, or reboot.
- **Backups** go in the folder printed at the start. They are **not** a full undo — the VM snapshot is your undo.
- **Domain controllers** are audit-only.

## Limits

- Tested with syntax/static checks and isolated tests only — **not** inside a real competition VM. Snapshot first.
- The values (password length, lockout, etc.) are generic defaults, not an answer key. The README always wins.
- Old systems (Windows 7/8.1, Server 2008, Ubuntu 14 / Upstart, end-of-life repos) need manual work.
