import SwiftUI

struct TopToolbar: View {
    let viewModel: RepositoryStoreViewModel
    let openRepositoryAction: () -> Void
    let selectRepositoryAction: (UUID) -> Void

    @State private var showForcePushAlert = false

    var body: some View {
        HStack(spacing: 8) {
            Menu {
                if viewModel.savedRepositories.isEmpty {
                    Text("No saved repositories")
                } else {
                    Section("Recent Repositories") {
                        ForEach(viewModel.savedRepositories) { repository in
                            Button {
                                selectRepositoryAction(repository.id)
                            } label: {
                                HStack {
                                    VStack(alignment: .leading, spacing: 2) {
                                        Text(repository.name)
                                        Text(repository.path)
                                            .font(.caption2)
                                            .foregroundStyle(.secondary)
                                    }
                                    if !repository.existsOnDisk {
                                        Spacer()
                                        Text("Missing")
                                            .font(.caption2)
                                            .foregroundStyle(.tertiary)
                                    }
                                }
                            }
                            .disabled(!repository.existsOnDisk)
                        }
                    }
                }

                Divider()

                Button("Open Repository…") {
                    openRepositoryAction()
                }
            } label: {
                ToolbarCard(
                    icon: "folder",
                    title: "Repository",
                    value: viewModel.selectedRepository?.displayName ?? "No repository selected"
                )
            }
            .buttonStyle(.plain)
            .menuIndicator(.hidden) // Manual chevron in ToolbarCard is better placed

            BranchesPopoverButton(
                viewModelFactory: { [viewModel] in viewModel.makeBranchesViewModel() }
            ) {
                if viewModel.makeBranchesViewModel() != nil {
                    ToolbarCard(
                        icon: "point.3.connected.trianglepath.dotted",
                        title: "Branch",
                        value: RepositoryBranchDisplayFormatter.displayText(for: viewModel.tip)
                    )
                } else {
                    ToolbarCard(
                        icon: "exclamationmark.triangle",
                        title: "Branch",
                        value: "Selector Unavailable"
                    )
                }
            }
            .disabled(viewModel.makeBranchesViewModel() == nil)

            if viewModel.showSyncBar {
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

            Spacer()
        }
        .padding(.horizontal, 12)
        .frame(height: 58)
        .background(.bar)
        .overlay(alignment: .bottom) {
            Divider()
        }
    }
}
