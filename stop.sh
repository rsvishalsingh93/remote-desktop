#!/usr/bin/env bash
# Stop a remote test computer: ./stop.sh [run id]   (no id: every run still in progress)
set -euo pipefail
REPO=rsvishalsingh93/remote-desktop
ids="${1:-$(gh run list -R "$REPO" -w remote-desktop.yml --status in_progress --json databaseId --jq '.[].databaseId')}"
[ -n "$ids" ] || { echo "Nothing running."; exit 0; }
for id in $ids; do gh run cancel "$id" -R "$REPO" && echo "Stopped $id"; done
