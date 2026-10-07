#!/bin/bash
# Turns the unsigned FaceCheck.app into what the phone installs:
#   dist/repo/        a flat Sileo repo (Packages + Release) with two .debs,
#                     rootless (/var/jb, iphoneos-arm64) and rootful (/, iphoneos-arm)
#   dist/repo/FaceCheck.ipa   for TrollStore
# Usage: packaging/package.sh <path/to/FaceCheck.app> <build number>
set -euo pipefail

APP="$1"
VERSION="1.0.${2:-1}"
ID="com.kobz.facecheck"
HERE="$(cd "$(dirname "$0")" && pwd)"
OUT="dist/repo"
rm -rf dist && mkdir -p "$OUT/debs"

# Jailbroken iOS still wants a signature, an ad-hoc one is enough.
ldid -S "$APP/FaceCheck"

work="$(mktemp -d)"
mkdir -p "$work/Payload"
cp -R "$APP" "$work/Payload/"
(cd "$work" && zip -qr FaceCheck.ipa Payload)
mv "$work/FaceCheck.ipa" "$OUT/"

make_deb() {
  local prefix="$1" arch="$2" root
  root="$(mktemp -d)"
  mkdir -p "$root$prefix/Applications" "$root/DEBIAN"
  cp -R "$APP" "$root$prefix/Applications/"
  sed -e "s|@VERSION@|$VERSION|" -e "s|@ARCH@|$arch|" -e "s|@ID@|$ID|" "$HERE/control" > "$root/DEBIAN/control"
  for s in postinst postrm; do
    sed "s|@APP@|$prefix/Applications/FaceCheck.app|" "$HERE/$s" > "$root/DEBIAN/$s"
    chmod 0755 "$root/DEBIAN/$s"
  done
  dpkg-deb -Zgzip --root-owner-group -b "$root" "$OUT/debs/${ID}_${VERSION}_${arch}.deb"
}
make_deb /var/jb iphoneos-arm64
make_deb "" iphoneos-arm

cd "$OUT"
dpkg-scanpackages -m debs /dev/null > Packages
gzip -k9 Packages
bzip2 -k9 Packages
cp "$HERE/Release" Release
cp "$HERE/index.html" index.html
ls -la . debs
