# Check Debian 12 Security Updates — One Step

Run this command **inside your Debian VM**, then send me the output:

```bash
grep -RnsE '^[[:space:]]*(deb |URIs:|Suites:|Enabled:)' \
  /etc/apt/sources.list /etc/apt/sources.list.d/ 2>/dev/null
```

This only reads your repository settings. It does not change anything.

## What we are checking

Whether the official **Bookworm security-update repository** is enabled. Without it, `apt upgrade` might not offer available security updates.

A valid traditional entry looks like:

```text
deb https://security.debian.org/debian-security bookworm-security main non-free-firmware
```

Your system may instead use the equivalent multiline `.sources` format. An official `https://deb.debian.org/debian-security` URI is also valid.

**Do not add or replace entries yet. Send the command output first so we can check for missing, disabled, duplicate, or incorrect sources.**

- Stay on `bookworm`, `bookworm-updates`, and `bookworm-security`.
- Do not switch to `stable`, `trixie`, `testing`, or `sid`.
- Do not add backports just to chase update points.
- Do not copy the Google AI snippet's incorrect `http://debian.org bookworm-security` entry.
- No score increase is guaranteed; this checks whether updates are configured correctly.
