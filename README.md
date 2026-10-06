# remote-desktop

A short-lived GitHub Mac or Windows computer that you can see and control from your own Mac.
Use it to test software on a clean machine. The connection goes through Tailscale (a private network).

## Start
```
./start.sh macos 60      # Mac for 60 minutes (max 340): opens Screen Sharing when ready
./start.sh windows 60    # Windows: prints the address for Windows App
```
It starts the workflow, waits until remote access is on (2–5 minutes), and prints the address and user.

| | Mac | Windows |
|---|---|---|
| App on your Mac | Screen Sharing (built in). `start.sh` opens `vnc://<address>`; or Finder → Go → Connect to Server (⌘K) | [Windows App](https://apps.apple.com/app/windows-app/id1295203466) → **+** → **Add PC** → PC name = address |
| User | `tester` (if asked, choose **Log in as yourself**) | `runneradmin` |
| Password | the `RD_PASSWORD` secret | the `RD_PASSWORD` secret |
| Commands | `ssh -i ~/.ssh/remote_desktop_ed25519 tester@<address>` | `ssh -i ~/.ssh/remote_desktop_ed25519 runneradmin@<address>` (Windows PowerShell 5.1, like a buyer's) |

On the Desktop of both: `step-guide/` (Chrome → `chrome://extensions` → Developer mode → Load unpacked).

## Stop
```
./stop.sh            # every run still in progress
./stop.sh <run-id>
```
A run also stops by itself after the minutes you asked for. Hosted runners are free for this public repo.

## Needs (once)
- On your Mac: `gh` logged in, Tailscale on, the SSH key `~/.ssh/remote_desktop_ed25519` (public half in `authorized_keys`).
- Repo secrets: `TAILSCALE_GITHUB_AUTH_KEY` (Tailscale auth key: reusable, ephemeral), `RD_PASSWORD` (12+ characters with
  capital letters, small letters, numbers and a symbol; Windows rejects weaker ones).

## Why it is built this way (facts, with sources)
- **Mac user `tester`, not `runner`.** On the macOS 26 runner image, `runner` has a SecureToken, so root can't set its
  password without the old one: `dscl -passwd` fails with `eDSAuthFailed`, `sysadminctl -resetPasswordFor` says
  "Operation is not permitted without secure token unlock" (seen 6 Oct 2026, macOS 26.6.2). A new local admin
  account avoids it; the same approach: [prateeknot/macos-cloud](https://github.com/prateeknot/macos-cloud)
  (`.github/workflows/macos.yml`). Image facts: [macOS 26 runners GA](https://github.blog/changelog/2026-02-26-macos-26-is-now-generally-available-for-github-hosted-runners/).
- **Screen Sharing as another user** than the one at the console: macOS asks "Share Display" or "Log in as yourself";
  "Log in as yourself" opens a separate session ([Lehigh: Connect to another Mac](https://lehigh.atlassian.net/wiki/spaces/LKB/pages/26679969/Connect+to+another+Mac+from+macOS)).
- **Black screen fix.** A headless runner whose display sleeps or locks streams an empty picture (black, only the
  cursor). The workflow turns off sleep and the screen lock (`pmset`, `DisableScreenLock`), as macos-cloud does.
  If it still shows black, that project also auto-logs the new user in at the console (`kcpassword`); add that only if needed.
- **Address from Tailscale, not the log.** GitHub shows a job's log only after it ends, so `start.sh` waits for the
  "Enable …" step to succeed and reads the address of `gha-<os>-<run id>` from `tailscale status`.
- **Keep-alive loop of 15 s sleeps.** One long `sleep` ignores a cancel on Windows and the run stays "in progress".

## When something fails
`gh run view <run-id> -R rsvishalsingh93/remote-desktop --log-failed`, then read the docs above before changing the
workflow. Write what you found in this section.
