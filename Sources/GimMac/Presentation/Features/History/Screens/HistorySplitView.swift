import SwiftUI

/// Bridges the native History split into the SwiftUI `RepositoryScreen` shell.
struct HistorySplitView: NSViewControllerRepresentable {
    let viewModel: RepositoryStoreViewModel

    func makeNSViewController(context: Context) -> HistorySplitViewController {
        HistorySplitViewController(viewModel: viewModel)
    }

    func updateNSViewController(_ nsViewController: HistorySplitViewController, context: Context) {
        // Panes observe the view model directly; nothing to push on update.
    }
}
