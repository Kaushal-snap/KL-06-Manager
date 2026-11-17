# KL-06 Manager Changelog

## 0.2.1-beta (Build 3) — Verified Target Prerelease (Beta Phase)

- **Target Verification:** Verified native run on ASUS VivoBook K15 OLED (K513EA), macOS Sequoia 15.8.3 (i5-1135G7 Tiger Lake-U).
- **Execution Confirmation:** Verified `LOCAL • NATIVE` execution status, responsive Core Audio volume control, and accurate CPU/memory/battery telemetry.
- **Global Hotkey:** Verified registration and window show/hide toggling via global F13 (virtual keyCode 105, no modifiers) with Carbon `buffer.count` (`Int`) fix.
- **Screenshots:** Added native on-device screenshots documenting Overview, Performance, Display & Sound, and About pages.
- **Artifact Intake:** Integrated and validated owner-tested `KL-06.zip` (SHA-256: `ee499aafcd36663e06cfe6c19f04f7d422c1f6b5c98fa8663c4eca9128c33317`).
- **Release Automation:** Configured `scripts/validate_and_stage_release.py` and GitHub Actions workflow template with strict archive validation and draft/beta prerelease enforcement.
- **Preservation Rules Maintained:** Custom WhateverXe 0.8.2 binary, OLED/DPCD brightness, paired DSDT/SSDT-ASUS-FN, and HDR-OFF baseline preserved. Fan controls honestly marked unavailable; no fake sliders or simulated curves.
- **Privacy Enforcement:** Raw proprietary source code removed from public staging; project marked private/not open source. Private reports, EFI binaries, and credentials strictly excluded.

## 0.2.1 (Build 2) — F13 Event Handler Correction

- Fixed `InstallEventHandler` event count parameter type mismatch (`UInt32` to `Int`) in `HotKey.swift`.
- Preserved bundle identifier `app.klasus.controlcenter` and restore journal `~/Library/Application Support/KL-Asus/Restore-v1.plist`.
- Maintained standalone hardware intake collectors v1.1 with Bash 3.2 literal filter loader repair.

## 0.1.0 — Initial Prototype Baseline

- Renamed visible application to KL-06 with MyASUS-inspired UI.
- Implemented nine reversible desktop tweaks with atomic restore journaling.
- Real CPU/memory usage counters and Core Audio output volume support.
