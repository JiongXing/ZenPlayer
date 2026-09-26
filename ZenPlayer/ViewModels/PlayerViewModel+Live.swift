import Foundation

extension PlayerViewModel {
    convenience init() {
        self.init(progressStore: .shared, queueStore: .shared, defaults: .standard,
                  localFile: { id, media in
                      DownloadManager.shared.completedFileURL(for: id, type: media == .audio ? .mp3 : .mp4)
                  },
                  makeAudioProcessor: { AVPlayerDenoiseTapProcessor(strength: $0, enabled: $1) },
                  isOffline: { PlaybackNetworkStatus.shared.isOffline })
    }
}
