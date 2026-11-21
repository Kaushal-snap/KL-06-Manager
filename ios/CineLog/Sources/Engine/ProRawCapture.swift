import Foundation
import AVFoundation
import Photos

/// Apple ProRAW still capture (real DNG written by AVFoundation). There is no RAW *video* API on
/// iPhone 13/14 Pro, so "RAW" in CineLog means ProRAW stills, available when the current camera format supports it.
public final class ProRawCapture: NSObject, ObservableObject, AVCapturePhotoCaptureDelegate {
    @Published public var message: String = ""
    @Published public var savedCount: Int = 0
    private weak var photoOutput: AVCapturePhotoOutput?

    // Bayer RAW sequence (experimental "RAW video" = back-to-back Bayer RAW photos saved as numbered DNGs).
    @Published public var sequenceActive = false
    @Published public var sequenceFrames = 0
    @Published public var sequenceFPS: Double = 0
    private var folder: URL?
    private var inFlight = 0
    private var seqStart = Date()
    private let ioQueue = DispatchQueue(label: "com.cinelog.dngwrite", qos: .userInitiated)

    /// Files land in Files app > CineLog > CineRAW_<time>/frame_00001.dng (not copied to Photos: far too large).
    public func startSequence(using output: AVCapturePhotoOutput) {
        guard let fmt = output.availableRawPhotoPixelFormatTypes.first(where: { AVCapturePhotoOutput.isBayerRAWPixelFormat($0) }) else {
            message = "Bayer RAW not offered by this camera/format."; return
        }
        let dir = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
            .appendingPathComponent("CineRAW_\(Int(Date().timeIntervalSince1970))")
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        folder = dir; photoOutput = output; seqFormat = fmt
        sequenceFrames = 0; sequenceFPS = 0; inFlight = 0; seqStart = Date(); sequenceActive = true
        message = "RAW sequence started (speed depends on phone; watch the fps counter)."
        pump()
    }
    public func stopSequence() {
        sequenceActive = false
        let name = folder?.lastPathComponent ?? ""
        message = "RAW sequence stopped: \(sequenceFrames) frames in \(name)"
    }
    private var seqFormat: OSType = 0
    private func pump() {
        guard sequenceActive, let out = photoOutput else { return }
        while inFlight < 2 && sequenceActive {
            inFlight += 1
            let st = AVCapturePhotoSettings(rawPixelFormatType: seqFormat)
            st.photoQualityPrioritization = .speed
            out.capturePhoto(with: st, delegate: self)
        }
    }

    public func capture(using output: AVCapturePhotoOutput) {
        photoOutput = output
        guard output.isAppleProRAWSupported else {
            message = "ProRAW not available in the current video format. Try 4K 24/30 fps or a photo-capable format."
            return
        }
        output.isAppleProRAWEnabled = true
        guard let rawFormat = output.availableRawPhotoPixelFormatTypes.first(where: { AVCapturePhotoOutput.isAppleProRAWPixelFormat($0) }) else {
            message = "No ProRAW pixel format offered by this camera."
            return
        }
        let settings = AVCapturePhotoSettings(rawPixelFormatType: rawFormat)
        output.capturePhoto(with: settings, delegate: self)
    }

    public func photoOutput(_ output: AVCapturePhotoOutput, didFinishProcessingPhoto photo: AVCapturePhoto, error: Error?) {
        if sequenceActive || folder != nil && inFlight > 0 {
            DispatchQueue.main.async {
                self.inFlight = max(0, self.inFlight - 1)
                if error == nil, photo.isRawPhoto, let data = photo.fileDataRepresentation(), let dir = self.folder {
                    self.sequenceFrames += 1
                    let n = self.sequenceFrames
                    let secs = max(0.001, Date().timeIntervalSince(self.seqStart))
                    self.sequenceFPS = Double(n) / secs
                    self.ioQueue.async { try? data.write(to: dir.appendingPathComponent(String(format: "frame_%05d.dng", n))) }
                } else if let error = error { self.message = "RAW frame failed: \(error.localizedDescription)" }
                self.pump()
            }
            return
        }
        if let error = error { DispatchQueue.main.async { self.message = "Capture failed: \(error.localizedDescription)" }; return }
        guard photo.isRawPhoto, let data = photo.fileDataRepresentation() else { return }
        let url = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
            .appendingPathComponent("CineRAW_\(Int(Date().timeIntervalSince1970)).dng")
        do { try data.write(to: url, options: .atomic) } catch {
            DispatchQueue.main.async { self.message = "Could not write DNG: \(error.localizedDescription)" }; return
        }
        PHPhotoLibrary.shared().performChanges({
            let req = PHAssetCreationRequest.forAsset()
            req.addResource(with: .photo, fileURL: url, options: nil)
        }) { ok, err in
            DispatchQueue.main.async {
                self.message = ok ? "ProRAW saved (\(url.lastPathComponent))" : "Saved in app files; Photos: \(err?.localizedDescription ?? "failed")"
                if ok { self.savedCount += 1 }
            }
        }
    }
}
