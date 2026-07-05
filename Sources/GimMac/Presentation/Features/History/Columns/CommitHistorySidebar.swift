import AppKit
import SwiftUI

struct CommitHistorySidebar: View {
    let viewModel: RepositoryStoreViewModel

    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    @State private var activeSheet: HistorySheet?

    private enum HistorySheet: Int, Identifiable {
        case squash, createTag, createBranch, reset, reorder
        var id: Int { rawValue }
    }

    // Bridges the ViewModel's SHA-keyed selection to List(selection:). SwiftUI
    // owns shift/Cmd-click; writes route through the ViewModel to load files.
    private var historySelection: Binding<Set<Commit.ID>> {
        Binding(
            get: { viewModel.selectedHistoryCommitIDs },
            set: { viewModel.updateHistorySelection($0) }
        )
    }

    var body: some View {
        VStack(spacing: 0) {
            Button {
                Task { await viewModel.performPrimaryAction() }
            } label: {
                HStack(spacing: 7) {
                    Image(systemName: "point.3.connected.trianglepath.dotted")
                        .font(.system(size: 12))
                        .accessibilityHidden(true)

                    Text(viewModel.primaryAction.label)
                        .font(.system(size: 12))

                    Spacer()
                }
                .foregroundStyle(.secondary)
                .padding(.horizontal, 10)
                .frame(height: 32)
                .background(.quaternary)
                .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
//                .clipShape(RoundedRectangle(cornerRadius: 7, style: .continuous))
            }
            .buttonStyle(.plain)
            .padding(.horizontal, 10)
            .padding(.top, 10)
            .padding(.bottom, 8)
            .accessibilityLabel(viewModel.primaryAction.label)
            .overlay(alignment: .trailing) {
                if viewModel.historyOutcome == .success {
                    Image(systemName: "checkmark.circle.fill")
                        .foregroundStyle(.green)
                        .transition(.scale.combined(with: .opacity))
                }
            }
            .animation(Motion.resolve(.snappy, reduceMotion: reduceMotion), value: viewModel.historyOutcome)

            List(selection: historySelection) {
              ForEach(viewModel.commits) { commit in
                CommitRow(
                    authorName: commit.authorName,
                    title: commit.summary,
                    subtitle: "\(commit.authorDisplayName) • \(relativeString(for: commit.date))",
                    isUnpushed: viewModel.unpushedSHAs.contains(commit.id),
                    isSelected: viewModel.selectedHistoryCommitIDs.contains(commit.id)
                )
                .contextMenu {
                    multiSelectContextMenu()
                }
                .listRowInsets(EdgeInsets())
                .listRowSeparator(.hidden)
                .onAppear {
                    if commit.id == viewModel.commits.last?.id {
                        Task { await viewModel.loadMoreHistory() }
                    }
                }
              }
            }
            .listStyle(.sidebar)
            .scrollContentBackground(.automatic)
        }
        .sheet(item: $activeSheet) { sheet in
            switch sheet {
            case .squash:
                SquashCommitsSheet(
                    commits: viewModel.selectedHistoryCommits,
                    onConfirm: { message in
                        await viewModel.squashSelectedCommits(message: message)
                    },
                    onCancel: { activeSheet = nil }
                )
            case .createTag:
                if let commit = viewModel.selectedCommit {
                    CreateTagSheet(
                        commit: commit,
                        onConfirm: { name, message in
                            let didSucceed = await viewModel.createTagOnSelectedCommit(named: name, message: message)
                            if didSucceed {
                                viewModel.signalHistoryOutcome(.success)
                            }
                            return didSucceed
                        },
                        onCancel: { activeSheet = nil }
                    )
                }
            case .createBranch:
                if let commit = viewModel.selectedCommit {
                    CreateBranchFromCommitSheet(
                        commit: commit,
                        onConfirm: { name in
                            let didSucceed = await viewModel.createBranchFromSelectedCommit(named: name)
                            if didSucceed {
                                viewModel.signalHistoryOutcome(.success)
                            }
                            return didSucceed
                        },
                        onCancel: { activeSheet = nil }
                    )
                }
            case .reset:
                if let commit = viewModel.selectedCommit {
                    ResetToCommitSheet(
                        commit: commit,
                        onConfirm: { mode in
                            await viewModel.resetToSelectedCommit(mode: mode)
                        },
                        onCancel: { activeSheet = nil }
                    )
                }
            case .reorder:
                ReorderCommitsSheet(
                    commits: viewModel.selectedHistoryCommits,
                    onConfirm: { ordered in
                        await viewModel.reorderCommits(ordered)
                    },
                    onCancel: { activeSheet = nil }
                )
            }
        }
    }

    @ViewBuilder
    private func multiSelectContextMenu() -> some View {
        let selectedCommits = viewModel.selectedHistoryCommits
        let count = selectedCommits.count

        if count > 1 {
            Button("Cherry-pick \(count) Commits") {
                Task { await viewModel.cherryPickSelectedCommits() }
            }
            Button("Squash \(count) Commits…") {
                activeSheet = .squash
            }
            Button("Reorder \(count) Commits…") {
                activeSheet = .reorder
            }
        } else {
            Button("Cherry-pick Commit") {
                Task { await viewModel.cherryPickSelectedCommits() }
            }
            Button("Revert This Commit") {
                Task { await viewModel.revertSelectedCommit() }
            }
            Divider()
            Button("Create Branch from Commit…") {
                activeSheet = .createBranch
            }
            Button("Create Tag…") {
                activeSheet = .createTag
            }
            Button("Reset to Commit…") {
                activeSheet = .reset
            }
        }
    }

    private static let relativeFormatter = RelativeDateTimeFormatter()

    private func relativeString(for date: Date) -> String {
        Self.relativeFormatter.localizedString(for: date, relativeTo: Date())
    }
}
