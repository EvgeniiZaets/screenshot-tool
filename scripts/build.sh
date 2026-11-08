#!/bin/bash
set -euo pipefail
cd "$(dirname "$0")/.."

configuration="${CONFIGURATION:-release}"
export CLANG_MODULE_CACHE_PATH="$PWD/.build/clang-module-cache"
export SWIFTPM_MODULECACHE_OVERRIDE="$PWD/.build/swift-module-cache"
mkdir -p "$CLANG_MODULE_CACHE_PATH" "$SWIFTPM_MODULECACHE_OVERRIDE"

arguments=(--configuration "$configuration" --disable-sandbox
    --cache-path "$PWD/.build/cache" --config-path "$PWD/.build/config" --security-path "$PWD/.build/security")
if [[ "${UNIVERSAL:-0}" == "1" ]]; then
    arguments+=(--arch arm64 --arch x86_64)
fi
swift build "${arguments[@]}"
bin_path="$(swift build "${arguments[@]}" --show-bin-path)"
app="$PWD/build/Screenshoter.app"
mkdir -p "$app/Contents/MacOS" "$app/Contents/Resources"
cp "$bin_path/Screenshoter" "$app/Contents/MacOS/Screenshoter"
cp Resources/Info.plist "$app/Contents/Info.plist"
swift scripts/make-icon.swift "$app/Contents/Resources/AppIcon.icns"
plutil -lint "$app/Contents/Info.plist"
codesign --force --sign "${CODE_SIGN_IDENTITY:--}" --options runtime "$app"
codesign --verify --strict "$app"
printf '\nBuilt %s\n' "$app"
