import SwiftUI

struct ChangedFilesColumn: View {
    private let files = [
        ("Sources/Gi.../MainMenuFactory.swift", true),
        ("Sour.../MainSplitViewController.swift", false)
    ]

    var body: some View {
        VStack(spacing: 0) {
            CommitDetailsHeader()

            Divider()

            HStack {
                Text("Changed Files")
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundStyle(.secondary)

                Spacer()

                Text("2")
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundStyle(.secondary)
            }
            .padding(.horizontal, 12)
            .frame(height: 32)
            .background(.bar)

            List(files.indices, id: \.self) { index in
                ChangedFileRow(title: files[index].0, selected: files[index].1)
                    .listRowInsets(EdgeInsets())
                    .listRowSeparator(.hidden)
                    .listRowBackground(Color.clear)
            }
            .listStyle(.plain)
            .scrollContentBackground(.hidden)
        }
        .background(Color(nsColor: .controlBackgroundColor))
    }
}
