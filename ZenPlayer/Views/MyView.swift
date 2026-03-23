//
//  MyView.swift
//  ZenPlayer
//
//  Created by Codex on 2026/3/23.
//

import SwiftUI

struct MyView: View {
    var body: some View {
        List {
            Section {
                NavigationLink {
                    RecentPlaybackListView()
                } label: {
                    featureRow(
                        title: L10n.text(.myRecentPlayback),
                        systemImage: "clock.arrow.circlepath"
                    )
                }

                NavigationLink {
                    LanguageSettingsView()
                } label: {
                    featureRow(
                        title: L10n.text(.myLanguage),
                        systemImage: "globe"
                    )
                }

                NavigationLink {
                    AboutView()
                } label: {
                    featureRow(
                        title: L10n.text(.myAbout),
                        systemImage: "info.circle"
                    )
                }
            }
        }
        .navigationTitle(L10n.text(.myTitle))
        #if os(iOS)
        .listStyle(.insetGrouped)
        #endif
    }

    private func featureRow(title: LocalizedStringKey, systemImage: String) -> some View {
        Label(title, systemImage: systemImage)
            .padding(.vertical, 4)
    }
}

#Preview {
    NavigationStack {
        MyView()
    }
    .environmentObject(LanguageSettings())
}
