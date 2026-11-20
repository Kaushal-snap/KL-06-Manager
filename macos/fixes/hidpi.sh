#!/bin/bash
# HiDPI (Retina-like scaling) for the internal 1920x1080 OLED. Usage: bash hidpi.sh [install|rollback|status]
OV=/Library/Displays/Contents/Resources/Overrides
find_ids() {
  V=$(ioreg -lw0 | grep -m1 '"DisplayVendorID"' | sed 's/.*= *//')
  P=$(ioreg -lw0 | grep -m1 '"DisplayProductID"' | sed 's/.*= *//')
  if [ -z "$V" ] || [ -z "$P" ]; then
    E=$(ioreg -lw0 | grep -m1 '"IODisplayEDID"' | sed 's/.*<//; s/>.*//')
    if [ ${#E} -ge 24 ]; then
      V=$((16#${E:16:4}))
      P=$((16#${E:22:2}${E:20:2}))
    fi
  fi
  [ -n "$V" ] && [ -n "$P" ] || { echo "Display ID nahi mili. Ye output bhejo: ioreg -lw0 | grep -E 'DisplayVendorID|DisplayProductID|IODisplayEDID'"; exit 1; }
  VH=$(printf "%x" "$V"); PH=$(printf "%x" "$P")
  DIR="$OV/DisplayVendorID-$VH"; FILE="$DIR/DisplayProductID-$PH"
}
mk() { printf "%08x%08x%08x%08x" "$1" "$2" 1 2097152 | xxd -r -p | base64; }
case "${1:-install}" in
status) find_ids; echo "Vendor $V ($VH) Product $P ($PH)"; ls -la "$FILE" 2>&1;;
rollback)
  find_ids
  if [ -f "$FILE.bak" ]; then sudo mv "$FILE.bak" "$FILE"; else sudo rm -f "$FILE"; fi
  echo "ROLLBACK OK. Restart karo."; exit 0;;
install)
  find_ids
  sudo mkdir -p "$DIR"
  [ -f "$FILE" ] && [ ! -f "$FILE.bak" ] && sudo cp "$FILE" "$FILE.bak"
  T=$(mktemp)
  {
    echo '<?xml version="1.0" encoding="UTF-8"?>'
    echo '<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">'
    echo '<plist version="1.0"><dict>'
    echo "<key>DisplayProductID</key><integer>$P</integer>"
    echo "<key>DisplayVendorID</key><integer>$V</integer>"
    echo '<key>scale-resolutions</key><array>'
    for m in "2048 1152" "2560 1440" "2880 1620" "3200 1800"; do
      set -- $m; echo "<data>$(mk $1 $2)</data>"
    done
    echo '</array></dict></plist>'
  } > "$T"
  plutil -lint "$T" || exit 1
  sudo cp "$T" "$FILE"; sudo chown root:wheel "$FILE"; sudo chmod 644 "$FILE"; rm -f "$T"
  echo "INSTALL OK: $FILE"
  echo "Ab restart karo. Phir System Settings > Displays me 1280x720 / 1440x810 / 1600x900 (HiDPI) option chuno.";;
esac
