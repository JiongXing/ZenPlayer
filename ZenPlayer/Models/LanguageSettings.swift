//
//  LanguageSettings.swift
//  ZenPlayer
//

import Combine
import Foundation
import SwiftUI

struct AppLanguage: Identifiable, Hashable {
    let code: String

    var id: String { code }
    var locale: Locale { Locale(identifier: code) }

    static var supported: [AppLanguage] {
        LocalizationConfig.supportedLanguageCodes.map { AppLanguage(code: $0) }
    }
}

final class LanguageSettings: ObservableObject {
    @Published var selectedLanguage: AppLanguage {
        didSet {
            guard oldValue != selectedLanguage else { return }
            L10n.setCurrentLocale(selectedLanguage.locale)
        }
    }

    var currentLocale: Locale { selectedLanguage.locale }
    var locale: Locale { currentLocale }

    private let notificationCenter: NotificationCenter
    private var localeDidChangeObserver: NSObjectProtocol?

    init(notificationCenter: NotificationCenter = .default) {
        self.notificationCenter = notificationCenter

        let best = LocalizationConfig.bestMatch(preferredLanguages: Locale.preferredLanguages)
        selectedLanguage = AppLanguage(code: best)
        L10n.setCurrentLocale(selectedLanguage.locale)

        localeDidChangeObserver = notificationCenter.addObserver(
            forName: NSLocale.currentLocaleDidChangeNotification,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            self?.refreshFromSystemLanguage()
        }
    }

    deinit {
        if let observer = localeDidChangeObserver {
            notificationCenter.removeObserver(observer)
        }
    }

    private func refreshFromSystemLanguage() {
        let best = LocalizationConfig.bestMatch(preferredLanguages: Locale.preferredLanguages)
        let language = AppLanguage(code: best)

        if language != selectedLanguage {
            selectedLanguage = language
        } else {
            L10n.setCurrentLocale(selectedLanguage.locale)
        }
    }
}
