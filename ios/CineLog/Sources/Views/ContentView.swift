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
            Color.black.ignoresSafeArea()

            // The camera preview is immersive; all controls stay inside the
            // device safe area so the Dynamic Island and Home indicator remain clear.
            CameraPreviewView(cameraManager: cameraManager)
                .ignoresSafeArea()

            ScopeOverlaysView(
                cameraManager: cameraManager,
                videoWriter: videoWriter,
                showCinemaGuide: $showCinemaGuide,
                showGrid: $showGrid
            )
            .ignoresSafeArea(edges: .bottom)

            VStack(spacing: 0) {
                // Compact tool strip below the top status/HUD area.
                HStack(spacing: 8) {
                    Spacer(minLength: 0)
                    monitoringModeButton
                    guideToggleButton
                    rawModeToggleButton
                }
                .padding(.top, 58)
                .padding(.trailing, 2)

                Spacer(minLength: 12)

                // Keep the primary shutter centered and separated from the
                // parameter tray for comfortable one-handed operation.
                recordButton
                    .frame(maxWidth: .infinity)
                    .padding(.bottom, 12)

                CinemaControlsView(
                    cameraManager: cameraManager,
                    videoWriter: videoWriter,
                    selectedTab: $selectedTab
                )
                .padding(.bottom, 6)
            }
            .padding(.horizontal, 12)
        }
        .preferredColorScheme(.dark)
        .onAppear {
            setupCallbacks()
            cameraManager.configureSession()
        }
        .alert(isPresented: $showSaveAlert) {
            Alert(
                title: Text("Clip Saved Successfully!"),
                message: Text("Saved: \(lastRecordedURL?.lastPathComponent ?? "")"),
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

    // MARK: - Recording

    private var recordButton: some View {
        Button(action: toggleRecording) {
            ZStack {
                Circle()
                    .stroke(Color.white.opacity(0.95), lineWidth: 4)
                    .frame(width: 76, height: 76)

                if videoWriter.isRecording || rawWriter.isRawRecording {
                    RoundedRectangle(cornerRadius: 7)
                        .fill(Color.red)
                        .frame(width: 30, height: 30)
                } else {
                    Circle()
                        .fill(Color.red)
                        .frame(width: 60, height: 60)
                }
            }
            .frame(width: 84, height: 84)
            .contentShape(Circle())
        }
        .buttonStyle(.plain)
        .accessibilityLabel(videoWriter.isRecording || rawWriter.isRawRecording ? "Stop recording" : "Start recording")
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

    // MARK: - Tool buttons

    private var monitoringModeButton: some View {
        Button(action: cycleMonitoringMode) {
            toolButtonContent(icon: monitoringIcon, title: monitoringLabel, tint: .white)
        }
        .buttonStyle(.plain)
        .accessibilityLabel("Monitoring mode: \(monitoringLabel)")
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
        case .rec709LUT: return "709"
        case .flatLog: return "LOG"
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
            toolButtonContent(
                icon: "aspectratio",
                title: showCinemaGuide ? "2.39" : "16:9",
                tint: showCinemaGuide ? .yellow : .white
            )
        }
        .buttonStyle(.plain)
        .accessibilityLabel("Toggle cinema aspect guide")
    }

    private var rawModeToggleButton: some View {
        Button(action: { isRawMode.toggle() }) {
            toolButtonContent(
                icon: "camera.aperture",
                title: isRawMode ? "cDNG" : "PRORES",
                tint: isRawMode ? .orange : .white
            )
        }
        .buttonStyle(.plain)
        .accessibilityLabel(isRawMode ? "CinemaDNG RAW mode" : "ProRes video mode")
    }

    private func toolButtonContent(icon: String, title: String, tint: Color) -> some View {
        VStack(spacing: 4) {
            Image(systemName: icon)
                .font(.system(size: 17, weight: .semibold))
            Text(title)
                .font(.system(size: 8, weight: .bold, design: .monospaced))
                .lineLimit(1)
                .minimumScaleFactor(0.75)
        }
        .foregroundColor(tint)
        .frame(width: 54, height: 52)
        .background(Color.black.opacity(0.72))
        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .stroke(Color.white.opacity(0.12), lineWidth: 1)
        }
        .contentShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
    }
}
