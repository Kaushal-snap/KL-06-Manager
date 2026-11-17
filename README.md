# KL-06 0.2.1

Independent local macOS window/menu-bar companion. Formerly **KL -Asus**. Capability-aware intake for different Hackintosh hardware—not a universal hardware driver or a promise that every control works everywhere.

**Status:** Tested & verified native build on target (ASUS VivoBook K15 OLED, macOS Sequoia 15.8.3, i5-1135G7). Verified working on-device with active `LOCAL • NATIVE` status, global F13 (keyCode 105) hotkey registered, Core Audio volume control, and telemetry counters operational.

## Screenshots (Native macOS Sequoia Verification)

| Overview | Performance |
| :---: | :---: |
| ![Overview](docs/screenshots/overview.png) | ![Performance](docs/screenshots/performance.png) |

| Display & Sound | About KL-06 |
| :---: | :---: |
| ![Display & Sound](docs/screenshots/display-and-sound.png) | ![About KL-06](docs/screenshots/about.png) |

## Build / update on your Mac

1. Download the **`KL-06-0.2.1-update-and-report.zip` file card in Arena**, then unzip it in Downloads. Downloads do not happen automatically. The extracted folder is **`KL-06-0.2.1`** and includes app source/builders, the hardware-report script and `START-HERE.txt`.
2. **Quit any old KL -Asus / KL-06 app with ⌘Q first**, not just its window.
3. In a new Terminal window, run this complete command without sudo:

```bash
/bin/bash "$HOME/Downloads/KL-06-0.2.1/UPDATE-KL-06.command"
```

If you extracted somewhere else, type `/bin/bash ` (with a space), drag **UPDATE-KL-06.command** from that folder into Terminal, then press Return. Do not run an older copy from a different folder. The wrapper runs the included `TEST-MAC.command`, then `BUILD-MAC.command` only if tests pass.

The first step compiles isolated native tests against **fake preferences**, not your desktop settings. Only after they pass does the build create a new `Local-build/Build.XXXXXX/KL-06.app`, locally ad-hoc sign it and reveal it in Finder. Open it yourself. Nothing installs into Applications or launches automatically. No network downloads, Xcode installation or security bypass are performed.

Installed Apple Xcode/Command Line Tools are required **only to build the app**, not for the separate hardware report. Select the installed Xcode under Xcode → Settings → Locations → Command Line Tools if needed. A compiler error is not a reason to change SIP, EFI, BIOS or drivers. Share only error lines with personal paths removed if the build fails.

Current app build target: **x86_64 / macOS 13+ APIs**. Intel and AMD x86_64 systems can be evaluated as candidates, but per-device/query/control tests are required. Minimum deployment version is not certification for every CPU, GPU, firmware or macOS release. ARM/older macOS builds are not approved by this release. No Hackintosh EFI OS-support gate is broadened.

### If your original v0.2.1 download reports `UInt32` → `Int`

The original source incorrectly converted the `InstallEventHandler` event count. No Xcode/driver/EFI/security change is needed. For the already-extracted original folder in Downloads, quit any old KL app and paste this block into Terminal:

```bash
/usr/bin/sed -i ".before-f13-fix-$(/bin/date +%Y%m%d-%H%M%S)" \
  's/UInt32(buffer[.]count)/buffer.count/' \
  "$HOME/Downloads/KL-06-0.2.1/Sources/HotKey.swift" &&
/bin/bash "$HOME/Downloads/KL-06-0.2.1/UPDATE-KL-06.command"
```

This backs up and edits **only that app source file**, then retries the existing test/build wrapper. It does not change desktop preferences or hardware configuration. The reissued v0.2.1 ZIP already contains the correction; `SOURCE-REVISION.txt` and checksums identify its source revision. It is still a preview, not a newly native-certified release. If a different compiler error follows, retain the first new error rather than changing security or drivers.

### Existing restore points are preserved

The visible app, executable, menu and source folder are now **KL-06**. The existing bundle identifier `app.klasus.controlcenter` and private journal `~/Library/Application Support/KL-Asus/Restore-v1.plist` are **intentionally retained** so original v0.1 preference backups are not lost. Do not delete/move that legacy-named folder while restore entries remain. Same bundle identity also prevents old and new app versions from intentionally managing preferences simultaneously; quit the old version before opening the new one.

Close hides the window; choose **KL** in the menu bar to reopen. ⌘Q / Quit exits and releases temporary keep-awake and the F13 reservation. Applied desktop preferences remain until explicitly restored.

## F13 / physical PrtSc global shortcut

- **F13 alone, macOS virtual keyCode 105**, with no Command/Option/Control/Shift modifier. The owner reports the physical PrtSc key sends this event; no keyboard/ACPI/EFI remap is applied.
- While KL-06 is running, press once to bring it forward (including a closed or minimized window); press again when it is already in front to hide it. If visible behind another app, it comes forward rather than disappearing. Holding the key does not repeatedly toggle.
- Open native confirmation/save dialogs are focused instead of hidden. While the optional OS power authorization/sample is in flight, the shortcut does nothing so it cannot cover that separate prompt. Nothing is applied, restored, sampled or authorized by the shortcut itself.
- Works through a **Carbon `RegisterEventHotKey` registration**, not a keyboard event tap or global key logger. No Accessibility or Input Monitoring permission is requested. Only the app's own returned registration/handler is removed on quit; no system key binding is rewritten.
- If macOS refuses registration (for example because another shortcut owns F13), KL-06 shows a warning and its About/menu status says unavailable. Use the KL menu-bar icon or Dock normally. Review competing shortcuts and quit/reopen KL-06 to retry; do not disable security protections.
- **Not a launcher when KL-06 is quit**, and no login/lock-screen shortcut or automatic login item is installed. The browser preview does not bind a global key. Actual F13/PrtSc behavior still needs verification on the owner's Mac.

