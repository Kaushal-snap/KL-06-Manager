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
| **Android ⟷ iOS** | Two-way | Desktop-Hub Relay | Authenticated desktop forwarder via local paired PC/Mac | **Disclosed Relay**: Explicitly routes through desktop hub; end-to-end verified via SHA-256. |

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
      "version": "0.3.0",
      "build": 5,
      "minOS": "13.0",
      "downloadUrl": "https://github.com/Kaushal-snap/KL-06-Manager/releases/download/v0.3.0-beta.2/KL-06.zip",
      "sha256": "acf8991e078e676509ddcfdc3ddc1ec5503e6802a2749078eef82f19925bec8e",
      "sizeBytes": 145733,
      "installerType": "verified-manual-archive"
    },
    "android": {
      "version": "0.3.0",
      "build": 5,
      "minOS": "26",
      "downloadUrl": "https://github.com/Kaushal-snap/KL-06-Manager/releases/download/v0.3.0-beta.2/KL-06-Manager.apk",
      "sha256": "c5efb20ba7bd802eeb8a7b9eb94f7dbd0d407fdaa3ad72819291c3b9d96f192b",
      "sizeBytes": 1223723,
      "installerType": "package-installer-intent"
    },
    "ios": {
      "version": "0.3.0",
      "build": 5,
      "minOS": "16.0",
      "downloadUrl": "https://testflight.apple.com/join/kl06-beta",
      "sha256": "0000000000000000000000000000000000000000000000000000000000000000",
      "sizeBytes": 0,
      "installerType": "testflight-redirect"
    }
  }
}
```

### 🛑 Platform Installation Rules
- **Android Sideload / Private Beta:** Requires matching certificate signing lineage. Dispatched via standard `ACTION_INSTALL_PACKAGE` intent requiring user confirmation. `versionCode` must strictly increase (blocking downgrade attacks).
- **iOS / iPadOS:** Redirects to official TestFlight or App Store distribution URL. **Self-installing downloaded IPAs and private API updaters are strictly prohibited.**
- **macOS:** Staged download verified against announced SHA-256 and size; reveals verified archive in Finder with safe replacement guidance. No root daemons.
- **Windows:** Standard user execution of signed installer / MSIX package.
- **Zero Embedded Secrets:** No GitHub PATs, Google service-account keys, or private signing keys are embedded in clients or repositories. Missing credentials produce an explicit unavailable state.
