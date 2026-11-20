# KL-06 manual fan control — ASUS VivoBook K513EA

## Current implementation status

Manual fan writes are intentionally **not enabled** on either desktop platform. The current macOS reader (macos/Sources/SMCReader.c) implements only fixed SMC read-key-info (9) and read-value (5) operations for FNum, F0Ac, and F1Ac. It has no target/mode write operation. FanMonitor.swift reports manualControl: false.

The Windows native host currently exposes system telemetry and an allowlisted set of desktop controls; it has no validated ASUS EC/WMI fan-write provider. Historical HWiNFO CSV import is not a live control API.

## Why a slider is not enabled yet

A UI-only percentage control would be misleading: it could change a number without changing the physical fan. K513EA fan control depends on the exact BIOS/EC firmware, ACPI/WMI interface, and whether the installed Windows/VirtualSMC stack exposes a supported writable method. A generic EC register write or guessed SMC key can freeze fans, overheat the system, or leave firmware in a non-default mode.

## Required implementation gates

1. **Identify, don't guess:** collect exact K513EA BIOS version and a narrowly scoped read-only inventory of ASUS WMI/ACPI/EC and SMC providers. Do not dump serials or full raw IORegistry.
2. **Windows provider:** determine whether the installed ASUS platform exposes a documented vendor WMI method or supported ASUS service/API for fan mode/curve. Do not write arbitrary EC registers. If the supported interface is absent, keep Windows control unavailable.
3. **macOS provider:** determine whether the exact Intel Hackintosh's VirtualSMC/ASUS ACPI stack has a documented, supported fan-control interface. Standard AppleSMC fan RPM reads do not imply target writes. No speculative SMC key writes.
4. **Capability handshake:** native backend must report provider identity, supported fan count, supported modes/range, current mode, and whether a write is supported. UI stays disabled unless every field is verified.
5. **Guarded command:** allow only documented modes/steps, require explicit confirmation, bound requests, verify readback, rate-limit changes, and provide a firmware/automatic restore path on app exit, crash recovery, sleep, thermal fault, or provider loss.
6. **Thermal fail-safe:** never allow fan-off or below-firmware-safe minimum. If temperature telemetry is missing/stale, reject manual changes and restore automatic firmware mode. Never claim a requested speed is applied without readback.
7. **Physical test:** validate on the exact K513EA, exact BIOS and OS build under light/normal load; verify RPM and temperatures, sleep/wake, app crash, and reboot restore. Only then enable the UI and publish a release.

## Current app behavior

- macOS: RPM snapshot is read-only. Manual control is disabled.
- Windows: diagnostics/history remain separate from live control. Manual control is disabled.
- iOS/Android: no fan-control UI.
- No kernel extension, driver, privileged helper, root service, firmware/EFI write, or arbitrary EC write is installed or invoked.

## Owner data needed for the next engineering step

Run macos/DIAGNOSE-ASUS-FAN-PATH.command on the native Intel Hackintosh and provide its small TXT report. On Windows, provide the exact BIOS version from msinfo32 and the ASUS System Control Interface / MyASUS version (if installed). These identify which documented provider, if any, can be investigated. Do not share serial numbers.
