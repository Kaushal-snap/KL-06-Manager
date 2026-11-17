<div align="center">

# 🛡️ KL-06 Architecture & Privilege Boundary

[![Security Boundary](https://img.shields.io/badge/Security-Privilege%20Boundary-7C3AED?style=for-the-badge&logo=shield&logoColor=white)](ARCHITECTURE.md)
[![Execution Privilege](https://img.shields.io/badge/Execution-User%20Space%20(Non--Root)-059669?style=for-the-badge&logo=apple&logoColor=white)](ARCHITECTURE.md)
[![Telemetry](https://img.shields.io/badge/Telemetry-Zero%20Network%20Outbound-0284C7?style=for-the-badge&logo=cloudflare&logoColor=white)](ARCHITECTURE.md)
[![Invariants](https://img.shields.io/badge/Invariants-Enforced%20Honesty-F59E0B?style=for-the-badge&logo=checkmarx&logoColor=white)](ARCHITECTURE.md)

<p align="center">
  <a href="README.md">🏠 Overview & Downloads</a> •
  <a href="CHANGELOG.md">📋 Release Changelog</a> •
  <a href="ECOSYSTEM.md">🌐 Multi-Device Ecosystem</a> •
  <a href="HARDWARE-REPORTS.md">📊 Hardware Telemetry</a> •
  <a href="COMPONENT-REPORT.md">🧪 Component Intake</a>
</p>

---

</div>

<br/>

## 🏛️ Core Control & Privilege Flow

```
Bundled local HTML/CSS/JS (same files as honest browser demo)
        │ {id, method, params} + fixed UI allowlist
        ▼
WKScriptMessageHandler — exact bundled MAIN-FRAME file URL only
        ├── state → Mach/sysctl, numerical IOKit battery fields, IOPS, Metal, CoreGraphics, Core Audio
        ├── volume → supported, settable default-output volume channels only
        ├── tweak → known nine-key registry → native confirmation → private journal → CFPreferences write/read-back
        ├── restore → saved original only; conflict/managed/journal checks; no guessed defaults
        ├── settings → fixed pane URLs opened by NSWorkspace, no settings write
        ├── UI relaunch → confirmed Dock/Finder requests only
        ├── keep awake → confirmed child caffeinate, -i -t 900, stopped on quit
        ├── power sample → native consent → OS authorization → ONE fixed, bounded powermetrics command
        └── export → native save panel → minimized state, no raw diagnostics
```

There is no daemon, kext, socket server, download/update action, generic command runner or network endpoint. The Python development preview serves only static demo assets and is not part of the app. The executable runs at the logged-in user's privilege; only the fixed optional sampler requests OS-local authorization. Preferences and the restore journal are written only after a user asks and confirms; opening the app is read-only.

<br/>

## ⌨️ F13 Global Hotkey Boundary (v0.2.1)

`F13HotKey` installs a Carbon application-target handler for this app's own hotkey pressed/released events and calls `RegisterEventHotKey(105, 0, ...)`. Only that registration's signature/ID reaches a one-press latch and pure window-toggle policy. Holding the key cannot repeatedly toggle. Active visible window → hide; background/closed/minimized → show; a modal/sheet → focus it, never hide it. The handler does nothing while optional power authorization/sampling is in flight, avoiding activation over a separate OS-owned prompt. This action has no preference, bridge, shell, sample or firmware operation.

There is no raw keyboard monitor/event tap, remapping, key log, Accessibility/Input Monitoring permission request, startup helper or activation when the app is not running. Unregister removes only the returned app-owned references; partial failures clean up the handler. Registration failure is surfaced in a native alert, menu and About state, not disguised as success or replaced by a broader monitor. Quit unregisters the key. A fixed F13 reservation intentionally consumes this key while the app runs; another app/system shortcut can conflict. Native tests exercise the pure policy and press/release latch without registering a real shortcut; portable source/browser checks cannot certify real global key delivery.

<br/>

## 🔒 Atomic Restore Invariants

1. Source definitions, not UI parameters, choose the preference domain/key/target.
2. Original absence is distinct from an explicit false or a presumed default.
3. Persist a private atomic restore entry BEFORE first write. Save failure means no system preference write.
4. Verify the written value. Failure retains the record for review; no automatic retry or “repair”.
5. Restore only if the current value still equals what KL-06 applied. Otherwise skip the newer external choice.
6. Corrupt, oversized, unknown-ID or symlink restore journals block new changes. Managed preferences are never changed.
7. Relaunch Dock/Finder is a separate informed action; never kill unrelated processes or reset the session.

These guardrails do not claim immunity to a malicious process already running as the same user, nor replace a backup. There is no filesystem/firmware undo feature. The journal is limited to this app's nine desktop keys.

<br/>

## 🎯 Honesty Invariants & Safety Guardrails

- Demo charts are marked illustrative and controls cannot change or simulate a persisted system state.
- Native bridge failures show unavailable/stale; no substitution of demo values or fabricated zero sensors.
- CPU load is not frequency, power, thermal compliance or XCPM correctness.
- Reported ACPI capacity ratio is not independent battery-health measurement.
- `supportsFamily(.metal3)` is one capability query, not Metal API-version marketing or passed GPU workloads.
- Settings shortcuts are labelled as such. Windows ASUS firmware controls stay unavailable until a separately audited, exact-device implementation exists.
- Existing USB function is owner-reported; this app neither maps it nor changes its validation status.

<br/>

## 🌐 Multi-Device Ecosystem & Transfer Boundary

KL-06 supports authenticated multi-device companion roles (macOS, Windows, Android, iOS):
- **Local Private LAN Only (RFC 1918):** No public tunnels, third-party cloud relays, or open ports.
- **Explicit Pairing & Out-of-Band Verification:** Requires 32-character random pair code and TLS certificate SHA-256 fingerprint verification from the host dialog.
- **Two-Way Streamed File Transfer:**
  - Receiver explicitly accepts or declines before byte streaming begins.
  - Slashes, traversal (`..`), NUL bytes, ADS streams, and DOS reserved names are permanently rejected.
  - Streaming SHA-256 calculation verifies integrity before finalization; partial files automatically cleaned on abort.
- **Secure Signed OTA Catalog:**
  - Pinned Ed25519 root trust key verifies update metadata before trusting URLs.
  - Monotonic versioning strictly blocks downgrade attacks.
  - Platform installation handoff respects operating system security (Android `PackageInstaller` intent, iOS TestFlight/Store redirect, macOS/Windows verified manual handoff).

<br/>

## 🧪 Review & Test Boundary

Portable Node tests check the UI model, validation, demo isolation, privacy/CSP and native-source boundaries. Browser tests exercise navigation/responsiveness and mocked native action wiring, never actual hardware controls. Swift grammar parsing is not compilation. Native tests use dependency-injected fake preferences and a temporary journal; they are supplied for the Mac but cannot be executed in the Linux environment. Actual native compilation, settings effects/restore, menu-bar/window behavior, Core Audio, power authorization/sensors and battery/display queries remain target-verification work.

<br/>

## 🏷️ Generic-Device & Rename Continuity

The new visible name/executable is KL-06. The legacy `app.klasus.controlcenter` bundle identity and `KL-Asus/Restore-v1.plist` path are deliberately unchanged for restore continuity. Quit old builds before opening this one; no journal migration, deletion or overwritten baseline is attempted.

The UI no longer calls every machine an ASUS or reuses the first owner's audio/USB claims. Independent standard-API capabilities are derived from actual returned fields. GPU/device presence never turns into an invented usage value or a fan/clock control. The separate Bash intake collector is not executed automatically by the app; it produces an unreviewed text file for its owner's local privacy check and optional Arena submission. That observation cannot promote any device to tested/approved.
