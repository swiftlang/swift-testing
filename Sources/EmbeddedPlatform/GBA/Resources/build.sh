#!/usr/bin/env bash
#
# Builds EmbeddedShowcase as a Game Boy Advance ROM.
#
# Usage: Sources/EmbeddedPlatform/GBA/Resources/build.sh
#
# Downloads the GBA LLVM devkit into Tools/ first if it isn't there.
#
# The Embedded Swift Concurrency runtime must be prebuilt in .build/concurrency,
# because toolchains don't ship it for armv4t.

set -euo pipefail

RESOURCES=$(cd "$(dirname "$0")" && pwd)
SRCROOT=$(cd "$RESOURCES/../../../.." && pwd)
cd "$SRCROOT"

PRODUCT=EmbeddedShowcase
VERBOSE=0
for arg in "$@"; do
  case "$arg" in
    -v) VERBOSE=1 ;;
    --verbose) VERBOSE=1 ;;
    *) PRODUCT=$arg ;;
  esac
done

TRIPLE=armv4t-none-none-eabi
BUILDROOT=.build/$TRIPLE/release

if [ ! -d Tools ]; then
  echo "Downloading Tools from GitHub since none exist yet".
  "$RESOURCES/retrieve-tools.sh"
fi

if [ ! -e .build/concurrency ]; then
  if [ -n "${SWT_GBA_CONCURRENCY_DIR:-}" ]; then
    mkdir -p .build
    ln -s "$SWT_GBA_CONCURRENCY_DIR" .build/concurrency
  else
    echo "error: .build/concurrency doesn't exist. Set SWT_GBA_CONCURRENCY_DIR to a" >&2
    echo "prebuilt Embedded Swift Concurrency runtime for $TRIPLE." >&2
    exit 1
  fi
fi

VERBOSE_FLAG=""
if [ $VERBOSE ]; then
  VERBOSE_FLAG="--verbose"
fi

SWT_EMBEDDED=1 SWT_BUILD_GBA=1 swift build -c release --build-system native \
  --toolset "$RESOURCES/toolset.json" \
  --triple "$TRIPLE" \
  --product "EmbeddedShowcase" \
  $VERBOSE_FLAG

Tools/bin/llvm-objcopy -O binary "$BUILDROOT/$PRODUCT" "$BUILDROOT/$PRODUCT.gba"
Tools/bin/gbafix "$BUILDROOT/$PRODUCT.gba"
echo "Built $BUILDROOT/$PRODUCT.gba"
