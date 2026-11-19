# KL-06 Manager for Mac — 0.3.0-beta.2 / build 5

**No precompiled Mac app, Apple-SDK compile, native signature or device certification is claimed here.** This is the Mac part of the whole four-platform source candidate. Extract the **entire parent `KL-06-0.3.0-beta.2` folder**; its builder also needs sibling `companion/server.py`. Frozen beta.1/build 4 and the canonical working app are separate and unchanged.

## Build on the intended Intel Mac

Download the source ZIP **as a file** (preview is not download), extract the whole folder, keep the old working app/restore journal, quit the old app with **Command-Q**, then run this complete command if extracted into Downloads:

```bash
/bin/bash "$HOME/Downloads/KL-06-0.3.0-beta.2/macos/UPDATE-KL-06.command"
```

Else type `/bin/bash `, drag this folder's `UPDATE-KL-06.command` into Terminal and Return. **No sudo.** Installed Xcode/Command Line Tools required; nothing is downloaded/installed. The wrapper first runs native tests with injected fake preferences/synthetic transport, then compiles C + Swift/AppKit/WKWebView, locally ad-hoc signs/verifies a **new** `macos/Local-build/Build.XXXXXX/KL-06 Manager.app` and reveals it in Finder. Open it yourself. No automatic replacement, installation or launch. Compiler logs may contain private account paths; review/redact before sharing.

Target **x86_64 / macOS 13–26 APIs**; Sequoia is the intended owner test target, not a certification. macOS 26 untested; **27+ blocked**. No ARM/universal-Hackintosh approval, Developer ID signing/notarization or privileged helper. Do not change SIP/AMFI/Gatekeeper, EFI or working graphics to solve a build/security error. The disabled manual CI template can set `KL06_REVEAL_BUILD=0` to skip only Finder reveal; it still cannot approve a physical device.

## Implemented Mac functions

- **13 local Cirrus pages / 12 reversible current-user preferences**, independent OLED-dark/navy/teal theme with light option. Exact journal-before-write, readback, original absence and observed-conflict preservation; not a CPU/GPU "boost". Safe default-output Core Audio volume and temporary 15-minute idle-system assertion. No Electron/external fonts/scripts/assets.
- Current native CPU/RAM/battery/filesystem/display/audio properties; usage/history colours require valid real values. Metal API/model flags do not certify Metal 3 or invent GPU load/clock. Capacity-ratio health is separate from current battery charge.
- **Fan & sensors:** existing AppleSMC/VirtualSMC `FNum`, `F0Ac`, `F1Ac` **read only**. Fixed read-info/read-value commands, typed size/range/status checks, single worker, five-second minimum interval, two-fan cap and stale withholding after 12 seconds. Zero only from a valid successful read. Query-result age is not physical acquisition age. Values are provider-reported, **not independently calibrated**. A blocked kernel call cannot be hard-cancelled; cached data expires and no overlapping reads accumulate.
- **ASUS K513EA fan-path note:** the app's current reader only consumes standard SMC fan keys; it does not create them. ASUS fan telemetry on compatible laptops may be exposed through the ASUS ATK/WMI ACPI device (`PNP0C14` / `ATK0100`, `WMNB`) by a VirtualSMC plugin. The separate AsusFanControl project documents that path, but K513EA-specific support is **not yet verified**. Run `/bin/bash DIAGNOSE-ASUS-FAN-PATH.command` on the native laptop and inspect the private report before considering any EFI/kext change. No fan-mode or thermal-profile writes are included.
- Local Windows HWiNFO CSV history import: native picker, 5 MiB/10,000-sample cap, numeric allowlist, source-separated min/median/max and timestamped graphs, no formulas/footer identities. It stays **historical Windows**, not live Mac or a firmware-write interface; transient memory, no automatic save/upload. Clear locally.
- Storage is real read-only home-filesystem capacity/free; no destructive cleaner. Optional targeted `COLLECT-MAC-FANS.command` uses the same reader and existing Apple tools, no sudo/driver/network download. It creates a new small private JSON/TXT report; review it before sharing. No more generic inventory is required.
- **Optional phone companion:** explicitly enabled, private-IPv4 HTTPS TLS broker with already-installed Python 3.9+. Five-minute random code + full certificate pin + native laptop pair approval; each remote write separately confirms actual percent/title/ID. Maximum 30-minute session/90-second request; revoke with Stop/Command-Q. No remote shell, firewall edit, cloud relay, administrator sample or firmware access. Details stay in the native dialog, not JS/export. Clock deadlines use matching fixed mach-uptime epochs, not Python 3.9's process-relative clock.

When no companion is running, hidden windows skip native sampling. Enabling the bounded companion opts into low-rate snapshots even while the window is hidden, so stop it when not needed for battery/privacy. Both phone-local controls and native pinned clients exist separately in the sibling Android/iOS projects; this Mac app is not a phone hardware driver.

## Preserved identity and boundaries

`app.klasus.controlcenter`; restore journal **`~/Library/Application Support/KL-Asus/Restore-v1.plist`** is intentionally preserved. Do not delete a journal to bypass a conflict. **F13 alone / keyCode 105 / physical PrtSc** shows/fronts/hides only while running, no keylogger/event tap/remap/login item/keyboard-monitoring permission. Actual global-key operation needs this exact candidate's owner test.

**No privileged helper** is supplied. Only the existing explicit fixed five-sample powermetrics read may request native macOS authorization; cancel safely, no custom password box/storage/root shell. No firmware fan curves/targets/ASUS modes/charge caps/voltage/clock tuning, driver/kext install, HDR/DTS/system-wide microphone DSP, Metal unlock, disk/RAM cleaner, EFI/Windows/partition change or hidden persistence. Preserve working custom graphics/Metal 2, OLED/Fn/audio/USB and **HDR OFF**.

## Verification and handoff

- `TEST-PORTABLE.sh`: Mac Node/C/Python portable checks, no native provider access. Whole-root `../TEST-PORTABLE.sh` also covers common UI, broker/release/package policy and optional Java. Developer tools are not app-runtime dependencies.
- `TEST-MAC.command`: native fake-preference/C tests **pending** on Apple tools, not a hardware test.
- `../BUILD-STATUS.json`, `../docs/VERIFICATION.md`: executed vs unexecuted evidence.
- `../docs/OWNER-TEST-CHECKLIST.md`, `../docs/COMPANION-PROTOCOL.md`, `../docs/SAFETY-PRIVACY-REMOVAL.md`, `../docs/DEPENDENCIES-LICENSES.md`.
- `../docs/RELEASE-AUTOMATION.md`: implemented but **inactive** exact owner-tested Drive ZIP → new **PRIVATE KL-06-Manager/main beta** gate. Source-only/UNTESTED ZIPs or a false template are not release approval. No real repository/workflow/service setup occurred here.

Retain the project license. No vendor app/driver/EFI/raw report is included. Source/build preparation and a browser preview are not four-platform device validation.
