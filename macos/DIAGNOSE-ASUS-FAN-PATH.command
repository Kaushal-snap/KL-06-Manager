#!/bin/bash
# Read-only ASUS/SMC fan-path inventory for native Intel Hackintosh.
# No sudo, writes, kext installation, firmware calls or fan-control operations.
set -eu
set -o pipefail
export PATH=/usr/bin:/bin:/usr/sbin:/sbin
if [ "$(uname -s)" != Darwin ] || [ "$(uname -m)" != x86_64 ]; then
  printf '%s\n' 'Run on the native Intel ASUS Hackintosh.' >&2
  exit 78
fi
umask 077
BASE="$HOME"
if [ -d "$HOME/Desktop" ] && [ ! -L "$HOME/Desktop" ]; then BASE="$HOME/Desktop"; fi
OUT=$(/usr/bin/mktemp -d "$BASE/KL06-ASUS-Fan-Diagnostic.XXXXXX")
REPORT="$OUT/ASUS-FAN-PATH.txt"
{
  printf '%s\n' 'KL-06 ASUS FAN PATH DIAGNOSTIC' 'Read-only inventory only; no hardware settings changed.'
  printf '\n%s\n' '--- macOS / CPU ---'
  /usr/bin/sw_vers
  /usr/bin/uname -m
  /usr/sbin/sysctl -n machdep.cpu.brand_string 2>/dev/null || true
  printf '\n%s\n' '--- loaded relevant kernel extensions ---'
  /usr/bin/kmutil showloaded 2>/dev/null | /usr/bin/grep -Ei 'VirtualSMC|AsusFanControl|AsusSMC|Lilu|SMCSuperIO' || true
  printf '\n%s\n' '--- IOService fan / SMC / ASUS / ACPI candidates ---'
  /usr/sbin/ioreg -p IOService -l -w0 2>/dev/null | /usr/bin/grep -Ei 'AppleSMC|VirtualSMC|AsusFanControl|AsusSMC|ATKD|PNP0C14|ATK0100|WMNB' || true
  printf '\n%s\n' '--- IOACPIPlane ASUS / WMI candidates ---'
  /usr/sbin/ioreg -p IOACPIPlane -l -w0 2>/dev/null | /usr/bin/grep -Ei 'ATKD|PNP0C14|ATK0100|WMNB|ASUS' || true
  printf '\n%s\n' '--- notes ---'
  printf '%s\n' 'No matching line is not proof that the hardware is absent; ACPI naming and driver exposure vary.'
  printf '%s\n' 'This report contains no serial-number or full IORegistry dump.'
} > "$REPORT"
printf '%s\n' 'Diagnostic saved in:' "$REPORT"
printf '%s\n' 'Open the TXT file and send its contents for the K513EA fan-path diagnosis.'
