<div align="center">

# 📋 Changelog — KL-06 Manager

[![Changelog](https://img.shields.io/badge/Changelog-v0.2.1--Beta.3-059669?style=for-the-badge&logo=gitbook&logoColor=white)](CHANGELOG.md)
[![Candidate](https://img.shields.io/badge/Candidate-v0.3.0--beta.1%20(Staged)-2563EB?style=for-the-badge&logo=apple&logoColor=white)](CHANGELOG.md)
[![Integrity](https://img.shields.io/badge/Binary%20Integrity-SHA--256%20Verified-7C3AED?style=for-the-badge&logo=checkmarx&logoColor=white)](CHANGELOG.md)
[![Hardware](https://img.shields.io/badge/Target-ASUS%20VivoBook%20OLED-EA580C?style=for-the-badge&logo=asus&logoColor=white)](CHANGELOG.md)

<p align="center">
  <a href="README.md">🏠 Home</a> •
  <a href="ARCHITECTURE.md">🛡️ Architecture</a> •
  <a href="HARDWARE-REPORTS.md">📊 Hardware Reports</a> •
  <a href="COMPONENT-REPORT.md">🧪 Component Audit</a>
</p>

---

</div>

<br/>

All notable changes, verified runs, and milestone releases for **KL-06 Manager** are documented in this file.

<br/>

## 🌌 [0.3.0-beta.1] — 2026-11-17 (Staged Candidate / Cirrus Theme)

### 🎨 Modular UI & Cirrus Theme
- **Independent Cirrus Theme:** Introduces dedicated high-contrast OLED dark palette with subtle linear gradients and high-readability typography.
- **Dedicated Subsystem Views:** Separated navigation panels into distinct modules:
  - **Audio:** Master volume slider, default audio device identification, and route switching.
  - **Display:** Dynamic resolution, DPCD backlight scaling, and 30-bit color profile status.
  - **Storage:** Data volume mount metrics, free space, and APFS container statistics.
  - **Fan Telemetry:** Read-only AppleSMC fan speed monitoring (`F0Ac`/`F1Ac`).
  - **Historical Telemetry:** Graphical view for imported metrics and system trends.

### 💨 Read-Only AppleSMC Fan Telemetry
- **Auditable C SMC Reader (`SMCReader.c`):** Queries standard AppleSMC keys (`FNum`, `F0Ac`, `F1Ac`) strictly via user-space IOKit interfaces.
- **Zero Fan Writes:** No privileged helper tools, no custom kernel extensions, and zero simulated fan speed curves.

### 📈 Historical Telemetry & HWiNFO Import
- **Windows HWiNFO CSV Importer:** Local JavaScript parser capable of parsing historical sensor dumps with unpadded-second timestamps.
- **Zero-Network Policy:** All CSV processing happens completely client-side in the WebKit sandbox with zero outbound transmissions.

### 🧪 Pre-Execution Verification
- 58 portable Node.js tests passed.
- 68 synthetic C assertions passed (clean under Clang UndefinedBehaviorSanitizer).
- 12 source package invariants verified.
- *Status:* Staged on GitHub Releases as a draft prerelease; awaiting native compilation and physical validation on target Intel Mac via `UPDATE-KL-06.command`.

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
