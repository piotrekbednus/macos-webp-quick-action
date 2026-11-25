#!/bin/bash
# Installs the Quick Actions into ~/Library/Services.
set -euo pipefail

cd "$(dirname "$0")"
DEST="$HOME/Library/Services"
export PATH="/opt/homebrew/bin:/usr/local/bin:$PATH"

missing=()
command -v cwebp   >/dev/null 2>&1 || missing+=(webp)
command -v avifenc >/dev/null 2>&1 || missing+=(libavif)

if [ ${#missing[@]} -gt 0 ]; then
  if command -v brew >/dev/null 2>&1; then
    read -r -p "Install ${missing[*]} with Homebrew now? [Y/n] " answer
    if [[ ! "$answer" =~ ^[Nn] ]]; then
      brew install "${missing[@]}"
    else
      echo "Skipped. The matching Quick Action will tell you what is missing when you use it."
    fi
  else
    echo "Missing: ${missing[*]}. Install Homebrew (https://brew.sh), then: brew install ${missing[*]}"
  fi
fi

mkdir -p "$DEST"
staging=""
trap 'if [ -n "$staging" ]; then rm -rf "$staging"; fi' EXIT
for wf in workflows/*.workflow; do
  name="$(basename "$wf")"
  # Copy to a staging name first, so a failed copy (set -e stops the script)
  # leaves any existing installation in place.
  staging="$DEST/.$name.installing"
  rm -rf "$staging"
  cp -R "$wf" "$staging"
  # Files downloaded from the web are quarantined; Finder would not run them.
  xattr -dr com.apple.quarantine "$staging" 2>/dev/null || true
  rm -rf "$DEST/$name"
  mv "$staging" "$DEST/$name"
  echo "Installed $name"
done

/System/Library/CoreServices/pbs -flush
echo "Done. Right-click an image in Finder > Quick Actions."
