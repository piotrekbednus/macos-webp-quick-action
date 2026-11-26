#!/bin/bash
# One-line install of the latest release, for people happy to use Terminal:
#
#   curl -fsSL https://raw.githubusercontent.com/piotrekbednus/macos-webp-quick-action/main/quick-install.sh | bash
#
# Downloads the same .pkg as the Download button and installs it with
# macOS's own installer. Files fetched with curl are not quarantined, so the
# "Apple could not verify" step does not appear.
set -euo pipefail

# Everything runs from main(), called on the last line, so a download cut off
# half-way through this script cannot run a partial command.
main() {
  local url="https://github.com/piotrekbednus/macos-webp-quick-action/releases/latest/download/WebP-AVIF-Quick-Actions.pkg"
  local pkg
  TMP_DIR="$(mktemp -d -t webp-avif)"
  trap 'rm -rf "$TMP_DIR"' EXIT
  pkg="$TMP_DIR/WebP-AVIF-Quick-Actions.pkg"

  if [ "$(uname -s)" != Darwin ]; then
    echo "This installs Finder Quick Actions and only works on macOS." >&2
    exit 1
  fi

  echo "Downloading WebP & AVIF Quick Actions..."
  curl -fL --progress-bar -o "$pkg" "$url"
  # A real installer package, not an error page.
  pkgutil --payload-files "$pkg" >/dev/null 2>&1 || { echo "The download is not a valid installer. Try again later." >&2; exit 1; }

  echo "Installing. macOS asks for your password (nothing appears as you type it)."
  sudo installer -pkg "$pkg" -target / >/dev/null

  echo
  echo "Done. In Finder, select images, right-click > Quick Actions > Convert to WebP or Convert to AVIF."
  echo "Like it? You can buy me a coffee: https://buymeacoffee.com/convert_png_to_webp_avif"
}

main "$@"
