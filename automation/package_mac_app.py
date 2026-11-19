#!/usr/bin/env python3
"""
package_mac_app.py: Package KL-06 Manager 0.4.7 for macOS with CodeResources, OPEN-KL06.command launcher, and Gatekeeper instructions.
"""
import os, sys, zipfile, plistlib, hashlib, time
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
OUTPUT_DIR = ROOT / "build" / "deliverables"
OUTPUT_DIR.mkdir(parents=True, exist_ok=True)
OUTPUT_ZIP = OUTPUT_DIR / "KL-06 Manager 0.4.7.zip"

BASE_ZIP = ROOT / "google_drive" / "KL-06 Manager 0.4.3.zip"
if not BASE_ZIP.exists():
    BASE_ZIP = ROOT / "google_drive" / "KL-06 Manager 0.4.5.zip"

def main():
    print(f"Reading base macOS binary from {BASE_ZIP}...")
    with zipfile.ZipFile(BASE_ZIP, "r") as z:
        binary_data = z.read("KL-06 Manager.app/Contents/MacOS/KL-06")

    # Generate CodeResources
    res_dir = ROOT / "macos" / "Resources"
    files_dict = {}
    files2_dict = {}
    resource_files = {}

    for root, dirs, files in os.walk(res_dir):
        for f in sorted(files):
            p = Path(root) / f
            rel = "Resources/" + str(p.relative_to(res_dir))
            data = p.read_bytes()
            files_dict[rel] = hashlib.sha1(data).digest()
            files2_dict[rel] = {"hash2": hashlib.sha256(data).digest()}
            resource_files[rel] = data

    # Companion server.py
    server_py = ROOT / "companion" / "server.py"
    if server_py.exists():
        rel = "Resources/Companion/server.py"
        data = server_py.read_bytes()
        files_dict[rel] = hashlib.sha1(data).digest()
        files2_dict[rel] = {"hash2": hashlib.sha256(data).digest()}
        resource_files[rel] = data

    # Fix scripts
    for fix_file in ["KL-06-Fix-All.sh", "KL-06-Fix-All.command"]:
        fp = ROOT / "macos" / fix_file
        if fp.exists():
            rel = f"Resources/{fix_file}"
            data = fp.read_bytes()
            files_dict[rel] = hashlib.sha1(data).digest()
            files2_dict[rel] = {"hash2": hashlib.sha256(data).digest()}
            resource_files[rel] = data

    rules = {
        "^Resources/": True,
        "^Resources/.*\\.lproj/": {"optional": True, "weight": 1000.0},
        "^Resources/.*\\.lproj/locversion.plist$": {"omit": True, "weight": 1100.0},
        "^Resources/Base\\.lproj/": {"weight": 1010.0},
        "^version.plist$": True
    }
    rules2 = {
        "^.*": True,
        "^[^/]+$": {"nested": True, "weight": 10.0},
        "^Resources/.*\\.lproj/": {"optional": True, "weight": 1000.0},
        "^Resources/.*\\.lproj/locversion.plist$": {"omit": True, "weight": 1100.0},
        "^Resources/Base\\.lproj/": {"weight": 1010.0},
        "^version.plist$": True
    }

    cr = {
        "files": files_dict,
        "files2": files2_dict,
        "rules": rules,
        "rules2": rules2
    }
    cr_bytes = plistlib.dumps(cr, fmt=plistlib.FMT_XML)

    info_plist_bytes = (ROOT / "macos" / "Info.plist").read_bytes()

    open_command = b"""#!/bin/bash
# ==============================================================================
# KL-06 Manager macOS Launcher & Gatekeeper Fix
# Automatically removes Gatekeeper quarantine attribute and opens the app!
# ==============================================================================
DIR="$(cd -P -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
APP="$DIR/KL-06 Manager.app"
echo "=========================================="
echo "  KL-06 Manager v0.4.7-beta macOS Launcher"
echo "=========================================="
echo "[1/3] Removing macOS Gatekeeper quarantine lock..."
xattr -cr "$APP" 2>/dev/null || true
echo "[2/3] Applying local ad-hoc signature..."
codesign --force --deep --sign - "$APP" 2>/dev/null || true
echo "[3/3] Launching KL-06 Manager..."
open "$APP"
echo "Done! You can close this Terminal window."
"""

    how_to_open = b"""================================================================================
KL-06 Manager v0.4.7-beta (Build 12) \xe2\x80\x94 macOS Installation & Gatekeeper Fix
================================================================================

If macOS displays:
"\xe2\x80\x9cKL-06 Manager\xe2\x80\x9d is damaged and can\xe2\x80\x99t be opened. You should move it to the Bin."

This is standard macOS Gatekeeper quarantine on downloaded internet files.

HOW TO OPEN INSTANTLY:
Option 1 (Easiest):
  Double-click "OPEN-KL06.command" in this folder. It strips the quarantine
  attribute, signs ad-hoc locally, and launches the app immediately!

Option 2 (Terminal):
  Open Terminal and run:
  xattr -cr "$HOME/Downloads/KL-06 Manager"*.app && codesign --force --deep --sign - "$HOME/Downloads/KL-06 Manager"*.app && open "$HOME/Downloads/KL-06 Manager"*.app

Option 3 (System Settings):
  Go to System Settings -> Privacy & Security -> Security -> Click "Open Anyway".
================================================================================
"""

    now_tuple = (2026, 11, 19, 18, 0, 0)

    with zipfile.ZipFile(OUTPUT_ZIP, "w", compression=zipfile.ZIP_DEFLATED) as zf:
        def add_dir(name):
            zi = zipfile.ZipInfo(name.rstrip('/') + '/', date_time=now_tuple)
            zi.external_attr = 0o40755 << 16
            zf.writestr(zi, b'')

        def add_file(name, data, mode=0o100644):
            zi = zipfile.ZipInfo(name, date_time=now_tuple)
            zi.compress_type = zipfile.ZIP_DEFLATED
            zi.external_attr = mode << 16
            zf.writestr(zi, data)

        add_dir("KL-06 Manager.app")
        add_dir("KL-06 Manager.app/Contents")
        add_dir("KL-06 Manager.app/Contents/_CodeSignature")
        add_dir("KL-06 Manager.app/Contents/MacOS")
        add_dir("KL-06 Manager.app/Contents/Resources")
        add_dir("KL-06 Manager.app/Contents/Resources/Companion")

        add_file("KL-06 Manager.app/Contents/Info.plist", info_plist_bytes, 0o100644)
        add_file("KL-06 Manager.app/Contents/_CodeSignature/CodeResources", cr_bytes, 0o100644)
        add_file("KL-06 Manager.app/Contents/MacOS/KL-06", binary_data, 0o100755)

        for rel, data in resource_files.items():
            mode = 0o100755 if rel.endswith((".sh", ".command")) else 0o100644
            add_file(f"KL-06 Manager.app/Contents/{rel}", data, mode)

        add_file("OPEN-KL06.command", open_command, 0o100755)
        add_file("HOW-TO-OPEN.txt", how_to_open, 0o100644)

        fix_all_sh = ROOT / "macos" / "KL-06-Fix-All.sh"
        if fix_all_sh.exists():
            add_file("KL-06-Fix-All.sh", fix_all_sh.read_bytes(), 0o100755)
        fix_all_cmd = ROOT / "macos" / "KL-06-Fix-All.command"
        if fix_all_cmd.exists():
            add_file("KL-06-Fix-All.command", fix_all_cmd.read_bytes(), 0o100755)

    sha256 = hashlib.sha256(OUTPUT_ZIP.read_bytes()).hexdigest()
    size = OUTPUT_ZIP.stat().st_size
    print(f"Created {OUTPUT_ZIP.name}: {size} bytes, SHA-256: {sha256}")
    return sha256

if __name__ == "__main__":
    main()
