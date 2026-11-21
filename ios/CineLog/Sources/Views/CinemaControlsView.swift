import SwiftUI

public struct CinemaControlsView: View {
    @ObservedObject var cameraManager: CameraManager
    @ObservedObject var videoWriter: VideoWriter
    @Binding var selectedTab: Int // 0: None, 1: Shutter, 2: ISO, 3: WB, 4: Focus, 5: Codec
    
    let shutterSpeeds: [Double] = [1.0/24.0, 1.0/48.0, 1.0/50.0, 1.0/60.0, 1.0/96.0, 1.0/120.0, 1.0/240.0]
    let isoPresets: [Float] = [50, 64, 100, 200, 400, 800, 1250, 1600, 3200, 6400]
    let kelvinPresets: [Float] = [2800, 3200, 4300, 5600, 6500, 7500]
    
    public var body: some View {
        VStack(spacing: 8) {
            // Selected Parameter Control Tray
            if selectedTab != 0 {
                parameterAdjuster
                    .padding(.horizontal, 16)
                    .padding(.vertical, 8)
                    .background(Color.black.opacity(0.85))
                    .cornerRadius(12)
                    .transition(.move(edge: .bottom).combined(with: .opacity))
            }
            
            // Bottom Cinema Parameter Bar
            HStack(spacing: 12) {
                paramButton(title: "RES", value: cameraManager.currentResolution == .uhd4K ? "4K" : "1080p", isSelected: false) {
                    cameraManager.setResolution(cameraManager.currentResolution == .uhd4K ? .fhd1080p : .uhd4K)
                }
                paramButton(title: "FPS", value: "\(cameraManager.currentFrameRate.rawValue) fps", isSelected: false) {
                    let list = cameraManager.supportedFrameRates.isEmpty ? FrameRate.allCases : cameraManager.supportedFrameRates
                    let i = list.firstIndex(of: cameraManager.currentFrameRate) ?? -1
                    cameraManager.setFrameRate(list[(i + 1) % list.count])
                }
                
                paramButton(
                    title: "SHUTTER",
                    value: formatShutter(cameraManager.currentShutterSpeed),
                    isSelected: selectedTab == 1
                ) {
                    toggleTab(1)
                }
                
                paramButton(
                    title: "ISO",
                    value: "\(Int(cameraManager.currentISO))",
                    isSelected: selectedTab == 2
                ) {
                    toggleTab(2)
                }
                
                paramButton(
                    title: "WB",
                    value: "\(Int(cameraManager.currentKelvin))K",
                    isSelected: selectedTab == 3
                ) {
                    toggleTab(3)
                }
                
                paramButton(
                    title: "FOCUS",
                    value: String(format: "%.2f", cameraManager.currentLensPosition),
                    isSelected: selectedTab == 4
                ) {
                    toggleTab(4)
                }
                
                paramButton(
                    title: "CODEC",
                    value: codecAbbreviation(videoWriter.currentCodec),
                    isSelected: selectedTab == 5
                ) {
                    toggleTab(5)
                }
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 10)
            .background(Color.black.opacity(0.8))
            .cornerRadius(16)
        }
    }
    
    private func toggleTab(_ tab: Int) {
        withAnimation(.easeInOut(duration: 0.2)) {
            selectedTab = (selectedTab == tab) ? 0 : tab
        }
    }
    
    private func paramButton(title: String, value: String, isSelected: Bool, action: (() -> Void)? = nil) -> some View {
        Button(action: { action?() }) {
            VStack(spacing: 2) {
                Text(title)
                    .font(.system(size: 9, weight: .bold, design: .monospaced))
                    .foregroundColor(isSelected ? .yellow : .gray)
                Text(value)
                    .font(.system(size: 13, weight: .semibold, design: .monospaced))
                    .foregroundColor(isSelected ? .yellow : .white)
            }
            .frame(minWidth: 50)
            .padding(.vertical, 4)
            .padding(.horizontal, 6)
            .background(isSelected ? Color.yellow.opacity(0.2) : Color.white.opacity(0.08))
            .cornerRadius(8)
        }
    }
    
