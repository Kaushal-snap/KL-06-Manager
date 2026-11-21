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
            if selectedTab != 0 {
                parameterAdjuster
                    .padding(.horizontal, 12)
                    .padding(.vertical, 9)
                    .frame(maxWidth: .infinity)
                    .background(Color.black.opacity(0.88))
                    .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
                    .overlay {
                        RoundedRectangle(cornerRadius: 14, style: .continuous)
                            .stroke(Color.white.opacity(0.12), lineWidth: 1)
                    }
                    .transition(.move(edge: .bottom).combined(with: .opacity))
            }

            // Horizontal scrolling prevents the six manual controls from
            // being compressed or clipped on the 430 pt iPhone 14 Pro Max.
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 7) {
                    paramButton(title: "FPS", value: "\(cameraManager.currentFrameRate.rawValue)", isSelected: false)

                    paramButton(
                        title: "SHUTTER",
                        value: formatShutter(cameraManager.currentShutterSpeed),
                        isSelected: selectedTab == 1
                    ) { toggleTab(1) }

                    paramButton(
                        title: "ISO",
                        value: "\(Int(cameraManager.currentISO))",
                        isSelected: selectedTab == 2
                    ) { toggleTab(2) }

                    paramButton(
                        title: "WB",
                        value: "\(Int(cameraManager.currentKelvin))K",
                        isSelected: selectedTab == 3
                    ) { toggleTab(3) }

                    paramButton(
                        title: "FOCUS",
                        value: String(format: "%.2f", cameraManager.currentLensPosition),
                        isSelected: selectedTab == 4
                    ) { toggleTab(4) }

                    paramButton(
                        title: "CODEC",
                        value: codecAbbreviation(videoWriter.currentCodec),
                        isSelected: selectedTab == 5
                    ) { toggleTab(5) }
                }
                .padding(.horizontal, 2)
            }
            .contentMargins(.horizontal, 2, for: .scrollContent)
            .padding(.horizontal, 8)
            .padding(.vertical, 9)
            .background(Color.black.opacity(0.88))
            .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
            .overlay {
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .stroke(Color.white.opacity(0.14), lineWidth: 1)
            }
        }
    }

    private func toggleTab(_ tab: Int) {
        withAnimation(.easeInOut(duration: 0.2)) {
            selectedTab = (selectedTab == tab) ? 0 : tab
        }
    }

    private func paramButton(title: String, value: String, isSelected: Bool, action: (() -> Void)? = nil) -> some View {
        Button(action: { action?() }) {
            VStack(spacing: 4) {
                Text(title)
                    .font(.system(size: 9, weight: .bold, design: .monospaced))
                    .foregroundColor(isSelected ? .yellow : .gray)
                    .lineLimit(1)

                Text(value)
                    .font(.system(size: 12, weight: .semibold, design: .monospaced))
                    .foregroundColor(isSelected ? .yellow : .white)
                    .lineLimit(1)
                    .minimumScaleFactor(0.75)
            }
            .frame(width: 58, height: 43)
            .background(isSelected ? Color.yellow.opacity(0.18) : Color.white.opacity(0.07))
            .clipShape(RoundedRectangle(cornerRadius: 9, style: .continuous))
            .contentShape(RoundedRectangle(cornerRadius: 9, style: .continuous))
        }
        .buttonStyle(.plain)
    }

    @ViewBuilder
    private var parameterAdjuster: some View {
        switch selectedTab {
        case 1:
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 10) {
                    ForEach(shutterSpeeds, id: \.self) { speed in
                        Button(action: { cameraManager.setShutterSpeed(speed) }) {
                            Text(formatShutter(speed))
                                .font(.system(size: 13, weight: .medium, design: .monospaced))
                                .padding(.horizontal, 12)
                                .padding(.vertical, 7)
                                .background(abs(cameraManager.currentShutterSpeed - speed) < 0.001 ? Color.yellow : Color.gray.opacity(0.3))
                                .foregroundColor(abs(cameraManager.currentShutterSpeed - speed) < 0.001 ? .black : .white)
                                .clipShape(RoundedRectangle(cornerRadius: 7))
                        }
                        .buttonStyle(.plain)
                    }
                }
            }

        case 2:
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 10) {
                    ForEach(isoPresets, id: \.self) { iso in
                        Button(action: { cameraManager.setISO(iso) }) {
                            Text("\(Int(iso))")
                                .font(.system(size: 13, weight: .medium, design: .monospaced))
                                .padding(.horizontal, 12)
                                .padding(.vertical, 7)
                                .background(cameraManager.currentISO == iso ? Color.yellow : Color.gray.opacity(0.3))
                                .foregroundColor(cameraManager.currentISO == iso ? .black : .white)
                                .clipShape(RoundedRectangle(cornerRadius: 7))
                        }
                        .buttonStyle(.plain)
                    }
                }
            }

        case 3:
            VStack(spacing: 8) {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 8) {
                        ForEach(kelvinPresets, id: \.self) { kelvin in
                            Button(action: { cameraManager.setKelvin(kelvin) }) {
                                Text("\(Int(kelvin))K")
                                    .font(.system(size: 11, weight: .medium, design: .monospaced))
                                    .padding(.horizontal, 9)
                                    .padding(.vertical, 6)
                                    .background(cameraManager.currentKelvin == kelvin ? Color.yellow : Color.gray.opacity(0.3))
                                    .foregroundColor(cameraManager.currentKelvin == kelvin ? .black : .white)
                                    .clipShape(RoundedRectangle(cornerRadius: 6))
                            }
                            .buttonStyle(.plain)
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
                .tint(.yellow)
            }

        case 4:
            HStack(spacing: 10) {
                Text("MACRO").font(.system(size: 10, weight: .bold)).foregroundColor(.gray)
                Slider(
                    value: Binding(
                        get: { Double(cameraManager.currentLensPosition) },
                        set: { cameraManager.setLensPosition(Float($0)) }
                    ),
                    in: 0.0...1.0
                )
                .tint(.green)
                Text("INF").font(.system(size: 10, weight: .bold)).foregroundColor(.gray)
            }

        case 5:
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 10) {
                    ForEach(RecordingCodec.allCases, id: \.self) { codec in
                        Button(action: { videoWriter.currentCodec = codec }) {
                            Text(codecAbbreviation(codec))
                                .font(.system(size: 12, weight: .bold, design: .monospaced))
                                .padding(.horizontal, 12)
                                .padding(.vertical, 7)
                                .background(videoWriter.currentCodec == codec ? Color.yellow : Color.gray.opacity(0.3))
                                .foregroundColor(videoWriter.currentCodec == codec ? .black : .white)
                                .clipShape(RoundedRectangle(cornerRadius: 7))
                        }
                        .buttonStyle(.plain)
                    }
                }
            }

        default:
            EmptyView()
        }
    }

    private func formatShutter(_ speed: Double) -> String {
        if speed >= 1.0 { return String(format: "%.1fs", speed) }
        return "1/\(Int(round(1.0 / speed)))"
    }

    private func codecAbbreviation(_ codec: RecordingCodec) -> String {
        switch codec {
        case .proRes422HQ: return "HQ 422"
        case .proRes422: return "PR 422"
        case .hevc10Bit: return "HEVC 10b"
        }
    }
}
