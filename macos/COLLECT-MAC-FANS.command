#!/bin/bash
# Targeted read-only existing-SMC fan check. Does not install or write hardware.
set -eu
set -o pipefail
export PATH=/usr/bin:/bin:/usr/sbin:/sbin
umask 077
if [ "${1:-}" = --help ]; then printf '%s\n' 'On your Intel Mac: /bin/bash COLLECT-MAC-FANS.command' 'Compiles a tiny local read-only helper using installed Apple tools. No sudo/download/driver/EFI changes.'; exit 0; fi
if [ "$(uname -s)" != Darwin ] || [ "$(uname -m)" != x86_64 ]; then printf '%s\n' 'Requires x86_64 macOS + installed Xcode/Command Line Tools. No native query was run.' >&2; exit 78; fi
if [ "$(id -u)" -eq 0 ]; then printf '%s\n' 'Run as your normal user, without sudo. Permission errors are useful diagnostic results.' >&2; exit 78; fi
MAJOR=$(/usr/bin/sw_vers -productVersion | /usr/bin/awk -F. '{print $1}')
case "$MAJOR" in ''|*[!0-9]*) exit 78;; esac
if [ "$MAJOR" -lt 13 ] || [ "$MAJOR" -ge 27 ]; then printf '%s\n' 'This candidate targets macOS 13–26 APIs; 26 is untested, 27+ blocked.' >&2; exit 78; fi
ROOT="$(cd -P -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
BASE="$HOME"; if [ -d "$HOME/Desktop" ] && [ ! -L "$HOME/Desktop" ]; then BASE="$HOME/Desktop"; fi
DEST=$(/usr/bin/mktemp -d "$BASE/KL-06-Fans.XXXXXX")
WORK=$(/usr/bin/mktemp -d "${TMPDIR:-/tmp}/KL06-Fan-Build.XXXXXX")
cleanup() { /bin/rm -rf -- "$WORK"; }
trap cleanup EXIT
if ! /usr/bin/xcrun --sdk macosx clang -std=c11 -O2 -target x86_64-apple-macosx13.0 \
  -I"$ROOT/Sources" "$ROOT/Sources/SMCReader.c" "$ROOT/tools/fan-reader/main.c" \
  -framework IOKit -framework CoreFoundation -o "$WORK/fan-read" >/dev/null 2>&1; then
  printf '%s\n' '{"schema":"KL06_MAC_FAN_READ_V1","status":"compiler-unavailable-or-build-failed","reported_at_utc":null,"sample_age_seconds":null,"query_duration_seconds":null,"fans":[],"hardware_writes":false,"privilege_requested":false}' > "$DEST/FAN-READINGS.json"
else
  "$WORK/fan-read" > "$DEST/FAN-READINGS.json"
fi
{ printf '%s\n' 'BEGIN KL06_MAC_FAN_READ_V1'; /bin/cat "$DEST/FAN-READINGS.json"; printf '%s\n' 'END KL06_MAC_FAN_READ_V1'; } > "$DEST/FAN-READINGS.txt"
printf '%s\n' 'Fan report written to a new private folder:' "$DEST" 'Share only reviewed FAN-READINGS.json or .txt. Missing readings do not prove a missing/broken fan. No sudo, driver or setting change.'
