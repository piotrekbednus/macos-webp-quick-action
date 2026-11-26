#!/bin/bash
# Removes WebP & AVIF Quick Actions installed with the .pkg installer.
# Double-click it in Finder; macOS asks for your password.
SERVICES="/Library/Services"
APP="/Library/Application Support/WebP AVIF Quick Actions"

echo "Removing WebP & AVIF Quick Actions..."
osascript -e "do shell script \"rm -rf '$SERVICES/Convert to WebP.workflow' '$SERVICES/Convert to AVIF.workflow' '$APP'; pkgutil --forget com.automateyourstuff.webp-avif-quick-actions >/dev/null 2>&1; true\" with administrator privileges" >/dev/null

if [ -e "$SERVICES/Convert to WebP.workflow" ] || [ -e "$SERVICES/Convert to AVIF.workflow" ] || [ -e "$APP" ]; then
  echo "Not removed (cancelled, or the password was not accepted)."
  exit 1
fi
/System/Library/CoreServices/pbs -flush
echo "Removed. You can close this window."
