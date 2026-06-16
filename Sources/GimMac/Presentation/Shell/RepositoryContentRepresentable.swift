import SwiftUI

/// Bridges the tab-switching container into SwiftUI.
struct RepositoryContentView: NSViewControllerRepresentable {
    let viewModel: RepositoryStoreViewModel
    let viewTab: Int

    func makeNSViewController(context: Context) -> RepositoryContentViewController {
        RepositoryContentViewController(viewModel: viewModel)
    }

    func updateNSViewController(_ nsViewController: RepositoryContentViewController, context: Context) {
        nsViewController.showTab(viewTab, animated: true)
    }
}
