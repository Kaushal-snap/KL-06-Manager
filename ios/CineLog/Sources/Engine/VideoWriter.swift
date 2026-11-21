import Foundation
import AVFoundation
import CoreMedia
import CoreVideo
import VideoToolbox
import Photos

public enum RecordingCodec: String, CaseIterable {
    case proRes422HQ = "ProRes 422 HQ"
    case proRes422 = "ProRes 422"
    case hevc10Bit = "HEVC 10-bit"

    /// Rough data rate for 4K 24 fps (ProRes figures from Apple's ProRes white paper), Mbps.
    var approxMbps: Double {
        switch self { case .proRes422HQ: return 707; case .proRes422: return 471; case .hevc10Bit: return 150 }
    }
}

/// How much disk a recording may use.
public enum StorageMode: String, CaseIterable {
    case full = "Full only"
    case fullPlusProxy = "Full + Proxy"
    case proxyOnly = "Proxy only (tiny)"
}

public final class VideoWriter: ObservableObject {
    private struct Track {
        var writer: AVAssetWriter
        var video: AVAssetWriterInput
        var audio: AVAssetWriterInput?
        var adaptor: AVAssetWriterInputPixelBufferAdaptor
        var url: URL
    }
    private var full: Track?
    private var proxy: Track?

    private let writeQueue = DispatchQueue(label: "com.cinelog.writerQueue", qos: .userInteractive)

    @Published public var isRecording = false
    @Published public var recordingDuration: TimeInterval = 0.0
    @Published public var recordedFileSizeMB: Double = 0.0
    @Published public var droppedFrames: Int = 0
    @Published public var currentCodec: RecordingCodec = .hevc10Bit      // HEVC default: ~5x smaller than ProRes HQ
    @Published public var storageMode: StorageMode = .fullPlusProxy
    @Published public var lastMessage: String = ""
    /// Proxy: HEVC 10-bit, 1920x1080 (or source size if smaller), 15 Mbps.
    public var proxyBitrate = 15_000_000

    private var sessionStarted = false
    private var timer: Timer?

    public init() {}

    /// Estimated disk use in MB per minute for the current settings (4K24 reference; scales with pixels and fps).
    public func estimatedMBPerMinute(width: Int, height: Int, fps: Int) -> Double {
        let scale = (Double(width * height) / (3840.0 * 2160.0)) * (Double(fps) / 24.0)
        let fullMbps = currentCodec.approxMbps * scale
        let proxyMbps = Double(proxyBitrate) / 1_000_000
        let mbps: Double
        switch storageMode {
        case .full: mbps = fullMbps
        case .fullPlusProxy: mbps = fullMbps + proxyMbps
        case .proxyOnly: mbps = proxyMbps
        }
        return mbps / 8.0 * 60.0
    }

    private func makeTrack(url: URL, codec: AVVideoCodecType, width: Int, height: Int, fps: Int,
                           bitrate: Int?, tagColor: Bool, audioAAC: Bool, includeAudio: Bool) throws -> Track {
        let writer = try AVAssetWriter(outputURL: url, fileType: .mov)
        var settings: [String: Any] = [
            AVVideoCodecKey: codec, AVVideoWidthKey: width, AVVideoHeightKey: height
        ]
        if tagColor {
            // Frames are Apple-Log-style, not display-referred: BT.2020 primaries/matrix, transfer left untagged
            // so Resolve/FCP do not apply an HLG curve on top. Use a Color Space Transform (Apple Log) in post.
            settings[AVVideoColorPropertiesKey] = [
                AVVideoColorPrimariesKey: AVVideoColorPrimaries_ITU_R_2020,
                AVVideoYCbCrMatrixKey: AVVideoYCbCrMatrix_ITU_R_2020
            ]
        }
        if codec == .hevc {
            var comp: [String: Any] = [
                AVVideoProfileLevelKey: kVTProfileLevel_HEVC_Main10_AutoLevel as String,
                AVVideoExpectedSourceFrameRateKey: fps
            ]
            if let b = bitrate { comp[AVVideoAverageBitRateKey] = b }
            settings[AVVideoCompressionPropertiesKey] = comp
        }
        let input = AVAssetWriterInput(mediaType: .video, outputSettings: settings)
        input.expectsMediaDataInRealTime = true
        guard writer.canAdd(input) else { throw NSError(domain: "CineLog", code: 1, userInfo: [NSLocalizedDescriptionKey: "Codec not supported on this device"]) }
        writer.add(input)
        let adaptor = AVAssetWriterInputPixelBufferAdaptor(assetWriterInput: input, sourcePixelBufferAttributes: [
            kCVPixelBufferPixelFormatTypeKey as String: kCVPixelFormatType_420YpCbCr10BiPlanarVideoRange,
            kCVPixelBufferWidthKey as String: width, kCVPixelBufferHeightKey as String: height
        ])
        var audioInput: AVAssetWriterInput?
        if includeAudio {
            let a: [String: Any] = audioAAC
                ? [AVFormatIDKey: kAudioFormatMPEG4AAC, AVSampleRateKey: 48000.0, AVNumberOfChannelsKey: 2, AVEncoderBitRateKey: 128_000]
                : [AVFormatIDKey: kAudioFormatLinearPCM, AVSampleRateKey: 48000.0, AVNumberOfChannelsKey: 2,
                   AVLinearPCMBitDepthKey: 24, AVLinearPCMIsFloatKey: false, AVLinearPCMIsBigEndianKey: false,
                   AVLinearPCMIsNonInterleaved: false]
            let ai = AVAssetWriterInput(mediaType: .audio, outputSettings: a)
            ai.expectsMediaDataInRealTime = true
            if writer.canAdd(ai) { writer.add(ai); audioInput = ai }
        }
        guard writer.startWriting() else { throw writer.error ?? NSError(domain: "CineLog", code: 2) }
        return Track(writer: writer, video: input, audio: audioInput, adaptor: adaptor, url: url)
    }

