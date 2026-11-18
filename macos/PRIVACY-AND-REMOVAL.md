# Mac privacy/removal — beta.2 / build 5

The authoritative four-platform guide is **`../docs/SAFETY-PRIVACY-REMOVAL.md`**; LAN limits are in `../docs/COMPANION-PROTOCOL.md`. Unlike the older Mac-only candidate, this app includes an **explicitly opt-in network listener**, not an unconditional "no networking" claim. It starts off and is bounded/private/pinned, with a separate native confirmation for every write. No cloud upload/relay, report auto-upload, discovery, public bind, firewall edit, root helper, login item or automatic updater.

- Bundled offline/non-persistent WKWebView; no external fonts/scripts. HWiNFO import is a bounded local historical numeric CSV, transient memory, not automatically persisted/exported/uploaded. Clearing references is not secure memory erasure.
- Existing `~/Library/Application Support/KL-Asus/Restore-v1.plist` deliberately retained. Original/absence is saved before a preference write; readback and observed external-conflict rules apply. Never erase it to force an update/restore. Desktop volume is not journal-restored.
- Existing SMC provider reads only `FNum`, `F0Ac`, `F1Ac`; no sweep/driver/sudo. Denied stays denied. Timestamp/result age is not physical acquisition age/calibration. No firmware or boot changes.
- Builder writes a fresh `macos/Local-build/`; Xcode can use normal local caches. Logs can expose private account paths. Targeted fan collector writes only its own new private report folder/temporary compiler workspace; review its small JSON/TXT before sharing.
- Optional native save-picker export is minimized, not guaranteed anonymous. No imported CSV/raw powermetrics, pairing secret/token, account/network/SMBIOS identity or original preference value is intentionally exported.
- Optional Python broker uses a private per-session temporary directory for key/cert/IPC; normal Stop/Command-Q removes it and revokes all phones. A forced app crash may leave a bounded child until expiry; snapshots go stale after 12 seconds and no native writer remains. If needed stop only that known session's process with ordinary OS tools, not every Python process. No global trust-store entry is installed.

Only the existing explicit fixed five-sample powermetrics read may request **macOS-local** administrator authorization. Cancel safely. No custom password field, password storage, sudoers policy, unrestricted shell or hidden persistent helper; a phone cannot request this action. Audio does not request/record microphone access; DTS/system-wide mic DSP/HDR controls are not implemented.

## Remove safely

1. Stop the companion. Restore eligible saved preferences from Safety; inspect conflicts/failures and retain the journal if unresolved. No blind restore on quit.
2. **Command-Q**; close only hides the Mac window. Running-only F13 and normal temporary assertion end on quit. Forced termination limitations apply.
3. Delete only this new testing app/source/Local-build output and your chosen collector/export files if unwanted. Keep the old working app/journal/backups. Delete the journal yourself only after deliberate successful restoration/review.
4. No driver/service/helper/login item needs uninstalling. Do not touch EFI, Windows data/boot, SIP/AMFI/Gatekeeper or working custom graphics/OLED/Fn/audio/USB. Keep Mac HDR OFF.

Root source/hash manifests and the separate exact-tested release gate do not prove privacy, native compilation, sensor calibration, signing/notarization or physical-device operation. See `../BUILD-STATUS.json` and `../docs/OWNER-TEST-CHECKLIST.md`.
