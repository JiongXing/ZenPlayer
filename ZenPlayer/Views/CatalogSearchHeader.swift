import SwiftUI

struct CatalogSearchHeader: View {
    @Binding var query: String
    let prompt: L10nKey
    let resultText: String
    let isLimited: Bool
    let isEmpty: Bool
    @FocusState.Binding var isFocused: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 8) {
                TextField(L10n.string(prompt), text: $query)
                    .textFieldStyle(.roundedBorder)
                    .frame(minHeight: 44)
                    .focused($isFocused)
                    .accessibilityIdentifier("catalogSearchField")
                    .autocorrectionDisabled()
                if !query.isEmpty {
                    Button { query = "" } label: {
                        Label(L10n.text(.catalogClear), systemImage: "xmark.circle.fill")
                            .labelStyle(.iconOnly)
                            .frame(minWidth: 44, minHeight: 44)
                    }
                    .buttonStyle(.plain)
                }
            }
            Text(resultText).font(.subheadline)
            if isLimited {
                Label(L10n.text(.catalogLimited), systemImage: "info.circle").font(.caption)
            }
            if isEmpty { Text(L10n.text(.catalogNoResults)).font(.subheadline).foregroundStyle(.secondary) }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 8)
    }
}
