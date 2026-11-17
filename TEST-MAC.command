#!/bin/bash
# Native compile/logic checks. Uses fake preferences + a temporary local journal.
set -eu
set -o pipefail
export PATH=/usr/bin:/bin:/usr/sbin:/sbin
if [ "$(/usr/bin/uname -s)" != Darwin ]; then printf '%s\n' 'Native tests require macOS + installed Xcode; not run here.' >&2; exit 78; fi
if [ "$(/usr/bin/id -u)" -eq 0 ]; then printf '%s\n' 'Do not run these tests with sudo.' >&2; exit 78; fi
if [ "$(/usr/bin/uname -m)" != x86_64 ]; then printf '%s\n' 'This test build targets x86_64 macOS 13+; other architectures are not approved.' >&2; exit 78; fi
OS_MAJOR=$(/usr/bin/sw_vers -productVersion | /usr/bin/awk -F. '{print $1}')
case "$OS_MAJOR" in ''|*[!0-9]*) printf '%s\n' 'Cannot determine macOS version.' >&2; exit 78 ;; esac
if [ "$OS_MAJOR" -lt 13 ]; then printf '%s\n' 'KL-06 app build requires macOS 13 or newer. The standalone report still works without the app.' >&2; exit 78; fi
ROOT="$(cd -P -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
SDK="$(/usr/bin/xcrun --sdk macosx --show-sdk-path)"
/bin/mkdir -p "$ROOT/Local-build"
WORK="$(/usr/bin/mktemp -d "$ROOT/Local-build/Test.XXXXXX")"
/usr/bin/xcrun --sdk macosx swiftc -swift-version 5 -target x86_64-apple-macosx13.0 -sdk "$SDK" -module-cache-path "$WORK/ModuleCache" \
  "$ROOT/Sources/Core.swift" "$ROOT/Sources/HotKey.swift" "$ROOT/tests/mac/main.swift" \
  -framework AppKit -framework Carbon -framework IOKit -framework Metal -framework CoreAudio -o "$WORK/NativeTests" 2>&1 | /usr/bin/tee "$WORK/TEST-BUILD.log"
"$WORK/NativeTests" 2>&1 | /usr/bin/tee "$WORK/TEST-RESULTS.log"
printf '%s\n' 'These tests did not write real desktop preferences or sample real power.'
