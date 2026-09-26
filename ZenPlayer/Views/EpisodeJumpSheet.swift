import SwiftUI

struct EpisodeJumpSheet: View {
    @Binding var input: String
    let submit: () -> Void
    @Environment(\.dismiss) private var dismiss
    @FocusState private var isFocused: Bool

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                Text(L10n.text(.catalogJumpTitle)).font(.headline)
                TextField(L10n.string(.catalogJumpInput), text: $input)
                    .textFieldStyle(.roundedBorder)
                    .frame(minHeight: 44)
                    .focused($isFocused)
                    .autocorrectionDisabled()
                    .onSubmit(confirm)
                HStack {
                    Button { dismiss() } label: {
                        Text(L10n.text(.commonCancel)).frame(minWidth: 44, minHeight: 44)
                    }
                        .keyboardShortcut(.cancelAction)
                    Spacer()
                    Button(action: confirm) {
                        Text(L10n.text(.catalogJumpGo)).frame(minWidth: 44, minHeight: 44)
                    }
                        .buttonStyle(.borderedProminent)
                        .keyboardShortcut(.defaultAction)
                }
            }
            .padding(24)
        }
        .frame(idealWidth: 380, idealHeight: 230)
        .task { isFocused = true }
    }

    private func confirm() {
        isFocused = false
        dismiss()
        submit()
    }
}
