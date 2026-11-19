#!/bin/bash
# Native compile/logic tests. Fake preferences, synthetic SMC transport; no real sensor read.
set -eu
set -o pipefail
export PATH=/usr/bin:/bin:/usr/sbin:/sbin
if [ "$(uname -s)" != Darwin ] || [ "$(uname -m)" != x86_64 ]; then printf '%s\n' 'Native tests need Intel macOS and installed Apple tools. Not run on this platform.' >&2; exit 78; fi
if [ "$(id -u)" -eq 0 ]; then printf '%s\n' 'Run without sudo.' >&2; exit 78; fi
OS_MAJOR=$(/usr/bin/sw_vers -productVersion | /usr/bin/awk -F. '{print $1}')
case "$OS_MAJOR" in ''|*[!0-9]*) exit 78;; esac
if [ "$OS_MAJOR" -lt 13 ] || [ "$OS_MAJOR" -ge 27 ]; then printf '%s\n' 'macOS 13–26 API target; 26 untested, 27+ blocked.' >&2; exit 78; fi
ROOT="$(cd -P -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
SDK=$(/usr/bin/xcrun --sdk macosx --show-sdk-path)
/bin/mkdir -p "$ROOT/Local-build"
WORK=$(/usr/bin/mktemp -d "$ROOT/Local-build/Test.XXXXXX")
/usr/bin/xcrun --sdk macosx clang -std=c11 -O2 -target x86_64-apple-macosx13.0 -isysroot "$SDK" -I"$ROOT/Sources" -c "$ROOT/Sources/SMCReader.c" -o "$WORK/SMCReader.o"
/usr/bin/xcrun --sdk macosx swiftc -swift-version 5 -target x86_64-apple-macosx13.0 -sdk "$SDK" -module-cache-path "$WORK/ModuleCache" \
  -import-objc-header "$ROOT/Sources/SMCReader.h" "$WORK/SMCReader.o" \
  "$ROOT/Sources/Core.swift" "$ROOT/Sources/FanMonitor.swift" "$ROOT/Sources/HotKey.swift" "$ROOT/Sources/DesktopCompanion.swift" "$ROOT/tests/mac/main.swift" \
  -framework AppKit -framework Carbon -framework IOKit -framework Metal -framework CoreAudio -o "$WORK/NativeTests" 2>&1 | /usr/bin/tee "$WORK/TEST-BUILD.log"
/usr/bin/xcrun --sdk macosx clang -std=c11 -O2 -DKL06_SMC_TEST -I"$ROOT/Sources" "$ROOT/Sources/SMCReader.c" "$ROOT/tests/smc/test_smc.c" -framework IOKit -framework CoreFoundation -o "$WORK/SMCTests"
"$WORK/SMCTests" 2>&1 | /usr/bin/tee "$WORK/SMC-TEST-RESULTS.log"
"$WORK/NativeTests" 2>&1 | /usr/bin/tee "$WORK/TEST-RESULTS.log"
printf '%s\n' 'Logic/compile checks complete. No real desktop preferences, SMC values, global shortcut or power sampler was accessed by these tests.'
