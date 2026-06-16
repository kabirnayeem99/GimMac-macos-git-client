import AppKit
import SwiftUI

/// Content pane of the Changes split. Switches between the diff viewer and the
/// summary/empty content based on `changedFilesCount`.
struct ChangesContentView: View {
    let viewModel: RepositoryStoreViewModel

    var body: some View {
        Group {
            if viewModel.changedFilesCount > 0 {
                DiffViewer(viewModel: viewModel)
            } else {
                MainContent(viewModel: viewModel)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color(NSColor.windowBackgroundColor))
    }
}
