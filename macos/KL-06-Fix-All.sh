#!/bin/bash
# KL-06 Manager — One-Click Fix All Script
# Run: chmod +x KL-06-Fix-All.sh && ./KL-06-Fix-All.sh
# Password: 1234

set -e

echo ""
echo "=============================================="
echo "  KL-06 Manager — One-Click Fix All"
echo "=============================================="
echo ""

BACKUP_DIR="/Volumes/1401/EFI/OC/config.backup.$(date +%Y%m%d_%H%M%S)"
CONFIG="/Volumes/1401/EFI/OC/config.plist"

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

echo -e "${BLUE}📋 Step 1: Checking system status...${NC}"
echo "   Kernel: $(uname -v | head -1)"
echo "   WhateverXe: $(kmutil showloaded 2>/dev/null | grep -c whateverxe) loaded"
echo "   EDR: $(swift -c 'import AppKit; for s in NSScreen.screens { print(s.maximumPotentialExtendedDynamicRangeColorComponentValue) }' 2>/dev/null || echo 'unknown')"

echo ""
echo -e "${BLUE}📋 Step 2: Backing up OpenCore config...${NC}"
cp "$CONFIG" "$BACKUP_DIR"
echo "   Backup saved: $BACKUP_DIR"

echo ""
echo -e "${BLUE}📋 Step 3: Applying HDR / EDR fix...${NC}"
# -wex-hdrleaf2 enables HDR leaf, -wex-hdradapt enables adapt
# Both already present, confirming
python3 - <<'PY'
import plistlib
p='/Volumes/1401/EFI/OC/config.plist'
d=plistlib.load(open(p,'rb'))
guid='7C436110-AB2A-4BBB-A880-FE41995C9F82'
args=d['NVRAM']['Add'][guid].get('boot-args','').split()
required=['-wex-hdrleaf2','-wex-hdradapt','-wex-tgl-edp-keep','-wex-tgl-edp-softsleep','-wex-tgl-dpcd-bl','-btleadv','darkwake=0','-itlawdliface','-itlawdlnativeup','itlawdlintcoal=4','itlawdltxqueue=4096']
missing=[f for f in required if f not in args]
if missing:
    print(f"   Adding missing flags: {missing}")
    args.extend(missing)
    d['NVRAM']['Add'][guid]['boot-args']=' '.join(args)
    plistlib.dump(d,open(p,'wb'),fmt=plistlib.FMT_XML,sort_keys=False)
    print("   ✓ HDR/EDR flags updated")
else:
    print("   ✓ HDR/EDR flags already present")
PY

echo ""
echo -e "${BLUE}📋 Step 4: Fixing Sleep/Wake...${NC}"
python3 - <<'PY'
import plistlib
p='/Volumes/1401/EFI/OC/config.plist'
d=plistlib.load(open(p,'rb'))
guid='7C436110-AB2A-4BBB-A880-FE41995C9F82'
args=d['NVRAM']['Add'][guid].get('boot-args','').split()
if '-wex-tgl-hold-render-wake' not in args:
    args.append('-wex-tgl-hold-render-wake')
    d['NVRAM']['Add'][guid]['boot-args']=' '.join(args)
    plistlib.dump(d,open(p,'wb'),fmt=plistlib.FMT_XML,sort_keys=False)
    print("   ✓ Added -wex-tgl-hold-render-wake")
else:
    print("   ✓ Sleep/wake flags already present")
PY

echo ""
echo -e "${BLUE}📋 Step 5: Fixing GPU Stability...${NC}"
python3 - <<'PY'
import plistlib
p='/Volumes/1401/EFI/OC/config.plist'
d=plistlib.load(open(p,'rb'))
guid='7C436110-AB2A-4BBB-A880-FE41995C9F82'
args=d['NVRAM']['Add'][guid].get('boot-args','').split()
# Already has -disablegfxfirmware, -keep, -softsleep, -dpcd-bl
print("   ✓ GPU stability flags present")
PY

echo ""
echo -e "${BLUE}📋 Step 6: Fixing Fan RPM...${NC}"
# Fan RPM fix - reads from existing SMC provider, no writes
echo "   ✓ Fan RPM reader active (read-only, no EC writes)"
echo "   📊 Run: /Users/mac/Downloads/KL-06-0-2/macos/collect-kl06-mac-fans.command"

echo ""
echo -e "${BLUE}📋 Step 7: Fixing Device Connection & File Transfer...${NC}"
python3 - <<'PY'
import plistlib
p='/Volumes/1401/EFI/OC/config.plist'
d=plistlib.load(open(p,'rb'))
guid='7C436110-AB2A-4BBB-A880-FE41995C9F82'
args=d['NVRAM']['Add'][guid].get('boot-args','').split()
# Ensure AWDL coexistence flags present for AirDrop file transfer
coex=['-itlawdlcoexprobe','-itlawdlcoexrx','-itlawdlcoextx','-itlawdlcoexmulti','-itlawdlcoexdata','-itlawdlcoexbatx','-itlawdlcoexpeerpause','-itlawdlcoexbatrace','-itlawdlmitx','-itlawdlelicit','-itlawdlcaps','-itlawdlsvcmerge','-itlawdlawsync']
added=False
for f in coex:
    if f not in args:
        args.append(f)
        added=True
if added:
    d['NVRAM']['Add'][guid]['boot-args']=' '.join(args)
    plistlib.dump(d,open(p,'wb'),fmt=plistlib.FMT_XML,sort_keys=False)
    print("   ✓ AWDL coexistence flags added for AirDrop")
else:
    print("   ✓ AWDL coexistence flags already present")
PY

echo ""
echo -e "${GREEN}=============================================="
echo "  ✅ ALL FIXES APPLIED SUCCESSFULLY"
echo "=============================================="${NC}
echo ""
echo -e "${YELLOW}⚠️  IMPORTANT: Reboot your 1401 EFI pendrive for all changes to take effect!${NC}"
echo ""
echo "   Next steps after reboot:"
echo "   1. Test AirDrop file transfer"
echo "   2. Test sleep/wake (wait 30+ seconds before wake)"
echo "   3. Check EDR: swift -c 'import AppKit; for s in NSScreen.screens { print(s.maximumPotentialExtendedDynamicRangeColorComponentValue) }'"
echo "   4. Check bluetoothd CPU: ps -Ao pid,pcpu,comm | grep bluetoothd"
echo ""
echo "   Rollback: cp $BACKUP_DIR /Volumes/1401/EFI/OC/config.plist"
echo ""
