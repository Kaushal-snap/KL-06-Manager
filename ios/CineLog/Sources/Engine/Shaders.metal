#include <metal_stdlib>
using namespace metal;

// Apple Log encoding (parameters from Apple's Apple Log Profile white paper - verify against the PDF).
// NOTE: on iPhone 13/14 Pro this is an APPROXIMATION computed from Apple's HLG stream,
// not true sensor Log (that needs A17 Pro hardware).
constant float kAL_R0 = -0.05641088f;
constant float kAL_Rt = 0.01f;
constant float kAL_c  = 47.28711236f;
constant float kAL_b  = 0.00964052f;
constant float kAL_g  = 0.08550479f;
constant float kAL_d  = 0.69336945f;

constant float kHlgA = 0.17883277f;
constant float kHlgB = 0.28466892f;
constant float kHlgC = 0.55991073f;
// HLG scene-linear value of 100% diffuse white (75% signal) = 0.265 -> scale so white = 1.0 reflectance
constant float kHlgWhiteScale = 1.0f / 0.265f;

inline float appleLogEncode(float r) {
    if (r >= kAL_Rt) return kAL_g * log2(r + kAL_b) + kAL_d;
    if (r >= kAL_R0) return kAL_c * (r - kAL_R0) * (r - kAL_R0);
    return 0.0f;
}
inline float appleLogDecode(float p) {
    float pt = kAL_c * (kAL_Rt - kAL_R0) * (kAL_Rt - kAL_R0);
    if (p >= pt) return exp2((p - kAL_d) / kAL_g) - kAL_b;
    return sqrt(max(p, 0.0f) / kAL_c) + kAL_R0;
}

// BT.2020 YCbCr (full-range normalised) -> RGB
constant float3x3 kYUV2RGB_BT2020 = float3x3(
    float3(1.0f,  0.0f,      1.4746f),
    float3(1.0f, -0.16455f, -0.57135f),
    float3(1.0f,  1.8814f,   0.0f)
);

// 10-bit biplanar video-range (P010 style) camera frame -> Apple-Log-style RGB (rgba16Float)
kernel void sensorToAppleLogKernel(
    texture2d<float, access::read>  inY      [[texture(0)]],
    texture2d<float, access::read>  inUV     [[texture(1)]],
    texture2d<float, access::write> outColor [[texture(2)]],
    uint2 gid [[thread_position_in_grid]]
) {
    if (gid.x >= outColor.get_width() || gid.y >= outColor.get_height()) return;
    // P010 keeps the 10 code bits in the top of 16: unorm * 65535 / 64 = 10-bit code
    float yCode  = inY.read(gid).r * (65535.0f / 64.0f);
    float2 uvCode = inUV.read(gid / 2).rg * (65535.0f / 64.0f);
    float yn = clamp((yCode - 64.0f) / 876.0f, 0.0f, 1.0f);            // video range removal
    float2 cn = (uvCode - 512.0f) / 896.0f;
    float3 rgb = max(float3(0.0f), kYUV2RGB_BT2020 * float3(yn, cn.x, cn.y));  // HLG-encoded RGB

    float3 logRGB;
    for (int i = 0; i < 3; ++i) {
        float v = rgb[i];
        float e = (v <= 0.5f) ? (v * v) / 3.0f : (exp((v - kHlgC) / kHlgA) + kHlgB) / 12.0f;
        logRGB[i] = clamp(appleLogEncode(e * kHlgWhiteScale), 0.0f, 1.0f);
    }
    outColor.write(float4(logRGB, 1.0f), gid);
}

// Log RGB (rgba16Float) -> 10-bit BT.2020 video-range biplanar buffer for the recorder.
kernel void logToP010Kernel(
    texture2d<float, access::read>  inLog  [[texture(0)]],
    texture2d<float, access::write> outY   [[texture(1)]],
    texture2d<float, access::write> outUV  [[texture(2)]],
    uint2 gid [[thread_position_in_grid]]
) {
    if (gid.x >= outY.get_width() || gid.y >= outY.get_height()) return;
    float3 c = inLog.read(gid).rgb;
    float y = 0.2627f * c.r + 0.6780f * c.g + 0.0593f * c.b;
    outY.write(float4((64.0f + 876.0f * y) * (64.0f / 65535.0f), 0, 0, 1), gid);
    if ((gid.x & 1) == 0 && (gid.y & 1) == 0) {
        float3 s = c + inLog.read(gid + uint2(1, 0)).rgb + inLog.read(gid + uint2(0, 1)).rgb + inLog.read(gid + uint2(1, 1)).rgb;
        s *= 0.25f;
        float ys = 0.2627f * s.r + 0.6780f * s.g + 0.0593f * s.b;
        float cb = (s.b - ys) / 1.8814f;
        float cr = (s.r - ys) / 1.4746f;
        outUV.write(float4((512.0f + 896.0f * cb) * (64.0f / 65535.0f), (512.0f + 896.0f * cr) * (64.0f / 65535.0f), 0, 1), gid / 2);
    }
}

