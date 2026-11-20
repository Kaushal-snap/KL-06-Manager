import Foundation
import simd

/// Mathematical color space models and transfer functions for Apple Log, Rec.2020, and Cinema RAW.
public struct ColorMath {
    
    // MARK: - Official Apple Log Transfer Function Parameters
    // Defined according to Apple Log Profile White Paper (ISO 12646 / ITU-R BT.2020)
    public static let appleLogC: Float = 0.1856326002
    public static let appleLogD: Float = 0.6133036136
    public static let appleLogE: Float = 0.0384214013
    public static let appleLogF: Float = 4.2000000000
    public static let appleLogCutoff: Float = 0.0100000000
    
    // MARK: - ARIB STD-B67 (HLG) Parameters
    // Used to unpack 10-bit HDR sensor buffer into pure scene-linear light
    public static let hlgA: Float = 0.17883277
    public static let hlgB: Float = 0.28466892
    public static let hlgC: Float = 0.55991073
    
    /// Converts a normalized 10-bit HLG sensor value (0.0 ... 1.0) into Scene Linear Light (0.0 ... 12.0+)
    @inline(__always)
    public static func hlgToSceneLinear(_ v: Float) -> Float {
        if v <= 0.5 {
            return (v * v) / 3.0
        } else {
            return (exp((v - hlgC) / hlgA) + hlgB) / 12.0
        }
    }
    
    /// Converts Scene Linear Light (normalized to 18% gray = 0.18) into official Apple Log encoding
    @inline(__always)
    public static func sceneLinearToAppleLog(_ r: Float) -> Float {
        if r < appleLogCutoff {
            return max(0.0, appleLogF * r)
        } else {
            return appleLogC * log(r + appleLogE) + appleLogD
        }
    }
    
    /// Complete pipeline conversion: Takes 10-bit sensor input and maps directly to Apple Log
    @inline(__always)
    public static func sensorToAppleLog(_ v: Float) -> Float {
        let linear = hlgToSceneLinear(v)
        return sceneLinearToAppleLog(linear)
    }
    
    /// Converts Apple Log back to scene linear (Inverse OETF) for monitoring or LUT transforms
    @inline(__always)
    public static func appleLogToSceneLinear(_ logVal: Float) -> Float {
        let cutLog = appleLogF * appleLogCutoff
        if logVal < cutLog {
            return max(0.0, logVal / appleLogF)
        } else {
            return exp((logVal - appleLogD) / appleLogC) - appleLogE
        }
    }
    
    /// Monitoring Preview Curve: Evaluates Apple Log to Rec.709 display transform
    @inline(__always)
    public static func appleLogToRec709Preview(_ logVal: Float) -> Float {
        let linear = appleLogToSceneLinear(logVal)
        // High-contrast cinema tonemap curve for Rec.709 monitor preview
        let mapped = (linear * (2.51 * linear + 0.03)) / (linear * (2.43 * linear + 0.59) + 0.14)
        return clamp(pow(mapped, 1.0 / 2.2), min: 0.0, max: 1.0)
    }
    
    @inline(__always)
    public static func clamp(_ val: Float, min minVal: Float, max maxVal: Float) -> Float {
        return Swift.min(Swift.max(val, minVal), maxVal)
    }
}
