import SwiftUI

/// Push/sync control hosted by the unified window toolbar's `sync` item.
/// Extracted verbatim from the former `TopToolbar`, including the force-push
/// confirmation alert and its `@State`. Visibility (the former `showSyncBar`
/// gate) is handled by the toolbar item's reactive `isHidden` in
/// `MainToolbarController`; this view always renders its card when shown.
struct SyncMenuButton: View {
    let viewModel: RepositoryStoreViewModel

    @State private var showForcePushAlert = false

    var body: some View {
        Menu {
            Button(viewModel.primaryAction.label) {
                Task { await viewModel.performPrimaryAction() }
            }
            .disabled(viewModel.isSyncInProgress || !viewModel.canPerformPrimaryAction)

            if viewModel.showForcePushOption {
                Divider()
                Button("Force Push \(viewModel.remoteName ?? "origin")…", role: .destructive) {
                    showForcePushAlert = true
                }
                .disabled(viewModel.isSyncInProgress)
            }
        } label: {
            PushToolbarCard(
                label: viewModel.primaryAction.label,
                subtitle: viewModel.primaryAction.subtitle,
                badge: viewModel.primaryAction.badge,
                lastFetched: viewModel.lastFetched,
                isLoading: viewModel.isSyncInProgress
            )
        }
        .buttonStyle(.plain)
        .menuIndicator(.hidden) // Manual chevron in PushToolbarCard is better placed
        .fixedSize()
        .alert(
            "Force Push to \(viewModel.remoteName ?? "origin")?",
            isPresented: $showForcePushAlert
        ) {
            Button("Cancel", role: .cancel) {}
            Button("Force Push", role: .destructive) {
                Task { await viewModel.performForcePush() }
            }
        } message: {
            Text("This overwrites the remote branch history with your local commits and cannot be undone.")
        }
    }
}
