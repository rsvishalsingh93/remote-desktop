#!/usr/bin/env bash
# Remote screen for a GitHub macOS runner: RustDesk in direct-IP mode over Tailscale (no relay, no third party).
# Usage (in the workflow, as user runner): RD_PASSWORD=... bash mac/rustdesk.sh
#
# Why RustDesk and not Apple Screen Sharing: since macOS 12.1 kickstart can't enable Screen Sharing (Apple), and Screen
# Sharing then has no screen-recording permission. Facts checked by mac-diagnose.yml on macOS 26 (ARM and Intel,
# 6 Oct 2026): SIP is disabled and root can write the system privacy database (TCC.db). So we grant the permissions to
# RustDesk there, the method verified by github.com/skyro777/MacOS (apple-project/, macos-15). Steps below follow it.
set -euo pipefail
: "${RD_PASSWORD:?RD_PASSWORD is not set}"
APP=/Applications/RustDesk.app
BIN="$APP/Contents/MacOS/RustDesk"
BUNDLE=com.carriez.rustdesk          # lowercase: matches the app's code signature
PORT=21118                           # RustDesk direct-IP port
PREFS="$HOME/Library/Preferences/com.carriez.RustDesk"
TCC="/Library/Application Support/com.apple.TCC/TCC.db"

echo "== 1. install RustDesk"
[ -x "$BIN" ] || brew install --cask rustdesk >/dev/null
xattr -dr com.apple.quarantine "$APP" 2>/dev/null || true

echo "== 2. config: direct IP, fixed password, accept without a click"
# Server keys must sit in an [options] table, or RustDesk ignores them (skyro777 mac_02).
# enable-hwcodec N: the VM has no real GPU; with it on, RustDesk picks hevc_videotoolbox, every frame fails
# ("encode fail: no valid frame") and the viewer sees a green screen (8 Oct 2026). VP9 is software.
mkdir -p "$PREFS"
printf "id = '%s'\npassword = '%s'\n" "$(date +%s | tail -c 10)" "$RD_PASSWORD" > "$PREFS/RustDesk.toml"
cat > "$PREFS/RustDesk2.toml" <<EOF
[options]
custom-rendezvous-server = ''
relay-server = ''
direct-server = 'Y'
direct-access-port = '$PORT'
verification-method = 'use-fixed-password'
allow-keyboard = 'Y'
allow-mouse = 'Y'
allow-clipboard = 'Y'
allow-file-transfer = 'Y'
enable-hwcodec = 'N'
codec-preference = 'vp9'
EOF
sudo mkdir -p /var/root/Library/Preferences/com.carriez.RustDesk
sudo cp "$PREFS"/RustDesk.toml "$PREFS"/RustDesk2.toml /var/root/Library/Preferences/com.carriez.RustDesk/

echo "== 3. grant screen recording, accessibility and input monitoring in TCC.db"
csrutil status
cols=$(sudo sqlite3 "$TCC" "PRAGMA table_info(access);" | cut -d'|' -f2 | paste -sd, -)
value() {   # SQL value of column $1 for service $2, client $3, client type $4 (skyro777 mac_grant_tcc.py)
  case $1 in
    service) printf "'%s'" "$2" ;;
    client) printf "'%s'" "$3" ;;
    client_type) printf "%s" "$4" ;;
    auth_value) printf "2" ;;                      # allowed
    auth_reason) printf "4" ;;                     # system set
    auth_version) printf "1" ;;
    csreq) printf "NULL" ;;                        # like the pre-granted /bin/bash row
    policy_id|indirect_object_identifier_type|flags) printf "0" ;;
    indirect_object_identifier) printf "'UNUSED'" ;;
    *) printf "NULL" ;;
  esac
}
for svc in kTCCServiceScreenCapture kTCCServiceAccessibility kTCCServiceListenEvent kTCCServicePostEvent; do
  for pair in "$BUNDLE|0" "$BIN|1"; do              # bundle id (client_type 0) and binary path (client_type 1)
    c=${pair%|*}; t=${pair##*|}; vals=""
    IFS=, read -ra colarr <<<"$cols"
    for col in "${colarr[@]}"; do vals+="$(value "$col" "$svc" "$c" "$t"),"; done
    sudo sqlite3 "$TCC" "INSERT OR REPLACE INTO access ($cols) VALUES (${vals%,});"
  done
done
sudo killall tccd 2>/dev/null || true; sleep 3
sudo sqlite3 "$TCC" "select service, client, auth_value from access where client like '%rustdesk%' or client like '%RustDesk%';"
# Screen-capture approvals (avoids the "allow to record" reminder), as skyro777 mac_lib preauthorize_screencapture.
for plist in "$HOME/Library/Group Containers/group.com.apple.replayd/ScreenCaptureApprovals.plist" \
             "/Library/Group Containers/group.com.apple.replayd/ScreenCaptureApprovals.plist"; do
  sudo mkdir -p "$(dirname "$plist")"
  sudo defaults write "$plist" "$BIN" -date "2099-01-01 00:00:00 +0000" || true
done
sudo killall -HUP replayd cfprefsd 2>/dev/null || true

echo "== 4. keep the display awake, start RustDesk"
sudo pmset -a sleep 0 displaysleep 0 disksleep 0 || true
open -a RustDesk
for _ in $(seq 1 30); do nc -z 127.0.0.1 $PORT 2>/dev/null && break; sleep 2; done
nc -z 127.0.0.1 $PORT && echo "RustDesk is listening on $PORT" || { echo "::error::RustDesk is not listening on $PORT"; exit 1; }
# Watchdog: a Cmd+Q typed in the session quits RustDesk on this Mac (its window is the front app) and the viewer gets
# "Failed to connect ... Please try later" (8 Oct 2026). Start it again within 5 s; restarts go to /tmp/rd-restarts.log.
nohup bash -c 'while true; do pgrep -x RustDesk >/dev/null || { date -u +%T >> /tmp/rd-restarts.log; open -a RustDesk; }; sleep 5; done' \
  >/dev/null 2>&1 < /dev/null &