## Hardware-report script in the same ZIP

No app build or Xcode is needed for this part. After extracting the ZIP in Downloads:

```bash
/bin/bash "$HOME/Downloads/KL-06-0.2.1/KL-06-Hardware-Report.command"
```

It creates **REPORT.txt** in a new **KL-06-Report.XXXXXX** Desktop folder (home fallback). Review that file before sending it to Arena; add the physical laptop/motherboard model and actually tested features. This script only queries hardware/software context; it does not update the app or change the machine. `KL-06-SHARE-COMMAND.txt` is the complete standalone paste alternative to share with other owners. A single bare command cannot download anything from an unpublished URL; share the actual script or complete paste block.

## What's included

- Read-only CPU load, memory/compression/swap, Metal device/family flags, main display, reported battery capacity/current charge and home-filesystem free space.
- **Color-coded actual CPU load and memory occupancy.** GPU/display accent colors indicate categories, **not invented utilization**. Missing GPU load/sensors remain unavailable.
- Capability-aware hardware inventory: no hard-coded ASUS model or assertion that an unknown owner's audio/USB works. SMBIOS is labelled as possibly injected, not physical evidence. Desktops without a battery are normal.
- Supported Core Audio default-output volume; fixed Settings shortcuts for display, sound, keyboard/trackpad, battery, accessibility, login items, network, storage and notifications. Shortcuts are not custom hardware-control implementations.
- Nine individually confirmed user-level preferences: Dock auto-hide/reveal/minimize/launch animation; Finder path/status/hidden files/extensions; visible scrollbars. Journal-before-write, read-back, exact original restoration including unset keys, managed-preference checks and external-conflict skips.
- Separately confirmed Dock/Finder relaunch; no unrelated application killing.
- Optional **fixed five-sample powermetrics** CPU/GPU read, with macOS-local authorization. No task/process sampler or settings writes. Supported fields only; output estimates and missing counters are not certification.
- Temporary **15-minute keep-awake**, stopped on quit; increases battery use and is not a sleep fix. No persistent pmset changes.
- User-chosen minimized JSON snapshot export. No serial, UUID, account name, SSID/MAC, process/window titles, raw registry or EFI. Review before sharing.
- [Generic shareable hardware report](HARDWARE-REPORTS.md), requiring no app/Xcode/Python/sudo and producing a reviewed `REPORT.txt` for Arena.

## What a report cannot automatically enable

Firmware fan curves/RPM, CPU/GPU clock or voltage controls, charging thresholds, automatic HDR, licensed DTS playback, system-wide microphone noise cancellation and universal keyboard-light/brightness control require specific APIs/drivers/firmware/licensing and real device tests. They are **not implemented or faked** here. A GPU name is not a safe clock-control interface; a display/HDR label is not permission to enable HDR; a codec ID is not a DTS licence. No destructive disk “optimizer”, cache purge, swap/Spotlight disabling or automatic driver installation is included.

Existing graphics (including custom WEX/OLED), Fn/input, USB/audio/network, EFI, Windows, NVRAM, SIP, BIOS and persistent system power settings remain untouched. Service counts are not port maps and an inventory does not certify hardware function. Battery capacity loss cannot be repaired by app tweaks.

## Hardware support workflow

1. Another owner runs the standalone report command and reviews the text locally.
2. They add physical motherboard/laptop model, actually tested functions and requested control/bug; attach only `REPORT.txt` to Arena.
3. We separate working standard APIs from unsupported providers and ask for minimal missing evidence.
4. Any hardware-specific provider is implemented narrowly and target-tested before being enabled. Unknown support stays unavailable.

No auto-upload, guessed firmware method, cloud profile approval or automatic EFI change occurs. See [HARDWARE-REPORTS.md](HARDWARE-REPORTS.md) and [PUBLISHING.md](PUBLISHING.md). There is no published download URL yet; GitHub credentials should never be pasted into chat.

## Restore / uninstall

Use **Safety & restore → Restore my desktop changes** first if you want the original desktop preferences back. Read results: conflicting newer external choices or managed keys are skipped. Keep the legacy-named restore file until desired restorations are complete. Relaunch affected UI apps separately when convenient, after finishing file copies.

Quit the app. Then delete your own built app/source if desired. Only after desired changes are restored may you remove the app's now-empty legacy `KL-Asus` Application Support directory. No privileged helper, kext, launch agent, updater or background tuning service was installed.

## Development / limits

AppKit/WebKit host + bundled offline UI; IOKit/IOPS/Mach/sysctl/Metal/CoreGraphics/Core Audio; Carbon for the single F13 shortcut. No Node/Electron/cloud runtime. The exact UI can run as an honest browser preview, whose provider refuses all native changes. Native bridge admits known actions only from the exact bundled main-frame file URL; no arbitrary shell/EC/firmware bridge exists. The optional fixed power command is the only administrator action.

```bash
node --test tests/model.test.js
```

Optional developer browser checks use separately installed Playwright and serve `Resources/` on port 4173. Native `TEST-MAC.command` compiles fake-preference journal/parser tests; it does not test real hardware controls. See [VERIFICATION.md](VERIFICATION.md) for executed checks and pending target tests. New app/source/report code is under the included MIT project license; Apple frameworks are not redistributed, and no ASUS/DTS/third-party driver code is bundled.
