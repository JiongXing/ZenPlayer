import Foundation
import Network
import Observation

@MainActor
@Observable
final class PlaybackNetworkStatus {
    static let shared = PlaybackNetworkStatus()
    private(set) var isOffline = false
    @ObservationIgnored private let monitor = NWPathMonitor()

    private init() {
        monitor.pathUpdateHandler = { [weak self] path in
            let offline = path.status == .unsatisfied
            Task { @MainActor [weak self] in self?.isOffline = offline }
        }
        monitor.start(queue: DispatchQueue(label: "ZenPlayer.PlaybackNetwork"))
    }

    deinit { monitor.cancel() }
}
