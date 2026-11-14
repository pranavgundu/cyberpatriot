# CyberPatriot Checklists

Pick your machine and work through its checklist from top to bottom.

| Machine | Checklist | Script |
|---|---|---|
| Windows 10 / 11 | [Windows.md](Windows.md) | `windows.ps1` |
| Windows Server | [Windows-Server.md](Windows-Server.md) | `windows-server.ps1` and `windows.ps1` |
| Linux Mint | [Linux-Mint.md](Linux-Mint.md) | `linux.sh` |
| Ubuntu / Debian | [Ubuntu-Debian-Linux.md](Ubuntu-Debian-Linux.md) | `linux.sh` |

## Run without cloning

You do not need Git. Download only the scripts you need using the commands below. They save the scripts in a `cyberpatriot-scripts` folder in your home directory.

Take a VM snapshot first. Read the downloaded scripts before running them with administrator or root access. These commands use the `main` branch; they will include updates only after those updates are pushed to GitHub.

**Repository access:** the public download URLs currently return `404`. If the repository is private, use the [authenticated download option](#private-repository-downloads) below. Public downloads work only when the repository and files are publicly accessible.

### Windows 10 / 11

Open **Windows PowerShell as administrator** (not PowerShell 7), then download:

```powershell
New-Item -ItemType Directory -Force -Path "$HOME\cyberpatriot-scripts" | Out-Null
Set-Location "$HOME\cyberpatriot-scripts"
Invoke-WebRequest -UseBasicParsing -Uri 'https://raw.githubusercontent.com/pranavgundu/cyberpatriot/main/scripts/windows.ps1' -OutFile windows.ps1
```

Review `windows.ps1`, then run the audit:

```powershell
Set-ExecutionPolicy -Scope Process -ExecutionPolicy Bypass
.\windows.ps1
```

### Windows Server

Open **Windows PowerShell as administrator**, then download both files into the same folder:

```powershell
New-Item -ItemType Directory -Force -Path "$HOME\cyberpatriot-scripts" | Out-Null
Set-Location "$HOME\cyberpatriot-scripts"
$base = 'https://raw.githubusercontent.com/pranavgundu/cyberpatriot/main/scripts'
Invoke-WebRequest -UseBasicParsing -Uri "$base/windows.ps1" -OutFile windows.ps1
Invoke-WebRequest -UseBasicParsing -Uri "$base/windows-server.ps1" -OutFile windows-server.ps1
```

Review both files, then run the audit:

```powershell
Set-ExecutionPolicy -Scope Process -ExecutionPolicy Bypass
.\windows-server.ps1
```

### Linux Mint / Ubuntu / Debian

Open a terminal and download:

```bash
mkdir -p "$HOME/cyberpatriot-scripts" && cd "$HOME/cyberpatriot-scripts" &&
  curl -fL --output linux.sh https://raw.githubusercontent.com/pranavgundu/cyberpatriot/main/scripts/linux.sh
```

If `curl` is missing, install it with `sudo apt update && sudo apt install curl`, then retry the download.

Review `linux.sh`, then run the audit:

```bash
sudo bash linux.sh --audit
```

Keep using this folder for the apply and audit commands in your checklist. Do not pipe the download into Bash or PowerShell: apply mode needs an interactive terminal for its prompts.

## Private repository downloads

If the public URLs return `404`, install the [GitHub CLI](https://cli.github.com/) and run `gh auth login` with an account that has access to this repository. This does not require cloning. If the account cannot access the repository, ask the owner for access.

Use the matching commands below **instead of** the public download commands. If any download fails, stop and fix access before running a script.

### Windows (including Server)

Run in Windows PowerShell as administrator. Download `windows.ps1` for all Windows machines; download the second file only for Windows Server.

```powershell
New-Item -ItemType Directory -Force -Path "$HOME\cyberpatriot-scripts" | Out-Null
Set-Location "$HOME\cyberpatriot-scripts"
gh api -H 'Accept: application/vnd.github.raw+json' 'repos/pranavgundu/cyberpatriot/contents/scripts/windows.ps1?ref=main' | Set-Content -Encoding UTF8 windows.ps1
# Windows Server only:
gh api -H 'Accept: application/vnd.github.raw+json' 'repos/pranavgundu/cyberpatriot/contents/scripts/windows-server.ps1?ref=main' | Set-Content -Encoding UTF8 windows-server.ps1
```

Review the files, then use the execution-policy and audit commands for your system above.

### Linux

```bash
mkdir -p "$HOME/cyberpatriot-scripts" && cd "$HOME/cyberpatriot-scripts" &&
  gh api -H 'Accept: application/vnd.github.raw+json' 'repos/pranavgundu/cyberpatriot/contents/scripts/linux.sh?ref=main' > linux.sh
```

Review `linux.sh`, then run `sudo bash linux.sh --audit`.

## Checklist order

1. **Get ready:** take a snapshot, read the image README, and answer forensic questions.
2. **Script fixes:** run apply mode and review each prompt.
3. **Users:** make accounts and admins match the image README.
4. **Policies:** check passwords, login, sudo/UAC, and remote access.
5. **Apps and files:** update required software and review prohibited apps, media, and backdoors.
6. **Finish:** re-run the audit, test required services, and check the score.

The Windows Server checklist also has a separate step for server roles before apps and files.

**Check a box only after verifying it on the current image.** Running the script is not enough.

## What the scripts do

- **Audit mode is the default.** It reads system settings and saves a report without changing those settings.
- **Apply mode asks before each change.** Windows requires `YES`; Linux requires `y`. Other answers skip the change.
- **Scripts never delete users or files, clear logs, or reboot.**
- **Backups** go in the folder printed at the start. They are not a complete rollback. Keep your VM snapshot.
- **Domain controllers** are audit-only.

## Limits

- Tested with syntax/static checks and isolated tests only, not inside a real competition VM. Snapshot first.
- Password lengths, lockout settings, and other defaults are not an answer key. Follow the image README if it gives different requirements.
- Old systems (Windows 7/8.1, Server 2008, Ubuntu 14 / Upstart, and end-of-life repositories) need manual work.
