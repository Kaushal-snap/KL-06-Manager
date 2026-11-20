import SwiftUI

public struct ScopeOverlaysView: View {
    @ObservedObject var cameraManager: CameraManager
    @ObservedObject var videoWriter: VideoWriter
    @Binding var showCinemaGuide: Bool
    @Binding var showGrid: Bool
    
    public var body: some View {
        ZStack {
            // 1. Composition Overlays
            if showGrid {
                gridOverlay
            }
            if showCinemaGuide {
                cinemaScopeOverlay // 2.39:1 Anamorphic Letterbox
            }
            
            // 2. Top Cinema Status Bar
            VStack {
                topStatusBar
                    .padding(.horizontal, 16)
                    .padding(.top, 40)
                Spacer()
            }
        }
    }
    
    private var topStatusBar: some View {
        HStack {
            // Recording Indicator & Timecode
            HStack(spacing: 8) {
                Circle()
                    .fill(videoWriter.isRecording ? Color.red : Color.gray.opacity(0.5))
                    .frame(width: 12, height: 12)
                
                Text(formatTimecode(videoWriter.recordingDuration))
                    .font(.system(size: 16, weight: .bold, design: .monospaced))
                    .foregroundColor(videoWriter.isRecording ? .red : .white)
            }
            .padding(.horizontal, 10)
            .padding(.vertical, 6)
            .background(Color.black.opacity(0.75))
            .cornerRadius(8)
            
            Spacer()
            
            // Log Profile Badge
            Text("APPLE LOG · BT.2020")
                .font(.system(size: 11, weight: .black, design: .monospaced))
                .foregroundColor(.black)
                .padding(.horizontal, 8)
                .padding(.vertical, 4)
                .background(Color.yellow)
                .cornerRadius(4)
            
            Spacer()
            
            // Storage & Bitrate Info
            VStack(alignment: .trailing, spacing: 2) {
                Text(String(format: "%.1f MB", videoWriter.recordedFileSizeMB))
                    .font(.system(size: 12, weight: .semibold, design: .monospaced))
                    .foregroundColor(.white)
                if videoWriter.droppedFrames > 0 {
                    Text("DROP: \(videoWriter.droppedFrames)")
                        .font(.system(size: 10, weight: .bold, design: .monospaced))
                        .foregroundColor(.red)
                }
            }
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
            .background(Color.black.opacity(0.75))
            .cornerRadius(8)
        }
    }
    
    private var gridOverlay: some View {
        GeometryReader { geo in
            Path { path in
                let w = geo.size.width
                let h = geo.size.height
                // Rule of thirds
                path.move(to: CGPoint(x: w / 3, y: 0))
                path.addLine(to: CGPoint(x: w / 3, y: h))
                path.move(to: CGPoint(x: 2 * w / 3, y: 0))
                path.addLine(to: CGPoint(x: 2 * w / 3, y: h))
                
                path.move(to: CGPoint(x: 0, y: h / 3))
                path.addLine(to: CGPoint(x: w, y: h / 3))
                path.move(to: CGPoint(x: 0, y: 2 * h / 3))
                path.addLine(to: CGPoint(x: w, y: 2 * h / 3))
            }
            .stroke(Color.white.opacity(0.25), lineWidth: 1)
        }
    }
    
    private var cinemaScopeOverlay: some View {
        GeometryReader { geo in
            let totalHeight = geo.size.height
            let cinemaHeight = geo.size.width / 2.39
            let barHeight = max(0, (totalHeight - cinemaHeight) / 2)
            
            VStack(spacing: 0) {
                Color.black.opacity(0.65).frame(height: barHeight)
                Spacer()
                Color.black.opacity(0.65).frame(height: barHeight)
            }
        }
    }
    
    private func formatTimecode(_ duration: TimeInterval) -> String {
        let hours = Int(duration) / 3600
        let minutes = (Int(duration) % 3600) / 60
        let seconds = Int(duration) % 60
        let frames = Int((duration.truncatingRemainder(dividingBy: 1.0)) * 24.0)
        return String(format: "%02d:%02d:%02d:%02d", hours, minutes, seconds, frames)
    }
}
