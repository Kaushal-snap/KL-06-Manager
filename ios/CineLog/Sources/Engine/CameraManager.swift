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
    public let photoOutput = AVCapturePhotoOutput()
    
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
    @Published public var statusMessage: String = ""
    @Published public var supportedFrameRates: [FrameRate] = []
    
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
            self.videoDataOutput.alwaysDiscardsLateVideoFrames = true
            self.videoDataOutput.videoSettings = [
                kCVPixelBufferPixelFormatTypeKey as String: kCVPixelFormatType_420YpCbCr10BiPlanarVideoRange
            ]
            self.videoDataOutput.setSampleBufferDelegate(self, queue: self.sessionQueue)
            
            if self.captureSession.canAddOutput(self.videoDataOutput) {
                self.captureSession.addOutput(self.videoDataOutput)
            }
            
            if self.captureSession.canAddOutput(self.photoOutput) { self.captureSession.addOutput(self.photoOutput) }
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
    
    // MARK: - RAW sequence mode (Bayer RAW through AVCapturePhotoOutput)
    /// Switches to the photo preset so the photo output can offer Bayer RAW, then reports whether it does.
    public func enterRawMode(completion: @escaping (Bool) -> Void) {
        sessionQueue.async { [weak self] in
            guard let self = self else { return }
            self.captureSession.beginConfiguration()
            self.captureSession.sessionPreset = .photo
            if self.photoOutput.isAppleProRAWSupported { self.photoOutput.isAppleProRAWEnabled = false } // list Bayer formats only
            self.photoOutput.maxPhotoQualityPrioritization = .speed
            self.captureSession.commitConfiguration()
            let ok = self.photoOutput.availableRawPhotoPixelFormatTypes.contains { AVCapturePhotoOutput.isBayerRAWPixelFormat($0) }
            DispatchQueue.main.async { completion(ok) }
        }
    }
    public func exitRawMode() { reconfigureFormat() }

    // MARK: - Format selection: 10-bit HLG (Dolby Vision-capable) format, resolution/fps from the UI
    private func applyBest10BitFormat(for device: AVCaptureDevice, targetFPS: Int) {
        let wantW: Int32 = currentResolution == .uhd4K ? 3840 : 1920
        let wantH: Int32 = currentResolution == .uhd4K ? 2160 : 1080
        func fpsOK(_ f: AVCaptureDevice.Format) -> Bool {
            f.videoSupportedFrameRateRanges.contains { $0.minFrameRate <= Double(targetFPS) && $0.maxFrameRate >= Double(targetFPS) }
        }
        let tenBit = device.formats.filter {
            $0.formatDescription.mediaSubType.rawValue == kCVPixelFormatType_420YpCbCr10BiPlanarVideoRange
                && $0.supportedColorSpaces.contains(.HLG_BT2020)
        }
        var rates = Set<FrameRate>()
        for f in tenBit {
            let d = CMVideoFormatDescriptionGetDimensions(f.formatDescription)
            guard d.width == wantW && d.height == wantH else { continue }
            for r in FrameRate.allCases where f.videoSupportedFrameRateRanges.contains(where: { $0.minFrameRate <= Double(r.rawValue) && $0.maxFrameRate >= Double(r.rawValue) }) { rates.insert(r) }
        }
        let chosen = tenBit.first { f in
            let d = CMVideoFormatDescriptionGetDimensions(f.formatDescription)
            return d.width == wantW && d.height == wantH && fpsOK(f)
        }
        DispatchQueue.main.async {
            self.supportedFrameRates = FrameRate.allCases.filter { rates.contains($0) }
            if chosen == nil { self.statusMessage = "\(self.currentResolution.rawValue) \(targetFPS) fps 10-bit HLG is not supported on this iPhone." }
            else { self.statusMessage = "" }
        }
        guard let format = chosen else { return }
        do {
            try device.lockForConfiguration()
            captureSession.sessionPreset = .inputPriority
            device.activeFormat = format
            let duration = CMTime(value: 1, timescale: CMTimeScale(targetFPS))
            device.activeVideoMinFrameDuration = duration
            device.activeVideoMaxFrameDuration = duration
            // Real 10-bit HLG capture (Apple's HDR video path). The Log look is computed from it in Metal.
            device.activeColorSpace = .HLG_BT2020
            if device.activeFormat.isVideoHDRSupported {
                device.automaticallyAdjustsVideoHDREnabled = false
                device.isVideoHDREnabled = true
            }
            if let conn = videoDataOutput.connection(with: .video), conn.isVideoStabilizationSupported {
                conn.preferredVideoStabilizationMode = .off
            }
            device.unlockForConfiguration()
        } catch {
            print("[CameraManager] Could not lock camera for configuration: \(error)")
        }
    }

    /// Re-apply resolution / frame-rate chosen in the UI.
    public func reconfigureFormat() {
        sessionQueue.async { [weak self] in
            guard let self = self, let device = self.activeCamera else { return }
            self.captureSession.beginConfiguration()
            self.applyBest10BitFormat(for: device, targetFPS: self.currentFrameRate.rawValue)
            self.captureSession.commitConfiguration()
            self.lockCinemaManualControls()
        }
    }
    public func setFrameRate(_ fps: FrameRate) { currentFrameRate = fps; reconfigureFormat() }
    public func setResolution(_ res: VideoResolution) { currentResolution = res; reconfigureFormat() }

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
            
            // 10-bit HLG frame -> Apple-Log-style 10-bit frame (recorded) + monitoring texture (preview)
            metalPipeline.processFrame(pixelBuffer: pixelBuffer) { [weak self] logBuffer, preview in
                guard let self = self else { return }
                if let preview = preview {
                    DispatchQueue.main.async { self.onPreviewTextureUpdated?(preview) }
                }
                // If the Log pass failed, record the untouched camera frame (HLG) instead of dropping it.
                self.onVideoFrame?(logBuffer ?? pixelBuffer, pts)
            }
        } else if output == audioDataOutput {
            onAudioSample?(sampleBuffer)
        }
    }
}
