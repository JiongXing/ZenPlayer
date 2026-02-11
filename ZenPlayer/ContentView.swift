//
//  ContentView.swift
//  ZenPlayer
//
//  Created by jxing on 2026/2/11.
//

import SwiftUI

struct ContentView: View {
    var body: some View {
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
}

#Preview {
    ContentView()
}
