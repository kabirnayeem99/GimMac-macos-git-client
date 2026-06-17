import SwiftUI

struct CommitDetailsHeader: View {
    let viewModel: RepositoryStoreViewModel
    @State private var isShowingProfile = false
    @State private var copiedCommitHash = false
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        let selectedCount = viewModel.selectedHistoryCommits.count
        Group {
            if selectedCount > 1 {
                multiSelectionHeader(count: selectedCount)
            } else {
                singleCommitHeader
            }
        }
        .id(selectedCount > 1 ? "multi" : "single")
        .transition(.opacity)
        .animation(Motion.resolve(Motion.snappy, reduceMotion: reduceMotion), value: selectedCount > 1)
    }

    private var singleCommitHeader: some View {
        VStack(alignment: .leading, spacing: 7) {
            HStack(alignment: .top) {
                Text(viewModel.selectedCommit?.summary ?? "No selected commit")
                    .font(.system(size: 14, weight: .semibold))
                    .lineLimit(2)

                Spacer()
            }

            HStack(spacing: 7) {
                Button {
                    isShowingProfile.toggle()
                } label: {
                    AuthorAvatar(name: viewModel.currentGitUser.name, size: 22, fontSize: 8)
                }
                .buttonStyle(.plain)
                .accessibilityLabel("Author: \(viewModel.currentGitUser.name), \(viewModel.currentGitUser.email)")
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

                if let commit = viewModel.selectedCommit {
                    Button {
                        viewModel.copyCommitHash(commit.id)
                        copiedCommitHash = true
                        Task {
                            try? await Task.sleep(for: .seconds(1))
                            copiedCommitHash = false
                        }
                    } label: {
                        Image(systemName: copiedCommitHash ? "checkmark" : "doc.on.doc")
                            .font(.system(size: 10))
                            .foregroundStyle(copiedCommitHash ? .green : .primary)
                            .contentTransition(.symbolEffect(.replace))
                    }
                    .buttonStyle(.borderless)
                    .help(copiedCommitHash ? "Copied" : "Copy commit hash")
                    .accessibilityLabel(copiedCommitHash ? "Copied commit hash" : "Copy commit hash")
                }
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
                    .contentTransition(.numericText())
                    .motion(Motion.feedback, reduceMotion: reduceMotion, value: count)
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
