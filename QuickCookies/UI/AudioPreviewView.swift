import SwiftUI
import AVFoundation

public struct AudioPreviewView: View {
    public let filePath: String

    @State private var player: AVPlayer? = nil
    @State private var isPlaying: Bool = false
    @State private var currentTime: Double = 0
    @State private var duration: Double = 0
    @State private var timeObserver: Any? = nil
    @State private var metadataString: String = ""
    @State private var waveformPhase: Double = 0

    public init(filePath: String) {
        self.filePath = filePath
    }

    public var body: some View {
        VStack(spacing: 20) {
            Spacer()

            // 音频图标与波形动效区
            VStack(spacing: 12) {
                ZStack {
                    Circle()
                        .fill(Color.appText.opacity(0.06))
                        .frame(width: 64, height: 64)

                    Image(systemName: isPlaying ? "waveform.circle.fill" : "music.note")
                        .font(.system(size: 30))
                        .foregroundColor(isPlaying ? .accentColor : Color.appText.opacity(0.8))
                        .scaleEffect(isPlaying ? 1.05 : 1.0)
                        .animation(.easeInOut(duration: 0.3), value: isPlaying)
                }

                // 动态声波柱状谱
                HStack(spacing: 4) {
                    ForEach(0..<16, id: \.self) { index in
                        let height: CGFloat = isPlaying
                            ? CGFloat(10 + 20 * sin(Double(index) * 0.4 + waveformPhase))
                            : 6
                        RoundedRectangle(cornerRadius: 2)
                            .fill(isPlaying ? Color.accentColor.opacity(0.7) : Color.appText.opacity(0.2))
                            .frame(width: 3, height: max(4, height))
                            .animation(.easeInOut(duration: 0.15), value: height)
                    }
                }
                .frame(height: 32)
            }

            // 元数据信息
            if !metadataString.isEmpty {
                Text(metadataString)
                    .font(.system(size: 11, design: .monospaced))
                    .foregroundColor(Color.appText.opacity(0.5))
            }

            // 进度条与时间
            VStack(spacing: 6) {
                GeometryReader { geometry in
                    ZStack(alignment: .leading) {
                        Capsule()
                            .fill(Color.appText.opacity(0.12))
                            .frame(height: 4)

                        Capsule()
                            .fill(Color.accentColor)
                            .frame(width: max(0, min(geometry.size.width, geometry.size.width * CGFloat(progress))), height: 4)
                    }
                    .contentShape(Rectangle())
                    .gesture(
                        DragGesture(minimumDistance: 0)
                            .onChanged { value in
                                let fraction = max(0, min(1, value.location.x / geometry.size.width))
                                seek(to: fraction * duration)
                            }
                    )
                }
                .frame(height: 12)

                HStack {
                    Text(formatTime(currentTime))
                        .font(.system(size: 11, design: .monospaced))
                        .foregroundColor(Color.appText.opacity(0.6))

                    Spacer()

                    Text(formatTime(duration))
                        .font(.system(size: 11, design: .monospaced))
                        .foregroundColor(Color.appText.opacity(0.6))
                }
            }
            .padding(.horizontal, 24)

            // 控制按键
            HStack(spacing: 24) {
                Button(action: {
                    seek(to: max(0, currentTime - 5))
                }) {
                    Image(systemName: "gobackward.5")
                        .font(.system(size: 14, weight: .medium))
                        .foregroundColor(Color.appText.opacity(0.7))
                }
                .buttonStyle(.plain)
                .help("Backward 5s".localized())

                Button(action: togglePlayPause) {
                    ZStack {
                        Circle()
                            .fill(Color.appText.opacity(0.12))
                            .frame(width: 44, height: 44)

                        Image(systemName: isPlaying ? "pause.fill" : "play.fill")
                            .font(.system(size: 18, weight: .semibold))
                            .foregroundColor(Color.appText)
                            .offset(x: isPlaying ? 0 : 1)
                    }
                }
                .buttonStyle(.plain)
                .keyboardShortcut(.space, modifiers: [])
                .help("Play / Pause (Space)".localized())

                Button(action: {
                    seek(to: min(duration, currentTime + 5))
                }) {
                    Image(systemName: "goforward.5")
                        .font(.system(size: 14, weight: .medium))
                        .foregroundColor(Color.appText.opacity(0.7))
                }
                .buttonStyle(.plain)
                .help("Forward 5s".localized())
            }

            Spacer()
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .onAppear {
            setupAudio()
        }
        .onDisappear {
            teardownAudio()
        }
    }

    private var progress: Double {
        guard duration > 0 else { return 0 }
        return currentTime / duration
    }

    private func setupAudio() {
        let url = URL(fileURLWithPath: filePath)
        let playerItem = AVPlayerItem(url: url)
        let player = AVPlayer(playerItem: playerItem)
        self.player = player

        let asset = AVURLAsset(url: url)
        Task {
            let assetDuration = try? await asset.load(.duration)
            let seconds = assetDuration.map { CMTimeGetSeconds($0) } ?? 0
            let tracks = try? await asset.load(.tracks)
            let audioTrack = tracks?.first(where: { $0.mediaType == .audio })
            let formatDesc = try? await audioTrack?.load(.formatDescriptions)

            var details: [String] = []
            if let desc = formatDesc?.first {
                let basic = CMAudioFormatDescriptionGetStreamBasicDescription(desc)?.pointee
                if let sampleRate = basic?.mSampleRate {
                    details.append(String(format: "%.1f kHz", sampleRate / 1000.0))
                }
                if let channels = basic?.mChannelsPerFrame {
                    details.append(channels == 2 ? "Stereo" : (channels == 1 ? "Mono" : "\(channels) ch"))
                }
            }
            let detailStr = details.joined(separator: " • ")

            await MainActor.run {
                self.duration = seconds
                self.metadataString = detailStr
            }
        }

        let interval = CMTime(seconds: 0.1, preferredTimescale: CMTimeScale(NSEC_PER_SEC))
        timeObserver = player.addPeriodicTimeObserver(forInterval: interval, queue: .main) { time in
            self.currentTime = CMTimeGetSeconds(time)
            if self.isPlaying {
                self.waveformPhase += 0.25
            }
            if let currentItem = player.currentItem, currentItem.status == .readyToPlay {
                let itemDuration = CMTimeGetSeconds(currentItem.duration)
                if itemDuration.isFinite && itemDuration > 0 {
                    self.duration = itemDuration
                }
            }
        }

        NotificationCenter.default.addObserver(
            forName: .AVPlayerItemDidPlayToEndTime,
            object: playerItem,
            queue: .main
        ) { _ in
            self.isPlaying = false
            self.seek(to: 0)
        }
    }

    private func teardownAudio() {
        if let token = timeObserver, let player = player {
            player.removeTimeObserver(token)
            self.timeObserver = nil
        }
        player?.pause()
        self.player = nil
        self.isPlaying = false
    }

    private func togglePlayPause() {
        guard let player = player else { return }
        if isPlaying {
            player.pause()
            isPlaying = false
        } else {
            if currentTime >= duration - 0.1 && duration > 0 {
                seek(to: 0)
            }
            player.play()
            isPlaying = true
        }
    }

    private func seek(to seconds: Double) {
        let target = CMTime(seconds: seconds, preferredTimescale: CMTimeScale(NSEC_PER_SEC))
        player?.seek(to: target, toleranceBefore: .zero, toleranceAfter: .zero)
        currentTime = seconds
    }

    private func formatTime(_ seconds: Double) -> String {
        guard seconds.isFinite && !seconds.isNaN && seconds >= 0 else { return "00:00" }
        let total = Int(seconds)
        let mins = total / 60
        let secs = total % 60
        return String(format: "%02d:%02d", mins, secs)
    }
}
