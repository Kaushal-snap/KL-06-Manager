import SwiftUI

public struct ScopeOverlaysView: View {
    @ObservedObject var cameraManager: CameraManager
    @ObservedObject var videoWriter: VideoWriter
    @Binding var showCinemaGuide: Bool
    @Binding var showGrid: Bool

    public var body: some View {
        ZStack {
            if showGrid {
                gridOverlay
            }
            if showCinemaGuide {
                cinemaScopeOverlay
            }

            VStack(spacing: 0) {
                topStatusBar
                    .padding(.horizontal, 12)
                    .padding(.top, 8)
                Spacer(minLength: 0)
            }
        }
        .allowsHitTesting(false)
    }

    private var topStatusBar: some View {
        HStack(spacing: 8) {
            HStack(spacing: 6) {
                Circle()
                    .fill(videoWriter.isRecording ? Color.red : Color.gray.opacity(0.65))
                    .frame(width: 8, height: 8)

                Text(formatTimecode(videoWriter.recordingDuration))
                    .font(.system(size: 12, weight: .bold, design: .monospaced))
                    .foregroundColor(videoWriter.isRecording ? .red : .white)
                    .lineLimit(1)
                    .minimumScaleFactor(0.75)
            }
            .padding(.horizontal, 9)
            .padding(.vertical, 7)
            .background(Color.black.opacity(0.78))
            .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))

            Spacer(minLength: 4)

            Text("APPLE LOG · BT.2020")
                .font(.system(size: 9, weight: .black, design: .monospaced))
                .foregroundColor(.black)
                .lineLimit(1)
                .minimumScaleFactor(0.7)
                .padding(.horizontal, 7)
                .padding(.vertical, 6)
                .background(Color.yellow)
                .clipShape(RoundedRectangle(cornerRadius: 5, style: .continuous))

            Spacer(minLength: 4)

            VStack(alignment: .trailing, spacing: 2) {
                Text(String(format: "%.1f MB", videoWriter.recordedFileSizeMB))
                    .font(.system(size: 10, weight: .semibold, design: .monospaced))
                    .foregroundColor(.white)
                    .lineLimit(1)
                if videoWriter.droppedFrames > 0 {
                    Text("DROP \(videoWriter.droppedFrames)")
                        .font(.system(size: 9, weight: .bold, design: .monospaced))
                        .foregroundColor(.red)
                        .lineLimit(1)
                }
            }
            .padding(.horizontal, 8)
            .padding(.vertical, 6)
            .background(Color.black.opacity(0.78))
            .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
        }
        .frame(maxWidth: .infinity)
    }

    private var gridOverlay: some View {
        GeometryReader { geometry in
            Path { path in
                let width = geometry.size.width
                let height = geometry.size.height

                path.move(to: CGPoint(x: width / 3, y: 0))
                path.addLine(to: CGPoint(x: width / 3, y: height))
                path.move(to: CGPoint(x: 2 * width / 3, y: 0))
                path.addLine(to: CGPoint(x: 2 * width / 3, y: height))

                path.move(to: CGPoint(x: 0, y: height / 3))
                path.addLine(to: CGPoint(x: width, y: height / 3))
                path.move(to: CGPoint(x: 0, y: 2 * height / 3))
                path.addLine(to: CGPoint(x: width, y: 2 * height / 3))
            }
            .stroke(Color.white.opacity(0.25), lineWidth: 1)
        }
    }

    private var cinemaScopeOverlay: some View {
        GeometryReader { geometry in
            let cinemaHeight = geometry.size.width / 2.39
            let barHeight = max(0, (geometry.size.height - cinemaHeight) / 2)

            VStack(spacing: 0) {
                Color.black.opacity(0.65)
                    .frame(height: barHeight)
                Spacer(minLength: 0)
                Color.black.opacity(0.65)
                    .frame(height: barHeight)
            }
        }
    }

    private func formatTimecode(_ duration: TimeInterval) -> String {
        let hours = Int(duration) / 3600
        let minutes = (Int(duration) % 3600) / 60
        let seconds = Int(duration) % 60
        let frames = Int(duration.truncatingRemainder(dividingBy: 1.0) * 24.0)
        return String(format: "%02d:%02d:%02d:%02d", hours, minutes, seconds, frames)
    }
}
