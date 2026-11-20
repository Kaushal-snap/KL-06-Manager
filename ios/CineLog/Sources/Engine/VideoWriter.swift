import Foundation
import AVFoundation
import CoreMedia
import CoreVideo
import Photos

public enum RecordingCodec: String, CaseIterable {
    case proRes422HQ = "Apple ProRes 422 HQ (10-bit)"
    case proRes422 = "Apple ProRes 422 (10-bit)"
    case hevc10Bit = "HEVC Main10 (10-bit BT.2020)"
}

public final class VideoWriter: ObservableObject {
    private var assetWriter: AVAssetWriter?
    private var videoWriterInput: AVAssetWriterInput?
    private var audioWriterInput: AVAssetWriterInput?
    private var pixelBufferAdaptor: AVAssetWriterInputPixelBufferAdaptor?
    
    private let writeQueue = DispatchQueue(label: "com.cinelog.writerQueue", qos: .userInteractive)
    
    @Published public var isRecording = false
    @Published public var recordingDuration: TimeInterval = 0.0
    @Published public var recordedFileSizeMB: Double = 0.0
    @Published public var droppedFrames: Int = 0
    @Published public var currentCodec: RecordingCodec = .proRes422HQ
    
    private var recordingStartTime: CMTime?
    private var timer: Timer?
    private var currentOutputFileURL: URL?
    
    public init() {}
    
    public func startRecording(width: Int = 3840, height: Int = 2160, fps: Int = 24) {
        writeQueue.async { [weak self] in
            guard let self = self, !self.isRecording else { return }
            
            let filename = "CineLog_\(Date().timeIntervalSince1970).mov"
            let docsUrl = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
            let outputUrl = docsUrl.appendingPathComponent(filename)
            self.currentOutputFileURL = outputUrl
            
            do {
                let writer = try AVAssetWriter(outputURL: outputUrl, fileType: .mov)
                self.assetWriter = writer
                
                // 1. Setup Video Compression Settings (ProRes 422 HQ or HEVC 10-bit)
                let videoCodec: AVVideoCodecType
                switch self.currentCodec {
                case .proRes422HQ:
                    videoCodec = .proRes422HQ
                case .proRes422:
                    videoCodec = .proRes422
                case .hevc10Bit:
                    videoCodec = .hevc
                }
                
                var videoSettings: [String: Any] = [
                    AVVideoCodecKey: videoCodec,
                    AVVideoWidthKey: width,
                    AVVideoHeightKey: height,
                    AVVideoColorPropertiesKey: [
                        AVVideoColorPrimariesKey: AVVideoColorPrimaries_ITU_R_2020,
                        AVVideoTransferFunctionKey: AVVideoTransferFunction_ITU_R_2020,
                        AVVideoYCbCrMatrixKey: AVVideoYCbCrMatrix_ITU_R_2020
                    ]
                ]
                
                if self.currentCodec == .hevc10Bit {
                    videoSettings[AVVideoCompressionPropertiesKey] = [
                        AVVideoAverageBitRateKey: 150_000_000, // 150 Mbps for pristine 4K 10-bit
                        AVVideoProfileLevelKey: kVTProfileLevel_HEVC_Main10_AutoLevel,
                        AVVideoExpectedSourceFrameRateKey: fps
                    ]
                }
                
                let videoInput = AVAssetWriterInput(mediaType: .video, outputSettings: videoSettings)
                videoInput.expectsMediaDataInRealTime = true
                self.videoWriterInput = videoInput
                
                let sourceBufferAttributes: [String: Any] = [
                    kCVPixelBufferPixelFormatTypeKey as String: kCVPixelFormatType_420YpCbCr10BiPlanarVideoRange,
                    kCVPixelBufferWidthKey as String: width,
                    kCVPixelBufferHeightKey as String: height
                ]
                self.pixelBufferAdaptor = AVAssetWriterInputPixelBufferAdaptor(
                    assetWriterInput: videoInput,
                    sourcePixelBufferAttributes: sourceBufferAttributes
                )
                
                if writer.canAdd(videoInput) {
                    writer.add(videoInput)
                }
                
                // 2. Setup Uncompressed 48kHz Linear PCM Audio
                let audioSettings: [String: Any] = [
                    AVFormatIDKey: kAudioFormatLinearPCM,
                    AVSampleRateKey: 48000.0,
                    AVNumberOfChannelsKey: 2,
                    AVLinearPCMBitDepthKey: 24,
                    AVLinearPCMIsFloatKey: false,
                    AVLinearPCMIsBigEndianKey: false,
                    AVLinearPCMIsNonInterleaved: false
                ]
                let audioInput = AVAssetWriterInput(mediaType: .audio, outputSettings: audioSettings)
                audioInput.expectsMediaDataInRealTime = true
                self.audioWriterInput = audioInput
                
                if writer.canAdd(audioInput) {
                    writer.add(audioInput)
                }
                
                writer.startWriting()
                self.recordingStartTime = nil
                
                DispatchQueue.main.async {
                    self.isRecording = true
                    self.recordingDuration = 0.0
                    self.droppedFrames = 0
                    self.startTimer()
                }
                print("[VideoWriter] Recording started at \(outputUrl.lastPathComponent)")
            } catch {
                print("[VideoWriter] Failed to start asset writer: \(error)")
            }
        }
    }
    
