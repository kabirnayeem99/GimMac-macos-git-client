import AppKit
import SwiftUI

/// Shared base for the repository's native split layouts (`ChangesSplitViewController`,
/// `HistorySplitViewController`).
///
/// Holds the common boilerplate both panes need: the injected view model, a
/// transparent SwiftUI hosting helper so a sidebar pane's `.sidebar` vibrant
/// material reads through. Subclasses add their split items in `viewDidLoad`.
@MainActor
class RepositorySplitViewController: NSSplitViewController {
    let viewModel: RepositoryStoreViewModel

    init(viewModel: RepositoryStoreViewModel) {
        self.viewModel = viewModel
        super.init(nibName: nil, bundle: nil)
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    /// Hosts a SwiftUI view with a transparent backing layer so the system
    /// sidebar material (and explicit content backgrounds) show through.
    func makeHostingController<Content: View>(_ rootView: Content) -> NSHostingController<Content> {
        let host = NSHostingController(rootView: rootView)
        host.view.wantsLayer = true
        host.view.layer?.backgroundColor = .clear
        return host
    }
}
