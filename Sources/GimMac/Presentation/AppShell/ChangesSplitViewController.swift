import AppKit
import SwiftUI

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
        splitView.dividerStyle = .thin

        // Sidebar pane. `sidebar(with:)` opts the pane into the system
        // `.sidebar` vibrant material and full-height behavior — no manual
        // NSVisualEffectView needed. The SwiftUI content is hosted with a
        // clear background so the material reads through.
        let sidebarHost = makeHostingController(
            Sidebar(selectedTab: viewTabBinding, viewModel: viewModel)
        )
        let sidebarItem = NSSplitViewItem(sidebarWithViewController: sidebarHost)
        sidebarItem.canCollapse = true
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

/// Content pane of the Changes split. Switches between the diff viewer and the
/// summary/empty content based on `changedFilesCount`; the `@Observable`
/// view model drives re-rendering. A solid window background keeps diff text
/// legible (the vibrant material is intentionally limited to the sidebar).
private struct ChangesContentView: View {
    let viewModel: RepositoryStoreViewModel

    var body: some View {
        Group {
            if viewModel.changedFilesCount > 0 {
                DiffViewer(viewModel: viewModel)
            } else {
                MainContent(viewModel: viewModel)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color(NSColor.windowBackgroundColor))
    }
}

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
