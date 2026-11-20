#include <metal_stdlib>
using namespace metal;

// MARK: - Color Math Constants for Apple Log and HLG
constant float kAppleLogC = 0.1856326002f;
constant float kAppleLogD = 0.6133036136f;
constant float kAppleLogE = 0.0384214013f;
constant float kAppleLogF = 4.2000000000f;
constant float kAppleLogCutoff = 0.0100000000f;

constant float kHlgA = 0.17883277f;
constant float kHlgB = 0.28466892f;
constant float kHlgC = 0.55991073f;

// Rec.2020 YUV to RGB Conversion Matrix
constant float3x3 kYUV2RGB_BT2020 = float3x3(
    float3(1.0f,  0.0f,      1.4746f),
    float3(1.0f, -0.16455f, -0.57135f),
    float3(1.0f,  1.8814f,   0.0f)
);

// MARK: - Pipeline Bypass Kernel: 10-Bit Sensor Stream to Pure Apple Log
kernel void sensorToAppleLogKernel(
    texture2d<float, access::read>  inY      [[texture(0)]],
    texture2d<float, access::read>  inUV     [[texture(1)]],
    texture2d<float, access::write> outColor [[texture(2)]],
    uint2 gid [[thread_position_in_grid]]
) {
    if (gid.x >= outColor.get_width() || gid.y >= outColor.get_height()) {
        return;
    }
    
    // Sample Y (Full 10-bit range) and UV (bi-planar subsampled)
    float y = inY.read(gid).r;
    float2 uv = inUV.read(gid / 2).rg - float2(0.5f, 0.5f);
    
    // Convert YUV to normalized linear RGB
    float3 yuv = float3(y, uv.x, uv.y);
    float3 rgbSensor = max(float3(0.0f), kYUV2RGB_BT2020 * yuv);
    
    // 1. Invert HLG Opto-Electronic Transfer Function to get True Scene Linear Light
    float3 linearLight;
    for (int i = 0; i < 3; ++i) {
        float v = rgbSensor[i];
        if (v <= 0.5f) {
            linearLight[i] = (v * v) / 3.0f;
        } else {
            linearLight[i] = (exp((v - kHlgC) / kHlgA) + kHlgB) / 12.0f;
        }
    }
    
    // 2. Apply Official Apple Log Transfer Function
    float3 appleLogRGB;
    for (int i = 0; i < 3; ++i) {
        float r = linearLight[i];
        if (r < kAppleLogCutoff) {
            appleLogRGB[i] = max(0.0f, kAppleLogF * r);
        } else {
            appleLogRGB[i] = kAppleLogC * log(r + kAppleLogE) + kAppleLogD;
        }
    }
    
    outColor.write(float4(appleLogRGB, 1.0f), gid);
}

// MARK: - Monitoring LUT Kernel: Real-time Apple Log to Rec.709 Preview
kernel void monitoringLUTKernel(
    texture2d<float, access::read>  inLogTexture  [[texture(0)]],
    texture2d<float, access::write> outPreview    [[texture(1)]],
    constant int &monitoringMode                 [[buffer(0)]], // 0: Raw Log, 1: Rec.709 LUT
    uint2 gid [[thread_position_in_grid]]
) {
    if (gid.x >= outPreview.get_width() || gid.y >= outPreview.get_height()) {
        return;
    }
    
    float4 logColor = inLogTexture.read(gid);
    
    if (monitoringMode == 0) {
        // Flat Log display
        outPreview.write(logColor, gid);
        return;
    }
    
    // Convert Apple Log back to linear for LUT display transform
    float3 linearLight;
    float cutLog = kAppleLogF * kAppleLogCutoff;
    for (int i = 0; i < 3; ++i) {
        float l = logColor[i];
        if (l < cutLog) {
            linearLight[i] = max(0.0f, l / kAppleLogF);
        } else {
            linearLight[i] = exp((l - kAppleLogD) / kAppleLogC) - kAppleLogE;
        }
    }
    
    // ACES-style filmic tone curve for rich cinematic Rec.709 monitoring
    float a = 2.51f;
    float b = 0.03f;
    float c = 2.43f;
    float d = 0.59f;
    float e = 0.14f;
    float3 rec709 = clamp((linearLight * (a * linearLight + b)) / (linearLight * (c * linearLight + d) + e), 0.0f, 1.0f);
    
    // Rec.709 gamma (2.2)
    rec709 = pow(rec709, float3(1.0f / 2.2f));
    
    outPreview.write(float4(rec709, 1.0f), gid);
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