    public func startRecording(width: Int = 3840, height: Int = 2160, fps: Int = 24) {
        writeQueue.async { [weak self] in
            guard let self = self, !self.isRecording else { return }
            let stem = "CineLog_\(Int(Date().timeIntervalSince1970))"
            let dir = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
            var message = ""
            do {
                if self.storageMode != .proxyOnly {
                    let codec: AVVideoCodecType = self.currentCodec == .proRes422HQ ? .proRes422HQ
                        : self.currentCodec == .proRes422 ? .proRes422 : .hevc
                    do {
                        self.full = try self.makeTrack(url: dir.appendingPathComponent("\(stem).mov"), codec: codec,
                            width: width, height: height, fps: fps, bitrate: 150_000_000,
                            tagColor: true, audioAAC: false, includeAudio: true)
                    } catch {
                        // ProRes is not available on every iPhone/storage size: fall back to HEVC 10-bit.
                        message = "\(self.currentCodec.rawValue) unavailable here, using HEVC 10-bit."
                        self.full = try self.makeTrack(url: dir.appendingPathComponent("\(stem).mov"), codec: .hevc,
                            width: width, height: height, fps: fps, bitrate: 150_000_000,
                            tagColor: true, audioAAC: false, includeAudio: true)
                    }
                }
                if self.storageMode != .full {
                    let pw = min(width, 1920), ph = min(height, 1080)
                    self.proxy = try self.makeTrack(url: dir.appendingPathComponent("\(stem)_proxy.mov"), codec: .hevc,
                        width: pw, height: ph, fps: fps, bitrate: self.proxyBitrate,
                        tagColor: true, audioAAC: true, includeAudio: true)
                }
            } catch {
                self.full = nil; self.proxy = nil
                DispatchQueue.main.async { self.lastMessage = "Could not start recording: \(error.localizedDescription)" }
                return
            }
            self.sessionStarted = false
            DispatchQueue.main.async {
                self.lastMessage = message
                self.isRecording = true
                self.recordingDuration = 0; self.recordedFileSizeMB = 0; self.droppedFrames = 0
                self.startTimer()
            }
        }
    }

    public func appendVideoFrame(pixelBuffer: CVPixelBuffer, presentationTime: CMTime) {
        writeQueue.async { [weak self] in
            guard let self = self, self.isRecording else { return }
            let tracks = [self.full, self.proxy].compactMap { $0 }
            if !self.sessionStarted {
                tracks.forEach { $0.writer.startSession(atSourceTime: presentationTime) }
                self.sessionStarted = true
            }
            for t in tracks {
                if t.video.isReadyForMoreMediaData {
                    if !t.adaptor.append(pixelBuffer, withPresentationTime: presentationTime) {
                        DispatchQueue.main.async { self.droppedFrames += 1 }
                    }
                } else {
                    DispatchQueue.main.async { self.droppedFrames += 1 }
                }
            }
        }
    }

    public func appendAudioSample(sampleBuffer: CMSampleBuffer) {
        writeQueue.async { [weak self] in
            guard let self = self, self.isRecording, self.sessionStarted else { return }
            for t in [self.full, self.proxy].compactMap({ $0 }) {
                if let a = t.audio, a.isReadyForMoreMediaData { a.append(sampleBuffer) }
            }
        }
    }

    public func stopRecording(completion: ((URL?) -> Void)? = nil) {
        writeQueue.async { [weak self] in
            guard let self = self, self.isRecording else { completion?(nil); return }
            let tracks = [self.full, self.proxy].compactMap { $0 }
            let group = DispatchGroup()
            for t in tracks {
                t.video.markAsFinished(); t.audio?.markAsFinished()
                group.enter()
                t.writer.finishWriting { group.leave() }
            }
            group.notify(queue: .main) {
                self.stopTimer()
                self.isRecording = false
                self.full = nil; self.proxy = nil
                let urls = tracks.map { $0.url }
                for url in urls {
                    PHPhotoLibrary.shared().performChanges({
                        PHAssetChangeRequest.creationRequestForAssetFromVideo(atFileURL: url)
                    }) { ok, err in print("[VideoWriter] Photos sync \(url.lastPathComponent): \(ok) \(String(describing: err))") }
                }
                completion?(urls.first)
            }
        }
    }

    private func startTimer() {
        timer = Timer.scheduledTimer(withTimeInterval: 0.5, repeats: true) { [weak self] _ in
            guard let self = self else { return }
            self.recordingDuration += 0.5
            let urls = [self.full, self.proxy].compactMap { $0?.url }
            let bytes = urls.reduce(UInt64(0)) { acc, u in
                acc + ((try? FileManager.default.attributesOfItem(atPath: u.path)[.size] as? UInt64) ?? 0)
            }
            self.recordedFileSizeMB = Double(bytes) / (1024.0 * 1024.0)
        }
    }

    private func stopTimer() { timer?.invalidate(); timer = nil }
}
