#!/bin/bash
# Local iOS CLI build script. Runs purely in Terminal without launching the Xcode GUI.
set -eu
set -o pipefail
export PATH=/usr/bin:/bin:/usr/sbin:/sbin

if [ "${1:-}" = --help ]; then
  printf '%s\n' \
    'KL-06 Mobile iOS CLI Builder' \
    'Usage: ./BUILD-IOS.command [options]' \
    'Options:' \
    '  --device       Build Release arm64 for physical iPhone and package KL06Mobile.ipa (default)' \
    '  --simulator    Build Debug for iOS Simulator' \
    '  --install      Build and attempt to deploy to connected iPhone via xcrun devicectl' \
    '  --help         Show this help message'
  exit 0
fi

if [ "$(uname -s)" != Darwin ] || [ "$(id -u)" -eq 0 ]; then
  printf '%s\n' 'Requires macOS with Apple Command Line Tools on a normal user account.' >&2
  exit 78
fi

ROOT="$(cd -P -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"

if ! command -v xcodebuild >/dev/null 2>&1; then
  printf '%s\n' 'xcodebuild not found. Install Apple Command Line Tools via: xcode-select --install' >&2
  exit 78
fi

TARGET_MODE="device"
INSTALL_ON_DEVICE=0
for arg in "$@"; do
  case "$arg" in
    --simulator) TARGET_MODE="simulator" ;;
    --device) TARGET_MODE="device" ;;
    --install) TARGET_MODE="device"; INSTALL_ON_DEVICE=1 ;;
  esac
done

mkdir -p "$ROOT/Local-build"
WORK=$(mktemp -d "$ROOT/Local-build/iOS.XXXXXX")
trap 'rm -rf "$WORK"' EXIT

printf '\n%s\n' "=========================================================="
printf '%s\n'   "  KL-06 Mobile (iOS) — Terminal Command Line Builder"
printf '%s\n'   "  Mode: $TARGET_MODE (No Xcode GUI required)"
printf '%s\n\n' "=========================================================="

if [ "$TARGET_MODE" = "simulator" ]; then
  printf '%s\n' "Building for iOS Simulator (Debug)..."
  xcodebuild -project "$ROOT/KL06Mobile.xcodeproj" \
    -scheme KL06Mobile \
    -configuration Debug \
    -sdk iphonesimulator \
    -destination 'generic/platform=iOS Simulator' \
    -derivedDataPath "$WORK/DerivedData" \
    CODE_SIGNING_ALLOWED=NO \
    CODE_SIGNING_REQUIRED=NO \
    CODE_SIGN_IDENTITY="" \
    build 2>&1 | tee "$WORK/BUILD.log"

  BUILT_APP=$(find "$WORK/DerivedData" -name "KL06Mobile.app" -type d | head -n 1)
  if [ -n "$BUILT_APP" ]; then
    rm -rf "$ROOT/Local-build/KL06Mobile-Simulator.app"
    cp -R "$BUILT_APP" "$ROOT/Local-build/KL06Mobile-Simulator.app"
    printf '\n%s\n' "SUCCESS: Simulator app built at: $ROOT/Local-build/KL06Mobile-Simulator.app"
  fi

else
  printf '%s\n' "Building for Physical iPhone (Release arm64)..."
  xcodebuild -project "$ROOT/KL06Mobile.xcodeproj" \
    -scheme KL06Mobile \
    -configuration Release \
    -sdk iphoneos \
    -destination 'generic/platform=iOS' \
    -derivedDataPath "$WORK/DerivedData" \
    CODE_SIGNING_ALLOWED=NO \
    CODE_SIGNING_REQUIRED=NO \
    CODE_SIGN_IDENTITY="" \
    build 2>&1 | tee "$WORK/BUILD.log"

  BUILT_APP=$(find "$WORK/DerivedData" -name "KL06Mobile.app" -type d | head -n 1)
  if [ -z "$BUILT_APP" ]; then
    printf '%s\n' "Error: KL06Mobile.app not found in build products." >&2
    exit 1
  fi

  rm -rf "$ROOT/Local-build/KL06Mobile.app" "$ROOT/Local-build/KL06Mobile.ipa"
  cp -R "$BUILT_APP" "$ROOT/Local-build/KL06Mobile.app"

  # Packaging into .ipa (Payload folder archive)
  printf '%s\n' "Packaging standalone KL06Mobile.ipa..."
  mkdir -p "$WORK/Payload"
  cp -R "$BUILT_APP" "$WORK/Payload/"
  (cd "$WORK" && /usr/bin/zip -q -r "$ROOT/Local-build/KL06Mobile.ipa" Payload)

  printf '\n%s\n' "=========================================================="
  printf '%s\n'   "  BUILD COMPLETE!"
  printf '%s\n'   "  App Bundle: $ROOT/Local-build/KL06Mobile.app"
  printf '%s\n'   "  IPA File:   $ROOT/Local-build/KL06Mobile.ipa"
  printf '%s\n'   "=========================================================="

  # Check for Apple Development identity in Keychain
  DEV_ID=$(security find-identity -p codesigning -v 2>/dev/null | grep "Apple Development" | head -n 1 | awk -F'"' '{print $2}' || true)
  if [ -n "$DEV_ID" ]; then
    printf '\n%s\n' "Detected Apple Developer Identity: $DEV_ID"
    codesign --force --sign "$DEV_ID" --timestamp=none "$ROOT/Local-build/KL06Mobile.app" 2>/dev/null || true
    printf '%s\n' "Ad-hoc/Development signature applied to KL06Mobile.app."
  fi

  if [ "$INSTALL_ON_DEVICE" -eq 1 ]; then
    if xcrun devicectl help >/dev/null 2>&1; then
      printf '\n%s\n' "Checking connected devices via xcrun devicectl..."
      xcrun devicectl list devices || true
      printf '\n%s\n' "To install, run:"
      printf '%s\n' "xcrun devicectl device install app --device <YOUR_DEVICE_UUID> \"$ROOT/Local-build/KL06Mobile.app\""
    elif command -v ideviceinstaller >/dev/null 2>&1; then
      printf '\n%s\n' "Installing via ideviceinstaller..."
      ideviceinstaller -i "$ROOT/Local-build/KL06Mobile.ipa" || true
    fi
  fi

  printf '\n%s\n' "HOW TO INSTALL ON YOUR PHYSICAL IPHONE (No Xcode GUI needed):"
  printf '%s\n' "Option 1 (Easiest - Free): Open Sideloadly or AltServer on your Mac/PC,"
  printf '%s\n' "         drag and drop \"$ROOT/Local-build/KL06Mobile.ipa\","
  printf '%s\n' "         enter your Apple ID, and it will install directly to your iPhone."
  printf '%s\n' "Option 2 (Terminal CLI): If ideviceinstaller is installed (brew install ideviceinstaller):"
  printf '%s\n' "         ideviceinstaller -i \"$ROOT/Local-build/KL06Mobile.ipa\""
  printf '%s\n' "Option 3 (TrollStore): If your iOS supports TrollStore, simply AirDrop or share"
  printf '%s\n' "         KL06Mobile.ipa to your iPhone and tap Install in TrollStore."
  printf '%s\n\n' "On iPhone: Go to Settings > General > VPN & Device Management > Trust Developer."
fi
