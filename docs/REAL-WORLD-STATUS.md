# KL-06 real-world status and verification plan

This file distinguishes implemented source paths from tested device behaviour. A successful permission prompt, pairing response, share-sheet launch, or GitHub Pages deployment is not proof of a working transport.

## Current transport matrix

| Path | Source status | Honest status |
|---|---|---|
| Android -> macOS/Windows desktop broker | Android native sender and shared TLS broker exist; chunks are 8 KiB to stay below the broker's 16 KiB JSON request limit | End-to-end device test still required |
| iOS -> desktop | iOS pairing/state client exists; no native file sender | Not implemented |
| macOS -> phone/PC | macOS desktop candidate has no file sender | Not implemented |
| Windows -> phone/Mac | Windows desktop candidate has no file sender | Not implemented |
| Android/iOS/macOS/Windows discovery | Android UDP scan + desktop UDP responder exist; macOS and iOS no longer return fabricated peers | Partial; Windows/iOS/macOS discovery is not implemented |
| Bluetooth transfer/discovery | No KL-06 Bluetooth transport implementation | Not implemented |
| Cellular/mobile-data relay | No relay server, NAT traversal, or authenticated internet endpoint | Not implemented |
| Wi-Fi / personal hotspot | Same private subnet + desktop broker can be used | Supported route in source; router/client isolation and device firewall can still block it |

### Pairing requirements

The current desktop broker is a private-LAN HTTPS service on TCP/UDP port 8766. Mobile direct pairing requires all three values displayed by the desktop:
1. HTTPS URL with the desktop's private LAN IPv4 address.
2. Full SHA-256 certificate fingerprint.
3. 32-character session pairing code.

The old 6-digit PIN UI was not connected to this protocol and has been marked unsupported. Permission grants do not mean a peer is connected.

### Transfer notes

- Android's native streamFileToPeer path hashes the selected file, initiates a transfer, and sends chunks to the desktop broker.
- The broker enforces a 16 KiB maximum JSON request body; Android chunks were reduced from 64 KiB to 8 KiB to fit the base64-encoded payload.
- The broker currently auto-approves a transfer from an already-paired token into the desktop Downloads folder. Per-file receiver confirmation is not yet implemented and is a remaining security/product requirement.
- iOS, macOS and Windows sender paths are not implemented end-to-end. A system share sheet is only an OS handoff; it does not confirm KL-06 delivery.
- No device-to-device transfer has been physically tested by this patch. Do not label the path verified until sender and receiver builds are installed and a checksum-matched file is received.

## Fan RPM on macOS

The native macOS reader queries only standard AppleSMC keys FNum, F0Ac and F1Ac and reports provider status without writing to the SMC or embedded controller. It does not install a driver or synthesize RPM.

If the Hackintosh's existing VirtualSMC/SMC provider does not publish these tachometer keys for the ASUS K513EA, the app cannot truthfully show RPM. This patch does not add an unverified ACPI-EC write/read path or fan-control driver. A real fix requires a read-only hardware report from the target Mac and a model-specific provider path, then a physical test against actual fan behaviour.

## UI refresh

- Shared mobile UI no longer redraws the whole page on every five-second telemetry poll; macOS state is accepted as macos.
- The macOS app now polls without rebuilding the page every two seconds; manual refresh and user actions still update the view.
- User-triggered actions may still cause a single content update. Focused text fields should be retested on the installed Android and iOS builds.

## Logs and Google Drive

- The shared web log buffer is local app storage. Android can write a local diagnostic report and open the OS share sheet; iOS opens a share sheet; macOS exports a user-selected file.
- No native app currently performs an authenticated Google Drive API upload to the private folder.
- The existing GitHub Actions Workload Identity configuration is a release-automation path, not runtime mobile/macOS log authentication.
- Runtime Drive sync requires Google OAuth client configuration for each native app, a Drive scope, secure refresh-token storage (Keychain/Android Keystore/Windows credential storage), and a verified folder-write test. No client IDs or tokens are embedded in this public repository.
- Until that is configured, the app must report Drive sync as not configured, never as connected or successful.

## Required device verification

1. Build fresh macOS, Android and iOS apps from this branch; Windows build must also be compiled before claiming support.
2. Put Android and the desktop on the same private Wi-Fi/hotspot subnet.
3. Start the desktop temporary companion, scan from Android, compare fingerprint and session code, pair, and finish pairing.
4. Send a small file and a multi-megabyte file; verify destination, byte count and SHA-256 independently.
5. Repeat with Wi-Fi client isolation/firewall enabled to confirm the expected failure message; do not fall back to fake peers.
6. On the ASUS K513EA Hackintosh, capture the fan report and confirm whether FNum, F0Ac, and F1Ac are exposed by the active SMC provider.
7. Verify that logs are only reported uploaded after a successful authenticated Drive API response.

Until those checks pass, VERSION.json keeps native and end-to-end verification flags false.
