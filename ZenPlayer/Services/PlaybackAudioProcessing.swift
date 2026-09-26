import AVFoundation

/// 会话仅依赖处理器控制面，便于隔离媒体准备延迟／失败；生产仍使用原 RNNoise 处理器。
protocol PlaybackAudioProcessing: AnyObject {
    func attach(to item: AVPlayerItem) async throws
    func updateStrength(_ value: Float)
    func setEnabled(_ isEnabled: Bool)
    func updateGainMultiplier(_ value: Float)
}
