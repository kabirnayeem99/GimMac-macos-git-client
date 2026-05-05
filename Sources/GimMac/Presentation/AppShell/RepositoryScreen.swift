import SwiftUI

struct RepositoryScreen: View {
    let viewModel: RepositoryStoreViewModel
    let openRepositoryAction: () -> Void
    @State private var selectedTab = 0

    var body: some View {
        VStack(spacing: 0) {
            TopToolbar(
                viewModel: viewModel,
                openRepositoryAction: openRepositoryAction
            )

            if selectedTab == 0 {
                HStack(spacing: 0) {
                    Sidebar(selectedTab: $selectedTab)
                        .frame(width: 320)

                    Divider()

                    MainContent()
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                }
            } else {
                HistoryRepositoryScreen(selectedTab: $selectedTab)
            }
        }
        .background(Color(NSColor.windowBackgroundColor))
        .frame(minWidth: 1180, minHeight: 740)
    }
}
