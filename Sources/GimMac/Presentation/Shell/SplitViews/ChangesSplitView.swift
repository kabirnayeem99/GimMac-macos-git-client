import SwiftUI

/// Bridges the native Changes split into the SwiftUI `RepositoryScreen` shell.
struct ChangesSplitView: NSViewControllerRepresentable {
    let viewModel: RepositoryStoreViewModel

    func makeNSViewController(context: Context) -> ChangesSplitViewController {
        ChangesSplitViewController(viewModel: viewModel)
    }

    func updateNSViewController(_ nsViewController: ChangesSplitViewController, context: Context) {
        // Panes observe the view model directly; nothing to push on update.
    }
}
