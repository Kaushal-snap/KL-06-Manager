# 🎥 CineLog Pro — iPhone 14 Pro Max Apple Log & Cinema RAW Camera

**Engineered by Kaushal Labana**  
*Unlock 10-bit Apple Log Profile & Cinema RAW video recording on iPhone 14 Pro Max by bypassing Apple’s native dynamic tone-mapping pipeline.*

---

## What CineLog really does (honest version)

CineLog turns an older iPhone (13 Pro / 14 Pro Max) into a more capable video camera using **public AVFoundation + Metal APIs only**. It cannot unlock hardware that the phone does not have.

| iPhone 18 Pro idea | On iPhone 13/14 Pro with CineLog |
| :-- | :-- |
| Apple Log / Log 2 | **Approximation**: 10-bit HLG from the camera -> Apple Log curve in Metal (parameters from Apple's Apple Log white paper; verify). Not true sensor Log; Apple's HLG tone mapping is still underneath. Grade with a Log-to-Rec.709 transform as a starting point. |
| ProRes video | Internal ProRes if the phone/storage supports it (falls back to HEVC 10-bit automatically). |
| ProRAW | **ProRAW stills** (real DNG) when the current format allows it. **No RAW video** (not possible on these phones). |
| Manual controls | ISO, shutter, white balance, focus: yes. Histogram/false colour/peaking: monitoring tools included. |
| 4K120, variable aperture, genlock, ProRes RAW video, external recording | **Not possible** (hardware). |

### Proxy / small files
Storage menu on the right column: **Full only**, **Full + Proxy** (1080p HEVC 10-bit, 15 Mbps, AAC) or **Proxy only**.
Default codec is HEVC 10-bit (~1.1 GB/min at 4K24) instead of ProRes HQ (~5 GB/min). The menu shows the estimated GB/min.

### Status
Written without a Mac: **not compiled or tested on a device yet.** Expect to fix build errors in Xcode.

---

## 📲 How to Install on iPhone 14 Pro Max

### Option 1: Sideload via Sideloadly (Mac or Windows PC) — Recommended
1. Download and open **Sideloadly** on your Mac or Windows PC.
2. Connect your iPhone 14 Pro Max via Lightning cable.
3. Drag `CineLog-Pro-v1.0.0-iPhone14ProMax.ipa` into Sideloadly.
4. Enter your Apple ID and click **Start**.
5. Once installed, on your iPhone go to:
   **Settings → General → VPN & Device Management → Developer App → Trust Certificate**.
6. Launch **CineLog Pro** and grant Camera & Microphone permissions.

### Option 2: AltStore / Scarlet / TrollStore
- In AltStore or Scarlet, tap the `+` button and select the `CineLog` IPA file.
- On TrollStore (iOS 16.0 – 16.6.1 / 17.0), simply tap the IPA file and select "Install".

### Option 3: Xcode Direct Install (Mac)
1. Open `ios/CineLog/CineLog.xcodeproj` in Xcode.
2. Select your connected iPhone 14 Pro Max as the run destination.
3. Select your personal Apple Development team under **Signing & Capabilities**.
4. Press **⌘R (Run)** to build and install directly onto your device.

---

## 🎨 Color Grading in DaVinci Resolve & Final Cut Pro

Because CineLog Pro encodes according to the **official Apple Log specification in ITU-R BT.2020**, you can grade your footage using official tools:

### In DaVinci Resolve:
1. Import your `.mov` clips from CineLog Pro into DaVinci Resolve Studio.
2. Go to **Project Settings → Color Management**:
   - **Color Science**: DaVinci YRGB Color Managed
   - **Color Processing Mode**: HDR DaVinci Wide Gamut Intermediate
   - **Output Color Space**: Rec.709 Gamma 2.4
3. Alternatively, in standard YRGB:
   - Add a node on your clip.
   - Apply the **Color Space Transform (CST)** OFX plugin:
     - **Input Color Space**: Apple Log
     - **Input Gamma**: Apple Log
     - **Output Color Space**: Rec.709
     - **Output Gamma**: Gamma 2.4
4. Or apply Apple's official **Apple Log to Rec.709 LUT** directly!

### In Final Cut Pro:
1. Select the clip in the browser.
2. In the **Info Inspector**, set **Camera LUT** to **Apple Log to Rec.709**.
3. Instant broadcast-ready cinematic color with full highlight retention!
