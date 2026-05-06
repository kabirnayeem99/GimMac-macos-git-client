import SwiftUI

struct TopToolbar: View {
    let viewModel: RepositoryStoreViewModel
    let openRepositoryAction: () -> Void
    let selectRepositoryAction: (UUID) -> Void

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
            .menuIndicator(.hidden)
            .frame(width: 300)

            ToolbarCard(
                icon: "point.3.connected.trianglepath.dotted",
                title: "Branch",
                value: RepositoryBranchDisplayFormatter.displayText(for: viewModel.repositoryState)
            )
            .frame(width: 240)

            if viewModel.hasRemote {
                PushToolbarCard(
                    label: viewModel.primaryAction.label,
                    subtitle: viewModel.primaryAction.subtitle,
                    badge: viewModel.primaryAction.badge
                )
                .frame(width: 260)
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
