//
//  LanguageSettingsView.swift
//  ZenPlayer
//
//  Created by Codex on 2026/3/23.
//

import SwiftUI

struct LanguageSettingsView: View {
    @EnvironmentObject private var languageSettings: LanguageSettings

    var body: some View {
        List {
            ForEach(AppLanguage.supported) { language in
                Button {
                    languageSettings.selectedLanguage = language
                } label: {
                    HStack(spacing: 12) {
                        Text(language.displayName)
                            .foregroundStyle(.primary)

                        Spacer()

                        if languageSettings.selectedLanguage == language {
                            Image(systemName: "checkmark")
                                .foregroundStyle(.tint)
                                .accessibilityLabel(L10n.text(.commonSelected))
                        }
                    }
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .accessibilityElement(children: .combine)
            }
        }
        .navigationTitle(L10n.text(.settingsLanguageTitle))
        #if os(iOS)
        .listStyle(.insetGrouped)
        #endif
    }
}

private extension AppLanguage {
    var displayName: String {
        switch code {
        case "zh-Hans":
            return L10n.string(.settingsLanguageNameZhHans)
        case "zh-Hant":
            return L10n.string(.settingsLanguageNameZhHant)
        default:
            return code
        }
    }
}

#Preview {
    NavigationStack {
        LanguageSettingsView()
    }
    .environmentObject(LanguageSettings())
}
