import SwiftUI

struct TopToolbar: View {
    let viewModel: RepositoryStoreViewModel
    let openRepositoryAction: () -> Void

    var body: some View {
        HStack(spacing: 8) {
            Button {
                openRepositoryAction()
            } label: {
                ToolbarCard(
                    icon: "folder",
                    title: "Repository",
                    value: viewModel.selectedRepository?.displayName ?? "No repository selected"
                )
            }
            .buttonStyle(.plain)
            .frame(width: 300)

            ToolbarCard(
                icon: "point.3.connected.trianglepath.dotted",
                title: "Branch",
                value: RepositoryBranchDisplayFormatter.displayText(for: viewModel.repositoryState)
            )
            .frame(width: 240)

            PushToolbarCard(
                label: viewModel.primaryAction.label,
                subtitle: viewModel.primaryAction.subtitle,
                badge: viewModel.primaryAction.badge
            )
            .frame(width: 260)

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
