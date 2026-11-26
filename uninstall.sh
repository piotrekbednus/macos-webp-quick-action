#!/bin/bash
set -uo pipefail

failed=0
for name in "Convert to WebP.workflow" "Convert to AVIF.workflow"; do
  path="$HOME/Library/Services/$name"
  if [ ! -e "$path" ]; then
    echo "Not installed: $name"
  elif rm -rf "$path" && [ ! -e "$path" ]; then
    echo "Removed $name"
  else
    echo "Could not remove $name" >&2
    failed=1
  fi
done

/System/Library/CoreServices/pbs -flush

if [ -e "/Library/Services/Convert to WebP.workflow" ] || [ -e "/Library/Services/Convert to AVIF.workflow" ]; then
  echo "The installer (.pkg) version is installed too. To remove it, run:"
  echo "  open \"/Library/Application Support/WebP AVIF Quick Actions/Uninstall.command\""
fi
exit $failed
