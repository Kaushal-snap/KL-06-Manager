import Foundation
import Metal
import MetalKit
import CoreVideo
import CoreMedia

public enum MonitoringMode: Int32 {
    case flatLog = 0
    case rec709LUT = 1
    case falseColor = 2
    case focusPeaking = 3
}

public final class MetalLogPipeline {
    public let device: MTLDevice
    public let commandQueue: MTLCommandQueue
    private var textureCache: CVMetalTextureCache?
    
    // Compute Pipeline States
    private var appleLogPipelineState: MTLComputePipelineState?
    private var monitoringLUTPipelineState: MTLComputePipelineState?
    private var falseColorPipelineState: MTLComputePipelineState?
    private var focusPeakingPipelineState: MTLComputePipelineState?
    
    // Intermediate Textures for High-Speed Processing
    private var logOutputTexture: MTLTexture?
    private var previewOutputTexture: MTLTexture?
    
    // Pixel buffer pool for zero-copy recording
    private var pixelBufferPool: CVPixelBufferPool?
    
    public var currentMonitoringMode: MonitoringMode = .rec709LUT
    public var peakingThreshold: Float = 0.35
    
    public init?() {
        guard let defaultDevice = MTLCreateSystemDefaultDevice(),
              let queue = defaultDevice.makeCommandQueue() else {
            return nil
        }
        self.device = defaultDevice
        self.commandQueue = queue
        
        CVMetalTextureCacheCreate(kCFAllocatorDefault, nil, device, nil, &textureCache)
        setupPipelines()
    }
    
    private func setupPipelines() {
        guard let library = try? device.makeDefaultLibrary() else {
            // If default library is absent (e.g. CLI build), compile from source dynamically
            compileShadersFromSource()
            return
        }
        buildPipelines(from: library)
    }
    
