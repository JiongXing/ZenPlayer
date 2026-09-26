import Foundation

nonisolated struct ResumeCandidate {
    enum Kind { case active, resume, next }
    let kind: Kind
    let context: PlaybackContext
    let position: Double
    let duration: Double?
}
