import Foundation
import simd

/// Mathematical color space models and transfer functions for Apple Log, Rec.2020, and Cinema RAW.
public struct ColorMath {
    
    // Apple Log parameters (Apple Log Profile white paper; verify against the PDF).
    public static let alR0: Float = -0.05641088, alRt: Float = 0.01, alC: Float = 47.28711236
    public static let alB: Float = 0.00964052, alG: Float = 0.08550479, alD: Float = 0.69336945

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
    
    /// Scene-linear reflectance (18% gray = 0.18) -> Apple Log code value.
    @inline(__always)
    public static func sceneLinearToAppleLog(_ r: Float) -> Float {
        if r >= alRt { return alG * log2(r + alB) + alD }
        if r >= alR0 { return alC * (r - alR0) * (r - alR0) }
        return 0
    }
    /// Apple Log code value -> scene-linear reflectance.
    @inline(__always)
    public static func appleLogToSceneLinear(_ p: Float) -> Float {
        let pt = alC * (alRt - alR0) * (alRt - alR0)
        if p >= pt { return exp2((p - alD) / alG) - alB }
        return (Swift.max(p, 0) / alC).squareRoot() + alR0
    }
    /// HLG signal -> reflectance where 100% diffuse white = 1.0 (HLG 75% signal = 0.265 scene linear).
    @inline(__always)
    public static func hlgToReflectance(_ v: Float) -> Float { hlgToSceneLinear(v) / 0.265 }
    @inline(__always)
    public static func sensorToAppleLog(_ v: Float) -> Float { sceneLinearToAppleLog(hlgToReflectance(v)) }

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
