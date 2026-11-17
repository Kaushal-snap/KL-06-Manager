# KL-06 source-snapshot changelog

## 0.2.1 (Build 3) — Tested Target Native Verification & Beta Prerelease

- **Target Verification:** Verified native run on ASUS VivoBook K15 OLED (macOS Sequoia 15.8.3, i5-1135G7). Confirmed `LOCAL • NATIVE` execution, Core Audio volume control, and telemetry counters operational.
- **F13 Hotkey:** Confirmed registration and operation of global F13 (virtual keyCode 105, no modifiers) window toggle with Carbon `buffer.count` (`Int`) fix.
- **Visual Evidence:** Added on-device screenshots documenting Overview, Performance, Display & Sound, and About views.
- **Release Automation:** Configured `scripts/validate_and_stage_release.py` and `.github/workflows/import-drive-release.yml` with strict archive safety, bundle identity (`app.klasus.controlcenter`), checksum verification, and draft prerelease staging.
- **Drive Handoff Intake:** Integrated owner-tested `KL-06.zip` (SHA-256: `ee499aafcd36663e06cfe6c19f04f7d422c1f6b5c98fa8663c4eca9128c33317`).
- **Hardware Safety Preserved:** Fan RPM and controls remain honestly unavailable; no fake sliders or EC/SMC writes. Metal 2 and HDR-OFF baseline preserved.

## 2026-11-16 — current source handoff, not a new native release

- App remains 0.2.1/build 3 with the owner's general working-fine report. No new UI/control/build was implemented in this transfer.
- Retains the F13/keyCode105/no-modifier show-hide hotkey and corrected InstallEventHandler buffer.count type. Portable checks do not establish native SDK or hardware behavior.
- Includes current generic/component collectors v1.1 with the Bash 3.2 literal-loader repair. Owner supplied a complete REPORT.txt separately; private reports are not bundled here.
- More polished independent MyASUS-inspired UI, continuous GPU/sensor providers and safe hardware-control investigation are future work. No verified fan/clock/charge/HDR/DTS/system-mic-DSP provider is claimed.
- No GitHub publication, workflow scheduling or automatic Drive-to-release connection was deployed.

## Existing app baseline

- KL -Asus was renamed KL-06 while preserving bundle identity and restore journal.
- Real CPU/memory reporting, supported volume/settings, bounded keep-awake and nine reversible user preferences exist. Unsupported firmware features remain unavailable.
