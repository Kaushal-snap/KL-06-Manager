<div align="center">

# ⚡ KL-06 Manager

### *Next-Generation Control Center for Modern Hackintosh Systems*

[![Release](https://img.shields.io/badge/Release-v0.3.0--Beta.1-2563EB?style=for-the-badge&logo=apple&logoColor=white)](https://github.com/Kaushal-snap/KL-06-Manager/releases/tag/v0.3.0-beta.1)
[![Build Status](https://img.shields.io/badge/Status-Verified%20Native%20(Build%204)-059669?style=for-the-badge&logo=checkmarx&logoColor=white)](https://github.com/Kaushal-snap/KL-06-Manager/releases)
[![macOS](https://img.shields.io/badge/macOS-Sequoia%2015.8.3%20(24H241)-7C3AED?style=for-the-badge&logo=apple&logoColor=white)](https://github.com/Kaushal-snap/KL-06-Manager)
[![Target Platform](https://img.shields.io/badge/Platform-ASUS%20VivoBook%20K15%20OLED-EA580C?style=for-the-badge&logo=asus&logoColor=white)](https://github.com/Kaushal-snap/KL-06-Manager)
[![CPU Arch](https://img.shields.io/badge/Arch-x86__64%20(Tiger%20Lake--U)-0284C7?style=for-the-badge&logo=intel&logoColor=white)](https://github.com/Kaushal-snap/KL-06-Manager)
[![Graphics](https://img.shields.io/badge/GPU-Intel%20Iris%20Xe%20(Metal%202)-0891B2?style=for-the-badge&logo=intel&logoColor=white)](https://github.com/Kaushal-snap/KL-06-Manager)
[![Hotkey](https://img.shields.io/badge/Hotkey-PrtSc%20%E2%86%92%20F13%20Toggle-F59E0B?style=for-the-badge&logo=hotjar&logoColor=white)](https://github.com/Kaushal-snap/KL-06-Manager)
[![Distribution](https://img.shields.io/badge/License-Proprietary%20%2F%20Closed--Source-DC2626?style=for-the-badge&logo=lock&logoColor=white)](https://github.com/Kaushal-snap/KL-06-Manager)

<br/>

<p align="center">
  <b>A lightweight, beautiful, and capability-aware macOS control companion.</b><br/>
  <i>Engineered specifically for Tiger Lake-U (Intel Core i5-1135G7) & Intel Iris Xe Graphics.</i><br/>
  Zero external telemetry • Read-only sensor verification • Atomic preference rollback
</p>

<p align="center">
  <a href="https://github.com/Kaushal-snap/KL-06-Manager/releases/tag/v0.3.0-beta.1"><img src="https://img.shields.io/badge/%E2%AC%87%EF%B8%8F_Download_Release-KL--06.zip_(Beta)-2563EB?style=for-the-badge" alt="Download Release" /></a>
  <a href="CHANGELOG.md"><img src="https://img.shields.io/badge/%F0%9F%93%8B_View_Changelog-v0.3.0--Beta.1-059669?style=for-the-badge" alt="Changelog" /></a>
  <a href="ARCHITECTURE.md"><img src="https://img.shields.io/badge/%F0%9F%9B%A1%EF%B8%8F_Architecture_%26_Security-Boundary_Specs-7C3AED?style=for-the-badge" alt="Architecture" /></a>
  <a href="HARDWARE-REPORTS.md"><img src="https://img.shields.io/badge/%F0%9F%93%8A_Hardware_Report-Telemetry_Specs-EA580C?style=for-the-badge" alt="Hardware Report" /></a>
</p>

---

</div>

<br/>

## 🎯 Target Hardware & Verified Baseline

KL-06 Manager is built and verified on physical hardware running **macOS Sequoia 15.8.3** (Build `24H241`, Darwin Kernel `24.6.0`, `x86_64`):

| Subsystem | Target Observation | Status Badge | Verified Safety Policy |
| :--- | :--- | :---: | :--- |
| **Graphics** | Intel Iris Xe Graphics (`0x9a49`), Metal 2, 1536 MB Dynamic VRAM | <img src="https://img.shields.io/badge/Active-34D399?style=flat-square&logo=nvidia&logoColor=white" alt="Active" /> | Custom WhateverXe 0.8.2 binary preserved (`9e18e609...`). No driver overwrite. |
| **Display** | 1920×1080 @ 60 Hz, 30-Bit Color Depth (ARGB2101010) | <img src="https://img.shields.io/badge/Active-34D399?style=flat-square&logo=airplay&logoColor=white" alt="Active" /> | OLED / DPCD brightness & DSDT + SSDT-ASUS-FN intact. **HDR OFF** baseline strictly preserved. |
| **Global Hotkey** | Physical `PrtSc` mapped to virtual **F13** (`keyCode 105`) | <img src="https://img.shields.io/badge/Active-34D399?style=flat-square&logo=hotjar&logoColor=white" alt="Active" /> | Show/Hide window toggle while running. Carbon `buffer.count` (`Int`) fix verified. |
| **Core Audio** | Built-in 44.1 kHz in / 96 kHz out (layout-id 7 / alc-layout-id 48) | <img src="https://img.shields.io/badge/Active-34D399?style=flat-square&logo=apple-music&logoColor=white" alt="Active" /> | Master output volume slider supported. Speakers, mic, & jack switching preserved. |
| **Desktop Tweaks**| 9 Reversible Dock, Finder, and Appearance settings | <img src="https://img.shields.io/badge/Active-34D399?style=flat-square&logo=macos&logoColor=white" alt="Active" /> | Atomic restore journal (`~/Library/Application Support/KL-Asus/Restore-v1.plist`). |
| **CPU Telemetry** | 11th Gen Intel Core i5-1135G7 @ 2.40 GHz (8 logical cores) | <img src="https://img.shields.io/badge/Read--Only-60A5FA?style=flat-square&logo=intel&logoColor=white" alt="Read-Only" /> | Real dynamic load & memory counters. No fake overclocking or CPUFriend tampering. |
| **Thermals & Fans**| `SMCSuperIO`: 0, `AsusSMC`: 0 (No WMI / EC fan RPM sensor) | <img src="https://img.shields.io/badge/Disabled-9CA3AF?style=flat-square&logo=fanarttv&logoColor=white" alt="Disabled" /> | **Strict Rule:** Fan controls honestly unavailable. No fake sliders or simulated curves. |
| **Battery Health** | Service Recommended, 314 cycles, 2236 / 3549 mAh (~63% ratio)| <img src="https://img.shields.io/badge/Honest-FBBF24?style=flat-square&logo=battery&logoColor=white" alt="Honest" /> | Real ACPI reporting surfaced honestly; no fake software calibration or charge limits. |

<br/>

---

## 📸 Verified On-Device Screenshots

Native execution captured live on target hardware (`LOCAL • NATIVE` state):

<div align="center">

| 1. Overview Dashboard | 2. Performance & Sampling |
| :---: | :---: |
| <img src="docs/screenshots/overview.png" width="480" alt="Overview Dashboard" /> | <img src="docs/screenshots/performance.png" width="480" alt="Performance & Sampling" /> |

| 3. Display & Sound Controls | 4. About KL-06 & Hotkey Status |
| :---: | :---: |
| <img src="docs/screenshots/display-and-sound.png" width="480" alt="Display & Sound Controls" /> | <img src="docs/screenshots/about.png" width="480" alt="About KL-06 & Hotkey Status" /> |

</div>

<br/>

---

## 🚀 Key Highlights & Capabilities

<div align="left">

### 🎨 MyASUS-Inspired Modern Interface
- **Dark Mode Aesthetic:** Tailored specifically for 1080p OLED panels with rich contrast and low power footprint.
- **Micro-Metric Telemetry:** Real-time CPU utilization, active memory pressure, and Mach kernel task metrics rendered via hardware-accelerated WebKit canvas.
- **Tactile Visual Feedback:** Color-coded status pills indicating live bridge connectivity (`LOCAL • NATIVE`).

### ⌨️ Global Hotkey Toggle (F13)
- Instant show/hide overlay toggle bound to the physical `PrtSc` key mapped as virtual **F13** (`keyCode 105`).
- Low-overhead Carbon application event loop listener with native press/release latching.
- Auto-focus preservation: Prevents activation over system dialogs or active password prompts.

### 🔊 Core Audio & Display Management
- Direct master volume slider manipulating macOS default output device channels without audio degradation.
- Display brightness integration harmonized with Apple DPCD / OLED backlight controllers.
- Preserves paired DSDT and SSDT-ASUS-FN brightness hotkey tables.

### 🛠️ 9 Reversible Desktop Tweaks & Atomic Rollback
Safely tweak system-level cosmetic preferences with automatic atomic rollback journaling:
- **Dock Configuration:** Auto-hide delay, magnification toggle, active app indicators, orientation.
- **Finder Preferences:** Show file extensions, display path bar, toggle hidden files, default search scope.
- **Appearance & Window Behavior:** Animated window minimization and dark menu bar styling.
- *Safety Journal:* Every write persists prior state to `~/Library/Application Support/KL-Asus/Restore-v1.plist` before applying changes.

</div>

<br/>

---

## 🛡️ Security, Privacy & Privilege Invariants

```
┌────────────────────────────────────────────────────────┐
│                   WKWebView UI Layer                   │
│         Bundled Local HTML / CSS / Modern JS           │
└───────────────────────────┬────────────────────────────┘
                            │ Safe JSON Message Allowlist
                            ▼
┌────────────────────────────────────────────────────────┐
│             WKScriptMessageHandler (Native)            │
├────────────────────────────────────────────────────────┤
│  • Read-only Mach task & sysctl queries                │
│  • CoreGraphics & CoreAudio default device API         │
│  • Nine-key CFPreferences registry with write verify   │
│  • Atomic restore journal check before write           │
│  • Bounded powermetrics sampler (user-authorized only) │
└───────────────────────────┬────────────────────────────┘
                            │
                            ▼
┌────────────────────────────────────────────────────────┐
│                   Target macOS Sequoia                 │
│      NO root daemons • NO kexts • NO EFI tampering     │
└────────────────────────────────────────────────────────┘
```

> [!IMPORTANT]
> **Strict Safety Standards:**
> 1. **Zero Network Traffic:** Enforces `connect-src 'none'`. No remote analytics, telemetry reporting, or auto-updaters.
> 2. **User-Space Privileges:** Runs strictly in user space (`UID 501`). No root daemons, background agents, or kernel extensions.
> 3. **Non-Destructive EFI Policy:** Never modifies OpenCore configs, ACPI tables, boot arguments, or WhateverGreen / WhateverXe binaries.
> 4. **No Simulated Controls:** Fan RPM sensors are missing on this hardware (`SMCSuperIO: 0, AsusSMC: 0`); therefore, fan controls are honestly disabled rather than faked with simulated sliders.

<br/>

---

## 📦 Download & Quick Installation (Beta)

> [!TIP]
> Download the pre-built, tested release binary directly from GitHub Releases:

1. **Download:** Grab [**`KL-06.zip`**](https://github.com/Kaushal-snap/KL-06-Manager/releases/tag/v0.3.0-beta.1) from the v0.3.0-beta.1 release (or use the [Google Drive Direct Download Mirror](https://drive.google.com/uc?id=1sewP7SFL_52wkvWgeu9pueWXp_wWmp0f&export=download)).
2. **Extract:** Double-click `KL-06.zip` to extract `KL-06 Manager.app`.
3. **Deploy:** Drag `KL-06 Manager.app` into `/Applications` (or test directly from `Downloads`).
4. **Launch & Toggle:** Open `KL-06 Manager.app` and press **`PrtSc` (F13)** anytime to summon or dismiss the control center.

### 🔐 Cryptographic Checksums & Binary Verification

```bash
# Verify release archive integrity (Clean Release ZIP)
shasum -a 256 KL-06.zip
# Expected: acf8991e078e676509ddcfdc3ddc1ec5503e6802a2749078eef82f19925bec8e

# Verify original intake archive integrity (Owner Build ZIP)
# SHA-256: df8582014df1e405c66125d8c0c7811b88cd6edfedc1bdda3c2c41cc89d6ec7d

# Verify Mach-O binary architecture and checksum
shasum -a 256 /Applications/KL-06\ Manager.app/Contents/MacOS/KL-06
# Expected: 4cb9aecf1cc460ed872d2260a1e9cd833d447585ffde77b4ab5cf152c748c3ba
# Architecture: Mach-O 64-bit executable x86_64
```

<br/>

---

## 🌌 Active Milestone: v0.3.0-beta.1 (Cirrus Theme / Build 4)

Native physical hardware compilation and verification completed on target ASUS VivoBook K15 OLED (K513EA):

| Feature Milestone | Status | Description |
| :--- | :---: | :--- |
| **Cirrus OLED-Dark Theme** | <img src="https://img.shields.io/badge/Verified-10B981?style=flat-square" alt="Verified" /> | High-contrast dark theme with bespoke gradients optimized for OLED panels. |
| **AppleSMC Fan Reader** | <img src="https://img.shields.io/badge/Verified%20Read--Only-10B981?style=flat-square" alt="Verified Read-Only" /> | Auditable read-only C reader querying standard `FNum` and `F0Ac`/`F1Ac` keys. |
| **Honest Fan Reporting** | <img src="https://img.shields.io/badge/Honest%20Unavailable-F59E0B?style=flat-square" alt="Honest Unavailable" /> | Sensor unavailable state reported honestly on target Hackintosh hardware. |
| **HWiNFO Telemetry Parser** | <img src="https://img.shields.io/badge/Verified-10B981?style=flat-square" alt="Verified" /> | Local Windows CSV importer supporting unpadded-second timestamps. |
| **Native Target Compile** | <img src="https://img.shields.io/badge/Native%20Sequoia%20Verified-10B981?style=flat-square" alt="Verified" /> | Compiled natively via `UPDATE-KL-06.command` on macOS Sequoia 15.8.3. |

<br/>

---

## 🔒 Proprietary License & Closed-Source Rights

**Copyright © 2026 Kaushal-snap. All Rights Reserved.**

This software is distributed in compiled binary form for testing and validation on verified hardware targets. Unauthorized copying, reverse engineering, redistribution, decompilation, or modification of this application or associated binary assets is strictly prohibited without express written permission.
