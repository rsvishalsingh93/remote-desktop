# remote-desktop

A short-lived GitHub Mac or Windows computer that you can see and control from your own Mac.
Use it to test software on a clean machine. The connection goes through Tailscale (a private network).

## Start
```
./start.sh macos 60          # Apple Silicon Mac for 60 minutes (max 340), screen 1024x768
./start.sh macos-intel 60    # Intel Mac, screen 1920x1080 (more RAM)
./start.sh windows 60        # Windows
```
It starts the workflow, waits until remote access is on (2–5 minutes), and prints the address and user.

| | Mac | Windows |
|---|---|---|
| App on your Mac | [RustDesk](https://rustdesk.com) (`brew install --cask rustdesk`, once) → enter `<address>:21118` → Connect. `start.sh` opens it. Apple Screen Sharing does **not** work (see Why) | [Windows App](https://apps.apple.com/app/windows-app/id1295203466) → **+** → **Add PC** → PC name = address |
| User | none: password only (RustDesk) | `runneradmin` |
| Password | the `RD_PASSWORD` secret | the `RD_PASSWORD` secret |
| Commands | `ssh -i ~/.ssh/remote_desktop_ed25519 -o IdentitiesOnly=yes runner@<address>` (not yet confirmed working on Mac, see When something fails) | `ssh -i ~/.ssh/remote_desktop_ed25519 -o IdentitiesOnly=yes runneradmin@<address>` (Windows PowerShell 5.1, like a buyer's) |

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
- **Mac screen = RustDesk with permissions written into TCC.db** (`mac/rustdesk.sh`). The method of
  [skyro777/MacOS](https://github.com/skyro777/MacOS) (`apple-project/`, verified on macos-15): GitHub's Mac images ship with
  SIP disabled ([runner-images#8162](https://github.com/actions/runner-images/issues/8162)), so root can write the system
  privacy database and grant RustDesk screen recording, accessibility and input monitoring (GitHub's own image script does
  the same for `/bin/bash`: [configure-tccdb-macos.sh](https://github.com/actions/runner-images/blob/main/images/macos/scripts/build/configure-tccdb-macos.sh)).
  RustDesk runs in direct-IP mode (port 21118, no relay server), so the connection stays inside Tailscale.
  Owner accepted (6 Oct 2026): password-only full control on a throwaway machine reachable only inside our Tailscale network.
- **Facts for macOS 26, from `mac-diagnose.yml`** (6 Oct 2026, run it again when the image changes):
  ARM `macos-latest` = 26.6.2, Intel `macos-26-intel` = 26.6.1; both: SIP disabled, TCC.db write OK, `runner` logged in
  at the console, `screencapture` works (ARM 1024x768, Intel 1920x1080).

### Dead ends (do not try again)
- **Apple Screen Sharing / VNC.** Apple: "In macOS 12.1 or later, Screen Sharing can't be enabled by the `kickstart`
  command-line tool" ([Apple Remote Desktop guide](https://support.apple.com/en-gw/guide/remote-desktop/apd8b1c65bd/mac)).
  kickstart itself prints "Screen recording might be disabled … must be enabled from System Settings or via MDM".
  Results: a user-name login fails with "Screen Sharing is not permitted on <address>"; the legacy VNC password
  (TigerVNC) fails with "The connection was dropped by the server before the session could be established".
- **Resetting `runner`'s password.** `runner` has a SecureToken: `dscl -passwd` gives `eDSAuthFailed`,
  `sysadminctl -resetPasswordFor` gives "Operation is not permitted without secure token unlock".
- **Address from Tailscale, not the log.** GitHub shows a job's log only after it ends, so `start.sh` waits for the
  "Enable …" step to succeed and reads the address of `gha-<os>-<run id>` from `tailscale status`.
- **Keep-alive loop of 15 s sleeps.** One long `sleep` ignores a cancel on Windows and the run stays "in progress".

## When something fails
`gh run view <run-id> -R rsvishalsingh93/remote-desktop --log-failed`, then read the docs above before changing the
workflow. Write what you found in this section.

- **Mac SSH refused the key** (6 Oct 2026, `Permission denied (publickey…)` with the right key and `IdentitiesOnly`).
  Cause not found yet; the workflow now also sets `~/.ssh` to 700. Check this on the next Mac run.
