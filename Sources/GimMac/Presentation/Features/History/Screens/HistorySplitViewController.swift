import AppKit

/// Native three-pane layout for the History tab.
///
/// Replaces the prior SwiftUI `HSplitView` (commit list + changed-files column
/// + diff) with a real `NSSplitViewController`: draggable dividers, a
/// collapsible commit-list pane carrying the system `.sidebar` vibrant
/// material, and two solid content panes. Mirrors `ChangesSplitViewController`
/// for the Changes tab.
@MainActor
final class HistorySplitViewController: RepositorySplitViewController {
    override func viewDidLoad() {
        super.viewDidLoad()
        splitView.dividerStyle = .thin

        // Commit-list pane — vibrant `.sidebar` material, system-managed.
        let sidebarHost = makeHostingController(
            CommitHistorySidebar(viewModel: viewModel)
        )
        let sidebarItem = NSSplitViewItem(sidebarWithViewController: sidebarHost)
        sidebarItem.canCollapse = true
        sidebarItem.minimumThickness = 280
        sidebarItem.maximumThickness = 360
        sidebarItem.holdingPriority = NSLayoutConstraint.Priority(261)
        addSplitViewItem(sidebarItem)

        // Changed-files column — solid content pane, holds its width.
        let filesHost = makeHostingController(HistoryFilesColumn(viewModel: viewModel))
        let filesItem = NSSplitViewItem(contentListWithViewController: filesHost)
        filesItem.canCollapse = false
        filesItem.minimumThickness = 260
        filesItem.maximumThickness = 420
        filesItem.holdingPriority = NSLayoutConstraint.Priority(260)
        addSplitViewItem(filesItem)

        // Diff pane — absorbs resize.
        let diffHost = makeHostingController(
            HistoryDiffContent(viewModel: viewModel)
        )
        let diffItem = NSSplitViewItem(viewController: diffHost)
        diffItem.canCollapse = false
        diffItem.minimumThickness = 520
        addSplitViewItem(diffItem)
    }

}
