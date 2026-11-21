import SwiftUI

public struct ContentView: View {
    @StateObject private var cameraManager: CameraManager
    @StateObject private var videoWriter = VideoWriter()
    @StateObject private var rawCapture = ProRawCapture()
    
    @State private var selectedTab: Int = 0
    @State private var showCinemaGuide: Bool = true
    @State private var showGrid: Bool = false
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
                    
                    // ProRAW still + storage/proxy menu
                    rawModeToggleButton
                    rawSequenceButton
                    storageMenu
                    
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
        .overlay(alignment: .top) {
            let msg = [cameraManager.statusMessage, videoWriter.lastMessage, rawCapture.message].first { !$0.isEmpty } ?? ""
            if !msg.isEmpty { Text(msg).font(.caption).padding(8).background(Color.black.opacity(0.75)).foregroundColor(.yellow).cornerRadius(8).padding(.top, 50) }
        }
        .onAppear {
            setupCallbacks()
            cameraManager.configureSession()
        }
        .alert(isPresented: $showSaveAlert) {
            Alert(
                title: Text("Clip Saved Successfully!"),
                message: Text("10-bit Apple-Log-style clip (grade with Apple Log CST; derived from HLG).\nSaved to Photos & Files: \(lastRecordedURL?.lastPathComponent ?? "")"),
                dismissButton: .default(Text("OK"))
            )
        }
    }
    
    private func setupCallbacks() {
        cameraManager.onVideoFrame = { [weak videoWriter] pixelBuffer, pts in
            videoWriter?.appendVideoFrame(pixelBuffer: pixelBuffer, presentationTime: pts)
        }
        cameraManager.onAudioSample = { [weak videoWriter] sampleBuffer in
            videoWriter?.appendAudioSample(sampleBuffer: sampleBuffer)
        }
    }
    
    // MARK: - Record Button Logic
    private var recordButton: some View {
        Button(action: toggleRecording) {
            ZStack {
                Circle()
                    .stroke(Color.white, lineWidth: 4)
                    .frame(width: 72, height: 72)
                
                if videoWriter.isRecording {
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
        if videoWriter.isRecording {
            videoWriter.stopRecording { url in
                self.lastRecordedURL = url
                self.showSaveAlert = true
            }
        } else {
            let is4K = cameraManager.currentResolution == .uhd4K
            videoWriter.startRecording(
                width: is4K ? 3840 : 1920,
                height: is4K ? 2160 : 1080,
                fps: cameraManager.currentFrameRate.rawValue
            )
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
        Button(action: { rawCapture.capture(using: cameraManager.photoOutput) }) {
            VStack(spacing: 2) {
                Image(systemName: "camera.aperture")
                    .font(.system(size: 16))
                Text("PRORAW")
                    .font(.system(size: 7, weight: .black))
            }
            .foregroundColor(.orange)
            .frame(width: 50, height: 50)
            .background(Color.black.opacity(0.7))
            .clipShape(Circle())
        }
    }

    private var rawSequenceButton: some View {
        Button(action: {
            if rawCapture.sequenceActive {
                rawCapture.stopSequence(); cameraManager.exitRawMode()
            } else {
                cameraManager.enterRawMode { ok in
                    if ok { rawCapture.startSequence(using: cameraManager.photoOutput) }
                    else { rawCapture.message = "Bayer RAW not available on this camera. Try the main (wide) camera."; cameraManager.exitRawMode() }
                }
            }
        }) {
            VStack(spacing: 2) {
                Image(systemName: "film.stack").font(.system(size: 16))
                Text(rawCapture.sequenceActive ? String(format: "%.1f fps", rawCapture.sequenceFPS) : "RAW SEQ")
                    .font(.system(size: 7, weight: .black))
            }
            .foregroundColor(rawCapture.sequenceActive ? .red : .orange)
            .frame(width: 50, height: 50)
            .background(Color.black.opacity(0.7))
            .clipShape(Circle())
        }
    }

    /// Storage: full file, full + small proxy, or proxy only; codec choice; live size estimate.
    private var storageMenu: some View {
        let is4K = cameraManager.currentResolution == .uhd4K
        let mb = videoWriter.estimatedMBPerMinute(width: is4K ? 3840 : 1920, height: is4K ? 2160 : 1080,
                                                  fps: cameraManager.currentFrameRate.rawValue)
        return Menu {
            Picker("Storage", selection: $videoWriter.storageMode) {
                ForEach(StorageMode.allCases, id: \.self) { Text($0.rawValue).tag($0) }
            }
            Picker("Codec", selection: $videoWriter.currentCodec) {
                ForEach(RecordingCodec.allCases, id: \.self) { Text($0.rawValue).tag($0) }
            }
        } label: {
            VStack(spacing: 2) {
                Image(systemName: "externaldrive")
                    .font(.system(size: 16))
                Text(String(format: "%.1f GB/m", mb / 1024.0))
                    .font(.system(size: 7, weight: .black))
            }
            .foregroundColor(.green)
            .frame(width: 50, height: 50)
            .background(Color.black.opacity(0.7))
            .clipShape(Circle())
        }
    }
}
