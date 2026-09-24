#!/usr/bin/env bash
#
# Downloads the GBA LLVM devkit into Tools/ at the root of the package, where
# toolset.json expects it.

set -euo pipefail

RESOURCES=$(cd "$(dirname "$0")" && pwd)
SRCROOT=$(cd "$RESOURCES/../../../.." && pwd)
cd "$SRCROOT"

arch=$(uname -m)
platform=$(uname)
if [[ $platform != Darwin ]]; then
  echo "Only macOS is supported."
  exit 1
fi
if [[ $arch != arm64 ]]; then
  echo "Only Apple Silicon is supported"
  exit 1
fi

if [ -e Tools ]; then
  read -p "Tools dir exists, overwrite? [y|N] " overwrite
  if [[ ! $overwrite =~ ^[yY] ]]; then
    echo "Nothing to do"
    exit 0
  fi
  rm -rf Tools
fi

name=gba-llvm-devkit-1-Darwin-arm64
dmg=$(mktemp -d)/$name.dmg
mkdir -p Tools
echo "Downloading tools for macOS..."
curl -L "https://github.com/stuij/gba-llvm-devkit/releases/download/release-v1/$name.dmg" -o "$dmg"

echo "Copying files"
mountpoint=$(mktemp -d)
hdiutil attach -quiet -nobrowse -mountpoint "$mountpoint" "$dmg"
cp -R "$mountpoint/$name"/* Tools/.
hdiutil detach -quiet "$mountpoint"
rm -f "$dmg"

sysroot=Tools/lib/clang-runtimes/arm-none-eabi/armv4t
ln -s libclang_rt.builtins.a "$sysroot/lib/libclang_rt.builtins-armv4t.a"
cp "$RESOURCES/module.modulemap" "$sysroot/include/"
