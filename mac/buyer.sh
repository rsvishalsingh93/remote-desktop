#!/bin/bash
# Buyer mode for a GitHub test Mac (run on it over SSH: bash buyer.sh). A buyer's Mac has no Xcode and no Command
# Line Tools: /usr/bin/git is only Apple's stand-in that asks to install them (the Hermes installer needs git).
# Moves Xcode and the tools aside (same disk: instant; the machine is thrown away after the run) and checks the result.
set -u
hide=/Users/Shared/hidden-developer-tools
sudo mkdir -p "$hide"
for d in /Applications/Xcode*.app /Library/Developer/CommandLineTools; do [ -e "$d" ] && sudo mv "$d" "$hide/"; done
sudo rm -f /var/db/xcode_select_link
# Forget the tools' install records too, or Apple's installer says "The software was installed" without downloading
# (seen on a second run, 13 Oct 2026; the first run on a fresh image downloaded them).
for p in $(pkgutil --pkgs | grep -i CLTools); do sudo pkgutil --forget "$p" >/dev/null; done
if xcode-select -p >/dev/null 2>&1; then echo "FAILED: xcode-select still finds $(xcode-select -p)"; exit 1; fi
echo "developer tools hidden: xcode-select -p fails, as on a buyer's Mac"
# Homebrew stays installed (this machine is driven with its cliclick and ffmpeg) but off the buyer shell's PATH:
# run the install in a clean environment, e.g.
#   env -i HOME="$HOME" USER="$USER" LOGNAME="$USER" SHELL=/bin/zsh TERM=xterm-256color PATH=/usr/bin:/bin:/usr/sbin:/sbin bash -c '<command>'
