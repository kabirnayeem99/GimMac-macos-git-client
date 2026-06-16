import SwiftUI
import Observation

struct CommitBox: View {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Bindable var viewModel: RepositoryStoreViewModel
    @State private var isShowingProfile = false
    @State private var showCoAuthorField = false
    @State private var coAuthorDraft = ""
    @State private var coAuthorError: String?
    @State private var invalidSubmissionTrigger = 0

    private var commitButtonLabel: String {
        if viewModel.isAmendMode { return "Amend commit" }
        return "Commit changes"
    }

    private var commitButtonAccessibilityValue: String {
        if viewModel.commitOutcome == .success { return "Commit created successfully" }
        if viewModel.isCommitting { return "Committing" }
        if !viewModel.canCommitChanges { return commitDisabledReason }
        return "Ready"
    }

    private var isCommitButtonDisabled: Bool {
        !viewModel.canCommitChanges || viewModel.commitOutcome == .success
    }

    private var commitDisabledReason: String {
        if viewModel.commitOutcome == .success { return "Commit created successfully." }
        if viewModel.isCommitting { return "Commit in progress." }
        if viewModel.selectedRepository == nil { return "Select a repository before committing." }
        if viewModel.hasUnresolvedConflicts { return "Resolve conflicts before committing." }
        if viewModel.commitSummary.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            return "Enter a commit summary."
        }
        if !viewModel.isAmendMode && viewModel.checkedChangedFilePaths.isEmpty {
            return "Select at least one changed file to commit."
        }
        return "Commit is not currently available."
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("Commit")
                .font(.caption.weight(.semibold))
                .foregroundStyle(.secondary)

