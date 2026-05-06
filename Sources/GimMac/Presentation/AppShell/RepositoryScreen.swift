import SwiftUI

struct RepositoryScreen: View {
    let viewModel: RepositoryStoreViewModel
    let openRepositoryAction: () -> Void
    let selectSavedRepositoryAction: (UUID) -> Void
    @State private var selectedTab = 0

    var body: some View {
        VStack(spacing: 0) {
            if viewModel.selectedRepository == nil {
                EmptyRepositoryStateView(openRepositoryAction: openRepositoryAction)
            } else {
                TopToolbar(
                    viewModel: viewModel,
                    openRepositoryAction: openRepositoryAction,
                    selectRepositoryAction: selectSavedRepositoryAction
                )

                if selectedTab == 0 {
                    HStack(spacing: 0) {
                        Sidebar(
                            selectedTab: $selectedTab,
                            viewModel: viewModel
                        )
                        .frame(width: 320)

                        Divider()

                        if viewModel.changedFilesCount > 0 {
                            DiffViewer(viewModel: viewModel)
                                .frame(maxWidth: .infinity, maxHeight: .infinity)
                        } else {
                            MainContent()
                                .frame(maxWidth: .infinity, maxHeight: .infinity)
                        }
                    }
                } else {
                    HistoryRepositoryScreen(
                        selectedTab: $selectedTab,
                        viewModel: viewModel
                    )
                }
            }
        }
        .background(Color(NSColor.windowBackgroundColor))
        .frame(minWidth: 1180, minHeight: 740)
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
