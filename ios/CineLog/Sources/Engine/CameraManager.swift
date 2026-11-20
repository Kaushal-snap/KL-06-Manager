import Foundation
import AVFoundation
import CoreMedia
import CoreVideo
import Combine

public enum VideoResolution: String, CaseIterable {
    case uhd4K = "4K UHD (3840x2160)"
    case fhd1080p = "1080p FHD (1920x1080)"
}

public enum FrameRate: Int, CaseIterable {
    case fps24 = 24
    case fps25 = 25
    case fps30 = 30
    case fps60 = 60
}

public final class CameraManager: NSObject, ObservableObject {
    public let captureSession = AVCaptureSession()
    private let sessionQueue = DispatchQueue(label: "com.cinelog.sessionQueue", qos: .userInteractive)
    private let videoDataOutput = AVCaptureVideoDataOutput()
    private let audioDataOutput = AVCaptureAudioDataOutput()
    
    public var activeCamera: AVCaptureDevice?
    public let metalPipeline: MetalLogPipeline
    
    // Published Camera States for UI
    @Published public var isSessionRunning = false
    @Published public var currentISO: Float = 100.0
    @Published public var currentShutterSpeed: Double = 1.0 / 48.0 // 180° rule for 24fps
    @Published public var currentKelvin: Float = 5600.0 // Daylight balanced
    @Published public var currentTint: Float = 0.0
    @Published public var currentLensPosition: Float = 0.5
    @Published public var currentFrameRate: FrameRate = .fps24
    @Published public var currentResolution: VideoResolution = .uhd4K
    @Published public var isManualLocked: Bool = true
    
    // Delegate hooks for video & audio recording
    public var onVideoFrame: ((CVPixelBuffer, CMTime) -> Void)?
    public var onAudioSample: ((CMSampleBuffer) -> Void)?
    public var onPreviewTextureUpdated: ((MTLTexture) -> Void)?
    
    public init(metalPipeline: MetalLogPipeline) {
        self.metalPipeline = metalPipeline
        super.init()
    }
    
    public func configureSession() {
        sessionQueue.async { [weak self] in
            guard let self = self else { return }
            self.captureSession.beginConfiguration()
            
            // Prefer multi-camera / wide angle sensor on iPhone 14 Pro Max (Sony IMX803 48MP)
            let deviceDiscovery = AVCaptureDevice.DiscoverySession(
                deviceTypes: [.builtInWideAngleCamera, .builtInTripleCamera],
                mediaType: .video,
                position: .back
            )
            
            guard let device = deviceDiscovery.devices.first else {
                print("[CameraManager] No compatible cinema camera device found.")
                self.captureSession.commitConfiguration()
                return
            }
            self.activeCamera = device
            
            do {
                let videoInput = try AVCaptureDeviceInput(device: device)
                if self.captureSession.canAddInput(videoInput) {
                    self.captureSession.addInput(videoInput)
                }
            } catch {
                print("[CameraManager] Error creating camera input: \(error)")
            }
            
            // Setup 48kHz uncompressed audio input
            if let audioDevice = AVCaptureDevice.default(for: .audio),
               let audioInput = try? AVCaptureDeviceInput(device: audioDevice),
               self.captureSession.canAddInput(audioInput) {
                self.captureSession.addInput(audioInput)
            }
            
            // Configure 10-bit uncompressed pipeline bypass output
            self.videoDataOutput.alwaysDiscardsLateVideoFrames = false
            self.videoDataOutput.videoSettings = [
                kCVPixelBufferPixelFormatTypeKey as String: kCVPixelFormatType_420YpCbCr10BiPlanarVideoRange
            ]
            self.videoDataOutput.setSampleBufferDelegate(self, queue: self.sessionQueue)
            
            if self.captureSession.canAddOutput(self.videoDataOutput) {
                self.captureSession.addOutput(self.videoDataOutput)
            }
            
            self.audioDataOutput.setSampleBufferDelegate(self, queue: self.sessionQueue)
            if self.captureSession.canAddOutput(self.audioDataOutput) {
                self.captureSession.addOutput(self.audioDataOutput)
            }
            
            // Apply 4K 10-bit format and bypass Apple's dynamic tone-mapping
            self.applyBest10BitFormat(for: device, targetFPS: self.currentFrameRate.rawValue)
            self.lockCinemaManualControls()
            
            self.captureSession.commitConfiguration()
            self.captureSession.startRunning()
            
            DispatchQueue.main.async {
                self.isSessionRunning = self.captureSession.isRunning
            }
        }
    }
    
