<div align="center">

# ⚡ KL-06 Manager

### *Next-Generation Control Center for Modern Hackintosh Systems*

[![Version](https://img.shields.io/badge/Release-v0.2.1--Beta-2563EB?style=for-the-badge&logo=apple&logoColor=white)](https://github.com/Kaushal-snap/KL-06-Manager/releases)
[![Status](https://img.shields.io/badge/Status-Verified%20Native-059669?style=for-the-badge&logo=checkmarx&logoColor=white)](https://github.com/Kaushal-snap/KL-06-Manager/releases)
[![Target](https://img.shields.io/badge/macOS-Sequoia%2015.8.3-7C3AED?style=for-the-badge&logo=apple&logoColor=white)](https://github.com/Kaushal-snap/KL-06-Manager)
[![Hardware](https://img.shields.io/badge/Hardware-ASUS%20K15%20OLED%20(K513EA)-EA580C?style=for-the-badge&logo=asus&logoColor=white)](https://github.com/Kaushal-snap/KL-06-Manager)
[![Architecture](https://img.shields.io/badge/Arch-x86__64%20(Intel)-0284C7?style=for-the-badge&logo=intel&logoColor=white)](https://github.com/Kaushal-snap/KL-06-Manager)
[![License](https://img.shields.io/badge/License-Proprietary%20%2F%20Closed--Source-DC2626?style=for-the-badge&logo=lock&logoColor=white)](https://github.com/Kaushal-snap/KL-06-Manager)

<br/>

<p align="center">
  <b>A lightweight, beautiful, and capability-aware macOS control companion.</b><br/>
  <i>Engineered specifically for Tiger Lake-U (Intel Core i5-1135G7) & Intel Iris Xe Graphics.</i>
</p>

---

[📥 Download KL-06.zip (Beta)](https://github.com/Kaushal-snap/KL-06-Manager/releases/tag/v0.2.1-beta.3) • [📖 Architecture](ARCHITECTURE.md) • [📋 Changelog](CHANGELOG.md) • [📊 Hardware Report](HARDWARE-REPORTS.md) • [🧪 Intake Specs](COMPONENT-REPORT.md)

---

</div>

<br/>

## 🎯 Target Hardware & Verified Baseline

Tested and verified on physical hardware running **macOS Sequoia 15.8.3** (Build `24H241`, Darwin `24.6.0`, x86_64):

| Subsystem | Target Observation | Status Badge | Enforced Policy |
| :--- | :--- | :---: | :--- |
| **Graphics** | Intel Iris Xe (`0x9a49`), Metal 2, 1536 MB Dynamic VRAM | <img src="https://img.shields.io/badge/Active-34D399?style=flat-square&logo=nvidia&logoColor=white" /> | Custom WhateverXe 0.8.2 binary preserved (`9e18e609...`). |
| **Display** | 1920×1080 @ 60 Hz, 30-Bit Color Depth (ARGB2101010) | <img src="https://img.shields.io/badge/Active-34D399?style=flat-square&logo=airplay&logoColor=white" /> | OLED / DPCD brightness & DSDT + SSDT-ASUS-FN intact. **HDR OFF** baseline preserved. |
| **Global Hotkey** | Physical `PrtSc` mapped to virtual **F13** (`keyCode 105`) | <img src="https://img.shields.io/badge/Active-34D399?style=flat-square&logo=hotjar&logoColor=white" /> | Show/Hide window toggle while running. Carbon `buffer.count` (`Int`) fix verified. |
| **Core Audio** | Built-in 44.1 kHz in / 96 kHz out (layout-id 7 / alc-layout-id 48) | <img src="https://img.shields.io/badge/Active-34D399?style=flat-square&logo=apple-music&logoColor=white" /> | Master output volume slider supported. Speakers, mic, & jack switching preserved. |
| **Desktop Tweaks**| 9 Reversible Dock, Finder, and Appearance settings | <img src="https://img.shields.io/badge/Active-34D399?style=flat-square&logo=macos&logoColor=white" /> | Atomic restore journal (`~/Library/Application Support/KL-Asus/Restore-v1.plist`). |
| **CPU Telemetry** | 11th Gen Intel Core i5-1135G7 @ 2.40 GHz (8 logical cores) | <img src="https://img.shields.io/badge/Read--Only-60A5FA?style=flat-square&logo=intel&logoColor=white" /> | Real dynamic load & memory counters. No fake overclocking or CPUFriend tampering. |
| **Thermals & Fans**| `SMCSuperIO`: 0, `AsusSMC`: 0 (No WMI / EC fan RPM sensor) | <img src="https://img.shields.io/badge/Disabled-9CA3AF?style=flat-square&logo=fanarttv&logoColor=white" /> | **Strict Rule:** Fan controls honestly unavailable. No fake sliders or simulated curves. |
| **Battery Health** | Service Recommended, 314 cycles, 2236 / 3549 mAh (~63% ratio)| <img src="https://img.shields.io/badge/Honest-FBBF24?style=flat-square&logo=battery&logoColor=white" /> | Real ACPI reporting surfaced honestly; no fake software calibration or charge limits. |

<br/>

---

## 📸 Verified On-Device Screenshots

Native execution captured live on target hardware (`LOCAL • NATIVE` state):

<div align="center">

| 1. Overview Dashboard | 2. Performance & Sampling |
| :---: | :---: |
| <img src="docs/screenshots/overview.png" width="480" /> | <img src="docs/screenshots/performance.png" width="480" /> |

| 3. Display & Sound Controls | 4. About KL-06 & Hotkey Status |
| :---: | :---: |
| <img src="docs/screenshots/display-and-sound.png" width="480" /> | <img src="docs/screenshots/about.png" width="480" /> |

</div>

<br/>

---

## 🚀 Key Highlights & Capabilities

- 🎨 **MyASUS-Inspired Modern Interface:** Sleek dark-mode aesthetic with real-time telemetry cards, color-coded status badges, and smooth gradient metrics.
- ⚡ **Zero Telemetry & Local-First:** No background daemons, no analytics tracking, no network calls (`connect-src 'none'`).
- 🛡️ **Preservation Invariants:**
  - Never touches your working EFI, OpenCore config, or boot arguments.
  - Retains bundle identity `app.klasus.controlcenter` and atomic restore journal.
  - Zero arbitrary kernel writes, MSR edits, or simulated fan controls.

<br/>

---

## 📦 How to Test & Install (Beta)

1. Go to the [Releases Page](https://github.com/Kaushal-snap/KL-06-Manager/releases/tag/v0.2.1-beta.3) and download **`KL-06.zip`**.
2. Unzip `KL-06.zip` on your Mac.
3. Move `KL-06.app` to your `/Applications` folder or run it directly from `Downloads`.
4. Press **`PrtSc` (F13)** anytime to toggle the control center window.

> **Integrity Verification:**
> - **SHA-256:** `ee499aafcd36663e06cfe6c19f04f7d422c1f6b5c98fa8663c4eca9128c33317`
> - **Architecture:** `x86_64` (Mach-O 64-bit)

<br/>

---

## 🔮 Roadmap Candidate: v0.3.0-beta.1 (Cirrus Theme)

Preparation and portable verification completed for the next candidate:
- 🌌 **Cirrus OLED-Dark Theme:** Refined independent dark & light aesthetics.
- 💨 **Read-Only AppleSMC Fan Reader:** Auditable C reader checking standard `FNum` and `F0Ac`/`F1Ac` keys (no fan writes or privileged helpers).
- 📈 **HWiNFO History Import:** Local Windows CSV history parser with unpadded-seconds timestamp handling for historical telemetry graphs.
- 🧪 **Portable Test Coverage:** 58 Node tests, 68 synthetic C assertions, and 12 package verification checks passed.
- *Status:* Awaiting native compilation & physical hardware test on owner's Mac (`UPDATE-KL-06.command`).

<br/>

---

## 🔒 License & Copyright

**Copyright © 2026 Kaushal-snap. All Rights Reserved.**  
This is a proprietary companion utility. Unauthorized reproduction, decompilation, redistribution, or modification without explicit written consent is prohibited.
