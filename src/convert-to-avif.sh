#!/bin/zsh
# Convert to AVIF - Finder Quick Action.
# Writes <name>.avif next to each selected image and leaves the original alone.

QUALITY=70   # 0-100 on libavif's scale (not the same scale as WebP).
SPEED=6      # 0 = slowest/smallest, 10 = fastest.

# The installer (.pkg) puts its own encoders here; the install.sh route uses
# Homebrew's.
export PATH="/Library/Application Support/WebP AVIF Quick Actions/bin:/opt/homebrew/bin:/usr/local/bin:$PATH"

notify() { osascript -e "display notification \"$1\" with title \"Convert to AVIF\""; }

if ! command -v avifenc >/dev/null 2>&1; then
  notify "avifenc not found. Reinstall from github.com/piotrekbednus/macos-webp-quick-action"
  exit 1
fi

encode() {
  # -y 444 keeps full colour resolution, so coloured text and thin UI lines in
  # screenshots stay sharp. The colour profile is kept (libavif stores Display
  # P3 / sRGB as compact CICP values); EXIF/XMP are left out.
  avifenc -q $QUALITY -s $SPEED -y 444 --ignore-exif --ignore-xmp "$1" "$2" >/dev/null 2>&1
}

# Next free "<name>.avif", "<name> 2.avif", ... so an existing file is never
# overwritten (e.g. photo.png and photo.jpg selected together). :r only strips
# an extension from the file name, never from a folder name.
output_for() {
  local base="${1:r}" out="${1:r}.avif" n=2
  while [[ -e "$out" ]]; do out="$base $n.avif"; n=$((n+1)); done
  print -r -- "$out"
}

# EXIF orientation (1-8) via ImageIO. We drop EXIF, so a rotated photo has
# to be turned the right way up in the pixels before encoding.
orientation() {
  osascript -l JavaScript -e 'ObjC.import("ImageIO"); function run(a) {
    var s = $.CGImageSourceCreateWithURL($.NSURL.fileURLWithPath(a[0]), null);
    if (!s) return 1;
    var p = ObjC.castRefToObject($.CGImageSourceCopyPropertiesAtIndex(s, 0, null));
    if (!p || p.isNil()) return 1;
    var o = p.objectForKey("Orientation");
    return (o && !o.isNil()) ? o.intValue : 1; }' "$1" 2>/dev/null || echo 1
}

# Rotate/flip the pixels of $1 in place to match EXIF orientation $2.
apply_orientation() {
  case "$2" in
    2) sips -f horizontal "$1" ;;
    3) sips -r 180 "$1" ;;
    4) sips -f vertical "$1" ;;
    5) sips -r 90 "$1" && sips -f horizontal "$1" ;;
    6) sips -r 90 "$1" ;;
    7) sips -r 90 "$1" && sips -f vertical "$1" ;;
    8) sips -r 270 "$1" ;;
  esac >/dev/null 2>&1
}

work="$(mktemp -d -t avif)"
trap 'rm -rf "$work"' EXIT

ok=0; fail=0
for f in "$@"; do
  [ -f "$f" ] || continue
  [[ "${f:e:l}" == avif ]] && continue
  out="$(output_for "$f")"
  orient="$(orientation "$f")"
  if [[ "${f:e:l}" == (png|jpg|jpeg) && "$orient" == 1 ]]; then
    src="$f"
  else
    # HEIC, GIF, BMP, ... or a rotated photo: let macOS decode it to PNG first.
    src="$work/input.png"
    if ! sips -s format png "$f" --out "$src" >/dev/null 2>&1 || ! apply_orientation "$src" "$orient"; then
      fail=$((fail+1)); continue
    fi
  fi
  # $out is always a new path, so removing it on failure cannot touch the input.
  if encode "$src" "$out" && [[ -s "$out" ]]; then
    ok=$((ok+1))
  else
    rm -f "$out"; fail=$((fail+1))
  fi
done

msg="Converted $ok file(s)"
[ $fail -gt 0 ] && msg="$msg, $fail failed"
notify "$msg"
