#!/bin/bash
# 1-Click iOS Physical Device (iPhone 14 Pro Max) Builder & Installer
set -eu
set -o pipefail
export PATH=/usr/bin:/bin:/usr/sbin:/sbin

ROOT="$(cd -P -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
DEVICE_ID="AD7FB167-56E0-524F-91E4-69437183D84D"

printf '\n%s\n' "=========================================================="
printf '%s\n'   "  KL-06 Mobile (iOS) — Physical iPhone 14 Pro Max Build"
printf '%s\n'   "  Target Device: Kaushal’s iPhone ($DEVICE_ID)"
printf '%s\n'   "=========================================================="

rm -rf "$ROOT/ios/Local-build"
mkdir -p "$ROOT/ios/Local-build"

printf '\n%s\n' "Compiling Release arm64 for physical iPhone..."
xcodebuild -project "$ROOT/ios/KL06Mobile.xcodeproj" \
  -scheme KL06Mobile \
  -configuration Release \
  -sdk iphoneos \
  -destination "id=$DEVICE_ID" \
  SYMROOT="$ROOT/ios/Local-build/Products" \
  CODE_SIGNING_ALLOWED=NO \
  CODE_SIGNING_REQUIRED=NO \
  CODE_SIGN_IDENTITY="" \
  build 2>&1 | tee "$ROOT/ios/Local-build/BUILD-IOS.log"

APP_PATH="$ROOT/ios/Local-build/Products/Release-iphoneos/KL06Mobile.app"
if [ ! -d "$APP_PATH" ]; then
  printf '\n%s\n' "Error: KL06Mobile.app was not built." >&2
  exit 1
fi

printf '\n%s\n' "Packaging standalone KL06Mobile.ipa..."
mkdir -p "$ROOT/ios/Local-build/Payload"
cp -R "$APP_PATH" "$ROOT/ios/Local-build/Payload/"
(cd "$ROOT/ios/Local-build" && /usr/bin/zip -q -r "$ROOT/ios/Local-build/KL06Mobile.ipa" Payload)

printf '\n%s\n' "=========================================================="
printf '%s\n'   "  BUILD SUCCESSFUL!"
printf '%s\n'   "  App Bundle: $APP_PATH"
printf '%s\n'   "  IPA File:   $ROOT/ios/Local-build/KL06Mobile.ipa"
printf '%s\n'   "=========================================================="

# Check for Apple Development certificate in Keychain
DEV_ID=$(security find-identity -p codesigning -v 2>/dev/null | grep "Apple Development" | head -n 1 | awk -F'"' '{print $2}' || true)

if [ -n "$DEV_ID" ]; then
  printf '\n%s\n' "Found Apple Development Identity: $DEV_ID"
  codesign --force --sign "$DEV_ID" --timestamp=none "$APP_PATH" 2>/dev/null || true
  printf '%s\n' "Installing to Kaushal’s iPhone via devicectl..."
  xcrun devicectl device install app --device "$DEVICE_ID" "$APP_PATH" || true
else
  printf '\n%s\n' "No Apple Developer Certificate found in Mac Keychain."
  printf '%s\n' "To install on your iPhone in 30 seconds (Free):"
  printf '%s\n' "1. Open Sideloadly (sideloadly.io) on your Mac"
  printf '%s\n' "2. Drag and drop: $ROOT/ios/Local-build/KL06Mobile.ipa"
  printf '%s\n' "3. Enter your free Apple ID and click Start!"
fi

printf '\n%s\n' "Note: On iPhone, ensure Developer Mode is ON:"
printf '%s\n\n' "Settings -> Privacy & Security -> Developer Mode -> Turn ON"