    private func compileShadersFromSource() {
        let shaderUrl = Bundle.main.url(forResource: "Shaders", withExtension: "metal")
        let source: String
        if let url = shaderUrl, let s = try? String(contentsOf: url) {
            source = s
        } else {
            // Built-in fallback string
            source = """
            #include <metal_stdlib>
            using namespace metal;
            constant float kAppleLogC = 0.1856326002f;
            constant float kAppleLogD = 0.6133036136f;
            constant float kAppleLogE = 0.0384214013f;
            constant float kAppleLogF = 4.2000000000f;
            constant float kAppleLogCutoff = 0.0100000000f;
            constant float kHlgA = 0.17883277f;
            constant float kHlgB = 0.28466892f;
            constant float kHlgC = 0.55991073f;
            constant float3x3 kYUV2RGB = float3x3(float3(1.0, 0.0, 1.4746), float3(1.0, -0.16455, -0.57135), float3(1.0, 1.8814, 0.0));
            kernel void sensorToAppleLogKernel(texture2d<float, access::read> inY [[texture(0)]], texture2d<float, access::read> inUV [[texture(1)]], texture2d<float, access::write> outColor [[texture(2)]], uint2 gid [[thread_position_in_grid]]) {
                if (gid.x >= outColor.get_width() || gid.y >= outColor.get_height()) return;
                float y = inY.read(gid).r;
                float2 uv = inUV.read(gid / 2).rg - float2(0.5, 0.5);
                float3 rgb = max(float3(0.0), kYUV2RGB * float3(y, uv.x, uv.y));
                float3 lin;
                for (int i=0; i<3; ++i) { float v = rgb[i]; lin[i] = (v <= 0.5f) ? ((v * v) / 3.0f) : ((exp((v - kHlgC) / kHlgA) + kHlgB) / 12.0f); }
                float3 logRgb;
                for (int i=0; i<3; ++i) { float r = lin[i]; logRgb[i] = (r < kAppleLogCutoff) ? max(0.0f, kAppleLogF * r) : (kAppleLogC * log(r + kAppleLogE) + kAppleLogD); }
                outColor.write(float4(logRgb, 1.0f), gid);
            }
            kernel void monitoringLUTKernel(texture2d<float, access::read> inLog [[texture(0)]], texture2d<float, access::write> outPrev [[texture(1)]], constant int &mode [[buffer(0)]], uint2 gid [[thread_position_in_grid]]) {
                if (gid.x >= outPrev.get_width() || gid.y >= outPrev.get_height()) return;
                float4 c = inLog.read(gid);
                if (mode == 0) { outPrev.write(c, gid); return; }
                float3 lin;
                for (int i=0; i<3; ++i) { float l = c[i]; lin[i] = (l < kAppleLogF * kAppleLogCutoff) ? max(0.0f, l / kAppleLogF) : (exp((l - kAppleLogD) / kAppleLogC) - kAppleLogE); }
                float3 r709 = pow(clamp((lin * (2.51f * lin + 0.03f)) / (lin * (2.43f * lin + 0.59f) + 0.14f), 0.0f, 1.0f), float3(1.0f / 2.2f));
                outPrev.write(float4(r709, 1.0f), gid);
            }
            kernel void falseColorKernel(texture2d<float, access::read> inTex [[texture(0)]], texture2d<float, access::write> outTex [[texture(1)]], uint2 gid [[thread_position_in_grid]]) {
                if (gid.x >= outTex.get_width() || gid.y >= outTex.get_height()) return;
                float4 s = inTex.read(gid);
                float luma = 0.2126f * s.r + 0.7152f * s.g + 0.0722f * s.b;
                float ire = luma * 100.0f;
                float3 c = (ire < 2.0f) ? float3(0.5, 0.0, 0.5) : (ire < 10.0f) ? float3(0.0, 0.0, 0.8) : (ire >= 38.0f && ire <= 44.0f) ? float3(0.0, 0.9, 0.0) : (ire >= 95.0f) ? float3(1.0, 0.0, 0.0) : float3(luma * 0.4f);
                outTex.write(float4(c, 1.0f), gid);
            }
            kernel void focusPeakingKernel(texture2d<float, access::read> inTex [[texture(0)]], texture2d<float, access::write> outTex [[texture(1)]], constant float &thresh [[buffer(0)]], uint2 gid [[thread_position_in_grid]]) {
                if (gid.x <= 1 || gid.y <= 1 || gid.x >= outTex.get_width() - 1 || gid.y >= outTex.get_height() - 1) return;
                float g00 = inTex.read(gid + uint2(-1, -1)).g, g02 = inTex.read(gid + uint2(1, -1)).g;
                float g10 = inTex.read(gid + uint2(-1, 0)).g, g12 = inTex.read(gid + uint2(1, 0)).g;
                float g20 = inTex.read(gid + uint2(-1, 1)).g, g22 = inTex.read(gid + uint2(1, 1)).g;
                float gx = (g02 + 2.0f*g12 + g22) - (g00 + 2.0f*g10 + g20);
                float gy = (g20 + 2.0f*inTex.read(gid + uint2(0, 1)).g + g22) - (g00 + 2.0f*inTex.read(gid + uint2(0, -1)).g + g02);
                float edge = sqrt(gx*gx + gy*gy);
                outTex.write(edge > thresh ? float4(0.0, 1.0, 0.4, 1.0) : inTex.read(gid), gid);
            }
            """
        }
        guard let library = try? device.makeLibrary(source: source, options: nil) else { return }
        buildPipelines(from: library)
    }
    
    private func buildPipelines(from library: MTLLibrary) {
        if let fn = library.makeFunction(name: "sensorToAppleLogKernel") {
            appleLogPipelineState = try? device.makeComputePipelineState(function: fn)
        }
        if let fn = library.makeFunction(name: "monitoringLUTKernel") {
            monitoringLUTPipelineState = try? device.makeComputePipelineState(function: fn)
        }
        if let fn = library.makeFunction(name: "falseColorKernel") {
            falseColorPipelineState = try? device.makeComputePipelineState(function: fn)
        }
        if let fn = library.makeFunction(name: "focusPeakingKernel") {
            focusPeakingPipelineState = try? device.makeComputePipelineState(function: fn)
        }
    }
    
