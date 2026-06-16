import AppKit
import SwiftUI

/// Diff pane of the History split. Solid window background keeps diff text
/// legible while the commit-list pane keeps the sidebar material.
struct HistoryDiffContent: View {
    let viewModel: RepositoryStoreViewModel

    var body: some View {
        DiffViewer(viewModel: viewModel, source: .history)
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .background(Color(NSColor.windowBackgroundColor))
    }
}
