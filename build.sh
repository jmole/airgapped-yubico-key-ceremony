#!/bin/sh
set -eu

REPO_ROOT=$(cd "$(dirname "$0")" && pwd)
BUILDROOT_DIR="$REPO_ROOT/third_party/buildroot"
BR2_EXTERNAL="$REPO_ROOT/airgapped-br2"
RSA_KEYGEN_DIR="$REPO_ROOT/rsa-keygen"

[ -d "$BUILDROOT_DIR" ] || { echo "ERROR: Buildroot not found at $BUILDROOT_DIR" >&2; exit 1; }
[ -d "$BR2_EXTERNAL" ] || { echo "ERROR: BR2_EXTERNAL not found at $BR2_EXTERNAL" >&2; exit 1; }
[ -d "$RSA_KEYGEN_DIR" ] || { echo "ERROR: rsa-keygen not found at $RSA_KEYGEN_DIR" >&2; exit 1; }

export BR2_EXTERNAL
export RSA_KEYGEN_DIR

cd "$BUILDROOT_DIR"

echo "Building config: key_ceremony_x86_64_defconfig..."
make key_ceremony_x86_64_defconfig

echo "(Re)building grub config..."
make grub2-rebuild

echo "Building with BR2_EXTERNAL=$BR2_EXTERNAL and RSA_KEYGEN_DIR=$RSA_KEYGEN_DIR"
make


# Copy resulting ISO to repo root and list it
OUT_IMG_DIR="$BUILDROOT_DIR/output/images"
ISO_SRC="$OUT_IMG_DIR/rootfs.iso9660"


if [ -n "${ISO_SRC:-}" ] && [ -f "$ISO_SRC" ]; then
  cp -f "$ISO_SRC" "$REPO_ROOT/"
  echo "\n\nSUCCESS!!\n\nCopied $(basename "$ISO_SRC") to $REPO_ROOT\n\n"
  ls -la "$REPO_ROOT/$(basename "$ISO_SRC")"
  echo "\n"
else
  echo "\n\nWARNING: No ISO image found in $OUT_IMG_DIR\n\n" >&2
  ls -la "$OUT_IMG_DIR" || true
fi