    public func appendVideoFrame(pixelBuffer: CVPixelBuffer, presentationTime: CMTime) {
        writeQueue.async { [weak self] in
            guard let self = self, self.isRecording,
                  let writer = self.assetWriter,
                  let videoInput = self.videoWriterInput,
                  let adaptor = self.pixelBufferAdaptor else { return }
            
            if self.recordingStartTime == nil {
                self.recordingStartTime = presentationTime
                writer.startSession(atSourceTime: presentationTime)
            }
            
            if videoInput.isReadyForMoreMediaData {
                if !adaptor.append(pixelBuffer, withPresentationTime: presentationTime) {
                    DispatchQueue.main.async { self.droppedFrames += 1 }
                }
            } else {
                DispatchQueue.main.async { self.droppedFrames += 1 }
            }
        }
    }
    
    public func appendAudioSample(sampleBuffer: CMSampleBuffer) {
        writeQueue.async { [weak self] in
            guard let self = self, self.isRecording,
                  let audioInput = self.audioWriterInput,
                  self.recordingStartTime != nil else { return }
            
            if audioInput.isReadyForMoreMediaData {
                audioInput.append(sampleBuffer)
            }
        }
    }
    
    public func stopRecording(completion: ((URL?) -> Void)? = nil) {
        writeQueue.async { [weak self] in
            guard let self = self, self.isRecording, let writer = self.assetWriter else {
                completion?(nil)
                return
            }
            
            self.videoWriterInput?.markAsFinished()
            self.audioWriterInput?.markAsFinished()
            
            writer.finishWriting { [weak self] in
                guard let self = self else { return }
                DispatchQueue.main.async {
                    self.stopTimer()
                    self.isRecording = false
                    let savedUrl = self.currentOutputFileURL
                    print("[VideoWriter] Recording saved successfully: \(savedUrl?.path ?? "")")
                    
                    // Save to Photos Library in background
                    if let url = savedUrl {
                        PHPhotoLibrary.shared().performChanges({
                            PHAssetChangeRequest.creationRequestForAssetFromVideo(atFileURL: url)
                        }) { success, error in
                            print("[VideoWriter] Photos sync: \(success), error: \(String(describing: error))")
                        }
                    }
                    completion?(savedUrl)
                }
            }
        }
    }
    
    private func startTimer() {
        timer = Timer.scheduledTimer(withTimeInterval: 0.5, repeats: true) { [weak self] _ in
            guard let self = self else { return }
            self.recordingDuration += 0.5
            if let url = self.currentOutputFileURL,
               let attrs = try? FileManager.default.attributesOfItem(atPath: url.path),
               let size = attrs[.size] as? UInt64 {
                self.recordedFileSizeMB = Double(size) / (1024.0 * 1024.0)
            }
        }
    }
    
    private func stopTimer() {
        timer?.invalidate()
        timer = nil
    }
}