    /// Core Processing Function: Transforms raw YUV camera buffer into Apple Log texture and monitoring view
    public func processFrame(pixelBuffer: CVPixelBuffer) -> (logTexture: MTLTexture?, previewTexture: MTLTexture?) {
        guard let cache = textureCache,
              let cmdBuffer = commandQueue.makeCommandBuffer() else {
            return (nil, nil)
        }
        
        let width = CVPixelBufferGetWidth(pixelBuffer)
        let height = CVPixelBufferGetHeight(pixelBuffer)
        
        // Zero-copy Metal texture extraction from Plane 0 (Y) and Plane 1 (UV)
        var yTextureRef: CVMetalTexture?
        CVMetalTextureCacheCreateTextureFromImage(
            kCFAllocatorDefault, cache, pixelBuffer, nil,
            .r16Unorm, width, height, 0, &yTextureRef
        )
        
        var uvTextureRef: CVMetalTexture?
        CVMetalTextureCacheCreateTextureFromImage(
            kCFAllocatorDefault, cache, pixelBuffer, nil,
            .rg16Unorm, width / 2, height / 2, 1, &uvTextureRef
        )
        
        guard let yTex = yTextureRef.flatMap(CVMetalTextureGetTexture),
              let uvTex = uvTextureRef.flatMap(CVMetalTextureGetTexture) else {
            return (nil, nil)
        }
        
        ensureTextures(width: width, height: height)
        guard let outLog = logOutputTexture,
              let outPreview = previewOutputTexture,
              let logPipeline = appleLogPipelineState,
              let lutPipeline = monitoringLUTPipelineState else {
            return (nil, nil)
        }
        
        // 1. Pass 1: Sensor to Apple Log Compute Pass
        if let encoder = cmdBuffer.makeComputeCommandEncoder() {
            encoder.setComputePipelineState(logPipeline)
            encoder.setTexture(yTex, index: 0)
            encoder.setTexture(uvTex, index: 1)
            encoder.setTexture(outLog, index: 2)
            
            let threadGroupSize = MTLSize(width: 16, height: 16, depth: 1)
            let threadGroups = MTLSize(
                width: (width + 15) / 16,
                height: (height + 15) / 16,
                depth: 1
            )
            encoder.dispatchThreadgroups(threadGroups, threadsPerThreadgroup: threadGroupSize)
            encoder.endEncoding()
        }
        
        // 2. Pass 2: Monitoring LUT / False Color / Focus Assist
        if let encoder = cmdBuffer.makeComputeCommandEncoder() {
            let threadGroupSize = MTLSize(width: 16, height: 16, depth: 1)
            let threadGroups = MTLSize(
                width: (width + 15) / 16,
                height: (height + 15) / 16,
                depth: 1
            )
            
            switch currentMonitoringMode {
            case .flatLog, .rec709LUT:
                encoder.setComputePipelineState(lutPipeline)
                encoder.setTexture(outLog, index: 0)
                encoder.setTexture(outPreview, index: 1)
                var modeVal = currentMonitoringMode.rawValue
                encoder.setBytes(&modeVal, length: MemoryLayout<Int32>.size, index: 0)
                encoder.dispatchThreadgroups(threadGroups, threadsPerThreadgroup: threadGroupSize)
                
            case .falseColor:
                if let fcPipeline = falseColorPipelineState {
                    encoder.setComputePipelineState(fcPipeline)
                    encoder.setTexture(outLog, index: 0)
                    encoder.setTexture(outPreview, index: 1)
                    encoder.dispatchThreadgroups(threadGroups, threadsPerThreadgroup: threadGroupSize)
                }
                
            case .focusPeaking:
                if let fpPipeline = focusPeakingPipelineState {
                    encoder.setComputePipelineState(fpPipeline)
                    encoder.setTexture(outLog, index: 0)
                    encoder.setTexture(outPreview, index: 1)
                    var thresh = peakingThreshold
                    encoder.setBytes(&thresh, length: MemoryLayout<Float>.size, index: 0)
                    encoder.dispatchThreadgroups(threadGroups, threadsPerThreadgroup: threadGroupSize)
                }
            }
            encoder.endEncoding()
        }
        
        cmdBuffer.commit()
        return (outLog, outPreview)
    }
    
    private func ensureTextures(width: Int, height: Int) {
        if logOutputTexture?.width != width || logOutputTexture?.height != height {
            let desc = MTLTextureDescriptor.texture2DDescriptor(
                pixelFormat: .rgba16Float,
                width: width,
                height: height,
                mipmapped: false
            )
            desc.usage = [.shaderRead, .shaderWrite]
            desc.storageMode = .shared
            logOutputTexture = device.makeTexture(descriptor: desc)
            
            let prevDesc = MTLTextureDescriptor.texture2DDescriptor(
                pixelFormat: .bgra8Unorm,
                width: width,
                height: height,
                mipmapped: false
            )
            prevDesc.usage = [.shaderRead, .shaderWrite]
            prevDesc.storageMode = .shared
            previewOutputTexture = device.makeTexture(descriptor: prevDesc)
        }
    }
}
