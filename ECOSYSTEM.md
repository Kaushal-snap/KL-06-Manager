<div align="center">

# 🌐 KL-06 Multi-Device Ecosystem Specification

### *Secure Two-Way File Transfer & Authenticated OTA Updates*

[![Ecosystem](https://img.shields.io/badge/Ecosystem-Multi--Device%20Companion-2563EB?style=for-the-badge&logo=apple&logoColor=white)](ECOSYSTEM.md)
[![Transfer](https://img.shields.io/badge/Transfer-Encrypted%20Streamed%20IO-059669?style=for-the-badge&logo=checkmarx&logoColor=white)](ECOSYSTEM.md)
[![Updates](https://img.shields.io/badge/OTA-Signed%20Catalog%20Verification-7C3AED?style=for-the-badge&logo=shield&logoColor=white)](ECOSYSTEM.md)
[![Privacy](https://img.shields.io/badge/Privacy-Zero%20Cloud%20Relay-EA580C?style=for-the-badge&logo=lock&logoColor=white)](ECOSYSTEM.md)

<p align="center">
  <a href="README.md">🏠 Home</a> •
  <a href="ARCHITECTURE.md">🛡️ Architecture</a> •
  <a href="CHANGELOG.md">📋 Changelog</a> •
  <a href="HARDWARE-REPORTS.md">📊 Hardware Reports</a>
</p>

---

</div>

<br/>

## 1. 📡 Multi-Device Route Matrix

KL-06 supports authenticated peer-to-peer communication across macOS, Windows, Android, and iOS. All endpoints require mutual session authorization, local-network isolation (RFC 1918), and explicit user consent.

| Route Pair | Direction | Route Category | Transport Mechanism | Trust & Privacy Policy |
| :--- | :---: | :---: | :--- | :--- |
| **macOS ⟷ Windows** | Two-way | Direct LAN | Authenticated TLS 1.2+ streaming socket | Direct peer-to-peer. Zero cloud relays. Native destination pickers. |
| **macOS ⟷ Android** | Two-way | Direct LAN | Storage Access Framework (SAF) URI streamed IO | App-scoped directory or SAF user grant. No `MANAGE_EXTERNAL_STORAGE`. |
| **macOS ⟷ iOS** | Two-way | Direct LAN | Security-scoped document container + URLSession | Public document picker. Foreground lifecycle enforced. |
| **Windows ⟷ Android** | Two-way | Direct LAN | Windows filesystem ⟷ Android SAF content stream | Standard user privileges. No elevated ACL modification. |
| **Windows ⟷ iOS** | Two-way | Direct LAN | Windows filesystem ⟷ iOS Security-scoped container | User selects save destination on both endpoints. |
| **Android ⟷ iOS** | Two-way | Direct LAN & Hotspot (AirDrop / Quick Share / Xender) | Authenticated TLS 1.2+ streaming socket & desktop forwarder | Direct Wi-Fi, Personal Hotspot (e.g. 172.20.10.x / 192.168.43.x), or desktop hub; end-to-end verified via SHA-256. |
| **Over-the-Internet / Remote** | Two-way | Encrypted Private Mesh / VPN | WireGuard, Tailscale (10.x, 100.64.0.0/10), or Port-forwarded TLS | Pinned TLS certificate SHA-256 + 32-char pair code. Zero unauthenticated cloud relays. |

<br/>

---

## 2. 📁 Two-Way File Transfer Protocol (`TransferEngine`)

### 🛡️ Non-Negotiable Invariants
1. **Explicit Receiver Consent:** Every incoming transfer starts in `awaiting_approval`. The receiver sees peer alias, sanitized filename, exact byte size, and selects destination. **Silent auto-accept is strictly prohibited.**
2. **Path Sanitization & Injection Defense:**
   - Slashes (`/`, `\`), NUL bytes (`\x00`), and directory traversal sequences (`..`) are rejected.
   - Windows Alternate Data Streams (`:stream`) and reserved DOS device names (`CON`, `PRN`, `AUX`, `NUL`, `COM1-9`, `LPT1-9`) are rejected.
3. **Collision Preservation:** If a file with the same name exists at destination, KL-06 appends ` (1)`, ` (2)` or prompts for explicit collision resolution. **Never silently overwrites.**
4. **Streamed Chunk IO & Backpressure:** Files stream in bounded chunks (up to 1 MB per chunk) directly to a private staging file (`.transfer_<id>.part`). The WebKit JavaScript bridge never loads full files into base64 JSON memory.
5. **Full Final Hash Verification:** Upon receiving announced bytes, the engine computes full SHA-256. If the digest mismatches, the staging file is immediately wiped and the transfer is aborted.
6. **Safe Cancellation & Monotonic Expiry:** Senders or receivers can cancel anytime. Transferred partial files are automatically removed upon cancel, rejection, or 1-hour session timeout.

```
Sender (Initiator)                                    Receiver (Target)
       │                                                      │
       ├────── /v1/transfer/init (Metadata + SHA-256) ───────▶│
       │                                                      │ [Displays Approval Prompt]
       │◀───── 202 Accepted (State: awaiting_approval) ───────┤
       │                                                      │
       │                                                 [User Approves]
       │◀───── Receiver Status: transferring ─────────────────┤
       │                                                      │
       ├────── Stream Chunk 0 (Offset: 0, Size: 64KB) ───────▶│ (Writes to .part file)
       ├────── Stream Chunk 1 (Offset: 65536, Size: 64KB) ───▶│ (Updates running SHA-256)
       │      ...                                            ...
       ├────── Stream Final Chunk (Offset: N) ───────────────▶│ (All bytes received)
       │                                                      │ [Verifies Final SHA-256]
       │◀───── 200 OK (State: complete, Final Path) ──────────┤ [Atomic Rename to Destination]
```

<br/>

---

## 3. 🚀 Secure OTA App Updates (`UpdateEngine`)

### 🔒 Catalog Verification & Signing Chain
The OTA engine queries signed update metadata (`KL06_SIGNED_UPDATE_CATALOG_V1`) from HTTPS-approved origins (`github.com`, `drive.google.com`).

```json
{
  "schema": "KL06_SIGNED_UPDATE_CATALOG_V1",
  "channel": "beta",
  "publishedAt": 1794931200,
  "expiresAt": 1804931200,
  "signingKeyId": "kl06-ed25519-root-2026",
  "signature": "...",
  "packages": {
    "macos": {
      "version": "0.4.0-beta.1",
      "build": 6,
      "minOS": "13.0",
      "supportedOS": "macOS 13, 14, 15+",
      "downloadUrl": "https://drive.google.com/uc?id=16SE_Z25itABzXg8p0aUrITkLr-2E-DVB&export=download",
      "sha256": "88c721b11a660fe72cabfe72950085508b98e336fa8b62cbe21b2aab87c38941",
      "sizeBytes": 199675,
      "installerType": "verified-manual-archive"
    },
    "android": {
      "version": "0.4.0-beta.1",
      "build": 6,
      "minOS": "26",
      "targetOS": "34",
      "supportedOS": "Android 8, 9, 10, 11, 12, 13, 14, 15, 16, 17+",
      "downloadUrl": "https://drive.google.com/uc?id=13ex_K-TosA7WOWNfErkIYQEEQkI_kM0b&export=download",
      "sha256": "fcfbfa14b08506b4dd829dfb0941e0ba00442dbd98e4e50e01a6c9534ef66fd7",
      "sizeBytes": 1069760,
      "installerType": "package-installer-intent"
    },
    "windows": {
      "version": "0.4.0-beta.1",
      "build": 6,
      "minOS": "6.1",
      "supportedOS": "Windows 7 SP1, 8, 8.1, 10, 11",
      "downloadUrl": "https://drive.google.com/uc?id=1legDzsIwv8oS00Ai3xHjCVu1-3wpWqsM&export=download",
      "sha256": "9cf98f9ef1ced9761a2156c026154f51b3330b68babe1eb68c2965290797e55f",
      "sizeBytes": 565574,
      "installerType": "verified-manual-archive"
    },
    "ios": {
      "version": "0.4.0-beta.1",
      "build": 6,
      "minOS": "16.0",
      "supportedOS": "iOS 16, 17, 18+",
      "downloadUrl": "https://testflight.apple.com/join/kl06-beta",
      "sha256": "0000000000000000000000000000000000000000000000000000000000000000",
      "sizeBytes": 0,
      "installerType": "testflight-redirect"
    }
  }
}
```

### 📶 Progressive Feature Matrix by OS Generation
KL-06 Manager dynamically adapts its capability pipeline as the host OS version increases, guaranteeing seamless backward compatibility down to the baseline minimum while unlocking next-generation features on modern hardware:

| Platform | Minimum Baseline | Unlocked Features by Generation |
| :--- | :--- | :--- |
| **Android** | **Android 8.0 Oreo (API 26)** | • **Android 8 & 9:** Base LAN peer relay, volume/brightness bridge, hardware telemetry.<br/>• **Android 10 & 11:** Auto dark mode (`prefers-color-scheme`), Wi-Fi LocalOnlyHotspot discovery, Scoped Storage.<br/>• **Android 12 & 12L:** Dynamic Color (Material You) styling, Bluetooth LE peer radar sweep.<br/>• **Android 13:** Auto-Pair incoming prompt dialog, granular media permissions, 6-digit mutual PIN confirmation, notification progress.<br/>• **Android 14 & 15:** Predictive back navigation, foreground `dataSync` transfer service, multi-gigabit chunked LAN streaming.<br/>• **Android 16, 17+:** 16KB memory page size optimization, Wi-Fi 7 multi-link mesh transfer. |
| **iOS** | **iOS 16.0** | • **iOS 16:** WKWebView isolated local bridge, pinned TLS authentication, Lock Screen widgets.<br/>• **iOS 17 & 18+:** Dynamic Island transfer progress, StandBy mode companion dashboard, AirDrop mesh handoff. |
| **macOS** | **macOS 13.0 Ventura** | • **macOS 13:** Stage Manager window management, native Menu Bar item, OLED brightness scalar, F13 hotkey.<br/>• **macOS 14 & 15+:** Desktop Interactive Widgets, Sonoma Game Mode governor, Sequoia Window Tiling integration. |
| **Windows** | **Windows 7 SP1** | • **Windows 7, 8, 8.1:** Aero / Classic desktop companion, .NET Desktop Runtime host, LAN peer discovery.<br/>• **Windows 10 & 11:** Edge WebView2 integration, Per-Monitor v2 high-DPI scaling, Mica / Acrylic glass material, Action Center notifications. |
```

### 🛑 Platform Installation Rules
- **Android Sideload / Private Beta:** Requires matching certificate signing lineage. Dispatched via standard `ACTION_INSTALL_PACKAGE` intent requiring user confirmation. `versionCode` must strictly increase (blocking downgrade attacks).
- **iOS / iPadOS:** Redirects to official TestFlight or App Store distribution URL. **Self-installing downloaded IPAs and private API updaters are strictly prohibited.**
- **macOS:** Staged download verified against announced SHA-256 and size; reveals verified archive in Finder with safe replacement guidance. No root daemons.
- **Windows:** Standard user execution of signed installer / MSIX package.
- **Zero Embedded Secrets:** No GitHub PATs, Google service-account keys, or private signing keys are embedded in clients or repositories. Missing credentials produce an explicit unavailable state.
