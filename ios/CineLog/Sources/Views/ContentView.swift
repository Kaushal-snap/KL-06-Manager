import SwiftUI

public struct ContentView: View {
    @StateObject private var cameraManager: CameraManager
    @StateObject private var videoWriter = VideoWriter()
    @StateObject private var rawWriter = CinemaDNGWriter()
    
    @State private var selectedTab: Int = 0
    @State private var showCinemaGuide: Bool = true
    @State private var showGrid: Bool = false
    @State private var isRawMode: Bool = false
    @State private var lastRecordedURL: URL?
    @State private var showSaveAlert: Bool = false
    
    public init() {
        let pipeline = MetalLogPipeline() ?? MetalLogPipeline.init()!
        _cameraManager = StateObject(wrappedValue: CameraManager(metalPipeline: pipeline))
    }
    
    public var body: some View {
        ZStack {
            Color.black.edgesIgnoringSafeArea(.all)
            
            // 1. Live Metal Viewport (120Hz ProMotion Apple Log View)
            CameraPreviewView(cameraManager: cameraManager)
                .edgesIgnoringSafeArea(.all)
            
            // 2. HUD & Cinema Scope Overlays
            ScopeOverlaysView(
                cameraManager: cameraManager,
                videoWriter: videoWriter,
                showCinemaGuide: $showCinemaGuide,
                showGrid: $showGrid
            )
            
            // 3. Right Action Column (Record Button & Assist Tools)
            HStack {
                Spacer()
                VStack(spacing: 20) {
                    // Monitoring Mode Cycle Button
                    monitoringModeButton
                    
                    // CinemaScope Guide Toggle
                    guideToggleButton
                    
                    // RAW Sequence Mode Toggle
                    rawModeToggleButton
                    
                    Spacer()
                    
                    // Main Cinema Record Button
                    recordButton
                    
                    Spacer()
                }
                .padding(.trailing, 16)
                .padding(.top, 100)
                .padding(.bottom, 120)
            }
            
            // 4. Bottom Cinema Control Wheels
            VStack {
                Spacer()
                CinemaControlsView(
                    cameraManager: cameraManager,
                    videoWriter: videoWriter,
                    selectedTab: $selectedTab
                )
                .padding(.bottom, 20)
            }
        }
        .onAppear {
            setupCallbacks()
            cameraManager.configureSession()
        }
        .alert(isPresented: $showSaveAlert) {
            Alert(
                title: Text("Clip Saved Successfully!"),
                message: Text("Recorded in 10-bit Apple Log format.\nSaved to Photos & Files: \(lastRecordedURL?.lastPathComponent ?? "")"),
                dismissButton: .default(Text("OK"))
            )
        }
    }
    
    private func setupCallbacks() {
        cameraManager.onVideoFrame = { [weak videoWriter, weak rawWriter] pixelBuffer, pts in
            if self.isRawMode {
                rawWriter?.appendRawFrame(pixelBuffer: pixelBuffer, presentationTime: pts)
            } else {
                videoWriter?.appendVideoFrame(pixelBuffer: pixelBuffer, presentationTime: pts)
            }
        }
        cameraManager.onAudioSample = { [weak videoWriter] sampleBuffer in
            if !self.isRawMode {
                videoWriter?.appendAudioSample(sampleBuffer: sampleBuffer)
            }
        }
    }
    
    // MARK: - Record Button Logic
    private var recordButton: some View {
        Button(action: toggleRecording) {
            ZStack {
                Circle()
                    .stroke(Color.white, lineWidth: 4)
                    .frame(width: 72, height: 72)
                
                if videoWriter.isRecording || rawWriter.isRawRecording {
                    RoundedRectangle(cornerRadius: 6)
                        .fill(Color.red)
                        .frame(width: 32, height: 32)
                } else {
                    Circle()
                        .fill(Color.red)
                        .frame(width: 58, height: 58)
                }
            }
        }
    }
    
    private func toggleRecording() {
        if isRawMode {
            if rawWriter.isRawRecording {
                rawWriter.stopRawSequence { url in
                    self.lastRecordedURL = url
                    self.showSaveAlert = true
                }
            } else {
                rawWriter.startRawSequence()
            }
        } else {
            if videoWriter.isRecording {
                videoWriter.stopRecording { url in
                    self.lastRecordedURL = url
                    self.showSaveAlert = true
                }
            } else {
                videoWriter.startRecording(
                    width: 3840,
                    height: 2160,
                    fps: cameraManager.currentFrameRate.rawValue
                )
            }
        }
    }
    
    // MARK: - Monitoring Mode Button
    private var monitoringModeButton: some View {
        Button(action: cycleMonitoringMode) {
            VStack(spacing: 2) {
                Image(systemName: monitoringIcon)
                    .font(.system(size: 18))
                Text(monitoringLabel)
                    .font(.system(size: 8, weight: .bold))
            }
            .foregroundColor(.white)
            .frame(width: 50, height: 50)
            .background(Color.black.opacity(0.7))
            .clipShape(Circle())
        }
    }
    
    private var monitoringIcon: String {
        switch cameraManager.metalPipeline.currentMonitoringMode {
        case .rec709LUT: return "tv"
        case .flatLog: return "film"
        case .falseColor: return "eyedropper.halffull"
        case .focusPeaking: return "waveform.path.badge.plus"
        }
    }
    
    private var monitoringLabel: String {
        switch cameraManager.metalPipeline.currentMonitoringMode {
        case .rec709LUT: return "LUT 709"
        case .flatLog: return "RAW LOG"
        case .falseColor: return "FALSE"
        case .focusPeaking: return "PEAK"
        }
    }
    
    private func cycleMonitoringMode() {
        let current = cameraManager.metalPipeline.currentMonitoringMode
        let next: MonitoringMode
        switch current {
        case .rec709LUT: next = .flatLog
        case .flatLog: next = .falseColor
        case .falseColor: next = .focusPeaking
        case .focusPeaking: next = .rec709LUT
        }
        cameraManager.metalPipeline.currentMonitoringMode = next
    }
    
    private var guideToggleButton: some View {
        Button(action: { showCinemaGuide.toggle() }) {
            VStack(spacing: 2) {
                Image(systemName: "aspectratio")
                    .font(.system(size: 16))
                Text(showCinemaGuide ? "2.39:1" : "16:9")
                    .font(.system(size: 8, weight: .bold))
            }
            .foregroundColor(showCinemaGuide ? .yellow : .white)
            .frame(width: 50, height: 50)
            .background(Color.black.opacity(0.7))
            .clipShape(Circle())
        }
    }
    
    private var rawModeToggleButton: some View {
        Button(action: { isRawMode.toggle() }) {
            VStack(spacing: 2) {
                Image(systemName: "camera.aperture")
                    .font(.system(size: 16))
                Text(isRawMode ? "cDNG RAW" : "PRORES")
                    .font(.system(size: 7, weight: .black))
            }
            .foregroundColor(isRawMode ? .orange : .white)
            .frame(width: 50, height: 50)
            .background(Color.black.opacity(0.7))
            .clipShape(Circle())
        }
    }
}
