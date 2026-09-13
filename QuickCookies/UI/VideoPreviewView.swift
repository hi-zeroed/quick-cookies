import SwiftUI
import AVKit
import AVFoundation

public struct VideoPreviewView: View {
    public let filePath: String

    @State private var player: AVPlayer? = nil

    public init(filePath: String) {
        self.filePath = filePath
    }

    public var body: some View {
        VideoPlayerRepresentable(filePath: filePath, player: $player)
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .cornerRadius(12)
            .overlay(
                RoundedRectangle(cornerRadius: 12)
                    .stroke(Color.appBorder.opacity(0.3), lineWidth: 1)
            )
            .onDisappear {
                player?.pause()
                player = nil
            }
    }
}

private struct VideoPlayerRepresentable: NSViewRepresentable {
    let filePath: String
    @Binding var player: AVPlayer?

    func makeCoordinator() -> Coordinator {
        Coordinator()
    }

    func makeNSView(context: Context) -> AVPlayerView {
        let playerView = AVPlayerView()
        playerView.controlsStyle = .floating
        playerView.showsFullScreenToggleButton = true
        playerView.showsSharingServiceButton = false
        playerView.wantsLayer = true
        playerView.layer?.cornerRadius = 12
        playerView.layer?.masksToBounds = true

        let url = URL(fileURLWithPath: filePath)
        let player = AVPlayer(url: url)
        playerView.player = player
        self.player = player
        context.coordinator.player = player

        player.play()
        return playerView
    }

    func updateNSView(_ nsView: AVPlayerView, context: Context) {
        if context.coordinator.currentPath != filePath {
            context.coordinator.currentPath = filePath
            let url = URL(fileURLWithPath: filePath)
            let player = AVPlayer(url: url)
            nsView.player = player
            self.player = player
            context.coordinator.player = player
            player.play()
        }
    }

    class Coordinator {
        var currentPath: String? = nil
        var player: AVPlayer? = nil

        deinit {
            player?.pause()
        }
    }
}
