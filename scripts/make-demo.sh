#!/usr/bin/env bash
# Regenerate the README demo images in docs/ from the real texture code.
set -euo pipefail
cd "$(dirname "$0")/.."
mkdir -p build/obj docs
swiftc -O Tools/Demo/main.swift Sources/Kozo/TextureGenerator.swift Sources/Kozo/Settings.swift -o build/obj/kozo-demo
build/obj/kozo-demo docs
