#!/usr/bin/env bash
# Build Kozo and wrap it into build/Kozo.app (ad-hoc signed).
# Uses swiftc directly so it works with just the Command Line Tools (no Xcode, and no
# dependency on SwiftPM, whose manifest linking is broken in some CLT installs).
set -euo pipefail
cd "$(dirname "$0")/.."

APP="build/Kozo.app"
mkdir -p build/obj

for arch in arm64 x86_64; do
  swiftc -O -target "$arch-apple-macos13.0" -framework Carbon \
    Sources/Kozo/*.swift -o "build/obj/Kozo-$arch"
done
lipo -create build/obj/Kozo-arm64 build/obj/Kozo-x86_64 -output build/obj/Kozo

rm -rf "$APP"
mkdir -p "$APP/Contents/MacOS" "$APP/Contents/Resources"
cp build/obj/Kozo "$APP/Contents/MacOS/Kozo"
cp Resources/Info.plist "$APP/Contents/Info.plist"
codesign --force --sign - "$APP"

echo "Built $APP"
echo "Run:     open $APP"
echo "Install: cp -R $APP /Applications/"
