#!/bin/bash
# Prepare a Windows test machine over SSH: ./winprep.sh <address> [--no-chrome] [--buyer]
# Copies windows/agent.ps1 + prep.ps1 to C:\ctl and runs prep.ps1. Then drive it with ./wc (needs the user signed in once with Windows App).
set -euo pipefail
cd "$(dirname "$0")"; ip=$1; shift || true
o=(-i ~/.ssh/remote_desktop_ed25519 -o IdentitiesOnly=yes -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null -o LogLevel=ERROR -o ConnectTimeout=15)
echo "$ip" > ~/.remote-desktop-ip
ssh "${o[@]}" runneradmin@$ip 'New-Item -ItemType Directory -Force C:\ctl | Out-Null' </dev/null
scp -q "${o[@]}" windows/agent.ps1 windows/prep.ps1 runneradmin@$ip:'C:/ctl/'
arg=""; for a in "$@"; do case $a in --no-chrome) arg="$arg -NoChrome" ;; --buyer) arg="$arg -Buyer" ;; *) echo "unknown option $a" >&2; exit 1 ;; esac; done
ssh "${o[@]}" runneradmin@$ip "powershell -NoProfile -ExecutionPolicy Bypass -File C:\ctl\prep.ps1 $arg" </dev/null
