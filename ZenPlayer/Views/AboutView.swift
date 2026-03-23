//
//  AboutView.swift
//  ZenPlayer
//
//  Created by Codex on 2026/3/23.
//

import SwiftUI

struct AboutView: View {
    var body: some View {
        List {
            Section {
                VStack(alignment: .leading, spacing: 8) {
                    Text(appDisplayName)
                        .font(.title2)
                        .fontWeight(.bold)

                    Text(L10n.text(.aboutDescription))
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
                .padding(.vertical, 4)
            }

            Section {
                LabeledContent(L10n.text(.aboutVersion), value: versionDescription)
            }
        }
        .navigationTitle(L10n.text(.aboutTitle))
        #if os(iOS)
        .listStyle(.insetGrouped)
        #endif
    }

    private var appDisplayName: String {
        Bundle.main.object(forInfoDictionaryKey: "CFBundleDisplayName") as? String
            ?? Bundle.main.object(forInfoDictionaryKey: "CFBundleName") as? String
            ?? "Zen Player"
    }

    private var versionDescription: String {
        let version = Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "-"
        let build = Bundle.main.object(forInfoDictionaryKey: "CFBundleVersion") as? String ?? "-"
        return "\(version) (\(build))"
    }
}

#Preview {
    NavigationStack {
        AboutView()
    }
}