// Monitoring: Log -> Rec.709-ish preview
kernel void monitoringLUTKernel(
    texture2d<float, access::read>  inLogTexture  [[texture(0)]],
    texture2d<float, access::write> outPreview    [[texture(1)]],
    constant int &monitoringMode                 [[buffer(0)]],
    uint2 gid [[thread_position_in_grid]]
) {
    if (gid.x >= outPreview.get_width() || gid.y >= outPreview.get_height()) return;
    float4 logColor = inLogTexture.read(gid);
    if (monitoringMode == 0) { outPreview.write(logColor, gid); return; }
    float3 lin;
    for (int i = 0; i < 3; ++i) lin[i] = max(0.0f, appleLogDecode(logColor[i]));
    float a = 2.51f, b = 0.03f, c = 2.43f, d = 0.59f, e = 0.14f;
    float3 rec709 = clamp((lin * (a * lin + b)) / (lin * (c * lin + d) + e), 0.0f, 1.0f);
    outPreview.write(float4(pow(rec709, float3(1.0f / 2.2f)), 1.0f), gid);
}

// MARK: - Exposure Assist: False Color (IRE Scale)
kernel void falseColorKernel(
    texture2d<float, access::read>  inTexture  [[texture(0)]],
    texture2d<float, access::write> outTexture [[texture(1)]],
    uint2 gid [[thread_position_in_grid]]
) {
    if (gid.x >= outTexture.get_width() || gid.y >= outTexture.get_height()) {
        return;
    }
    
    float4 src = inTexture.read(gid);
    // Luminance calculation
    float luma = 0.2126f * src.r + 0.7152f * src.g + 0.0722f * src.b;
    float ire = luma * 100.0f;
    
    float3 color;
    if (ire < 2.0f) {
        color = float3(0.5f, 0.0f, 0.5f); // Deep Purple: Clipped Shadows (0-2 IRE)
    } else if (ire < 10.0f) {
        color = float3(0.0f, 0.0f, 0.8f); // Blue: Near black (2-10 IRE)
    } else if (ire >= 38.0f && ire <= 44.0f) {
        color = float3(0.0f, 0.9f, 0.0f); // Green: 18% Middle Gray (Exposure target)
    } else if (ire >= 65.0f && ire <= 75.0f) {
        color = float3(1.0f, 0.5f, 0.6f); // Pink/Light Red: Caucasian/Skin Tones
    } else if (ire >= 95.0f) {
        color = float3(1.0f, 0.0f, 0.0f); // Bright Red: Highlight Clipping / Blown Out
    } else {
        // Monochrome background for contrast
        color = float3(luma * 0.4f);
    }
    
    outTexture.write(float4(color, 1.0f), gid);
}

// MARK: - Focus Assist: Real-time Sobel Edge Peaking
kernel void focusPeakingKernel(
    texture2d<float, access::read>  inTexture  [[texture(0)]],
    texture2d<float, access::write> outTexture [[texture(1)]],
    constant float &threshold                  [[buffer(0)]],
    uint2 gid [[thread_position_in_grid]]
) {
    if (gid.x <= 1 || gid.y <= 1 || gid.x >= outTexture.get_width() - 1 || gid.y >= outTexture.get_height() - 1) {
        return;
    }
    
    // Sobel 3x3 convolution for sharp edge detection
    float g00 = inTexture.read(gid + uint2(-1, -1)).g;
    float g01 = inTexture.read(gid + uint2( 0, -1)).g;
    float g02 = inTexture.read(gid + uint2( 1, -1)).g;
    float g10 = inTexture.read(gid + uint2(-1,  0)).g;
    float g12 = inTexture.read(gid + uint2( 1,  0)).g;
    float g20 = inTexture.read(gid + uint2(-1,  1)).g;
    float g21 = inTexture.read(gid + uint2( 0,  1)).g;
    float g22 = inTexture.read(gid + uint2( 1,  1)).g;
    
    float gx = (g02 + 2.0f * g12 + g22) - (g00 + 2.0f * g10 + g20);
    float gy = (g20 + 2.0f * g21 + g22) - (g00 + 2.0f * g01 + g02);
    float edge = sqrt(gx * gx + gy * gy);
    
    float4 original = inTexture.read(gid);
    if (edge > threshold) {
        // Neon green focus peaking overlay
        outTexture.write(float4(0.0f, 1.0f, 0.4f, 1.0f), gid);
    } else {
        outTexture.write(original, gid);
    }
}