    // MARK: - Format Selection & Pipeline Bypass Configuration
    private func applyBest10BitFormat(for device: AVCaptureDevice, targetFPS: Int) {
        do {
            try device.lockForConfiguration()
            
            // Search for 4K 10-bit format with BT.2020 wide color gamut
            var selectedFormat: AVCaptureDevice.Format?
            for format in device.formats {
                let dims = CMVideoFormatDescriptionGetDimensions(format.formatDescription)
                let is4K = dims.width == 3840 && dims.height == 2160
                let is10Bit = format.formatDescription.mediaSubType.rawValue == kCVPixelFormatType_420YpCbCr10BiPlanarVideoRange
                
                if is4K && is10Bit {
                    for range in format.videoSupportedFrameRateRanges {
                        if range.maxFrameRate >= Double(targetFPS) && range.minFrameRate <= Double(targetFPS) {
                            selectedFormat = format
                            break
                        }
                    }
                }
                if selectedFormat != nil { break }
            }
            
            if let format = selectedFormat {
                device.activeFormat = format
                let duration = CMTime(value: 1, timescale: CMTimeScale(targetFPS))
                device.activeVideoMinFrameDuration = duration
                device.activeVideoMaxFrameDuration = duration
                print("[CameraManager] Successfully selected 4K 10-bit HDR bypass format at \(targetFPS) fps.")
            }
            
            // Turn OFF digital EIS / stabilization warping that destroys sensor sharpness
            if let conn = self.videoDataOutput.connection(with: .video) {
                if conn.isVideoStabilizationSupported {
                    conn.preferredVideoStabilizationMode = .off
                }
            }
            
            device.unlockForConfiguration()
        } catch {
            print("[CameraManager] Could not lock camera for configuration: \(error)")
        }
    }
    
    // MARK: - Full Manual Lock (Disables Apple's Dynamic Smart HDR & Local Tone Mapping)
    public func lockCinemaManualControls() {
        guard let device = activeCamera else { return }
        do {
            try device.lockForConfiguration()
            
            // 1. Shutter & ISO Lock (Eliminates temporal exposure shifts)
            let duration = CMTime(seconds: currentShutterSpeed, preferredTimescale: 1000000)
            let iso = max(device.activeFormat.minISO, min(device.activeFormat.maxISO, currentISO))
            device.setExposureModeCustom(duration: duration, iso: iso, completionHandler: nil)
            
            // 2. White Balance Lock (Locks chromatic adaptation and sensor color gains)
            let temperatureAndTint = AVCaptureDevice.WhiteBalanceTemperatureAndTintValues(
                temperature: currentKelvin,
                tint: currentTint
            )
            let gains = device.deviceWhiteBalanceGains(for: temperatureAndTint)
            let normalizedGains = normalizedWhiteBalanceGains(gains, for: device)
            device.setWhiteBalanceModeLocked(with: normalizedGains, completionHandler: nil)
            
            // 3. Manual Focus Lock
            device.setFocusModeLocked(lensPosition: currentLensPosition, completionHandler: nil)
            
            device.unlockForConfiguration()
        } catch {
            print("[CameraManager] Failed to lock cinema manual controls: \(error)")
        }
    }
    
    public func setShutterSpeed(_ speed: Double) {
        currentShutterSpeed = speed
        lockCinemaManualControls()
    }
    
    public func setISO(_ iso: Float) {
        currentISO = iso
        lockCinemaManualControls()
    }
    
    public func setKelvin(_ kelvin: Float) {
        currentKelvin = kelvin
        lockCinemaManualControls()
    }
    
    public func setLensPosition(_ pos: Float) {
        currentLensPosition = pos
        lockCinemaManualControls()
    }
    
    private func normalizedWhiteBalanceGains(_ gains: AVCaptureDevice.WhiteBalanceGains, for device: AVCaptureDevice) -> AVCaptureDevice.WhiteBalanceGains {
        var g = gains
        let maxGain = device.maxWhiteBalanceGain
        g.redGain = max(1.0, min(maxGain, g.redGain))
        g.greenGain = max(1.0, min(maxGain, g.greenGain))
        g.blueGain = max(1.0, min(maxGain, g.blueGain))
        return g
    }
}

// MARK: - AVCaptureVideoDataOutputSampleBufferDelegate
extension CameraManager: AVCaptureVideoDataOutputSampleBufferDelegate, AVCaptureAudioDataOutputSampleBufferDelegate {
    public func captureOutput(_ output: AVCaptureOutput, didOutput sampleBuffer: CMSampleBuffer, from connection: AVCaptureConnection) {
        if output == videoDataOutput {
            guard let pixelBuffer = CMSampleBufferGetImageBuffer(sampleBuffer) else { return }
            let pts = CMSampleBufferGetPresentationTimeStamp(sampleBuffer)
            
            // Process 10-bit frame through Metal pipeline to get Apple Log & preview
            let (logTexture, previewTexture) = metalPipeline.processFrame(pixelBuffer: pixelBuffer)
            
            if let preview = previewTexture {
                DispatchQueue.main.async { [weak self] in
                    self?.onPreviewTextureUpdated?(preview)
                }
            }
            
            // Forward frame to video recorder
            onVideoFrame?(pixelBuffer, pts)
        } else if output == audioDataOutput {
            onAudioSample?(sampleBuffer)
        }
    }
}
