# Start with the checklist for your machine

Only checklists and the three hardening scripts are kept in this folder collection.

Each checklist begins with running the matching helper **in audit mode**, then follows with opt-in fixes and the manual work needed to finish the image. Mark an item complete only after verifying it against the competition image's README.

| Machine | Checklist | First command (from `Scripts/`) |
|---|---|---|
| Windows 10/11 | [Windows.md](Windows.md) | `.\windows.ps1` in elevated 64-bit Windows PowerShell 5.1 |
| Windows Server | [Windows-Server.md](Windows-Server.md) | `.\windows-server.ps1` in elevated 64-bit Windows PowerShell 5.1 |
| Linux Mint | [Linux-Mint.md](Linux-Mint.md) | `sudo bash linux.sh --audit` |
| Ubuntu / Debian | [Ubuntu-Debian-Linux.md](Ubuntu-Debian-Linux.md) | `sudo bash linux.sh --audit` |

## Scripts

- [linux.sh](../Scripts/linux.sh)
- [windows.ps1](../Scripts/windows.ps1)
- [windows-server.ps1](../Scripts/windows-server.ps1) — keep `windows.ps1` alongside it.

## After the audit

1. Snapshot the authorized VM; read its README and complete forensics before modifying evidence.
2. Apply only the modules that fit; decline uncertain prompts. Scripts must be allowed by the current competition rules.
3. Follow the rest of the machine checklist for users/groups, apps, files, policies and required service roles.
4. Re-audit and verify logins, required services, exact requirements and score. Do not alter scoring internals.

**Limits:** syntax/static checks and isolated helper tests passed, but the scripts have not been tested inside competition VMs. They are not full-score solutions. Backups are not complete rollback; use snapshots. Domain controllers are audit-only. Old Windows releases and legacy/EOL Linux configurations require manual handling.
