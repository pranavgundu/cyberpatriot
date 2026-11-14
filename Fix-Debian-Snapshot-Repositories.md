# Debian 12 — Replace Frozen Snapshot Update Sources

A dated `snapshot.debian.org` repository serves historical packages rather than ongoing updates. If your active sources use it, this can explain why upgrades find nothing new.

**Run these commands inside the Debian VM. Keep Debian 12 / Bookworm. This is not a release upgrade, and points are not guaranteed.**

## 1. Find the exact configuration file

```bash
grep -RnsE '^[[:space:]]*(deb |URIs:|Suites:|Enabled:)' \
  /etc/apt/sources.list /etc/apt/sources.list.d/ 2>/dev/null
```

Look at the filename at the beginning of each matching line.

- Confirm the suites are `bookworm`, `bookworm-updates`, and/or `bookworm-security`.
- If you see another release, a mix of releases, or cannot identify the active snapshot entries, **stop and send a screenshot of the full output**.
- A `.sources` stanza containing `Enabled: no` is disabled; changing only that stanza will not fix active sources.

## 2. Back up APT's configuration

```bash
sudo cp -a /etc/apt "/root/apt-before-live-repos-$(date +%Y%m%d-%H%M%S)"
```

Stop if the backup fails.

## 3. Edit the file that actually contains the snapshot source

For `/etc/apt/sources.list`:

```bash
sudo nano /etc/apt/sources.list
```

**If the output instead identifies `/etc/apt/sources.list.d/debian.sources`, edit that file instead:**

```bash
sudo nano /etc/apt/sources.list.d/debian.sources
```

If it identifies another filename, use that exact filename. Do not create a new sources file merely because one of the examples above is absent.

### Replace only the snapshot repository URLs

Replace the **entire dated URL**, including its timestamp, using the matching replacement:

| Old URL contains | New URL |
|---|---|
| `snapshot.debian.org/archive/debian/` followed by a timestamp | `https://deb.debian.org/debian` |
| `snapshot.debian.org/archive/debian-security/` followed by a timestamp | `https://security.debian.org/debian-security` |

For example, replace `https://snapshot.debian.org/archive/debian/20250101T000000Z/` with `https://deb.debian.org/debian`. **Do not leave the timestamp attached.**

Keep the existing Bookworm suite names, components, and `Signed-By` settings. Do not change signing-key paths or bypass signature checks.

Traditional `.list` entries should have this general shape (preserve any existing signing options and needed components):

```text
deb https://deb.debian.org/debian bookworm main non-free-firmware
deb https://deb.debian.org/debian bookworm-updates main non-free-firmware
deb https://security.debian.org/debian-security bookworm-security main non-free-firmware
```

For a multiline `.sources` file, change the `URIs:` value instead. **Do not paste traditional `deb ...` lines into a `.sources` file.** If a single stanza mixes normal and security suites with multiple snapshot URLs, stop and send it for review rather than guessing.

**Do not add duplicate entries.** If normal updates or security updates are entirely missing, report that before adding more configuration.

Save in nano: **Ctrl+O**, **Enter**, then **Ctrl+X**.

## 4. Refresh package lists

```bash
sudo apt update
```

**Stop and send the full error** if you see failed downloads, signature errors, conflicting `Signed-By` settings, or other repository errors. Do not use `--allow-unauthenticated` or disable verification.

If APT reports only an expected Bookworm release-information change, send that message too; do not blindly accept unrelated release changes.

## 5. Preview and install available upgrades

Only after the refresh succeeds without repository errors:

```bash
apt list --upgradable
sudo apt upgrade --simulate
```

Review the proposal. Stop if it would remove required software or indicates a different Debian release.

Then install:

```bash
sudo apt upgrade
```

Review the confirmation prompt before accepting. Do not force held packages, automatically remove packages, add backports, or switch to `stable`, `trixie`, `testing`, or `sid`.

## Send back

```text
File edited:
Did apt update finish without errors?:
Number of packages offered for upgrade:
Any packages kept back:
Score before / after:
```
