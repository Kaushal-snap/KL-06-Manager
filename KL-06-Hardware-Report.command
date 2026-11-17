#!/bin/bash
# KL-06 generic hardware report v1.1. Bash 3.2/macOS built-ins only.
# Read-only system queries. Writes only a new private report folder unless --stdout.
set -u
set -o pipefail
export PATH=/usr/bin:/bin:/usr/sbin:/sbin LC_ALL=C LANG=C
umask 077
save=1
case "${1:-}" in
  '') ;;
  --stdout) save=0 ;;
  --help) printf '%s\n' 'KL-06 hardware report v1.1: /bin/bash collect-kl06-hardware.sh [--stdout]' 'Default: a minimized REPORT.txt in a new Desktop folder (home fallback).' 'No sudo, downloads, installs, benchmarks, hardware writes or settings changes.'; exit 0 ;;
  *) printf '%s\n' 'Unknown option. Use --help.' >&2; exit 2 ;;
esac
if [ "$#" -gt 1 ]; then printf '%s\n' 'Too many arguments.' >&2; exit 2; fi
if [ "$(/usr/bin/uname -s 2>/dev/null)" != Darwin ]; then printf '%s\n' 'Run on macOS. No files or report created.' >&2; exit 78; fi
if [ "${EUID:-$(/usr/bin/id -u)}" -eq 0 ]; then printf '%s\n' 'Run without sudo, as the normal logged-in user. Nothing collected.' >&2; exit 78; fi
FILTER=''
{ IFS= read -r -d '' FILTER || :; } <<'KL06_FILTER'
function trim(s) { sub(/^[[:space:]]+/, "", s); sub(/[[:space:]]+$/, "", s); return s }
function emit(k,v) { v=trim(v); gsub(/[[:cntrl:]]/, " ", v); if(length(v)>0 && length(v)<=200) print k ": " v }
{
  line=$0; key=line; sub(/:.*/, "", key); key=trim(key)
  val=line; sub(/^[^:]*:[[:space:]]*/, "", val); val=trim(val)
  if(mode=="kexts") {
    for(i=1;i<NF;i++) {
      id=$i; ver=$(i+1); low=tolower(id)
      if(id ~ /^[A-Za-z0-9_.-]+$/ && length(id)<=150 && ver ~ /^\([0-9][A-Za-z0-9.+_-]*\)$/ && length(ver)<=45 && low ~ /(lilu|whatevergreen|whateverxe|nootedred|nootrx|amfipass|applealc|virtualsmc|smcprocessor|smcsuperio|smcbattery|smclightsensor|smcamdprocessor|amdryzencpupower|cputscsync|cpufriend|restrictevents|nvmefix|itlwm|airportbrcm|intelbluetooth|intelbtpatcher|bluetoolfixup|brcmpatchram|brcmfirmware|btleadvfixup|usbtoolbox|utbmap|utbdefault|usbmap|usbports|usbinjectall|xhci.unsupported|voodoo|brightnesskeys|asussmc|ecenabler|forgedinvariant|cryptexfixup|appleinteltgl|ioacceleratorfamily|iographicsfamily|nvenabler|webdriver|irisxe|nullmoth|zep245)/) print id " " ver
    }
  } else if(mode=="displays") {
    if(key ~ /^(Chipset Model|Type|Bus|VRAM \(Dynamic, Max\)|VRAM \(Total\)|Vendor|Device ID|Revision ID|Metal Support|Metal Family|Metal|Resolution|UI Looks like|Framebuffer Depth|Main Display|Mirror|Online|Connection Type|High Dynamic Range|HDR Support|Refresh Rate)$/) emit(key,val)
  } else if(mode=="audio") {
    if(key ~ /^(Input Channels|Output Channels|Current SampleRate)$/ && val ~ /^[0-9.]+$/) emit(key,val)
    if(key ~ /^(Default Input Device|Default Output Device|Default System Output Device)$/ && val ~ /^(Yes|No)$/) emit(key,val)
    if(key=="Transport" && val ~ /^(Built-in|USB|Bluetooth|HDMI|DisplayPort|Thunderbolt|Virtual)$/) emit(key,val)
  } else if(mode=="battery") {
    if(key ~ /^(Cycle Count|Full Charge Capacity \(mAh\)|State of Charge \(%\)|Amperage \(mA\)|Voltage \(mV\))$/ && val ~ /^-?[0-9]+$/) emit(key,val)
    if(key=="Maximum Capacity" && val ~ /^[0-9]+%$/) emit(key,val)
    if(key=="Condition" && val ~ /^(Normal|Service Recommended|Replace Soon|Replace Now|Service Battery|Check Battery)$/) emit(key,val)
    if(key ~ /^(Charging|Fully Charged)$/ && val ~ /^(Yes|No)$/) emit(key,val)
  } else if(mode=="numeric" || mode=="battery-raw") {
    k=line; sub(/^[^"]*"/, "", k); sub(/".*/, "", k)
    v=line; sub(/^.*=[[:space:]]*/, "", v); v=trim(v)
    ok=(mode=="numeric" && k ~ /^(vendor-id|device-id|revision-id|class-code|layout-id|alc-layout-id|IOHDACodecVendorID|IOHDACodecRevisionID)$/) || (mode=="battery-raw" && k ~ /^(DesignCapacity|AppleRawMaxCapacity|MaxCapacity|CycleCount)$/)
    if(ok && (v ~ /^(0x[0-9a-fA-F]+|[0-9]+)$/ || (v ~ /^<[0-9a-fA-F]+>$/ && length(v)<=18))) emit(k,v)
  } else if(mode=="power") {
    if(trim(line) ~ /^(AC Power|Battery Power|UPS Power):$/) print trim(line)
    if($1 ~ /^(sleep|displaysleep|disksleep|hibernatemode|standby|powernap|womp|tcpkeepalive|lowpowermode|powermode|gpuswitch)$/ && $2 ~ /^[0-9]+$/) print $1 "=" $2
  } else if(mode=="assertions") {
    if($1 ~ /^(BackgroundTask|UserIsActive|PreventUserIdleDisplaySleep|PreventSystemSleep|ExternalMedia|PreventUserIdleSystemSleep|NetworkClientActive)$/ && $2 ~ /^[0-9]+$/) print $1 "=" $2
  } else if(mode=="memory") {
    if(line ~ /^(Pages (free|active|inactive|wired down|occupied by compressor)|Pageouts|Swapins|Swapouts):[[:space:]]+[0-9]+\.?$/) print line
  }
}
KL06_FILTER
filter() { /usr/bin/awk -v mode="$1" "$FILTER"; }
section() { printf '\n== %s ==\n' "$1"; }
redact() {
  /usr/bin/sed -E \
    -e 's@/Users/[^/[:space:]]+@/Users/REDACTED@g' \
    -e 's/[[:xdigit:]]{8}-[[:xdigit:]]{4}-[[:xdigit:]]{4}-[[:xdigit:]]{4}-[[:xdigit:]]{12}/REDACTED-UUID/g' \
    -e 's/([[:xdigit:]]{2}:){5}[[:xdigit:]]{2}/REDACTED-MAC/g' \
    -e 's/[[:alnum:]_.%+-]+@[[:alnum:].-]+\.[[:alpha:]]{2,}/REDACTED-EMAIL/g' \
    -e 's/([0-9]{1,3}\.){3}[0-9]{1,3}/REDACTED-IP-OR-FOUR-PART-VERSION/g'
}
report() {
  printf '%s\n' 'BEGIN KL06_HW_REPORT_V1' 'Purpose: unreviewed compatibility intake, NOT hardware approval or an optimisation.'
  section 'RUNNING ENVIRONMENT'
  product=$(/usr/bin/sw_vers -productVersion 2>/dev/null || true)
  printf '%s\n' "$product" | /usr/bin/awk '/^[0-9]+\.[0-9]+(\.[0-9]+)?$/ {print "macOS: " $0}'
  /usr/bin/sw_vers -buildVersion 2>/dev/null | /usr/bin/awk '/^[0-9][A-Za-z0-9.]+$/ {print "Build: " $0}'
  /usr/bin/uname -r 2>/dev/null | /usr/bin/awk '/^[0-9]+\.[0-9]+\.[0-9]+$/ {print "Darwin: " $0}'
  arch=$(/usr/bin/uname -m 2>/dev/null || true)
  case "$arch" in x86_64|arm64|i386) printf 'Architecture: %s\n' "$arch" ;; *) printf '%s\n' 'Architecture: unavailable' ;; esac
  /usr/sbin/sysctl -n machdep.cpu.brand_string 2>/dev/null | /usr/bin/awk 'length($0)<=160 && /Intel|AMD|Apple|Virtual|QEMU/ {print "CPU reported: " $0}'
  for key in hw.physicalcpu hw.logicalcpu hw.memsize machdep.xcpm.mode; do
    /usr/sbin/sysctl -n "$key" 2>/dev/null | /usr/bin/awk -v k="$key" '/^[0-9]+$/ {print k ": " $0}'
  done
  /usr/sbin/sysctl -n hw.model 2>/dev/null | /usr/bin/awk '/^(MacBookPro|MacBookAir|MacBook|Macmini|MacPro|iMacPro|iMac|VirtualMac)[0-9]+,[0-9]+$/ {print "SMBIOS model (may be injected, NOT physical model): " $0}'
  major=${product%%.*}
  case "$major" in ''|*[!0-9]*) printf '%s\n' 'KL06_BASE_API: undetermined' ;; *)
    if [ "$major" -ge 13 ] && [ "$arch" = x86_64 ]; then printf '%s\n' 'KL06_BASE_API: x86_64/macOS13+ candidate; individual feature tests still required'
    else printf '%s\n' 'KL06_BASE_API: outside current x86_64/macOS13+ app build target; report is still useful'; fi ;;
  esac
  section 'DISPLAY / GPU (headings, display names and serials omitted)'
  /usr/sbin/system_profiler SPDisplaysDataType -detailLevel mini -timeout 25 2>/dev/null | filter displays
  printf '%s\n' 'Reported Metal/HDR text does not prove workload support or authorize enabling HDR.'
  section 'SELECTED LOADED DRIVER IDS / VERSIONS'
  loaded=$(/usr/bin/kmutil showloaded --list-only 2>/dev/null) || loaded=$(/usr/sbin/kextstat -l 2>/dev/null) || loaded=''
  selected=$(printf '%s\n' "$loaded" | filter kexts)
  if [ -n "$selected" ]; then printf '%s\n' "$selected"; else printf '%s\n' 'Unavailable/none matched; not a missing-driver diagnosis.'; fi
  printf '%s\n' 'Codeless maps may be absent here; loaded/version-labelled is not tested or binary-verified.'
  section 'REPORTED NUMERIC PCI / AUDIO FIELDS (may be spoofed/injected)'
  for node in IGPU GFX0 GFX1 PEGP HDEF HDAS XHC XHC1 XHC2; do
    props=$(/usr/sbin/ioreg -r -n "$node" -d 1 -l -w 0 2>/dev/null | filter numeric)
    if [ -n "$props" ]; then printf '[%s]\n%s\n' "$node" "$props"; fi
  done
  /usr/sbin/ioreg -r -c IOHDACodecDevice -d 1 -l -w 0 2>/dev/null | filter numeric
  section 'AUDIO ROUTE COUNTS / FORMATS (no device names)'
  /usr/sbin/system_profiler SPAudioDataType -detailLevel mini -timeout 20 2>/dev/null | filter audio
  section 'BATTERY (desktops may correctly have none)'
  /usr/sbin/system_profiler SPPowerDataType -detailLevel mini -timeout 20 2>/dev/null | filter battery
  /usr/sbin/ioreg -r -c AppleSmartBattery -d 1 -l -w 0 2>/dev/null | filter battery-raw
  printf '%s\n' 'MaxCapacity may be normalized; do not compute wear without valid same-unit capacities.'
  section 'POWER / MEMORY / FREE SPACE (no app/window/volume names)'
  /usr/bin/pmset -g custom 2>/dev/null | filter power
  /usr/bin/pmset -g assertions 2>/dev/null | filter assertions
  /usr/bin/vm_stat 2>/dev/null | filter memory
  /bin/df -Pk /System/Volumes/Data 2>/dev/null | /usr/bin/awk 'NR==2 && $2 ~ /^[0-9]+$/ && $4 ~ /^[0-9]+$/ {printf "Data_total_GiB: %.2f\nData_available_GiB: %.2f\n",$2/1048576,$4/1048576}'
  section 'SERVICE COUNTS (not function tests or port mapping)'
  for cls in X86PlatformPlugin IOAccelerator AppleUSBXHCI AppleUSBHostPort IOBluetoothHCIController VoodooI2CHIDDevice AppleBacklightDisplay; do
    if registry=$(/usr/sbin/ioreg -r -c "$cls" -d 1 -w 0 2>/dev/null); then
      count=$(printf '%s\n' "$registry" | /usr/bin/awk '/\+-o / {n++} END {print n+0}')
    else count=unavailable; fi
    printf '%s: %s\n' "$cls" "$count"
  done
  section 'OWNER TO ADD MANUALLY (no identifiers)'
  printf '%s\n' 'Physical motherboard/laptop model: NOT PROVIDED (SMBIOS is not physical evidence)' \
    'Features actually tested / working: NOT PROVIDED' 'Specific requested controls or bugs: NOT PROVIDED' \
    'If relevant: AC/battery, external display, reproduction steps. Do not add serials, MACs, credentials or recovery keys.'
  section 'LIMITS'
  printf '%s\n' 'No EFI/ESP read or mount, firmware/EC/ACPI writes, NVRAM dump, network query, raw registry/log, serial, UUID, host/account name, SSID/BSSID or paired-device list requested.' \
    'No benchmark, clock/fan/charge-limit/HDR/audio-DSP/disk optimisation or configuration change performed.' \
    'Empty/missing fields can be unsupported queries/permissions/localization, not faulty hardware.' \
    'Text filters minimise data but are not a privacy guarantee: inspect REPORT.txt before sharing.' \
    'Arena can review this report to propose capability-specific support. It does not make the app compatible with every Hackintosh.' \
    'END KL06_HW_REPORT_V1'
}
if [ "$save" -eq 0 ]; then
  report | redact
else
  if [ -d "$HOME/Desktop" ] && [ -w "$HOME/Desktop" ]; then base="$HOME/Desktop"; label=Desktop; else base="$HOME"; label='home folder'; fi
  folder=$(/usr/bin/mktemp -d "$base/KL-06-Report.XXXXXX" 2>/dev/null) || { printf '%s\n' 'Could not create private report folder; nothing collected. Try --stdout.' >&2; exit 1; }
  # Only projected/redacted output is written. Raw system command output never goes to files.
  if ! report | redact | /usr/bin/tee "$folder/REPORT.txt"; then printf '%s\n' 'Collection interrupted/incomplete. No settings were changed.' >&2; exit 1; fi
  /bin/chmod 600 "$folder/REPORT.txt" 2>/dev/null || true
  printf '\nSaved %s/REPORT.txt in your %s. Review it, then share REPORT.txt only.\n' "${folder##*/}" "$label"
fi
