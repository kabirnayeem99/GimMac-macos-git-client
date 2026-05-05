import SwiftUI

struct HistoryRepositoryScreen: View {
    @Binding var selectedTab: Int

    var body: some View {
        HSplitView {
            CommitHistorySidebar(selectedTab: $selectedTab)
                .frame(minWidth: 280, idealWidth: 300, maxWidth: 360)

            ChangedFilesColumn()
                .frame(minWidth: 260, idealWidth: 300, maxWidth: 360)

            DiffViewer()
                .frame(minWidth: 520, maxWidth: .infinity, maxHeight: .infinity)
        }
    }
}