    @ViewBuilder
    private var parameterAdjuster: some View {
        switch selectedTab {
        case 1:
            // Shutter Speed Selector
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 10) {
                    ForEach(shutterSpeeds, id: \.self) { speed in
                        Button(action: { cameraManager.setShutterSpeed(speed) }) {
                            Text(formatShutter(speed))
                                .font(.system(size: 13, weight: .medium, design: .monospaced))
                                .padding(.horizontal, 12)
                                .padding(.vertical, 6)
                                .background(abs(cameraManager.currentShutterSpeed - speed) < 0.001 ? Color.yellow : Color.gray.opacity(0.3))
                                .foregroundColor(abs(cameraManager.currentShutterSpeed - speed) < 0.001 ? .black : .white)
                                .cornerRadius(6)
                        }
                    }
                }
            }
            
        case 2:
            // ISO Selector
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 10) {
                    ForEach(isoPresets, id: \.self) { iso in
                        Button(action: { cameraManager.setISO(iso) }) {
                            Text("\(Int(iso))")
                                .font(.system(size: 13, weight: .medium, design: .monospaced))
                                .padding(.horizontal, 12)
                                .padding(.vertical, 6)
                                .background(cameraManager.currentISO == iso ? Color.yellow : Color.gray.opacity(0.3))
                                .foregroundColor(cameraManager.currentISO == iso ? .black : .white)
                                .cornerRadius(6)
                        }
                    }
                }
            }
            
        case 3:
            // White Balance Kelvin Slider & Presets
            VStack(spacing: 8) {
                HStack(spacing: 8) {
                    ForEach(kelvinPresets, id: \.self) { k in
                        Button(action: { cameraManager.setKelvin(k) }) {
                            Text("\(Int(k))K")
                                .font(.system(size: 11, design: .monospaced))
                                .padding(.horizontal, 8)
                                .padding(.vertical, 4)
                                .background(cameraManager.currentKelvin == k ? Color.yellow : Color.gray.opacity(0.3))
                                .foregroundColor(cameraManager.currentKelvin == k ? .black : .white)
                                .cornerRadius(4)
                        }
                    }
                }
                Slider(
                    value: Binding(
                        get: { Double(cameraManager.currentKelvin) },
                        set: { cameraManager.setKelvin(Float($0)) }
                    ),
                    in: 2000.0...10000.0,
                    step: 50.0
                )
                .accentColor(.yellow)
            }
            
        case 4:
            // Focus Slider
            HStack {
                Text("MACRO").font(.system(size: 10, weight: .bold)).foregroundColor(.gray)
                Slider(
                    value: Binding(
                        get: { Double(cameraManager.currentLensPosition) },
                        set: { cameraManager.setLensPosition(Float($0)) }
                    ),
                    in: 0.0...1.0
                )
                .accentColor(.green)
                Text("INF").font(.system(size: 10, weight: .bold)).foregroundColor(.gray)
            }
            
        case 5:
            // Codec Picker
            HStack(spacing: 10) {
                ForEach(RecordingCodec.allCases, id: \.self) { codec in
                    Button(action: { videoWriter.currentCodec = codec }) {
                        Text(codecAbbreviation(codec))
                            .font(.system(size: 12, weight: .bold, design: .monospaced))
                            .padding(.horizontal, 12)
                            .padding(.vertical, 6)
                            .background(videoWriter.currentCodec == codec ? Color.yellow : Color.gray.opacity(0.3))
                            .foregroundColor(videoWriter.currentCodec == codec ? .black : .white)
                            .cornerRadius(6)
                    }
                }
            }
            
        default:
            EmptyView()
        }
    }
    
    private func formatShutter(_ s: Double) -> String {
        if s >= 1.0 { return String(format: "%.1fs", s) }
        let den = Int(round(1.0 / s))
        return "1/\(den)"
    }
    
    private func codecAbbreviation(_ codec: RecordingCodec) -> String {
        switch codec {
        case .proRes422HQ: return "HQ 422"
        case .proRes422: return "PR 422"
        case .hevc10Bit: return "HEVC 10b"
        }
    }
}
