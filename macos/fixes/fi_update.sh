#!/bin/bash
# ForbiddenItlwm 0.6.0-beta.1 (Sequoia) + BTLEAdvFixup 0.9.2 updater. Usage: bash fi_update.sh [install|rollback]
DIR="$(cd "$(dirname "$0")" && pwd)"; bash "$DIR/k513ea_guard.sh" || exit 1
EFI="${EFI:-/Volumes/1401/EFI/OC}"
V=0.6.0-beta.1
U="https://github.com/retropineaple/ForbiddenItlwm/releases/download/v$V"
W="$HOME/fi_update"
PB=/usr/libexec/PlistBuddy
K=":NVRAM:Add:7C436110-AB2A-4BBB-A880-FE41995C9F82:boot-args"
FLAGS="-btleadv -itlawdlcoexprobe -itlawdliface -itlawdlnativeup -itlawdlcoexrx -itlawdlcoextx -itlawdlcoexmulti -itlawdlcoexdata -itlawdlmitx -itlawdlelicit -itlawdlcaps -itlawdlsvcmerge -itlawdlawsync itlawdlintcoal=4 -itlawdlcoexbatx -itlawdlcoexpeerpause itlawdltxqueue=4096"
[ -d "$EFI/Kexts" ] || { echo "EFI nahi mila: $EFI (pendrive lagao)"; exit 1; }
show(){ $PB -c "Print $K" "$EFI/config.plist" | sed 's/serial[^ ]*//'; }
if [ "$1" = rollback ]; then
  B=$(ls -d "$HOME"/efi_backup/fi_* 2>/dev/null | tail -1); [ -n "$B" ] || { echo "backup nahi mila"; exit 1; }
  for k in ForbiddenItlwm BTLEAdvFixup; do rm -rf "$EFI/Kexts/$k.kext"; ditto "$B/$k.kext" "$EFI/Kexts/$k.kext"; done
  cp "$B/config.plist" "$EFI/config.plist"; echo "ROLLBACK OK from $B. Ab restart karo."; exit 0
fi
set -e
B="$HOME/efi_backup/fi_$(date +%Y%m%d_%H%M%S)"; mkdir -p "$B" "$W"
for k in ForbiddenItlwm BTLEAdvFixup; do [ -d "$EFI/Kexts/$k.kext" ] || { echo "$k.kext EFI me nahi hai"; exit 1; }; ditto "$EFI/Kexts/$k.kext" "$B/$k.kext"; done
cp "$EFI/config.plist" "$B/config.plist"
rm -rf "$W"/*; cd "$W"
curl -fL -o fi.zip "$U/ForbiddenItlwm-$V-Sequoia.zip"
curl -fL -o bt.zip "$U/BTLEAdvFixup-0.9.2-Sequoia.zip"
mkdir fi bt; unzip -oq fi.zip -d fi; unzip -oq bt.zip -d bt
FK=$(find fi -name ForbiddenItlwm.kext -maxdepth 4 | head -1); BKX=$(find bt -name BTLEAdvFixup.kext -maxdepth 4 | head -1)
[ -n "$FK" ] && [ -n "$BKX" ] || { echo "zip me kext nahi mila"; ls -R fi bt; exit 1; }
for p in "$FK:ForbiddenItlwm" "$BKX:BTLEAdvFixup"; do
  src=${p%%:*}; n=${p##*:}; rm -rf "$EFI/Kexts/$n.kext"; ditto "$src" "$EFI/Kexts/$n.kext"
  echo "$n -> $($PB -c 'Print :CFBundleVersion' "$EFI/Kexts/$n.kext/Contents/Info.plist")"
  [ -x "$EFI/Kexts/$n.kext/Contents/MacOS/$n" ] || echo "WARNING: $n executable path alag hai, config.plist ExecutablePath check karo"
done
BA=$($PB -c "Print $K" "$EFI/config.plist")
for f in $FLAGS; do case " $BA " in *" $f "*) ;; *) BA="$BA $f";; esac; done
$PB -c "Set $K '$BA'" "$EFI/config.plist"
show; echo "INSTALL OK. Backup: $B. Ab restart karo (pendrive se)."
