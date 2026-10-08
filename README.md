# remote-desktop

A short-lived GitHub Mac or Windows computer that you can see and control from your own Mac.
Use it to test software on a clean machine. The connection goes through Tailscale (a private network).

## Start
```
./start.sh macos 60          # Apple Silicon Mac for 60 minutes (max 340), screen 1024x768. USE THIS ONE.
./start.sh macos-intel 60    # Intel Mac, screen 1920x1080: Dock and window-button clicks don't work (below)
./start.sh windows 60        # Windows
```
It starts the workflow, waits until remote access is on (2–5 minutes), and prints the address and user.

| | Mac | Windows |
|---|---|---|
| App on your Mac | [RustDesk](https://rustdesk.com) (`brew install --cask rustdesk`, once) → enter `<address>:21118` → Connect. `start.sh` opens it. Apple Screen Sharing does **not** work (see Why) | [Windows App](https://apps.apple.com/app/windows-app/id1295203466) → **+** → **Add PC** → PC name = address |
| User | none: password only (RustDesk) | `runneradmin` |
| Password | the `RD_PASSWORD` secret | the `RD_PASSWORD` secret |
| Commands | `ssh -i ~/.ssh/remote_desktop_ed25519 -o IdentitiesOnly=yes runner@<address>` | `ssh -i ~/.ssh/remote_desktop_ed25519 -o IdentitiesOnly=yes runneradmin@<address>` (Windows PowerShell 5.1, like a buyer's) |

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

## Test session checklist (for people and AI agents)
Mac minutes are limited and a Mac costs much more than Windows. Learned on 8 Oct 2026:
- **Ask for 30-60 minutes**, not hours, and start just before someone can join. Stop the run when nobody is testing
  (the agent doing other work counts as nobody). **Never stop a run the owner may still use without asking.**
- **Before you hand over:** from your Mac, `nc -z -G 5 <address> 21118` must succeed. Then connect once, or look at the
  screen over SSH (below), and check there is no waiting macOS box. Tell the owner the address and the exact stop time
  in UTC.
- **A buyer-like Mac without Chrome:** the image has Google Chrome and Chrome for Testing. To remove both:
  `sudo rm -rf "/Applications/Google Chrome.app" "/Applications/Google Chrome for Testing.app" ~/Library/Application\ Support/Google/Chrome ~/Library/Caches/Google/Chrome ~/Library/Preferences/com.google.Chrome.plist /Library/Google/GoogleSoftwareUpdate ~/Library/Google/GoogleSoftwareUpdate`
- **RustDesk's REC button** saves on the viewer's own Mac, in `~/Movies/RustDesk/` (RustDesk → Settings → General →
  Recording), so the file stays when the test machine ends. An `ffmpeg` recording made on the test machine is lost
  when the run ends: copy it off first (`scp runner@<address>:<file> .`).
- Keep license keys and passwords out of recordings, or blur them before anyone else sees the video.

## When something fails
`gh run view <run-id> -R rsvishalsingh93/remote-desktop --log-failed`, then read the docs above before changing the
workflow. Write what you found in this section.

- **Mac SSH refused the key** (6 Oct 2026). Fixed: `~/.ssh` must be mode 700 (sshd ignores keys otherwise). Use
  `-o IdentitiesOnly=yes`, or ssh offers other keys first and the server stops with "Too many authentication failures".
- **Intel Mac only: clicking a Dock icon does not start the app** (6 Oct 2026, RustDesk on macos-26-intel). On the
  Apple Silicon Mac (`macos`) everything works, Dock and window buttons included (tested 7 Oct 2026). Mouse, keyboard,
  menus and right-click work; macOS logs show RustDesk has Accessibility, PostEvent and ListenEvent allowed
  (`AUTHREQ_RESULT … authValue=2`). Window buttons (close, cancel) fail too; menus, right-click, typing and Finder's
  Go menu work. Tried without effect: slow single clicks (so not RustDesk issue #15878, click counting), and running
  RustDesk as the official `--server` LaunchAgent plus root `--service` LaunchDaemon (skyro777's setup). No documented
  cause found. Use the keyboard and menus: open apps with Finder → Go or ⌘ Space; close a window ⌘ W; quit ⌘ Q;
  cancel Esc; switch ⌘ Tab; or over SSH: `open -a Terminal`.
- **RustDesk shows a solid green screen** (8 Oct 2026, Apple Silicon `macos`). Connection, mouse and keyboard are fine,
  but the picture is green. The RustDesk log (`~/Library/Logs/RustDesk/RustDesk_rCURRENT.log`) says `encoder: H265`,
  `hevc_videotoolbox` and then `encode fail: no valid frame`: the VM has no real GPU, so hardware encoding fails.
  Fixed in `mac/rustdesk.sh`: `enable-hwcodec = 'N'` and `codec-preference = 'vp9'` in `RustDesk2.toml`. On a running
  machine: add both lines under `[options]`, `pkill -x RustDesk; open -a RustDesk`, reconnect. Restarting the
  RustDesk app on your own Mac does not help.
- **"Failed to connect to <address>:21118: Please try later" in the middle of a session** (8 Oct 2026): RustDesk on the
  test Mac had quit (no process, no crash report; most likely a ⌘Q typed while its own window was in front). Now
  `mac/rustdesk.sh` runs a watchdog that starts it again within 5 s (times in `/tmp/rd-restarts.log`): wait a few
  seconds and connect again. On a machine without the watchdog: `ssh … 'open -a RustDesk'`.
- **A macOS box "… is requesting to bypass the system private window picker …"** waits on the screen after the first
  screen capture by RustDesk, sshd or ffmpeg. Until someone clicks **Allow**, that app gets no picture. Look at the
  screen over SSH (`screencapture -x`, see below) and click Allow (`cliclick c:<x>,<y>`). The button under it is "Open
  System Settings": a click that lands on the wrong box opens Settings (close it: `osascript -e 'quit app "System Settings"'`).
- **Screenshots, clicks and recording over SSH on the Mac** (solved 8 Oct 2026). Plain `screencapture` over SSH says
  "could not create image from display": the screen permission belongs to the workflow's `/bin/bash`, not to sshd.
  Fix: over SSH, add TCC.db rows (same SQL as `mac/rustdesk.sh` step 3, client type 1) for
  `/usr/libexec/sshd-keygen-wrapper`, `/usr/libexec/sshd-session`, `/bin/bash`, `/bin/zsh` and the Homebrew `python3`/`ffmpeg`
  with kTCCServiceScreenCapture, Accessibility, ListenEvent, PostEvent; `sudo killall tccd`. Then `screencapture -x`,
  `brew install cliclick ffmpeg` (clicks/keys: `cliclick c:x,y`, `kd:cmd t:v ku:cmd`) and recording
  (`ffmpeg -f avfoundation -capture_cursor 1 -framerate 30 -i "0:none" …`, stop with `kill -INT <pid>`) all work.
  The first recording shows one "bypass the private window picker" box: click Allow once. Typing long text with
  `cliclick t:` sometimes triggers "show desktop" (windows slide off; click the wallpaper to bring them back): put the
  text on the clipboard with `pbcopy` and paste instead. To read a page in Chrome from SSH: quit Chrome, set
  `browser.allow_javascript_apple_events: true` in `~/Library/Application Support/Google/Chrome/Default/Preferences`,
  reopen, then `osascript` → `execute tab … javascript` (the menu item can't be clicked by automation; the first call
  shows one "control Google Chrome" box: Allow).
