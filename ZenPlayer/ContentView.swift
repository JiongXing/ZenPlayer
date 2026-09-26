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
    @State private var navigationPath = NavigationPath()
    @State private var selectedTab: RootTab = .home

    var body: some View {
        NavigationStack(path: $navigationPath) {
            TabView(selection: $selectedTab) {
                HomeView()
                    .miniPlayerInset()
                    .tabItem {
                        Label(L10n.text(.tabHome), systemImage: "house")
                    }
                    .tag(RootTab.home)

                MyView()
                    .miniPlayerInset()
                    .tabItem {
                        Label(L10n.text(.tabMy), systemImage: "person")
                    }
                    .tag(RootTab.my)
            }
            #if os(iOS)
            .tint(Color("HomeAccent"))
            #endif
            .navigationDestination(for: MyView.Destination.self) { destination in
                Group {
                    switch destination {
                    case .recentPlayback: RecentPlaybackListView()
                    case .completedDownloads: CompletedDownloadListView()
                    case .about: AboutView()
                    }
                }
                .miniPlayerInset()
            }
            .navigationDestination(for: CategoryItem.self) { category in
                CategoryDetailView(category: category)
                    .miniPlayerInset()
            }
            .navigationDestination(for: SeriesItem.self) { series in
                SeriesDetailView(series: series)
                    .miniPlayerInset()
            }
            .navigationDestination(for: SeriesDestination.self) { destination in
                SeriesDetailView(destination: destination)
                    .miniPlayerInset()
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
        .environment(\.openPlayerControls, { navigationPath.append(PlayerControlsRoute.current) })
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
