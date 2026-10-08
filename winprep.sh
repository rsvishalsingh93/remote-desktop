#!/bin/bash
# Prepare a Windows test machine over SSH: ./winprep.sh <address> [--no-chrome]
# Copies windows/agent.ps1 + prep.ps1 to C:\ctl and runs prep.ps1. Then drive it with ./wc (needs the user signed in once with Windows App).
set -euo pipefail
cd "$(dirname "$0")"; ip=$1; shift || true
o=(-i ~/.ssh/remote_desktop_ed25519 -o IdentitiesOnly=yes -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null -o LogLevel=ERROR -o ConnectTimeout=15)
echo "$ip" > ~/.remote-desktop-ip
ssh "${o[@]}" runneradmin@$ip 'New-Item -ItemType Directory -Force C:\ctl | Out-Null' </dev/null
scp -q "${o[@]}" windows/agent.ps1 windows/prep.ps1 runneradmin@$ip:'C:/ctl/'
arg=""; [ "${1:-}" = --no-chrome ] && arg="-NoChrome"
ssh "${o[@]}" runneradmin@$ip "powershell -NoProfile -ExecutionPolicy Bypass -File C:\ctl\prep.ps1 $arg" </dev/null
