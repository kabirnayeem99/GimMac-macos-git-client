import AppKit
import SwiftUI

/// Builds and owns the window's native unified `NSToolbar`, hosting the existing
/// SwiftUI toolbar controls (repository picker, branch picker, push/sync) inside
/// a single `NSToolbarItem` via `NSHostingView`.
///
/// This replaces the former in-content `TopToolbar` SwiftUI bar: the same control
/// bodies are reused verbatim (`RepositoryMenuButton`, `BranchToolbarButton`,
/// `SyncMenuButton`) so there is no duplicated menu/popover/alert logic.
///
/// **One hosted item, not three.** Each control was tried as its own custom-view
/// `NSToolbarItem`, but adjacent custom views sized with `.intrinsicContentSize`
/// don't reserve width against one another and overlap. Hosting all three in a
/// single SwiftUI `HStack` lets SwiftUI lay them out (no overlap) and lets the
/// push/sync card show/hide reactively via `if viewModel.showSyncBar` — no
/// `withObservationTracking` re-arm or live `insertItem`/`removeItem` needed.
@MainActor
final class MainToolbarController: NSObject, NSToolbarDelegate {
    private enum ItemID {
        static let repository = NSToolbarItem.Identifier("gimmac.toolbar.repository")
        static let controls = NSToolbarItem.Identifier("gimmac.toolbar.controls")
    }

    private static let toolbarIdentifier = NSToolbar.Identifier("gimmac.main.toolbar")

    private let viewModel: RepositoryStoreViewModel
    private let openRepositoryAction: () -> Void
    private let selectRepositoryAction: (UUID) -> Void

    init(
        viewModel: RepositoryStoreViewModel,
        openRepositoryAction: @escaping () -> Void,
        selectRepositoryAction: @escaping (UUID) -> Void
    ) {
        self.viewModel = viewModel
        self.openRepositoryAction = openRepositoryAction
        self.selectRepositoryAction = selectRepositoryAction
        super.init()
    }

    /// Build the toolbar and install it on the window. Idempotent: if the window
    /// already carries our toolbar, this does nothing.
    func install(on window: NSWindow) {
        guard window.toolbar?.identifier != Self.toolbarIdentifier else { return }

        let toolbar = NSToolbar(identifier: Self.toolbarIdentifier)
        toolbar.delegate = self
        toolbar.displayMode = .iconOnly
        toolbar.allowsUserCustomization = false

        window.toolbar = toolbar
        window.toolbarStyle = .unified
        // Hide the window title: the custom control cards own the unified toolbar
        // row; a visible "GimMac" title would compete for the leading area and
        // push the items off to the trailing edge.
        window.titleVisibility = .hidden
    }

    // MARK: - NSToolbarDelegate

    func toolbarDefaultItemIdentifiers(_ toolbar: NSToolbar) -> [NSToolbarItem.Identifier] {
        // Repository name leads (window subject, like Finder's folder title);
        // flexible space pushes the branch/sync icon buttons to the trailing edge.
        [ItemID.repository, .flexibleSpace, ItemID.controls]
    }

    func toolbarAllowedItemIdentifiers(_ toolbar: NSToolbar) -> [NSToolbarItem.Identifier] {
        [ItemID.repository, .flexibleSpace, ItemID.controls]
    }

    func toolbar(
        _ toolbar: NSToolbar,
        itemForItemIdentifier itemIdentifier: NSToolbarItem.Identifier,
        willBeInsertedIntoToolbar flag: Bool
    ) -> NSToolbarItem? {
        switch itemIdentifier {
        case ItemID.repository:
            return makeHostedItem(identifier: itemIdentifier) {
                RepositoryMenuButton(
                    viewModel: self.viewModel,
                    openRepositoryAction: self.openRepositoryAction,
                    selectRepositoryAction: self.selectRepositoryAction
                )
            }
        case ItemID.controls:
            return makeHostedItem(identifier: itemIdentifier) {
                TrailingToolbarControls(viewModel: self.viewModel)
            }
        default:
            return nil
        }
    }

    // MARK: - Hosting

    /// Wrap a SwiftUI control in an `NSHostingView` that sizes to its content.
    /// The cards declare their own 40pt height and `.fixedSize()` width, so
    /// `.intrinsicContentSize` lets the hosting view (and thus the toolbar item)
    /// hug the content. Leave autoresizing-mask translation on — combining it
    /// with manual `translatesAutoresizingMaskIntoConstraints = false` and no
    /// external width constraint makes the item width ambiguous, which the
    /// toolbar resolves by stretching it.
    private func makeHostedItem<Content: View>(
        identifier: NSToolbarItem.Identifier,
        @ViewBuilder content: () -> Content
    ) -> NSToolbarItem {
        let hosting = NSHostingView(rootView: content())
        hosting.sizingOptions = [.intrinsicContentSize]

        let item = NSToolbarItem(itemIdentifier: identifier)
        item.view = hosting
        return item
    }
}

/// Trailing icon buttons (branch picker + push/sync), laid out by SwiftUI inside
/// the trailing hosted toolbar item. The push/sync card appears only when
/// `showSyncBar` is set — the `@Observable` view model drives show/hide reactively.
private struct TrailingToolbarControls: View {
    let viewModel: RepositoryStoreViewModel

    var body: some View {
        HStack(spacing: 6) {
            BranchToolbarButton(viewModel: viewModel)

            if viewModel.showSyncBar {
                SyncMenuButton(viewModel: viewModel)
            }
        }
        .fixedSize()
    }
}
