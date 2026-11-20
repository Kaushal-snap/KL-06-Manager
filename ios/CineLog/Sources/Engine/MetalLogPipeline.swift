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
    private var logToP010PipelineState: MTLComputePipelineState?
    
    // Intermediate Textures for High-Speed Processing
    private var logOutputTexture: MTLTexture?
    private var previewOutputTexture: MTLTexture?
    
    // Pixel buffer pool for zero-copy recording
    private var pixelBufferPool: CVPixelBufferPool?
    private var poolWidth = 0, poolHeight = 0
    
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
        // Shaders.metal is compiled into the app's default library by Xcode.
        guard let library = device.makeDefaultLibrary() else {
            print("[MetalLogPipeline] default Metal library missing - build Shaders.metal into the target")
            return
        }
        buildPipelines(from: library)
    }

    private func buildPipelines(from library: MTLLibrary) {
        if let fn = library.makeFunction(name: "sensorToAppleLogKernel") {
            appleLogPipelineState = try? device.makeComputePipelineState(function: fn)
        }
        if let fn = library.makeFunction(name: "logToP010Kernel") {
            logToP010PipelineState = try? device.makeComputePipelineState(function: fn)
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
    
    private func makeOutputPool(width: Int, height: Int) {
        if poolWidth == width && poolHeight == height && pixelBufferPool != nil { return }
        let attrs: [String: Any] = [
            kCVPixelBufferPixelFormatTypeKey as String: kCVPixelFormatType_420YpCbCr10BiPlanarVideoRange,
            kCVPixelBufferWidthKey as String: width,
            kCVPixelBufferHeightKey as String: height,
            kCVPixelBufferIOSurfacePropertiesKey as String: [:] as [String: Any],
            kCVPixelBufferMetalCompatibilityKey as String: true
        ]
        var pool: CVPixelBufferPool?
        CVPixelBufferPoolCreate(kCFAllocatorDefault, nil, attrs as CFDictionary, &pool)
        pixelBufferPool = pool; poolWidth = width; poolHeight = height
    }

    private func planeTexture(_ buffer: CVPixelBuffer, _ format: MTLPixelFormat, _ w: Int, _ h: Int, _ plane: Int) -> (CVMetalTexture, MTLTexture)? {
        guard let cache = textureCache else { return nil }
        let usage = MTLTextureUsage([.shaderRead, .shaderWrite]).rawValue
        let attrs = [kCVMetalTextureUsage as String: usage] as CFDictionary
        var ref: CVMetalTexture?
        CVMetalTextureCacheCreateTextureFromImage(kCFAllocatorDefault, cache, buffer, attrs, format, w, h, plane, &ref)
        guard let r = ref, let t = CVMetalTextureGetTexture(r) else { return nil }
        return (r, t)
    }

    /// Camera 10-bit HLG frame -> Apple-Log-style 10-bit buffer (for recording) + monitoring texture.
    /// `completion` runs after the GPU has finished, so the buffer is safe to hand to the writer.
    public func processFrame(pixelBuffer: CVPixelBuffer,
                             completion: @escaping (_ logBuffer: CVPixelBuffer?, _ preview: MTLTexture?) -> Void) {
        let width = CVPixelBufferGetWidth(pixelBuffer)
        let height = CVPixelBufferGetHeight(pixelBuffer)
        ensureTextures(width: width, height: height)
        makeOutputPool(width: width, height: height)
        guard let cmdBuffer = commandQueue.makeCommandBuffer(),
              let inY = planeTexture(pixelBuffer, .r16Unorm, width, height, 0),
              let inUV = planeTexture(pixelBuffer, .rg16Unorm, width / 2, height / 2, 1),
              let outLog = logOutputTexture, let outPreview = previewOutputTexture,
              let logPipeline = appleLogPipelineState, let lutPipeline = monitoringLUTPipelineState else {
            completion(nil, nil); return
        }
        var outBuffer: CVPixelBuffer?
        var outY: (CVMetalTexture, MTLTexture)?
        var outUV: (CVMetalTexture, MTLTexture)?
        if let pool = pixelBufferPool, let p010 = logToP010PipelineState {
            CVPixelBufferPoolCreatePixelBuffer(kCFAllocatorDefault, pool, &outBuffer)
            if let b = outBuffer {
                outY = planeTexture(b, .r16Unorm, width, height, 0)
                outUV = planeTexture(b, .rg16Unorm, width / 2, height / 2, 1)
            }
            _ = p010
        }
        let tg = MTLSize(width: 16, height: 16, depth: 1)
        let groups = MTLSize(width: (width + 15) / 16, height: (height + 15) / 16, depth: 1)

        if let e = cmdBuffer.makeComputeCommandEncoder() {
            e.setComputePipelineState(logPipeline)
            e.setTexture(inY.1, index: 0); e.setTexture(inUV.1, index: 1); e.setTexture(outLog, index: 2)
            e.dispatchThreadgroups(groups, threadsPerThreadgroup: tg)
            e.endEncoding()
        }
        if let e = cmdBuffer.makeComputeCommandEncoder(), let p010 = logToP010PipelineState, let y = outY, let uv = outUV {
            e.setComputePipelineState(p010)
            e.setTexture(outLog, index: 0); e.setTexture(y.1, index: 1); e.setTexture(uv.1, index: 2)
            e.dispatchThreadgroups(groups, threadsPerThreadgroup: tg)
            e.endEncoding()
        }
        if let e = cmdBuffer.makeComputeCommandEncoder() {
            switch currentMonitoringMode {
            case .flatLog, .rec709LUT:
                e.setComputePipelineState(lutPipeline)
                e.setTexture(outLog, index: 0); e.setTexture(outPreview, index: 1)
                var modeVal = currentMonitoringMode.rawValue
                e.setBytes(&modeVal, length: MemoryLayout<Int32>.size, index: 0)
            case .falseColor:
                guard let p = falseColorPipelineState else { e.endEncoding(); break }
                e.setComputePipelineState(p); e.setTexture(outLog, index: 0); e.setTexture(outPreview, index: 1)
            case .focusPeaking:
                guard let p = focusPeakingPipelineState else { e.endEncoding(); break }
                e.setComputePipelineState(p); e.setTexture(outLog, index: 0); e.setTexture(outPreview, index: 1)
                var t = peakingThreshold
                e.setBytes(&t, length: MemoryLayout<Float>.size, index: 0)
            }
            e.dispatchThreadgroups(groups, threadsPerThreadgroup: tg)
            e.endEncoding()
        }
        // Keep CVMetalTextures alive until the GPU is done.
        cmdBuffer.addCompletedHandler { _ in
            _ = (inY, inUV, outY, outUV)
            completion(outY != nil ? outBuffer : nil, outPreview)
        }
        cmdBuffer.commit()
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
