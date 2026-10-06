#!/usr/bin/env bash
# Start a remote test computer and open it.
#   ./start.sh macos [minutes]        -> Apple Silicon Mac (1024x768 screen): connect with RustDesk to <address>:21118
#   ./start.sh macos-intel [minutes]  -> Intel Mac (1920x1080 screen), same
#   ./start.sh windows [minutes]   -> prints the address for Windows App, user "runneradmin"
# Needs: gh (logged in), Tailscale running on this Mac. Stop early: ./stop.sh
set -euo pipefail
OS="${1:-macos}"; MIN="${2:-60}"; REPO=rsvishalsingh93/remote-desktop
case "$OS" in macos|macos-intel|windows) ;; *) echo "usage: $0 macos|macos-intel|windows [minutes]"; exit 2;; esac
command -v tailscale >/dev/null || { echo "Tailscale is not installed on this Mac."; exit 1; }

before=$(gh run list -R "$REPO" -w remote-desktop.yml -L 1 --json databaseId --jq '.[0].databaseId // 0')
gh workflow run remote-desktop.yml -R "$REPO" -f os="$OS" -f minutes="$MIN"
run=""
for _ in $(seq 1 30); do
  run=$(gh run list -R "$REPO" -w remote-desktop.yml -L 1 --json databaseId --jq '.[0].databaseId')
  [ "$run" != "$before" ] && break; sleep 2
done
echo "Run: https://github.com/$REPO/actions/runs/$run"

# GitHub shows a run's log only after it ends, so the address comes from Tailscale (the machine
# joins as gha-<os>-<run id>), and "ready" means the step that enables remote access succeeded.
step=$([ "$OS" = windows ] && echo "Enable Remote Desktop (Windows)" || echo "Enable Screen Sharing (macOS)")
echo "Waiting for the machine (2-5 minutes)..."
while :; do
  read -r st co < <(gh run view "$run" -R "$REPO" --json status,jobs \
    --jq "[.status, ((.jobs[0].steps // [])[] | select(.name==\"$step\") | .conclusion) // \"\"] | @tsv" | tr '\t' ' ')
  [ "${co:-}" = success ] && break
  if [ "${co:-}" = failure ] || [ "$st" = completed ]; then
    echo "Failed. Log: gh run view $run -R $REPO --log-failed"; exit 1
  fi
  sleep 10
done
ip=$(tailscale status | awk -v h="gha-$OS-$run" '$2==h {print $1}')
[ -n "$ip" ] || { echo "Ready, but gha-$OS-$run is not in 'tailscale status' yet. Try again in a minute."; exit 1; }

if [ "$OS" != windows ]; then
  echo "Mac ready: $ip   RustDesk -> enter $ip:21118 -> password: the RD_PASSWORD secret"
  echo "ssh: ssh -i ~/.ssh/remote_desktop_ed25519 -o IdentitiesOnly=yes runner@$ip"
  [ -d /Applications/RustDesk.app ] && open -a RustDesk || echo "Install the viewer once: brew install --cask rustdesk"
else
  echo "Windows ready: $ip   user: runneradmin   password: the RD_PASSWORD secret"
  echo "Windows App -> + -> Add PC -> PC name: $ip -> connect.   ssh: ssh -i ~/.ssh/remote_desktop_ed25519 -o IdentitiesOnly=yes runneradmin@$ip"
fi
echo "Stop: ./stop.sh $run"
