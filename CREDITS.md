# Credits and attribution

This file records the upstream and community work used, adopted, modified or referenced
by fixes published in this repository. Current source/manifest credits are reviewed
explicitly; the publishing helper never invents authorship or licensing.

Attribution categories used throughout this repository:

- **Directly adopted** — code/configuration used unchanged from upstream.
- **Modified upstream** — upstream work changed for this laptop.
- **Community patch** — a patch published by another contributor.
- **Independent implementation** — original work for this machine.
- **Experimental** — not yet verified on hardware.
- **Inspired by** — approach informed by another project; not copied.

No credit in this file is invented. If a source is unknown, it is left unlisted rather
than guessed.

## Project

- **Kaushal-snap** — Repository owner, hardware owner and tester for the ASUS VivoBook
  K15 OLED (K513EA) Tiger Lake-U Hackintosh.

## Upstream and community sources

<!-- entries appended automatically by scripts/publish-fix.sh -->


[Buy Me a Coffee](https://buymeacoffee.com/KL06)
- **acidanthera/BrightnessKeys** ([source](https://github.com/acidanthera/BrightnessKeys)) — Reference for brightness hotkey event handling architecture. Contributor: vit9696 (Acidanthera) (commit `BrightnessKeys.kext 1.0.4 reference`). License: Check upstream repository.
- **Kaushal-snap/ASUS-VivoBook-K15-OLED-Hackintosh** ([source](https://github.com/Kaushal-snap/ASUS-VivoBook-K15-OLED-Hackintosh)) — Reference config.plist, DeviceProperties, and ACPI tables for K513EA. Contributor: Kaushal-snap (commit `reference EFI configuration`). License: MIT.
- **hieplpvip/AsusSMC** ([source](https://github.com/hieplpvip/AsusSMC)) — Reference for ACPI ATK device handling and keyboard backlight control. Contributor: hieplpvip (commit `AsusSMC VirtualSMC plugin reference`). License: MIT.
- **acidanthera/OpenCorePkg** ([source](https://github.com/acidanthera/OpenCorePkg)) — Reference for kext development practices. Contributor: Acidanthera (commit `KextInfo.plist structure and kext development patterns reference`). License: Check upstream repository.


## Current WEX/OLED multi-version architecture (2026-11-16)

- **Kaushal-snap** — owner/current Sequoia tester; supplied EFI and [OLED/DPCD/Fn source](https://github.com/Kaushal-snap/OLED-Display-Fix-Hakintosh/tree/a26005c17fd8f7f6d435bf72f964def42d491a75). Unchanged owner SSDT source + MIT license retained; active binaries preserved privately by hash.
- **b00t0x / WhateverXe** — [audited source](https://github.com/b00t0x/WhateverXe/tree/2bad71718c6b4f9887e2a504a19a24c3593ea1db), BSD-3-Clause retaining original WhateverGreen notices. Official backend/compatibility reference; custom owner binary is not replaced with stock.
- **b00t0x / WhateverXe-Graphics** — [audited package/signing sources](https://github.com/b00t0x/WhateverXe-Graphics/tree/61c7cddda38d6a5d0057a01f402aab6efb612e13), including Mod AMFIPass requirements. Referenced, not redistributed/installed here; mixed third-party notices remain applicable.
- **WilliamAlexanda's published RedmiBook community patches** — [exact patch source revision](https://github.com/WilliamAlexanda/macOS-for-RedmiBook-Pro-15-2021/tree/07bafb76f99abbdbf6a87493decb53be9fde1cc9/patches/whateverxe-0.8.0), 02/03 file hashes recorded. Original patch authorship retained where documented; no blanket MIT claim or unreviewed source redistribution.
- **Acidanthera and supplied kext projects** — Lilu/SMC/audio/brightness/input/USB/wireless/boot tooling retained by locked owner input or referenced as development tools. Per-component provenance/license review is required; root MIT does not cover every third-party binary.
- **New maintenance tooling/tests/workflows** — independent implementation in this branch, separate from upstream graphics patch authorship. No on-device graphics or future-OS validation is claimed.

See docs/THIRD-PARTY.md and locks/ for exact files/revisions/digests and unresolved provenance. Historical credit is not evidence that a historical graphics stack is active in the new Tahoe profile.

## KL -Asus companion (2026-11-16)

- **Kaushal-snap project / new utility implementation** — independently implemented app/UI, original vector/raster icon, native bridge, journal, tests and local build scripts. Uses Apple platform frameworks without redistributing them; not affiliated with ASUS or Apple. No ASUS MyASUS code, USBToolBox binary, kernel/graphics driver or third-party app source is bundled. Existing graphics/Fn upstream attribution above remains unchanged.

## KL-06 update

KL -Asus was renamed to KL-06; new generic report/projection, capability UI, F13 hotkey/wrapper and associated tests are independent project maintenance code. Legacy identity/journal paths are retained for restore continuity. The F13 registration uses the system Apple Carbon API (no Apple framework binaries or third-party hotkey library are redistributed). No additional ASUS, DTS, fan/EC or third-party driver implementation was imported or relicensed.

The component capability collector independently extends the project's minimized report code using macOS built-ins. No third-party SMC/fan tool, firmware controller or driver implementation is bundled.

## Verification-only legacy shell

GNU Bash 3.2.57 (Free Software Foundation, GPLv2-or-later), official source `https://ftp.gnu.org/gnu/bash/bash-3.2.57.tar.gz`, observed SHA-256 `3fa9daf85ebf35068f090ce51283ddeeb3c75eb5bc70b1a4a7cb05868bfe06a4`, was built only in the excluded sandbox development cache to reproduce the macOS-family parser failure. A Debian Bison 3.8.2 development tool regenerated its parser. Neither tool, source, binary nor generated code is bundled with KL-06 or the collectors. This is Linux legacy-shell verification, not use of Apple's Bash binary or Mac hardware testing.
