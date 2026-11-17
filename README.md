# KL-06 Manager

**KL-06 Manager** is an independent local macOS control center companion utility designed specifically for modern Hackintosh systems, tested and verified on the **ASUS VivoBook K15 OLED (K513EA)** running **macOS Sequoia 15.8.3** (Intel Core i5-1135G7 Tiger Lake-U, Intel Iris Xe Graphics).

> **Notice:** This is a private and proprietary companion project. It is **not open source** and is not affiliated with, sponsored by, or endorsed by ASUSTeK Computer Inc. or Apple Inc. All rights reserved.

---

## Current Status: Beta

- **App Version:** `0.2.1` (Build `3`) — Beta Phase
- **Execution Mode:** `LOCAL • NATIVE` (AppKit, WebKit, IOKit, Core Audio, Metal)
- **Target OS:** macOS Sequoia 15.8.3 (Build 24H241 / Darwin 24.6.0 / x86_64)
- **Bundle Identifier:** `app.klasus.controlcenter`
- **Restore Journal:** `~/Library/Application Support/KL-Asus/Restore-v1.plist`

---

## Verified Target Hardware & Capabilities

| Subsystem | Target Observation | Safe Policy & Enforced Boundary |
| :--- | :--- | :--- |
| **Graphics & Display** | Intel Iris Xe (0x9a49), Metal 2, 1536 MB dynamic VRAM, 1920×1080 @ 60 Hz, 30-bit color depth. | Custom WhateverXe 0.8.2 binary preserved (`9e18e609...`). OLED/DPCD brightness and paired DSDT + SSDT-ASUS-FN preserved. **HDR OFF baseline preserved** (30-bit framebuffer is not HDR workload certification). |
| **CPU & Telemetry** | 11th Gen Intel Core i5-1135G7 @ 2.40 GHz (4 physical / 8 logical cores). System avg: ~1530 MHz, CPU avg: ~1350 MHz, pkg power: ~6.14 W, die temp: ~46.0 °C. | Honest read-only sampling. No fake clock boost, overclocking, undervolting, or arbitrary ACPI writes. |
| **Thermals & Fans** | `SMCSuperIO` count: 0, `AsusSMC` count: 0. **No fan RPM reported.** | **Strict non-negotiable rule:** Absolutely no fan controls, no simulated curves, no EC/SMC writes. Fan panel is honestly marked as unavailable. |
| **Battery Health** | State of charge: ~80%, Condition: "Service Recommended", 314 cycles, 2236 mAh / 3549 mAh design (~63.0% reported ratio). | OS condition surfaced honestly; no fake battery "re-calibration" or charge-limit writes without verified hardware interfaces. |
| **Audio & USB** | Built-in 44.1 kHz input / 96 kHz output; layout-id 7 vs alc-layout-id 48 confirmed working (speakers, internal mic, headphone jack). 15 USB host ports. | Audio and USB port mappings preserved without modification. Supported output volume scalar managed via Core Audio. |
| **Global Shortcut** | Physical `PrtSc` mapped to virtual **F13** (keyCode 105, no modifiers). | Toggles window show/hide while app runs. Carbon `buffer.count` (`Int`) fix and native dialog focus protection preserved. |

---

## On-Device Target Verification Screenshots

The screenshots below demonstrate native on-device execution of **KL-06 Manager** on the ASUS VivoBook K15 OLED running macOS Sequoia:

| Overview Dashboard | Performance & Sampling |
| :---: | :---: |
| ![Overview](docs/screenshots/overview.png) | ![Performance](docs/screenshots/performance.png) |

| Display & Sound Controls | About & Privilege Boundary |
| :---: | :---: |
| ![Display & Sound](docs/screenshots/display-and-sound.png) | ![About KL-06](docs/screenshots/about.png) |

---

## Features & Reversible Desktop Controls

1. **Dashboard & Telemetry:**
   - Real-time CPU utilization aggregate load.
   - Memory breakdown (active, wired, compressed, swap).
   - Local storage usage and available space.
   - Battery charge percentage and reported health ratio.
   - Core Audio master output volume slider.

2. **Reversible Preferences (Atomic Restore Journal):**
   - Nine reversible Dock, Finder, and appearance settings.
   - Every change persists original state to `~/Library/Application Support/KL-Asus/Restore-v1.plist` before applying.
   - Restores original values accurately; skips external conflicting modifications.

3. **Privacy & Sandboxing:**
   - Zero cloud connectivity, no telemetry, no tracking daemons.
   - WebKit UI operates under strict Content Security Policy (`connect-src 'none'; default-src 'none'`).
   - Private reports (`REPORT.txt`), machine identifiers (SMBIOS serials, UUIDs), and raw EFI backups are never published.

---

## Releases & Downloads

Tested app builds are packaged and published as **Beta Prereleases**:
- **Latest Beta Release:** [KL-06 Manager v0.2.1 Beta (Build 3)](https://github.com/Kaushal-snap/new/releases/tag/v0.2.1-beta.3)
- **Artifact:** `KL-06.zip` (Tested `.app` bundle, SHA-256: `ee499aafcd36663e06cfe6c19f04f7d422c1f6b5c98fa8663c4eca9128c33317`)

---

## Legal & Privacy Notice

Copyright © 2026 Kaushal-snap. All Rights Reserved.  
Private & proprietary utility. Unauthorized reproduction, distribution, or reverse engineering is prohibited.
