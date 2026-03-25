//
//  L10n.swift
//  ZenPlayer
//

import Foundation
import OSLog
import SwiftUI

enum L10n {
    private static let logger = Logger(subsystem: Bundle.main.bundleIdentifier ?? "ZenPlayer", category: "Localization")
    static let currentLocale = Locale(identifier: "zh-Hant")
    private static let languageCode = "zh-Hant"
    private static let lock = NSLock()
    private static var missingLogged = Set<String>()

    static func text(_ key: L10nKey) -> LocalizedStringKey {
        LocalizedStringKey(key.rawValue)
    }

    static func string(_ key: L10nKey) -> String {
        localizedString(for: key.rawValue)
    }

    static func string(_ key: L10nKey, _ args: CVarArg...) -> String {
        String(format: string(key), locale: currentLocale, arguments: args)
    }

    private static func localizedString(for key: String) -> String {
        guard let path = Bundle.main.path(forResource: languageCode, ofType: "lproj"),
              let bundle = Bundle(path: path)
        else {
            warnMissingOnce(key: key)
            return "[missing:\(key)]"
        }

        let value = bundle.localizedString(forKey: key, value: nil, table: nil)
        guard value != key else {
            warnMissingOnce(key: key)
            return "[missing:\(key)]"
        }
        return value
    }

    private static func warnMissingOnce(key: String) {
        lock.lock()
        if missingLogged.contains(key) {
            lock.unlock()
            return
        }
        missingLogged.insert(key)
        lock.unlock()
        logger.warning("Missing localized string. locale=\(languageCode, privacy: .public), key=\(key, privacy: .public)")
    }
}
