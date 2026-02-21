//
//  ContentView.swift
//  ZenPlayer
//
//  Created by jxing on 2026/2/11.
//

import SwiftUI

struct ContentView: View {
    #if os(iOS)
    @Environment(\.horizontalSizeClass) private var sizeClass
    #endif

    var body: some View {
        Group {
            #if os(iOS)
            if sizeClass == .regular {
                iPadNavigationView
            } else {
                stackNavigationView
            }
            #else
            stackNavigationView
            #endif
        }
        #if os(iOS)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        #endif
    }

    // MARK: - NavigationStack（iPhone / macOS）

    private var stackNavigationView: some View {
        NavigationStack {
            HomeView()
                .navigationDestination(for: CategoryItem.self) { category in
                    CategoryDetailView(category: category)
                }
                .navigationDestination(for: SeriesItem.self) { series in
                    SeriesDetailView(series: series)
                }
        }
    }

    // MARK: - NavigationSplitView（iPad 双栏布局）

    #if os(iOS)
    private var iPadNavigationView: some View {
        NavigationSplitView {
            HomeView()
        } detail: {
            VStack(spacing: 12) {
                Image(systemName: "rectangle.stack")
                    .font(.system(size: 48))
                    .foregroundStyle(.tertiary)
                Text("选择类目开始浏览")
                    .font(.title3)
                    .foregroundStyle(.secondary)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
        .navigationDestination(for: CategoryItem.self) { category in
            CategoryDetailView(category: category)
        }
        .navigationDestination(for: SeriesItem.self) { series in
            SeriesDetailView(series: series)
        }
    }
    #endif
}

#Preview {
    ContentView()
}
