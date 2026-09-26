import SwiftUI

/// 内联状态，不遮挡播放／历史内容，不产生重复弹窗。
struct ProgressSaveNotice: View {
    let store: PlaybackProgressStore

    var body: some View {
        if store.saveError != nil || store.migrationError != nil || !store.recoveryIssues.isEmpty {
            HStack(alignment: .top) {
                Image(systemName: "exclamationmark.triangle")
                Text(L10n.text(store.saveError != nil ? .progressSaveFailed : .progressRecoveryIssue))
                Spacer(minLength: 8)
                Button(L10n.text(.progressRetry)) { store.retry() }
            }
            .font(.footnote)
            .padding(10)
            .background(.orange.opacity(0.12), in: RoundedRectangle(cornerRadius: 8))
        }
    }
}
