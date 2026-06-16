import AppKit
import Observation
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
/// single SwiftUI `HStack` lets SwiftUI lay them out without overlap. The sync
/// card stays in that layout and changes opacity when unavailable, avoiding
/// `withObservationTracking` re-arm or live item insertion/removal.
@MainActor
final class MainToolbarController: NSObject, NSToolbarDelegate {
    private enum ItemID {
        static let navigation = NSToolbarItem.Identifier("gimmac.toolbar.navigation")
        static let contextCluster = NSToolbarItem.Identifier("gimmac.toolbar.contextCluster")
    }

    private static let toolbarIdentifier = NSToolbar.Identifier("gimmac.main.toolbar")

    private let viewModel: RepositoryStoreViewModel
    private let openRepositoryAction: () -> Void
    private let newRepositoryAction: () -> Void
    private let cloneRepositoryAction: () -> Void
    private let selectRepositoryAction: (UUID) -> Void
    private weak var tabControl: NSSegmentedControl?
    private var isObservingToolbarState = false

    init(
        viewModel: RepositoryStoreViewModel,
        openRepositoryAction: @escaping () -> Void,
        newRepositoryAction: @escaping () -> Void,
        cloneRepositoryAction: @escaping () -> Void,
        selectRepositoryAction: @escaping (UUID) -> Void
    ) {
        self.viewModel = viewModel
        self.openRepositoryAction = openRepositoryAction
        self.newRepositoryAction = newRepositoryAction
        self.cloneRepositoryAction = cloneRepositoryAction
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
        [.flexibleSpace, ItemID.navigation, ItemID.contextCluster]
    }

    func toolbarAllowedItemIdentifiers(_ toolbar: NSToolbar) -> [NSToolbarItem.Identifier] {
        [.flexibleSpace, ItemID.navigation, ItemID.contextCluster]
    }

    func toolbar(
        _ toolbar: NSToolbar,
        itemForItemIdentifier itemIdentifier: NSToolbarItem.Identifier,
        willBeInsertedIntoToolbar flag: Bool
    ) -> NSToolbarItem? {
        switch itemIdentifier {
        case ItemID.navigation:
            return makeNavigationItem(identifier: itemIdentifier)
        case ItemID.contextCluster:
            return makeHostedItem(identifier: itemIdentifier) {
                ContextToolbarCluster(
                    viewModel: self.viewModel,
                    openRepositoryAction: self.openRepositoryAction,
                    newRepositoryAction: self.newRepositoryAction,
                    cloneRepositoryAction: self.cloneRepositoryAction,
                    selectRepositoryAction: self.selectRepositoryAction
                )
            }
        default:
            return nil
        }
    }

    private func makeNavigationItem(identifier: NSToolbarItem.Identifier) -> NSToolbarItem {
        let control = NSSegmentedControl(
            labels: ["Changes", "History"],
            trackingMode: .selectOne,
            target: self,
            action: #selector(tabControlChanged(_:))
        )
        control.segmentStyle = .rounded
        control.controlSize = .small
        control.setImage(
            NSImage(systemSymbolName: "tray.full", accessibilityDescription: nil),
            forSegment: 0
        )
        control.setImage(
            NSImage(systemSymbolName: "clock.arrow.circlepath", accessibilityDescription: nil),
            forSegment: 1
        )
        control.setWidth(92, forSegment: 0)
        control.setWidth(88, forSegment: 1)
        control.toolTip = "Switch between Changes and History"
        control.setAccessibilityLabel("Repository view")
        tabControl = control
        renderToolbarState()
        observeToolbarState()

        let item = NSToolbarItem(itemIdentifier: identifier)
        item.label = "Repository View"
        item.paletteLabel = "Repository View"
        item.view = control
        return item
    }

    @objc private func tabControlChanged(_ sender: NSSegmentedControl) {
        guard sender.selectedSegment >= 0 else { return }
        viewModel.viewTab = sender.selectedSegment
    }

    private func observeToolbarState() {
        guard !isObservingToolbarState else { return }
        isObservingToolbarState = true
        withObservationTracking { [weak self] in
            guard let self else { return }
            _ = self.viewModel.viewTab
            _ = self.viewModel.selectedRepository
        } onChange: { [weak self] in
            Task { @MainActor in
                self?.isObservingToolbarState = false
                self?.renderToolbarState()
                self?.observeToolbarState()
            }
        }
    }

    private func renderToolbarState() {
        tabControl?.selectedSegment = viewModel.viewTab
        tabControl?.isEnabled = viewModel.selectedRepository != nil
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
