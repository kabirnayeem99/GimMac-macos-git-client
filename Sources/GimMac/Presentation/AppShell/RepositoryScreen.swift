import SwiftUI

struct RepositoryScreen: View {
    let viewModel: RepositoryStoreViewModel
    let openRepositoryAction: () -> Void

    var body: some View {
        VStack(spacing: 0) {
            if viewModel.selectedRepository == nil {
                EmptyRepositoryStateView(openRepositoryAction: openRepositoryAction)
            } else {
                // The former in-content `TopToolbar` is now the window's native
                // unified `NSToolbar`, built by `MainToolbarController`.
                if viewModel.viewTab == 0 {
                    // Native two-pane layout: a real NSSplitViewController with a
                    // draggable divider and a vibrant `.sidebar` material pane.
                    // See ChangesSplitViewController.
                    ChangesSplitView(viewModel: viewModel)
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                } else {
                    // Native three-pane layout: commit list (vibrant sidebar) +
                    // changed-files column + diff. See HistorySplitViewController.
                    HistorySplitView(viewModel: viewModel)
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                }
            }
        }
        .background(Color(NSColor.windowBackgroundColor))
        .frame(minWidth: 1180, minHeight: 740)
        .sheet(isPresented: Binding(
            get: { viewModel.isResolvingConflicts },
            set: { if !$0 { viewModel.cancelConflictResolution() } }
        )) {
            ConflictsDialogView(viewModel: viewModel)
        }
        .task {
            await viewModel.refreshRepositoryScreenData()
            await viewModel.loadSavedRepositories()
        }
    }
}

private struct EmptyRepositoryStateView: View {
    let openRepositoryAction: () -> Void

    var body: some View {
        VStack(spacing: 14) {
            Image(systemName: "folder.badge.questionmark")
                .font(.system(size: 44, weight: .light))
                .foregroundStyle(.tertiary)

            Text("No Repository Selected")
                .font(.system(size: 22, weight: .semibold))

            Text("Select a local Git repository to view changes and history.")
                .font(.system(size: 13))
                .foregroundStyle(.secondary)

            Button("Select Repository") {
                openRepositoryAction()
            }
            .buttonStyle(.borderedProminent)
            .controlSize(.large)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .contentShape(Rectangle())
        .onTapGesture {
            openRepositoryAction()
        }
    }
}
