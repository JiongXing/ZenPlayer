import Foundation

enum CatalogLoadFailure {
    static func message(for error: Error) -> String {
        if case APIError.networkError(let underlying) = error { return message(for: underlying) }
        if let urlError = error as? URLError,
           [.notConnectedToInternet, .networkConnectionLost, .dataNotAllowed].contains(urlError.code) {
            return L10n.string(.catalogNeedsConnection)
        }
        return error.localizedDescription
    }
}
