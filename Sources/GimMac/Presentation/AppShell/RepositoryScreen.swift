import SwiftUI

struct RepositoryScreen: View {
    let viewModel: RepositoryStoreViewModel
    let openRepositoryAction: () -> Void

    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        ZStack {
            if viewModel.selectedRepository == nil {
                EmptyRepositoryStateView(openRepositoryAction: openRepositoryAction)
                    .transition(.opacity)
            } else {
                // The former in-content `TopToolbar` is now the window's native
                // unified `NSToolbar`, built by `MainToolbarController`.
                // The content container keeps the Changes and History native
                // split controllers alive across tab switches so divider
                // positions and first responder are preserved.
                RepositoryContentView(viewModel: viewModel, viewTab: viewModel.viewTab)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .transition(.opacity)
            }
        }
        .animation(Motion.resolve(Motion.spatial, reduceMotion: reduceMotion), value: viewModel.selectedRepository == nil)
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
