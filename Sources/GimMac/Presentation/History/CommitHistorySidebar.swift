import AppKit
import SwiftUI

struct CommitHistorySidebar: View {
    @Binding var selectedTab: Int
    let viewModel: RepositoryStoreViewModel

    @State private var activeSheet: HistorySheet?

    private enum HistorySheet: Int, Identifiable {
        case squash, createTag, createBranch, reset, reorder
        var id: Int { rawValue }
    }

    var body: some View {
        VStack(spacing: 0) {
            Picker("", selection: $selectedTab) {
                Text("Changes").tag(0)
                Text("History").tag(1)
            }
            .pickerStyle(.segmented)
            .controlSize(.small)
            .padding(10)

            Button {
            } label: {
                HStack(spacing: 7) {
                    Image(systemName: "point.3.connected.trianglepath.dotted")
                        .font(.system(size: 12))

                    Text(viewModel.primaryAction.label)
                        .font(.system(size: 12))

                    Spacer()

                    Image(systemName: "chevron.down")
                        .font(.system(size: 8, weight: .semibold))
                }
                .foregroundStyle(.secondary)
                .padding(.horizontal, 10)
                .frame(height: 32)
                .background(.quaternary)
                .clipShape(RoundedRectangle(cornerRadius: 7, style: .continuous))
            }
            .buttonStyle(.plain)
            .padding(.horizontal, 10)
            .padding(.bottom, 8)

            List(viewModel.commits.indices, id: \.self) { index in
                let commit = viewModel.commits[index]
                let isSelected = viewModel.selectedHistoryCommitIndices.contains(index)
                CommitRow(
                    title: commit.summary,
                    subtitle: "\(commit.authorDisplayName) • \(relativeString(for: commit.date))",
                    selected: isSelected,
                    isUnpushed: viewModel.unpushedSHAs.contains(commit.id)
                )
                .onTapGesture {
                    let shiftHeld = NSEvent.modifierFlags.contains(.shift)
                    viewModel.selectHistoryCommit(at: index, isShiftExtending: shiftHeld)
                }
                .contextMenu {
                    multiSelectContextMenu(for: index)
                }
                .listRowInsets(EdgeInsets())
                .listRowSeparator(.hidden)
                .listRowBackground(Color.clear)
            }
            .listStyle(.sidebar)
            .scrollContentBackground(.hidden)
        }
        .background(.thinMaterial)
        .sheet(item: $activeSheet) { sheet in
            switch sheet {
            case .squash:
                SquashCommitsSheet(
                    commits: viewModel.selectedHistoryCommits,
                    onConfirm: { message in
                        await viewModel.squashSelectedCommits(message: message)
                        activeSheet = nil
                    },
                    onCancel: { activeSheet = nil }
                )
            case .createTag:
                if let commit = viewModel.selectedCommit {
                    CreateTagSheet(
                        commit: commit,
                        onConfirm: { name, message in
                            await viewModel.createTagOnSelectedCommit(named: name, message: message)
                            activeSheet = nil
                        },
                        onCancel: { activeSheet = nil }
                    )
                }
            case .createBranch:
                if let commit = viewModel.selectedCommit {
                    CreateBranchFromCommitSheet(
                        commit: commit,
                        onConfirm: { name in
                            await viewModel.createBranchFromSelectedCommit(named: name)
                            activeSheet = nil
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
                            activeSheet = nil
                        },
                        onCancel: { activeSheet = nil }
                    )
                }
            case .reorder:
                ReorderCommitsSheet(
                    commits: viewModel.selectedHistoryCommits,
                    onConfirm: { ordered in
                        await viewModel.reorderCommits(ordered)
                        activeSheet = nil
                    },
                    onCancel: { activeSheet = nil }
                )
            }
        }
    }

    @ViewBuilder
    private func multiSelectContextMenu(for tappedIndex: Int) -> some View {
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

    private func relativeString(for date: Date) -> String {
        RelativeDateTimeFormatter().localizedString(for: date, relativeTo: Date())
    }
}
