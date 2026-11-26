#!/bin/bash
# Builds self-contained, universal (Apple Silicon + Intel) cwebp and avifenc
# for the installer, so people do not need Homebrew.
#
# Everything is linked statically from pinned source releases; the binaries
# depend only on libraries that ship with macOS. Output: build/encoders/
#
# Needs Xcode Command Line Tools, plus: brew install cmake nasm ninja
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
WORK="$ROOT/build/encoders-src"
OUT="$ROOT/build/encoders"
MIN_MACOS=11.0
ARCHS=(arm64 x86_64)

# Pinned versions (git tags).
ZLIB=v1.3.2
LIBPNG=v1.6.59
LIBJPEG_TURBO=3.2.1
LIBWEBP=v1.6.0
AOM=v3.15.3
LIBAVIF=v1.4.2

for tool in cmake nasm ninja git; do
  command -v "$tool" >/dev/null || { echo "Missing $tool (brew install cmake nasm ninja)"; exit 1; }
done

# Each checkout is named after its tag, so changing a pinned version above
# fetches and builds that version instead of reusing an older checkout.
fetch() { # url tag name
  if [ ! -d "$WORK/$3-$2" ]; then
    rm -rf "$WORK/$3-$2.partial"   # left over from an interrupted clone
    git -c advice.detachedHead=false clone --quiet --depth 1 --branch "$2" "$1" "$WORK/$3-$2.partial"
    mv "$WORK/$3-$2.partial" "$WORK/$3-$2"
  fi
}

mkdir -p "$WORK"
fetch https://github.com/madler/zlib.git                 "$ZLIB"          zlib
fetch https://github.com/pnggroup/libpng.git             "$LIBPNG"        libpng
fetch https://github.com/libjpeg-turbo/libjpeg-turbo.git "$LIBJPEG_TURBO" libjpeg-turbo
fetch https://github.com/webmproject/libwebp.git         "$LIBWEBP"       libwebp
fetch https://aomedia.googlesource.com/aom               "$AOM"           aom
fetch https://github.com/AOMediaCodec/libavif.git        "$LIBAVIF"       libavif

