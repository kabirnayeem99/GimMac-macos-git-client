import SwiftUI
import Observation

struct CommitBox: View {
    @Bindable var viewModel: RepositoryStoreViewModel
    @State private var isShowingProfile = false

    private var commitButtonLabel: String {
        if viewModel.isCommitting { return "Committing\u{2026}" }
        if viewModel.isAmendMode { return "Amend commit" }
        return "Commit changes"
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Commit")
                .font(.system(size: 11, weight: .semibold))
                .foregroundStyle(.secondary)

            HStack(alignment: .center, spacing: 10) {
                Circle()
                    .fill(.quaternary)
                    .frame(width: 28, height: 28)
                    .overlay {
                        Text(viewModel.currentGitUser.initials)
                            .font(.system(size: 9, weight: .bold))
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

                TextField("Summary (required)", text: $viewModel.commitSummary)
                    .textFieldStyle(.roundedBorder)
                    .controlSize(.small)
                    .overlay(alignment: .trailing) {
                        Text("\(viewModel.summaryCharacterCount)")
                            .font(.system(size: 10))
                            .foregroundStyle(viewModel.summaryExceedsRecommendedLength ? Color.red : Color.secondary)
                            .padding(.trailing, 6)
                    }
            }

            TextField("Description", text: $viewModel.commitDescription, axis: .vertical)
                .textFieldStyle(.roundedBorder)
                .font(.system(size: 12))
                .lineLimit(4...8)
                .frame(maxWidth: .infinity)

            if viewModel.hasCheckedConflicts {
                Label("Resolve all conflicts before committing.", systemImage: "exclamationmark.triangle.fill")
                    .font(.system(size: 11))
                    .foregroundStyle(.orange)
            }

            if let warning = viewModel.commitWarning {
                Label(warning.message, systemImage: "exclamationmark.triangle")
                    .font(.system(size: 11))
                    .foregroundStyle(.yellow)
            }

            HStack(spacing: 6) {
                Button {
                    Task {
                        await viewModel.commitChanges()
                    }
                } label: {
                    Text(commitButtonLabel)
                        .font(.system(size: 13, weight: .semibold))
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.borderedProminent)
                .controlSize(.regular)
                .disabled(!viewModel.canCommitChanges)

                Button {
                    viewModel.toggleAmendMode()
                } label: {
                    Image(systemName: viewModel.isAmendMode ? "arrow.uturn.backward.circle.fill" : "arrow.uturn.backward.circle")
                }
                .buttonStyle(.bordered)
                .controlSize(.regular)
                .help(viewModel.isAmendMode ? "Cancel amend" : "Amend last commit")
                .disabled(viewModel.isCommitting || viewModel.commits.isEmpty)

                Menu {
                    Toggle("Skip pre-commit hooks", isOn: $viewModel.skipHooks)
                    Toggle("Sign off", isOn: $viewModel.signOff)
                } label: {
                    Image(systemName: "ellipsis.circle")
                }
                .menuStyle(.borderlessButton)
                .menuIndicator(.hidden)
                .fixedSize()
                .help("Commit options")
            }

            VStack(alignment: .leading, spacing: 4) {
                HStack {
                    Text(viewModel.lastCommitSectionTitle)
                        .foregroundStyle(.secondary)

                    Spacer()

                    Button("Undo") {
                        Task { await viewModel.undoCommit() }
                    }
                    .buttonStyle(.borderless)
                    .controlSize(.small)
                    .disabled(viewModel.isSyncing || viewModel.isCommitting || viewModel.commits.isEmpty)
                }

                Text(viewModel.lastCommitSummary)
                    .font(.system(size: 12, weight: .semibold))
                    .lineLimit(1)
            }
            .font(.system(size: 11))
        }
        .padding(12)
        .background(.bar)
        .overlay(alignment: .top) {
            Divider()
        }
    }
}
