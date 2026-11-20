# 🎥 CineLog Pro — iPhone 14 Pro Max Apple Log & Cinema RAW Camera

**Engineered by Kaushal Labana**  
*Unlock 10-bit Apple Log Profile & Cinema RAW video recording on iPhone 14 Pro Max by bypassing Apple’s native dynamic tone-mapping pipeline.*

---

## ⚡ Why CineLog Pro? (The Technical Problem & The Solution)

### The Hardware Lock
Apple introduced **Apple Log** (`AVCaptureColorSpace.appleLog`) exclusively on iPhone 15 Pro and iPhone 16 Pro (A17 Pro / A18 Pro). On the **iPhone 14 Pro Max** (A16 Bionic with Sony IMX803 48MP Quad-Bayer sensor), Apple artificially hides and locks the Log profile in the native Camera app.

Furthermore, Apple's native video pipeline enforces:
1. **Aggressive Smart HDR Tone Mapping:** Shifts black levels and dynamic contrast frame-to-frame.
2. **Artificial Edge Sharpening & Noise Reduction:** Destroys fine optical texture and skin details.
3. **8-bit / Standard Rec.709 Clipping:** Crushes shadow detail and blows out specular highlights.

### The Pipeline Bypass Solution
**CineLog Pro** completely bypasses Apple’s default `AVCaptureMovieFileOutput` pipeline by implementing a custom low-level **AVFoundation + Metal Compute Pipeline**:

```
[Sony IMX803 48MP Sensor]
          │ (Locked Manual ISO, Shutter, Kelvin WB & Lens Focus)
          ▼
[10-Bit Wide Gamut Capture: kCVPixelFormatType_420YpCbCr10BiPlanarVideoRange]
          │
          ├──► [Metal Compute Kernel (Shaders.metal)]
          │         ├─ Step 1: Invert ARIB STD-B67 HLG OETF -> True Scene Linear Light
          │         └─ Step 2: Apply Official Apple Log Transfer Function (c=0.1856, d=0.6133, e=0.0384)
          │
          ├──► [AVAssetWriter Zero-Copy Adaptor]
          │         └─ Writes Apple ProRes 422 HQ (10-bit BT.2020) @ 220 Mbps
          │
          ├──► [CinemaDNG Sequence Mode]
          │         └─ Writes Uncompressed 10-bit/12-bit DNG Frames with Sensor Matrix
          │
          └──► [Live Monitoring Engine]
                    ├─ Real-time 3D LUT (Apple Log -> Rec.709 Monitor Transform)
                    ├─ False Color Exposure Assist (IRE Scale)
                    └─ Sobel Convolution Focus Peaking (Neon Green)
```

---

## 🔬 Mathematical Apple Log Implementation

Apple published the exact transfer function for Apple Log in their official developer whitepaper. In `ColorMath.swift` and `Shaders.metal`, CineLog Pro computes:

$$\text{AppleLog}(R) = \begin{cases} 4.2 \cdot R & \text{if } R < 0.01 \\ 0.1856326 \cdot \ln(R + 0.0384214) + 0.6133036 & \text{if } R \ge 0.01 \end{cases}$$

Where $R$ is normalized linear scene reflection (18% Middle Gray = $R = 0.18$, mapping to **44.2% Log IRE**).

---

## 🎛️ Cinema Camera Features

| Feature | Description |
| :--- | :--- |
| **Color Profiles** | Official Apple Log (BT.2020), Flat Cine Log, Rec.709 Preview |
| **Codecs** | Apple ProRes 422 HQ (10-bit), Apple ProRes 422, HEVC 10-bit Main10, CinemaDNG RAW |
| **Resolutions** | 4K UHD (3840×2160), 1080p FHD (1920×1080) |
| **Frame Rates** | 24 fps (Cinema), 25 fps (PAL), 30 fps, 60 fps |
| **Shutter Control** | 180° Shutter Angle rule (1/48s, 1/50s, 1/60s, 1/96s, 1/120s, 1/240s) |
| **ISO Range** | Manual ISO 50 to ISO 6400 |
| **White Balance** | Manual Kelvin wheel (2000K – 10000K) + Green/Magenta Tint lock |
| **Focus** | Manual lens position wheel with Sobel edge peaking |
| **Monitoring** | Instant toggle between Flat Apple Log and Rec.709 3D Preview LUT |
| **Exposure Assist** | Real-time False Color heat map (IRE 0 to 100) and Zebra stripes |
| **Audio** | Uncompressed 48 kHz 24-bit 2-channel Linear PCM stereo |
| **Aspect Guides** | 2.39:1 CinemaScope anamorphic letterbox + Rule of Thirds grid |
| **Storage** | Live bitrate, disk MB recorded, and drop frame detector |

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
