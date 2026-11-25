# Convert to WebP / AVIF - Finder Quick Actions for macOS

Right-click any image in Finder, choose **Quick Actions → Convert to WebP** (or
**Convert to AVIF**), and a compressed copy appears next to the original.

macOS can convert images to JPEG, PNG and HEIF from Finder, but not to WebP or
AVIF. These two Quick Actions fill that gap. They run locally, so nothing is
uploaded to an online converter.

- Works on many files at once: select them all, right-click, done.
- Takes PNG, JPEG, TIFF, HEIC and anything else macOS can open.
- Never touches the original or any other existing file. The new file gets the
  same name with a new extension; if that name is taken, it becomes
  `name 2.webp`, `name 3.webp` and so on. Files already in the target format
  are skipped.
- Shows a notification when it is finished.
- **Keeps the colour profile.** Screenshots on a Mac are tagged Display P3. Most
  `cwebp` one-liners drop that tag, which makes colours look washed out. Here
  WebP keeps the ICC profile. AVIF stores sRGB and Display P3 as compact CICP
  colour tags, and keeps any other profile (Adobe RGB, for example) as ICC.
- Removes EXIF and XMP metadata (camera, location and so on). Photos that rely on
  the EXIF orientation tag, such as portrait shots from a phone, are rotated in
  the pixels first, so they still come out the right way up.

## Install

You need [Homebrew](https://brew.sh).

```bash
git clone https://github.com/piotrekbednus/macos-webp-quick-action.git
cd macos-webp-quick-action
./install.sh
```

`install.sh` offers to run `brew install webp libavif` if the encoders are
missing, copies both actions to `~/Library/Services` and refreshes Finder's
menu.

If the actions do not show up, relaunch Finder (Option + right-click the Finder
icon in the Dock → Relaunch), or turn them on in **System Settings → Keyboard →
Keyboard Shortcuts → Services**. That is also where you can give them a
keyboard shortcut.

The first time you run one on your Desktop or in Downloads, macOS may ask for
permission to access that folder.

Uninstall with `./uninstall.sh`.

## What you get

One 2126×1810 browser screenshot (Display P3), default settings:

| File | Size |
|---|---|
| PNG (original) | 1,045 KB |
| WebP, quality 80 | 123 KB |
| AVIF, quality 70, 4:4:4 | 112 KB |

That is a single image, not a benchmark. Your results will vary with the
content.

## Settings

| | WebP | AVIF |
|---|---|---|
| Encoder | `cwebp` (libwebp) | `avifenc` (libavif + aom) |
| Quality | 80 | 70 (libavif's scale differs from WebP's) |
| Other | `-m 6 -sharp_yuv -metadata icc` | `-s 6 -y 444 --ignore-exif --ignore-xmp` |

AVIF uses full colour resolution (4:4:4) rather than the usual 4:2:0. This keeps
coloured text and thin UI lines in screenshots sharp, for a file that is about
5% bigger.

**Which one should I use?** WebP works in every current browser and encodes
quickly. AVIF is usually a little smaller at the same visual quality. Most
browsers support it too, but some image tools and CMSs still reject it.
Screenshots full of sharp text gain the least from AVIF.

## Changing the settings

The shell scripts live in `src/`. To change them:

1. Edit `QUALITY` (or anything else) in `src/convert-to-webp.sh` or
   `src/convert-to-avif.sh`.
2. Run `python3 build.py` to rebuild the bundles in `workflows/`.
3. Run `./install.sh`.

To change one installed copy without the repo, open it in Automator from
`~/Library/Services` and edit the script there.

## Made by

Built and used by the team behind
**[Remindlo](https://www.remindlo.co.uk)**, a tool for service businesses
(garages, salons, clinics, gyms) that sends automatic SMS and email appointment
reminders. We built these actions for the screenshots on our own website.

Also from us: **[Scanlo](https://scanlo.io)**, tracked QR codes for small
businesses (Google review, booking and payment codes) whose destination you can
change after printing.

## License

MIT
