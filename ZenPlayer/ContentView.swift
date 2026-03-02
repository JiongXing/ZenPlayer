//
//  ContentView.swift
//  ZenPlayer
//
//  Created by jxing on 2026/2/11.
//

import SwiftUI

struct ContentView: View {
    @EnvironmentObject private var languageSettings: LanguageSettings
    #if os(iOS)
    @Environment(\.horizontalSizeClass) private var sizeClass
    #endif

    @State private var isSettingsPresented = false
    @State private var showLanguageToast = false
    @State private var languageToastText = ""

    var body: some View {
        ZStack(alignment: .trailing) {
            mainNavigation
                .environment(\.locale, languageSettings.currentLocale)

            settingsMask
                .opacity(isSettingsPresented ? 1 : 0)
                .allowsHitTesting(isSettingsPresented)
                .zIndex(1)

            drawerContainer
                .zIndex(2)

            if showLanguageToast {
                languageToast
                    .padding(.top, 12)
                    .zIndex(3)
            }
        }
        #if os(iOS)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        #endif
        #if os(macOS)
        .onExitCommand {
            guard isSettingsPresented else { return }
            isSettingsPresented = false
        }
        #endif
        .onChange(of: languageSettings.selectedLanguage) { _, newLanguage in
            let name = L10n.string(newLanguage.nameKey, locale: newLanguage.locale)
            languageToastText = L10n.string(.settingsLanguageSwitchedTo, locale: newLanguage.locale, name)
            withAnimation(.easeOut(duration: 0.2)) {
                showLanguageToast = true
            }
            Task { @MainActor in
                try? await Task.sleep(for: .seconds(1.4))
                withAnimation(.easeIn(duration: 0.2)) {
                    showLanguageToast = false
                }
            }
        }
    }

    private var mainNavigation: some View {
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
    }

    // MARK: - NavigationStack（iPhone / macOS）

    private var stackNavigationView: some View {
        NavigationStack {
            HomeView()
                .toolbar {
                    settingsToolbarItem
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
    }

    // MARK: - NavigationSplitView（iPad 双栏布局）

    #if os(iOS)
    private var iPadNavigationView: some View {
        NavigationSplitView {
            HomeView()
                .toolbar {
                    settingsToolbarItem
                }
        } detail: {
            VStack(spacing: 12) {
                Image(systemName: "rectangle.stack")
                    .font(.system(size: 48))
                    .foregroundStyle(.tertiary)
                Text(L10n.text(.contentSelectCategoryHint))
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
        .navigationDestination(for: PlaybackContext.self) { context in
            PlayerView(context: context)
        }
    }
    #endif

    // MARK: - 设置按钮

    @ToolbarContentBuilder
    private var settingsToolbarItem: some ToolbarContent {
        #if os(macOS)
        ToolbarItem(placement: .automatic) {
            settingsButton
        }
        #else
        ToolbarItem(placement: .topBarTrailing) {
            settingsButton
        }
        #endif
    }

    private var settingsButton: some View {
        Button {
            withAnimation(.spring(response: 0.3, dampingFraction: 0.9)) {
                isSettingsPresented.toggle()
            }
        } label: {
            Image(systemName: "gearshape.fill")
                .font(.system(size: 15, weight: .semibold))
                .frame(width: 34, height: 34)
                .background {
                    Circle()
                        .fill(.ultraThinMaterial)
                        .overlay {
                            Circle()
                                .strokeBorder(Color.primary.opacity(0.1), lineWidth: 1)
                        }
                }
        }
        .buttonStyle(.plain)
        .accessibilityLabel(Text(L10n.text(.homeSettingsAccessibility)))
    }

    // MARK: - 设置抽屉

    private var settingsMask: some View {
        Rectangle()
            .fill(Color.black.opacity(0.18))
            .ignoresSafeArea()
            .onTapGesture {
                withAnimation(.spring(response: 0.3, dampingFraction: 0.9)) {
                    isSettingsPresented = false
                }
            }
    }

    private var drawerContainer: some View {
        GeometryReader { proxy in
            let width = drawerWidth(for: proxy.size.width)
            let hiddenOffset = width + 24

            SettingsDrawerView()
                .frame(width: width)
                .offset(x: isSettingsPresented ? 0 : hiddenOffset)
                .padding(.trailing, 12)
                .padding(.vertical, 12)
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .trailing)
                .allowsHitTesting(isSettingsPresented)
                .accessibilityHidden(!isSettingsPresented)
                .animation(.spring(response: 0.32, dampingFraction: 0.9), value: isSettingsPresented)
        }
    }

    private func drawerWidth(for containerWidth: CGFloat) -> CGFloat {
        #if os(macOS)
        min(max(340, containerWidth * 0.36), 440)
        #else
        min(max(280, containerWidth * 0.78), 360)
        #endif
    }

    private var languageToast: some View {
        Text(languageToastText)
            .font(.subheadline.weight(.medium))
            .foregroundStyle(.primary)
            .padding(.horizontal, 14)
            .padding(.vertical, 10)
            .background {
                Capsule(style: .continuous)
                    .fill(.ultraThinMaterial)
                    .overlay {
                        Capsule(style: .continuous)
                            .strokeBorder(Color.primary.opacity(0.1), lineWidth: 1)
                    }
            }
            .frame(maxWidth: .infinity, alignment: .top)
            .allowsHitTesting(false)
    }
}

#Preview {
    ContentView()
        .environmentObject(LanguageSettings())
}
