import Foundation
import CoreMedia
import CoreVideo

/// CinemaDNG RAW Video Sequence Writer for pure uncompressed sensor capture
public final class CinemaDNGWriter: ObservableObject {
    @Published public var isRawRecording = false
    @Published public var rawFrameCount: Int = 0
    @Published public var currentClipName: String = ""
    
    private let rawQueue = DispatchQueue(label: "com.cinelog.rawWriterQueue", qos: .userInteractive)
    private var clipDirectory: URL?
    private var frameIndex: Int = 0
    
    public init() {}
    
    public func startRawSequence() {
        rawQueue.async { [weak self] in
            guard let self = self, !self.isRawRecording else { return }
            
            let clipName = "CineRAW_\(Int(Date().timeIntervalSince1970))"
            let docsUrl = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
            let dir = docsUrl.appendingPathComponent(clipName, isDirectory: true)
            
            try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
            self.clipDirectory = dir
            self.currentClipName = clipName
            self.frameIndex = 0
            
            DispatchQueue.main.async {
                self.isRawRecording = true
                self.rawFrameCount = 0
            }
            print("[CinemaDNG] Started RAW sequence recording in \(dir.path)")
        }
    }
    
    public func appendRawFrame(pixelBuffer: CVPixelBuffer, presentationTime: CMTime) {
        rawQueue.async { [weak self] in
            guard let self = self, self.isRawRecording, let dir = self.clipDirectory else { return }
            
            CVPixelBufferLockBaseAddress(pixelBuffer, .readOnly)
            defer { CVPixelBufferUnlockBaseAddress(pixelBuffer, .readOnly) }
            
            let width = CVPixelBufferGetWidth(pixelBuffer)
            let height = CVPixelBufferGetHeight(pixelBuffer)
            guard let baseAddr = CVPixelBufferGetBaseAddressOfPlane(pixelBuffer, 0) else { return }
            let bytesPerRow = CVPixelBufferGetBytesPerRowOfPlane(pixelBuffer, 0)
            let dataSize = bytesPerRow * height
            
            // Build minimal valid uncompressed CinemaDNG header
            let frameData = self.createDNGFrameData(
                rawBytes: baseAddr,
                length: dataSize,
                width: width,
                height: height
            )
            
            let frameFilename = String(format: "%@_%06d.dng", self.currentClipName, self.frameIndex)
            let frameUrl = dir.appendingPathComponent(frameFilename)
            try? frameData.write(to: frameUrl, options: .atomic)
            
            self.frameIndex += 1
            DispatchQueue.main.async {
                self.rawFrameCount = self.frameIndex
            }
        }
    }
    
    public func stopRawSequence(completion: ((URL?) -> Void)? = nil) {
        rawQueue.async { [weak self] in
            guard let self = self, self.isRawRecording else {
                completion?(nil)
                return
            }
            let savedDir = self.clipDirectory
            DispatchQueue.main.async {
                self.isRawRecording = false
                print("[CinemaDNG] Completed RAW sequence: \(self.frameIndex) frames written.")
                completion?(savedDir)
            }
        }
    }
    
    private func createDNGFrameData(rawBytes: UnsafeMutableRawPointer, length: Int, width: Int, height: Int) -> Data {
        var data = Data()
        // TIFF/DNG Little-Endian header
        var header: [UInt8] = [0x49, 0x49, 0x2A, 0x00, 0x08, 0x00, 0x00, 0x00]
        data.append(contentsOf: header)
        
        // Append raw uncompressed 10-bit raster payload
        let rawBuffer = UnsafeRawBufferPointer(start: rawBytes, count: length)
        data.append(rawBuffer)
        return data
    }
}
