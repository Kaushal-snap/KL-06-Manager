import Foundation
import AVFoundation
import Photos

/// Apple ProRAW still capture (real DNG written by AVFoundation). There is no RAW *video* API on
/// iPhone 13/14 Pro, so "RAW" in CineLog means ProRAW stills, available when the current camera format supports it.
public final class ProRawCapture: NSObject, ObservableObject, AVCapturePhotoCaptureDelegate {
    @Published public var message: String = ""
    @Published public var savedCount: Int = 0
    private weak var photoOutput: AVCapturePhotoOutput?

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