            HStack(alignment: .center, spacing: 6) {
                Button {
                    isShowingProfile.toggle()
                } label: {
                    Circle()
                        .fill(.quaternary)
                        .frame(width: 28, height: 28)
                        .overlay {
                            Text(viewModel.currentGitUser.initials)
                                .font(.caption2.weight(.bold))
                                .foregroundStyle(.secondary)
                        }
                }
                .buttonStyle(.plain)
                .accessibilityLabel("Author: \(viewModel.currentGitUser.name), \(viewModel.currentGitUser.email)")
                .popover(isPresented: $isShowingProfile, arrowEdge: .top) {
                    VStack(alignment: .leading, spacing: 4) {
                        Text(viewModel.currentGitUser.name)
                            .font(.callout.weight(.semibold))
                        Text(viewModel.currentGitUser.email)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                    .padding(10)
                }

                TextField("Summary (required)", text: $viewModel.commitSummary)
                    .textFieldStyle(.roundedBorder)
                    .accessibilityLabel("Commit summary")
            }

            TextField("Description", text: $viewModel.commitDescription, axis: .vertical)
                .textFieldStyle(.roundedBorder)
                .font(.callout)
                .lineLimit(4...8)
                .frame(maxWidth: .infinity)
                .accessibilityLabel("Commit description")

            coAuthorSection

            CommitInlineStatusSection(viewModel: viewModel, reduceMotion: reduceMotion)

            HStack(spacing: 6) {
                Button {
                    submitCommit()
                } label: {
                    ZStack {
                        Text(commitButtonLabel)
                            .opacity(viewModel.isCommitting || viewModel.commitOutcome == .success ? 0 : 1)

                        ProgressView()
                            .controlSize(.small)
                            .opacity(viewModel.isCommitting && viewModel.commitOutcome != .success ? 1 : 0)

                        Image(systemName: "checkmark")
                            .symbolReplacement(reduceMotion: reduceMotion)
                            .opacity(viewModel.commitOutcome == .success ? 1 : 0)
                    }
                    .font(.body.weight(.semibold))
                    .frame(maxWidth: .infinity, minHeight: 20)
                    .motion(Motion.feedback, reduceMotion: reduceMotion, value: viewModel.commitOutcome)
                }
                .buttonStyle(.borderedProminent)
                .controlSize(.regular)
                .keyboardShortcut(.return, modifiers: .command)
                .disabled(isCommitButtonDisabled)
                .help(isCommitButtonDisabled ? commitDisabledReason : "Create a commit")
                .accessibilityLabel(commitButtonLabel)
                .accessibilityValue(commitButtonAccessibilityValue)

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
                .accessibilityLabel("Commit options")
            }

            if viewModel.canUndoLastCommit {
                VStack(alignment: .leading, spacing: 4) {
                    Text(viewModel.lastCommitSectionTitle)
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                    HStack {
                        Text(viewModel.lastCommitSummary)
                            .foregroundStyle(.secondary)
                            .font(.body)
                        
                        Spacer()

                        Button {
                            Task { await viewModel.undoCommit() }
                        } label: {
                            Image(systemName: "arrow.uturn.backward")
                        }
                        .buttonStyle(.bordered)
                        .controlSize(.small)
                        .disabled(viewModel.isSyncing || viewModel.isCommitting || viewModel.commits.isEmpty)
                        .help("Undo last commit")
                        .accessibilityLabel("Undo last commit")
                    }
                }
                .font(.caption)
            }
        }
        .padding(12)
        .liquidGlassBackground(fallbackMaterial: .bar)
        .overlay(alignment: .top) {
            Divider()
        }
        .phaseAnimator([0.0, -6.0, 6.0, -3.0, 3.0, 0.0], trigger: invalidSubmissionTrigger) { content, offset in
            content
                .offset(x: reduceMotion ? 0 : offset)
                .overlay {
                    RoundedRectangle(cornerRadius: 10)
                        .stroke(Color(.systemRed), lineWidth: 2)
                        .opacity(reduceMotion && offset != 0 ? 1 : 0)
                        .allowsHitTesting(false)
                }
        } animation: { _ in
            reduceMotion ? .easeInOut(duration: 0.12) : .easeInOut(duration: 0.06)
        }
    }

    // MARK: - Co-authors

    private var coAuthorSection: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(spacing: 6) {
                Button {
                    withAnimation(Motion.resolve(Motion.feedback, reduceMotion: reduceMotion)) {
                        showCoAuthorField.toggle()
                    }
                    if !showCoAuthorField { coAuthorError = nil }
                } label: {
                    Label("Add co-authors", systemImage: "person.badge.plus")
                        .font(.caption)
                }
                .buttonStyle(.borderless)
                .controlSize(.small)
                .help("Attribute this commit to additional authors")

                Spacer()
            }

            ForEach(viewModel.commitCoAuthors) { author in
                HStack(spacing: 4) {
                    Image(systemName: "person.crop.circle")
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                    Text(author.display)
                        .font(.caption)
                        .lineLimit(1)
                        .truncationMode(.middle)
                    Spacer(minLength: 4)
                    Button {
                        viewModel.removeCoAuthor(author)
                    } label: {
                        Image(systemName: "xmark.circle.fill")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                            .frame(width: 24, height: 24)
                            .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)
                    .help("Remove co-author")
                    .accessibilityLabel("Remove co-author \(author.display)")
                }
                .padding(.horizontal, 8)
                .padding(.vertical, 3)
                .background(.quaternary, in: Capsule())
            }

            if showCoAuthorField {
                VStack(alignment: .leading, spacing: 4) {
                    TextField("Name <email>", text: $coAuthorDraft)
                        .textFieldStyle(.roundedBorder)
                        .controlSize(.small)
                        .onSubmit(submitCoAuthor)

                    if let coAuthorError {
                        Text(coAuthorError)
                            .font(.caption2)
                            .foregroundStyle(Color(.systemRed))
                            .transition(Motion.inlineStatus(reduceMotion: reduceMotion))
                            .accessibilityLabel("Co-author error: \(coAuthorError)")
                    }
                }
                .transition(Motion.inlineStatus(reduceMotion: reduceMotion))
                .motion(Motion.feedback, reduceMotion: reduceMotion, value: coAuthorError)
            }
        }
    }

    private func submitCommit() {
        if !viewModel.canCommitChanges {
            invalidSubmissionTrigger += 1
        }
        Task {
            await viewModel.commitChanges()
        }
    }

    private func submitCoAuthor() {
        let token = coAuthorDraft.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !token.isEmpty else { return }
        if viewModel.addCoAuthor(from: token) {
            coAuthorDraft = ""
            coAuthorError = nil
        } else {
            coAuthorError = "Use the format: Name <email>"
        }
    }
}
