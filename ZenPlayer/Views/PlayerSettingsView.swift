import SwiftUI

struct PlayerSettingsView: View {
    @Environment(PlayerViewModel.self) private var session
    @State private var isExpanded = false
    @ScaledMetric(relativeTo: .footnote) private var optionWidth = 58

    private var summary: String {
        L10n.string(.playerSettingsSummary, session.denoiseLevel.label,
                    PlayerViewModel.amplificationLabel(session.amplificationMultiplier))
    }

    var body: some View {
        @Bindable var store = session.queueStore
        VStack(spacing: 8) {
            Divider()
            DisclosureGroup(isExpanded: $isExpanded) {
                VStack(alignment: .leading, spacing: 20) {
                    Toggle(L10n.text(.queueAutoAdvance), isOn: $store.autoAdvance)
                        .accessibilityIdentifier("player.autoAdvance")
                    VStack(alignment: .leading, spacing: 10) {
                        Text(L10n.text(.playerVoiceDenoise)).font(.subheadline)
                        LazyVGrid(columns: [GridItem(.adaptive(minimum: optionWidth))], spacing: 8) {
                            ForEach(PlayerViewModel.DenoiseLevel.allCases, id: \.rawValue) { level in
                                option(level.label, selected: session.denoiseLevel == level) {
                                    session.denoiseLevel = level
                                }
                                .accessibilityIdentifier("player.denoise.\(level.rawValue)")
                            }
                        }
                    }
                    VStack(alignment: .leading, spacing: 10) {
                        Text(L10n.text(.playerVolumeBoost)).font(.subheadline)
                        LazyVGrid(columns: [GridItem(.adaptive(minimum: optionWidth))], spacing: 8) {
                            ForEach(PlayerViewModel.supportedAmplificationOptions, id: \.self) { value in
                                option(PlayerViewModel.amplificationLabel(value), selected: session.amplificationMultiplier == value) {
                                    session.amplificationMultiplier = value
                                }
                                .accessibilityIdentifier("player.amplification.\(Int(value))")
                            }
                        }
                    }
                }
                .padding(.vertical, 12)
            } label: {
                ViewThatFits(in: .horizontal) {
                    HStack(spacing: 16) {
                        settingsLabel
                        Spacer(minLength: 0)
                        Text(summary).font(.caption).foregroundStyle(.secondary)
                    }
                    VStack(alignment: .leading, spacing: 4) {
                        settingsLabel
                        Text(summary).font(.caption).foregroundStyle(.secondary)
                    }
                }
                .frame(minHeight: 44)
                .contentShape(Rectangle())
            }
            .tint(.primary)
            .disclosureGroupStyle(PlayerSettingsDisclosureStyle())
        }
    }

    private var settingsLabel: some View {
        Label(L10n.text(.playerSettings), systemImage: "slider.horizontal.3")
            .font(.subheadline)
            .fixedSize(horizontal: true, vertical: false)
    }

    private func option(_ title: String, selected: Bool, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Text(title)
                .font(.footnote.weight(selected ? .semibold : .regular))
                .frame(maxWidth: .infinity, minHeight: 44)
                .background(.primary.opacity(selected ? 0.12 : 0.04), in: RoundedRectangle(cornerRadius: 8))
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityAddTraits(selected ? .isSelected : [])
    }
}

private struct PlayerSettingsDisclosureStyle: DisclosureGroupStyle {
    func makeBody(configuration: Configuration) -> some View {
        VStack(alignment: .leading, spacing: 0) {
            Button { configuration.isExpanded.toggle() } label: {
                HStack(spacing: 12) {
                    configuration.label
                    Image(systemName: configuration.isExpanded ? "chevron.down" : "chevron.right")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .accessibilityHidden(true)
                }
                .frame(minHeight: 44)
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .accessibilityIdentifier("player.settings")
            .accessibilityValue(L10n.text(configuration.isExpanded ? .playerSettingsExpanded : .playerSettingsCollapsed))
            if configuration.isExpanded {
                configuration.content
            }
        }
    }
}
