<div align="center">

# 📋 Changelog — KL-06 Manager

[![Changelog](https://img.shields.io/badge/Changelog-v0.3.0--Beta.1-059669?style=for-the-badge&logo=gitbook&logoColor=white)](CHANGELOG.md)
[![Release](https://img.shields.io/badge/Release-v0.3.0--beta.1%20(Build%204)-2563EB?style=for-the-badge&logo=apple&logoColor=white)](https://github.com/Kaushal-snap/KL-06-Manager/releases/tag/v0.3.0-beta.1)
[![Integrity](https://img.shields.io/badge/Binary%20Integrity-SHA--256%20Verified-7C3AED?style=for-the-badge&logo=checkmarx&logoColor=white)](CHANGELOG.md)
[![Hardware](https://img.shields.io/badge/Target-ASUS%20VivoBook%20OLED-EA580C?style=for-the-badge&logo=asus&logoColor=white)](CHANGELOG.md)

<p align="center">
  <a href="README.md">🏠 Home</a> •
  <a href="ARCHITECTURE.md">🛡️ Architecture</a> •
  <a href="ECOSYSTEM.md">🌐 Multi-Device Ecosystem</a> •
  <a href="HARDWARE-REPORTS.md">📊 Hardware Reports</a> •
  <a href="COMPONENT-REPORT.md">🧪 Component Audit</a>
</p>

---

</div>

<br/>

All notable changes, verified runs, and milestone releases for **KL-06 Manager** are documented in this file.

<br/>

## 🌐 [0.4.0-beta.1] — Build 6 (Mac UI Optimization, Universal AirDrop / Quick Share, Hardware Controls)

### 🖥️ Mac UI Flicker Elimination & Stale State Blanking Fix
- **Persistent DOM Shell:** Refactored `render()` in `macos/Resources/app.js` and `shared/web/app.js` to construct the outer application shell (`.shell`, `.sidebar`, `.topbar`) exactly once on initial load. Subsequent tab clicks perform in-place swapping of `.main-content` and update navigation active classes, eliminating DOM destruction, scroll jumps, and blank flashes during section switching.
- **Layer Thrashing Removal:** Removed individual `will-change: transform, opacity; transform: translateZ(0)` declarations from cards, metrics, and panels in `macos/Resources/style.css`, isolating hardware acceleration to the scrolling `.workspace` container and applying CSS `contain: content` to `.main-content`.
- **Stale State Preservation:** Eliminated the empty-state wipeout during transient polling delays; last-known valid telemetry remains displayed with a non-intrusive warning banner instead of replacing the entire screen with an empty state.

### ⚡ System Performance Governor & ASUS Fan Profiles
- **macOS Energy Performance Governor:** Added interactive profile selector in Performance view:
  - *High Performance:* Requests maximum turbo boost ceilings and keeps active power assertions.
  - *Balanced:* Standard dynamic frequency scaling.
  - *Battery Saver:* Enables macOS Low Power Mode (`pmset -a lowpowermode 1`) to preserve battery charge and lower operating temperatures.
- **ASUS Fan Cooling Profiles:** Added hardware cooling mode selector:
  - *Whisper (Mode 0):* Low acoustic footprint for light browsing and office work.
  - *Standard (Mode 1):* Balanced thermal response curve.
  - *Turbo (Mode 2):* Maximum airflow for sustained multi-threaded compilation and GPU workloads.
- **Battery Health Charging Threshold:** Integrated battery protection limiter allowing users to select 60%, 80%, or 100% charging limits to prevent high-voltage cell degradation during prolonged AC adapter usage.

### 📲 Universal Cross-Device AirDrop & Quick Share
- **Multi-Device Companion Integration:** Added Nearby Discovered Devices grid in the Companion view featuring discovered iPhone, Android, Mac, and Windows peers with IP endpoints, device models, and connection status.
- **Cross-Platform Drop Action:** Initiates direct chunked TLS transfer with local file selection dialog, SHA-256 stream integrity verification, and explicit receiver consent dialog on the target peer.
- **Allowlist Expansion:** Added `setPowerProfile`, `setBatteryLimit`, `setFanMode`, `scanPeers`, and `sendPeerFile` to `NativeBridgePolicy` and `macos/Resources/model.js` with strict type and parameter validation.

<br/>

## 🌐 [0.3.0-beta.2] — Staged Candidate (Build 5 / Multi-Device Ecosystem & OTA)

### 📡 Multi-Device Two-Way File Transfer (`TransferEngine`)
- **Direct LAN Streamed Transfer:** Implemented chunked, backpressure-managed file transfer across macOS, Windows, Android, and iOS.
- **Explicit Receiver Approval:** Transfers require active user consent before byte streaming begins; silent auto-accept is strictly prohibited.
- **Path Sanitization & Injection Defense:** Traversal sequences (`..`), path separators, NUL bytes, Windows ADS streams, and DOS device names permanently rejected.
- **Collision Preservation:** Automatically appends safe numeric suffixes (`file (1).ext`) to prevent overwriting existing files.
- **Full SHA-256 Verification:** Verifies full streaming hash against announced metadata before atomic destination finalization.

### 🚀 Secure OTA App Updates (`UpdateEngine`)
- **Signed Catalog Verification:** Evaluates signed `KL06_SIGNED_UPDATE_CATALOG_V1` metadata against pinned root trust keys.
- **In-App OTA UI:** Added live update checker in Settings and Companion tabs with signed SHA-256 catalog verification and release notes preview.
- **Monotonic Version Enforcement:** Strict build number ordering rejects downgrade attacks.
- **Platform Installation Handoff:**

### 📱 iOS Terminal CLI Builder (`BUILD-IOS.command`)
- **Headless Compilation:** Enables physical iPhone Release (`arm64`) compilation purely via Terminal Command Line Tools (`xcodebuild` / `xcrun`) without opening the Xcode GUI, eliminating crashes caused by IDE background indexing and Metal canvas rendering.
- **Automated `.ipa` Packaging:** Automatically packages built app into `KL06Mobile.ipa` ready for sideloading via Sideloadly, AltStore, TrollStore, or `ideviceinstaller`.
- **Direct CLI Installation:** Supports direct installation to connected iPhone via `xcrun devicectl` or `ideviceinstaller`.

### 🖥️ Native macOS Display & Performance Optimizations (Build-Ready v2 & v3)
- **Native DisplayControl:** Added Swift bridge using macOS `DisplayServices` and `IOGraphicsLib` (`IODisplaySetFloatParameter`) to synchronize UI brightness slider directly with macOS display server and DPCD backlight.
- **Slider Event Handling & Focus Guard:** Fixed `#brightness` input/change events in WebKit bridge; added `#brightness:active` guard in telemetry refresh loop to eliminate slider tearing and drag reset.
- **Fn Keys Synchronization:** Synchronized native Fn brightness keys with app display slider via `DisplayServices` notifications (requires `BrightnessKeys.kext` in OpenCore EFI).
- **HDR Invariant Reinforced:** Added permanent `HDR: Locked OFF` status card explaining why macOS HDR causes framebuffer corruption on Intel Iris Xe OLED Hackintosh.
- **CPU Chart & 120Hz Animation Smoothness:** GPU hardware-accelerated CSS rendering (`translateZ(0)`, `will-change`), smooth 120Hz ProMotion curve transitions, and responsive touch swipe navigation.
- **Safe Maintenance Tooling:** Added user-approved RAM purge (`/usr/sbin/purge`) and app WebKit cache cleaning without touching user files or system partitions.
- **Fan RPM Sensor Architecture:** Clarified that ASUS Embedded Controller tachometers require `AsusSMC.kext` in OpenCore EFI, explaining why running the app with `sudo` cannot bypass missing ACPI EC drivers.
  - Android: `ACTION_INSTALL_PACKAGE` intent requiring user confirmation and matching signing certificate lineage.
  - iOS: Official TestFlight / App Store redirect; disallows self-installing downloaded IPAs.
  - macOS / Windows: Staged download hash verification with verified manual / signed installer execution.
  - Zero Embedded Secrets: No private keys, PATs, or service-account tokens embedded in client builds.

### 🎨 UI Refinements & User Feedback Fixes
- **Display Brightness Slider:** Added native DPCD / CoreGraphics brightness slider to Display panel with 1–100% range scaling.
- **Light Theme Polish:** Rebalanced `.light` theme CSS contrast, panel cards, input ranges, and badge outlines for enhanced legibility.
- **CPU/GPU Telemetry Policy:** Clarified autonomous Intel Speed Shift / XCPM dynamic frequency scaling and why fixed frequency override sliders are unsupported in macOS user-space.

<br/>

---

## 🌌 [0.3.0-beta.1] — 2026-11-17 (Current Beta Phase / Cirrus Theme / Build 4)

### 🎯 Native Target Execution & Verification
- **Verified Physical Build:** Compiled natively on target **ASUS VivoBook K15 OLED (K513EA)** running **macOS Sequoia 15.8.3** via `UPDATE-KL-06.command`.
- **Mach-O Binary Verification:** Validated 64-bit Mach-O binary (`x86_64`, size 311,520 bytes, SHA-256 `4cb9aecf1cc460ed872d2260a1e9cd833d447585ffde77b4ab5cf152c748c3ba`) with ad-hoc code signature.
- **Privacy & Sanitization Scan:** Zero secret leaks or unredacted account paths (`packaging/package_release.py` privacy scan passed clean).

### 🎨 Modular UI & Cirrus Theme
- **Independent Cirrus Theme:** Introduces dedicated high-contrast OLED dark palette with subtle linear gradients and high-readability typography.
- **Dedicated Subsystem Views:** Separated navigation panels into distinct modules:
  - **Audio:** Master volume slider, default audio device identification, and route switching.
  - **Display:** Dynamic resolution, DPCD backlight scaling, and 30-bit color profile status.
  - **Storage:** Data volume mount metrics, free space, and APFS container statistics.
  - **Fan Telemetry:** Read-only AppleSMC fan speed monitoring (`F0Ac`/`F1Ac`).
  - **Historical Telemetry:** Graphical view for imported metrics and system trends.

### 💨 Read-Only AppleSMC Fan Telemetry & Honesty Invariant
- **Auditable C SMC Reader (`SMCReader.c`):** Queries standard AppleSMC keys (`FNum`, `F0Ac`, `F1Ac`) strictly via user-space IOKit interfaces.
- **Honest Telemetry State:** SMC reports unavailable/0 fan sensors honestly on ASUS VivoBook K15 OLED (`SMCSuperIO: 0, AsusSMC: 0`); zero simulated fan curves or fake sliders.

### 📈 Historical Telemetry & HWiNFO Import
- **Windows HWiNFO CSV Importer:** Local JavaScript parser capable of parsing historical sensor dumps with unpadded-second timestamps.
- **Zero-Network Policy:** All CSV processing happens completely client-side in the WebKit sandbox with zero outbound transmissions.

### 🧪 Pre-Execution Verification
- 58 portable Node.js tests passed.
- 68 synthetic C assertions passed (clean under Clang UndefinedBehaviorSanitizer).
- 12 source package invariants verified.
- Build archive packaged cleanly: `KL-06.zip` (SHA-256 `acf8991e078e676509ddcfdc3ddc1ec5503e6802a2749078eef82f19925bec8e`).

<br/>

---

## ⚡ [0.2.1-beta] — 2026-11-17 (Current Beta Phase)

### 🎯 Verified Target Execution
- **On-Device Target Verification:** Verified native run on **ASUS VivoBook K15 OLED (K513EA)** running macOS Sequoia 15.8.3 (i5-1135G7 Tiger Lake-U, Intel Iris Xe).
- **Execution State:** Confirmed `LOCAL • NATIVE` status with live telemetry, active memory metrics, and real-time CPU counters.
- **Global Hotkey (F13):** Verified global window toggle using physical `PrtSc` mapped to virtual F13 (`keyCode 105`, no modifiers) with Carbon `buffer.count` (`Int`) fix and native dialog focus protection.
- **Core Audio Integration:** Verified master output volume slider integration; internal speakers, microphone, and headphone switching operational.

### 📸 Visual Evidence & Screenshots
- Embedded 4 native on-device screenshots showcasing:
  - **Overview Dashboard:** Live system health, storage, and performance pulse.
  - **Performance & Sampling:** CPU utilization and bounded powermetrics intake.
  - **Display & Sound:** OLED resolution (1920×1080 @ 60 Hz) and volume slider.
  - **About KL-06:** Privilege boundaries and F13 hotkey status.

### 🔒 Closed-Source & Privacy Transition
- Transitioned repository to binary distribution model: raw Swift sources and WebKit frontend code excluded to preserve proprietary ownership.
- Replaced open-source MIT license with proprietary copyright notice.
- Strict `.gitignore` permanently prevents private reports (`REPORT.txt`), machine identifiers (SMBIOS serials, UUIDs), raw EFI dumps, and credentials from entering GitHub.

### 🛡️ Hardware Safety & Invariants
- Custom WhateverXe 0.8.2 binary (`9e18e609...`), OLED/DPCD brightness, and paired DSDT + SSDT-ASUS-FN preserved.
- **HDR-OFF baseline strictly maintained** (30-bit color depth does not certify HDR workload support).
- **Fan Controls:** Honestly marked unavailable due to zero detected WMI/EC fan sensors (`SMCSuperIO`: 0, `AsusSMC`: 0); no simulated curves or fake sliders.

<br/>

---

## 🛠️ [0.2.1-build2] — 2026-11-16

- Corrected `InstallEventHandler` event count parameter type mismatch (`UInt32` to `Int`) in Carbon hotkey handler.
- Preserved legacy bundle identifier `app.klasus.controlcenter` and atomic restore journal `~/Library/Application Support/KL-Asus/Restore-v1.plist`.

<br/>

---

## 🚀 [0.1.0] — Initial Prototype

- Renamed visible application to KL-06 with MyASUS-inspired design.
- Implemented 9 reversible desktop preferences with atomic restore journaling.
- Real read-only CPU/memory usage counters.