build_arch() {
  local arch="$1"
  local prefix="$WORK/$arch/prefix"
  local common=(
    -G Ninja
    -DCMAKE_BUILD_TYPE=Release
    -DCMAKE_OSX_ARCHITECTURES="$arch"
    -DCMAKE_OSX_DEPLOYMENT_TARGET="$MIN_MACOS"
    -DCMAKE_INSTALL_PREFIX="$prefix"
    -DCMAKE_PREFIX_PATH="$prefix"
    -DCMAKE_FIND_FRAMEWORK=NEVER
    # Never pick up Homebrew's copies of these libraries.
    "-DCMAKE_IGNORE_PREFIX_PATH=/opt/homebrew;/usr/local"
    -DBUILD_SHARED_LIBS=OFF
    -DCMAKE_POLICY_VERSION_MINIMUM=3.5
  )
  if [ "$arch" != "$(uname -m)" ]; then
    common+=(-DCMAKE_SYSTEM_NAME=Darwin -DCMAKE_SYSTEM_PROCESSOR="$arch")
  fi

  cm() { # source-dir build-name extra-args...
    local src="$1" b="$WORK/$arch/build-$2"; shift 2
    cmake -S "$src" -B "$b" "${common[@]}" "$@" >"$b.log" 2>&1 || { tail -40 "$b.log"; exit 1; }
    cmake --build "$b" >>"$b.log" 2>&1 || { tail -40 "$b.log"; exit 1; }
    cmake --install "$b" >>"$b.log" 2>&1 || { tail -40 "$b.log"; exit 1; }
    # Static only: a stray .dylib in the prefix would be linked instead.
    rm -f "$prefix"/lib/*.dylib
  }

  mkdir -p "$WORK/$arch"
  echo "[$arch] zlib";          cm "$WORK/zlib-$ZLIB" "zlib-$ZLIB" -DZLIB_BUILD_SHARED=OFF -DZLIB_BUILD_TESTING=OFF
  echo "[$arch] libpng";        cm "$WORK/libpng-$LIBPNG" "libpng-$LIBPNG" -DPNG_SHARED=OFF -DPNG_TESTS=OFF -DPNG_TOOLS=OFF -DPNG_FRAMEWORK=OFF
  echo "[$arch] libjpeg-turbo"; cm "$WORK/libjpeg-turbo-$LIBJPEG_TURBO" "libjpeg-turbo-$LIBJPEG_TURBO" -DENABLE_SHARED=OFF -DENABLE_STATIC=ON -DWITH_TURBOJPEG=OFF
  echo "[$arch] libwebp";       cm "$WORK/libwebp-$LIBWEBP" "libwebp-$LIBWEBP" \
    -DWEBP_BUILD_CWEBP=ON -DWEBP_BUILD_DWEBP=OFF -DWEBP_BUILD_GIF2WEBP=OFF \
    -DWEBP_BUILD_IMG2WEBP=OFF -DWEBP_BUILD_VWEBP=OFF -DWEBP_BUILD_WEBPINFO=OFF \
    -DWEBP_BUILD_WEBPMUX=OFF -DWEBP_BUILD_EXTRAS=OFF -DWEBP_BUILD_ANIM_UTILS=OFF \
    -DWEBP_USE_THREAD=ON
  echo "[$arch] aom";           cm "$WORK/aom-$AOM" "aom-$AOM" \
    -DAOM_TARGET_CPU="$arch" -DCONFIG_AV1_DECODER=0 -DENABLE_DOCS=0 -DENABLE_EXAMPLES=0 \
    -DENABLE_TESTDATA=0 -DENABLE_TESTS=0 -DENABLE_TOOLS=0
  echo "[$arch] libavif";       cm "$WORK/libavif-$LIBAVIF" "libavif-$LIBAVIF" \
    -DAVIF_BUILD_APPS=ON -DAVIF_CODEC_AOM=SYSTEM -DAVIF_CODEC_AOM_DECODE=OFF \
    -DAOM_INCLUDE_DIR="$prefix/include" -DAOM_LIBRARY="$prefix/lib/libaom.a" \
    -DAVIF_JPEG=SYSTEM -DAVIF_ZLIBPNG=SYSTEM -DAVIF_LIBYUV=OFF \
    -DAVIF_LIBSHARPYUV=OFF -DAVIF_LIBXML2=OFF
}

for arch in "${ARCHS[@]}"; do build_arch "$arch"; done

rm -rf "$OUT"; mkdir -p "$OUT/licenses"
for bin in cwebp avifenc; do
  args=(); for arch in "${ARCHS[@]}"; do args+=("$WORK/$arch/prefix/bin/$bin"); done
  lipo -create "${args[@]}" -output "$OUT/$bin"
  codesign --force --sign - "$OUT/$bin"
  # Fail loudly if anything outside the OS slipped in.
  if otool -L "$OUT/$bin" | grep -E '^[[:space:]]' | grep -vE '^\s+/(usr/lib|System/Library)/'; then
    echo "$bin links a non-system library (above)"; exit 1
  fi
done

cp "$WORK/zlib-$ZLIB/LICENSE" "$OUT/licenses/zlib.txt"
cp "$WORK/libpng-$LIBPNG/LICENSE" "$OUT/licenses/libpng.txt"
cp "$WORK/libjpeg-turbo-$LIBJPEG_TURBO/LICENSE.md" "$OUT/licenses/libjpeg-turbo.md"
cp "$WORK/libwebp-$LIBWEBP/COPYING" "$OUT/licenses/libwebp.txt"
cp "$WORK/libwebp-$LIBWEBP/PATENTS" "$OUT/licenses/libwebp-PATENTS.txt"
cp "$WORK/aom-$AOM/LICENSE" "$OUT/licenses/aom.txt"
cp "$WORK/aom-$AOM/PATENTS" "$OUT/licenses/aom-PATENTS.txt"
cp "$WORK/libavif-$LIBAVIF/LICENSE" "$OUT/licenses/libavif.txt"

lipo -info "$OUT/cwebp" "$OUT/avifenc"
"$OUT/cwebp" -version
"$OUT/avifenc" --version | head -1

# Written last, so it exists only after a complete build. Every input (pins,
# MIN_MACOS, ARCHS, flags) is in this script, so its hash identifies the build;
# build-pkg.sh rebuilds when it no longer matches.
shasum -a 256 "$ROOT/packaging/build-encoders.sh" | cut -d' ' -f1 > "$OUT/.build-inputs"
