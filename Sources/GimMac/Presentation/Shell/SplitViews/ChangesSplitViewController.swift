import AppKit

/// Native two-pane layout for the Changes tab.
///
/// Replaces the prior SwiftUI `HStack` (fixed-width sidebar + `Divider` +
/// content) with a real `NSSplitViewController` so the divider is draggable,
/// the sidebar is collapsible, and the sidebar pane gets the system-managed
/// `.sidebar` vibrant material for smooth light/dark transitions.
///
/// The full-width `TopToolbar`, the History tab, the empty state, and the
/// conflict sheet stay in the SwiftUI shell (`RepositoryScreen`); only the
/// Changes-tab two-pane region is hosted here. Menu-bar responder routing
/// remains entirely in `MainSplitViewController`.
@MainActor
final class ChangesSplitViewController: RepositorySplitViewController {
    override func viewDidLoad() {
        super.viewDidLoad()
        splitView.dividerStyle = .paneSplitter

        // Sidebar pane. `sidebar(with:)` opts the pane into the system
        // `.sidebar` vibrant material and full-height behavior — no manual
        // NSVisualEffectView needed. The SwiftUI content is hosted with a
        // clear background so the material reads through.
        let sidebarHost = makeHostingController(
            Sidebar(viewModel: viewModel)
        )
        let sidebarItem = NSSplitViewItem(sidebarWithViewController: sidebarHost)
        sidebarItem.canCollapse = false
        sidebarItem.minimumThickness = 260
        sidebarItem.maximumThickness = 420
        sidebarItem.holdingPriority = NSLayoutConstraint.Priority(260) // sidebar holds width; content absorbs resize
        addSplitViewItem(sidebarItem)

        // Content pane: diff viewer when there are changed files, otherwise the
        // empty/summary content. The switch is observation-driven inside SwiftUI.
        let contentHost = makeHostingController(ChangesContentView(viewModel: viewModel))
        let contentItem = NSSplitViewItem(viewController: contentHost)
        contentItem.canCollapse = false
        contentItem.minimumThickness = 480
        addSplitViewItem(contentItem)
    }

}
