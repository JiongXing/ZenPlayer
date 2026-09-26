//
//  ContentView.swift
//  ZenPlayer
//
//  Created by jxing on 2026/2/11.
//

import SwiftUI

struct ContentView: View {
    @Environment(PlayerViewModel.self) private var session
    @Environment(\.scenePhase) private var scenePhase
    @State private var visiblePlayerIDs: Set<UUID> = []
    @State private var navigationPath = NavigationPath()
    @State private var selectedTab: RootTab = .home

    var body: some View {
        NavigationStack(path: $navigationPath) {
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
            .navigationDestination(for: SeriesDestination.self) { destination in
                SeriesDetailView(destination: destination)
            }
            .navigationDestination(for: PlaybackContext.self) { context in
                PlayerView(context: context)
            }
            .navigationDestination(for: PlayerControlsRoute.self) { _ in
                if let context = session.currentContext {
                    PlayerView(context: context, selectsOnAppear: false)
                } else {
                    Text(L10n.text(.sessionStopped))
                }
            }
        }
        .safeAreaInset(edge: .bottom, spacing: 0) {
            if session.hasSession && visiblePlayerIDs.isEmpty {
                MiniPlayerView { navigationPath.append(PlayerControlsRoute.current) }
            }
        }
        .environment(\.playerControlsVisibility, { id, visible in
            if visible { visiblePlayerIDs.insert(id) } else { visiblePlayerIDs.remove(id) }
        })
        .onChange(of: scenePhase) { _, _ in session.saveForLifecycleChange() }
        .environment(\.locale, L10n.currentLocale)
        #if os(iOS)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        #endif
    }
}

private enum PlayerControlsRoute: Hashable { case current }

private enum RootTab {
    case home
    case my
}

#Preview {
    ContentView().environment(PlayerViewModel())
}
