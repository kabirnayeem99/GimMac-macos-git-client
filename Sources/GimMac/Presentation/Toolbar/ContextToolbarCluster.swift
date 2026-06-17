import SwiftUI

/// Repository, branch, and push/sync controls laid out as one trailing toolbar
/// cluster. The sync card keeps its layout slot when hidden.
struct ContextToolbarCluster: View {
    let viewModel: RepositoryStoreViewModel
    let openRepositoryAction: () -> Void
    let newRepositoryAction: () -> Void
    let cloneRepositoryAction: () -> Void
    let selectRepositoryAction: (UUID) -> Void
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        HStack(spacing: 6) {
            RepositoryMenuButton(
                viewModel: viewModel,
                openRepositoryAction: openRepositoryAction,
                newRepositoryAction: newRepositoryAction,
                cloneRepositoryAction: cloneRepositoryAction,
                selectRepositoryAction: selectRepositoryAction
            )

            BranchToolbarButton(viewModel: viewModel)

            if viewModel.showSyncBar {
                SyncMenuButton(viewModel: viewModel)
                    .opacity(viewModel.showSyncBar ? 1 : 0)
                    .allowsHitTesting(viewModel.showSyncBar)
                    .accessibilityHidden(!viewModel.showSyncBar)
                    .motion(Motion.spatial, reduceMotion: reduceMotion, value: viewModel.showSyncBar)
            }
        }
        .fixedSize()
    }
}
