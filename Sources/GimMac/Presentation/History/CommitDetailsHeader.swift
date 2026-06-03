import SwiftUI

struct CommitDetailsHeader: View {
    let viewModel: RepositoryStoreViewModel
    @State private var isShowingProfile = false

    var body: some View {
        let selectedCount = viewModel.selectedHistoryCommits.count
        if selectedCount > 1 {
            multiSelectionHeader(count: selectedCount)
        } else {
            singleCommitHeader
        }
    }

    private var singleCommitHeader: some View {
        VStack(alignment: .leading, spacing: 7) {
            HStack(alignment: .top) {
                Text(viewModel.selectedCommit?.summary ?? "No selected commit")
                    .font(.system(size: 14, weight: .semibold))
                    .lineLimit(2)

                Spacer()

                Button {
                } label: {
                    Image(systemName: "arrow.up.and.down.and.arrow.left.and.right")
                }
                .buttonStyle(.borderless)
                .foregroundStyle(.secondary)
            }

            HStack(spacing: 7) {
                Circle()
                    .fill(.quaternary)
                    .frame(width: 22, height: 22)
                    .overlay {
                        Text(viewModel.currentGitUser.initials)
                            .font(.system(size: 8, weight: .bold))
                            .foregroundStyle(.secondary)
                    }
                    .onHover { isHovered in
                        isShowingProfile = isHovered
                    }
                    .popover(isPresented: $isShowingProfile, arrowEdge: .top) {
                        VStack(alignment: .leading, spacing: 4) {
                            Text(viewModel.currentGitUser.name)
                                .font(.system(size: 12, weight: .semibold))
                            Text(viewModel.currentGitUser.email)
                                .font(.system(size: 11))
                                .foregroundStyle(.secondary)
                        }
                        .padding(10)
                    }

                Text(viewModel.selectedCommit?.authorDisplayName ?? viewModel.currentGitUser.name)
                    .font(.system(size: 11, weight: .medium))

                Text(viewModel.selectedCommit?.shortHash ?? "-------")
                    .font(.system(size: 11, design: .monospaced))
                    .foregroundStyle(.secondary)

                Button {
                } label: {
                    Image(systemName: "doc.on.doc")
                        .font(.system(size: 10))
                }
                .buttonStyle(.borderless)
            }
        }
        .padding(12)
        .frame(height: 78)
        .background(Color(nsColor: .windowBackgroundColor))
    }

    private func multiSelectionHeader(count: Int) -> some View {
        HStack(spacing: 10) {
            ZStack {
                ForEach(0..<min(count, 3), id: \.self) { i in
                    Circle()
                        .fill(.quaternary)
                        .frame(width: 22, height: 22)
                        .offset(x: CGFloat(i) * 6)
                }
            }
            .frame(width: 22 + CGFloat(min(count, 3) - 1) * 6, alignment: .leading)

            VStack(alignment: .leading, spacing: 2) {
                Text("\(count) Commits Selected")
                    .font(.system(size: 13, weight: .semibold))
                Text("Right-click to cherry-pick, squash, or reorder")
                    .font(.system(size: 11))
                    .foregroundStyle(.secondary)
            }

            Spacer()
        }
        .padding(12)
        .frame(height: 78)
        .background(Color(nsColor: .windowBackgroundColor))
    }
}
