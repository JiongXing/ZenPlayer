//
//  ContentView.swift
//  ZenPlayer
//
//  Created by jxing on 2026/2/11.
//

import SwiftUI

struct ContentView: View {
    @State private var selectedTab: RootTab = .home

    var body: some View {
        NavigationStack {
            TabView(selection: $selectedTab) {
                HomeView()
                    .tabItem {
                        Label(L10n.text(.tabHome), systemImage: "house")
                    }
                    .tag(RootTab.home)

                MyView()
                    .tabItem {
                        Label(L10n.text(.tabMy), systemImage: "person")
                    }
                    .tag(RootTab.my)
            }
            .navigationDestination(for: CategoryItem.self) { category in
                CategoryDetailView(category: category)
            }
            .navigationDestination(for: SeriesItem.self) { series in
                SeriesDetailView(series: series)
            }
            .navigationDestination(for: PlaybackContext.self) { context in
                PlayerView(context: context)
            }
        }
        .environment(\.locale, L10n.currentLocale)
        #if os(iOS)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        #endif
    }
}

private enum RootTab {
    case home
    case my
}

#Preview {
    ContentView()
}
