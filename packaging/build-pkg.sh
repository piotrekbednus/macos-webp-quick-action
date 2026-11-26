#!/bin/bash
# Builds dist/WebP-AVIF-Quick-Actions.pkg: the two Quick Actions plus bundled
# cwebp and avifenc, with a Welcome and an "All done" screen.
#
#   ./packaging/build-pkg.sh
#
# Unsigned by default: people who download it have to allow it once in
# System Settings > Privacy & Security > Open Anyway. With an Apple Developer
# ID, set these to get a signed and notarized package instead:
#
#   SIGN_APP="Developer ID Application: Name (TEAMID)"
#   SIGN_INSTALLER="Developer ID Installer: Name (TEAMID)"
#   NOTARY_PROFILE=<profile saved with: xcrun notarytool store-credentials>
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
VERSION="$(tr -d '[:space:]' < "$ROOT/VERSION")"
ID="com.automateyourstuff.webp-avif-quick-actions"
# Staged outside the repo. pkgbuild lists extended attributes (macOS adds
# com.apple.provenance to new files) as ._ entries; Installer turns them back
# into attributes, so no ._ files are installed.
STAGE="$(mktemp -d -t webp-avif-pkg)"
trap 'rm -rf "$STAGE"' EXIT
OUT="$ROOT/dist/WebP-AVIF-Quick-Actions.pkg"

# Reuse the encoders only if they were built from the current
# build-encoders.sh (see the fingerprint it writes at the end).
inputs="$(shasum -a 256 "$ROOT/packaging/build-encoders.sh" | cut -d' ' -f1)"
if [ ! -x "$ROOT/build/encoders/cwebp" ] || [ ! -x "$ROOT/build/encoders/avifenc" ] ||
   [ "$(cat "$ROOT/build/encoders/.build-inputs" 2>/dev/null)" != "$inputs" ]; then
  "$ROOT/packaging/build-encoders.sh"
fi
python3 "$ROOT/build.py"

PAYLOAD="$STAGE/root"
APP="$PAYLOAD/Library/Application Support/WebP AVIF Quick Actions"
mkdir -p "$PAYLOAD/Library/Services" "$APP/bin" "$ROOT/dist"

cp -R "$ROOT/workflows/"*.workflow "$PAYLOAD/Library/Services/"
cp "$ROOT/build/encoders/cwebp" "$ROOT/build/encoders/avifenc" "$APP/bin/"
cp -R "$ROOT/build/encoders/licenses" "$APP/licenses"
cp "$ROOT/LICENSE" "$APP/licenses/webp-avif-quick-actions.txt"
cp "$ROOT/packaging/Uninstall.command" "$APP/"
chmod 755 "$APP/bin/"* "$APP/Uninstall.command"
find "$PAYLOAD" -name .DS_Store -delete
xattr -cr "$PAYLOAD"   # no iCloud / Finder attributes in the payload

if [ -n "${SIGN_APP:-}" ]; then
  codesign --force --options runtime --timestamp --sign "$SIGN_APP" "$APP/bin/"*
fi

# Install exactly where stated. Without this, Installer may "relocate" a
# bundle to wherever it finds another copy with the same identifier.
pkgbuild --analyze --root "$PAYLOAD" "$STAGE/components.plist" >/dev/null
python3 - "$STAGE/components.plist" <<'EOF'
import plistlib, sys
p = sys.argv[1]
items = plistlib.load(open(p, "rb"))
for item in items:
    item["BundleIsRelocatable"] = False
plistlib.dump(items, open(p, "wb"))
EOF

pkgbuild --quiet --root "$PAYLOAD" --component-plist "$STAGE/components.plist" \
  --scripts "$ROOT/packaging/scripts" --identifier "$ID" --version "$VERSION" \
  --install-location / "$STAGE/component.pkg"

sed "s/@VERSION@/$VERSION/" "$ROOT/packaging/distribution.xml" > "$STAGE/distribution.xml"
sign=()
[ -n "${SIGN_INSTALLER:-}" ] && sign=(--sign "$SIGN_INSTALLER")
rm -f "$OUT"
productbuild --quiet --distribution "$STAGE/distribution.xml" \
  --resources "$ROOT/packaging/resources" --package-path "$STAGE" \
  ${sign[@]+"${sign[@]}"} "$OUT"

if [ -n "${NOTARY_PROFILE:-}" ]; then
  xcrun notarytool submit "$OUT" --keychain-profile "$NOTARY_PROFILE" --wait
  xcrun stapler staple "$OUT"
fi

echo "Built $OUT ($VERSION, $(du -h "$OUT" | cut -f1 | tr -d ' '))"
shasum -a 256 "$OUT"
