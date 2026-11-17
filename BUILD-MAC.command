#!/bin/bash
# Local build only. No install, download, sudo, host tuning, EFI or firmware access.
set -eu
set -o pipefail
export PATH=/usr/bin:/bin:/usr/sbin:/sbin
if [ "${1:-}" = --help ]; then
  printf '%s\n' 'Builds an x86_64 macOS 13+ KL-06.app using installed Apple Xcode tools.' 'Writes only a new Local-build folder beside this script. Does not launch/install the app.'
  exit 0
fi
if [ "$(/usr/bin/uname -s)" != Darwin ]; then
  printf '%s\n' 'This is macOS source. Build on your x86_64 Hackintosh with Xcode installed; no binary was produced.' >&2
  exit 78
fi
if [ "$(/usr/bin/id -u)" -eq 0 ]; then printf '%s\n' 'Run as your normal user, not with sudo.' >&2; exit 78; fi
if [ "$(/usr/bin/uname -m)" != x86_64 ]; then printf '%s\n' 'This build targets x86_64 macOS 13+ candidates. Per-device testing is still required.' >&2; exit 78; fi
OS_MAJOR=$(/usr/bin/sw_vers -productVersion | /usr/bin/awk -F. '{print $1}')
case "$OS_MAJOR" in ''|*[!0-9]*) printf '%s\n' 'Cannot determine macOS version.' >&2; exit 78 ;; esac
if [ "$OS_MAJOR" -lt 13 ]; then printf '%s\n' 'KL-06 app build requires macOS 13 or newer. The standalone report still works without the app.' >&2; exit 78; fi
ROOT="$(cd -P -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
if ! COMPILER="$(/usr/bin/xcrun --sdk macosx --find swiftc 2>/dev/null)"; then
  printf '%s\n' 'Apple Swift compiler not available. Select your installed Xcode in Xcode Settings > Locations > Command Line Tools, then try again. Nothing was installed.' >&2; exit 78
fi
SDK="$(/usr/bin/xcrun --sdk macosx --show-sdk-path)"
/bin/mkdir -p "$ROOT/Local-build"
WORK="$(/usr/bin/mktemp -d "$ROOT/Local-build/Build.XXXXXX")"
APP="$WORK/KL-06.app"
/bin/mkdir -p "$APP/Contents/MacOS" "$APP/Contents/Resources"
printf '%s\n' 'Building KL-06 locally. First build may take a minute…'
"$COMPILER" -swift-version 5 -O -target x86_64-apple-macosx13.0 -sdk "$SDK" \
  -module-cache-path "$WORK/ModuleCache" \
  "$ROOT/Sources/Core.swift" "$ROOT/Sources/HotKey.swift" "$ROOT/Sources/main.swift" \
  -framework AppKit -framework Carbon -framework WebKit -framework IOKit -framework Metal -framework CoreAudio \
  -o "$APP/Contents/MacOS/KL-06" 2>&1 | /usr/bin/tee "$WORK/BUILD.log"
/bin/cp "$ROOT/Info.plist" "$APP/Contents/Info.plist"
for name in index.html style.css model.js app.js icon.svg AppIcon.icns; do
  /bin/cp "$ROOT/Resources/$name" "$APP/Contents/Resources/$name"
done
/usr/bin/plutil -lint "$APP/Contents/Info.plist"
/usr/bin/codesign --force --sign - --timestamp=none "$APP"
/usr/bin/codesign --verify --deep --strict "$APP"
printf '\n%s\n%s\n%s\n' 'Built and locally ad-hoc signed:' "$APP" 'No setting was changed. Open the app in Finder to start; move it to ~/Applications only if you choose.'
/usr/bin/open -R "$APP"
