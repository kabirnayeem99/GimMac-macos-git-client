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
        return "Ready"
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Commit")
                .font(.caption.weight(.semibold))
                .foregroundStyle(.secondary)

            HStack(alignment: .center, spacing: 10) {
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
                    .controlSize(.small)
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
                .disabled(viewModel.isCommitting || viewModel.commitOutcome == .success)
                .accessibilityLabel(commitButtonLabel)
                .accessibilityValue(commitButtonAccessibilityValue)

                Button {
                    viewModel.toggleAmendMode()
                } label: {
                    Image(systemName: viewModel.isAmendMode ? "arrow.uturn.backward.circle.fill" : "arrow.uturn.backward.circle")
                        .symbolReplacement(reduceMotion: reduceMotion)
                        .motion(Motion.feedback, reduceMotion: reduceMotion, value: viewModel.isAmendMode)
                }
                .buttonStyle(.bordered)
                .controlSize(.regular)
                .help(viewModel.isAmendMode ? "Cancel amend" : "Amend last commit")
                .disabled(viewModel.isCommitting || viewModel.commits.isEmpty)
                .accessibilityLabel("Amend previous commit")
                .accessibilityValue(viewModel.isAmendMode ? "On" : "Off")
                .accessibilityAddTraits(viewModel.isAmendMode ? .isSelected : [])
                .hidden()

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

            VStack(alignment: .leading, spacing: 4) {
                HStack {
                    Text(viewModel.lastCommitSectionTitle)
                        .foregroundStyle(.secondary)

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

private struct CommitInlineStatusSection: View {
    let viewModel: RepositoryStoreViewModel
    let reduceMotion: Bool

    private var state: InlineStatusState {
        InlineStatusState(
            hasUnresolvedConflicts: viewModel.hasUnresolvedConflicts,
            warning: viewModel.commitWarning?.message,
            error: viewModel.errorMessage,
            outcome: viewModel.commitOutcome
        )
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            if viewModel.hasUnresolvedConflicts {
                Label("Resolve all conflicts before committing.", systemImage: "exclamationmark.triangle.fill")
                    .foregroundStyle(Color(.systemOrange))
                    .transition(Motion.inlineStatus(reduceMotion: reduceMotion))
                    .accessibilityLabel("Commit blocked: Resolve all conflicts before committing.")
            }

            if let warning = viewModel.commitWarning {
                Label(warning.message, systemImage: "exclamationmark.triangle")
                    .foregroundStyle(Color(.systemOrange))
                    .transition(Motion.inlineStatus(reduceMotion: reduceMotion))
                    .accessibilityLabel("Commit warning: \(warning.message)")
            }

            if let error = viewModel.errorMessage {
                Label(error, systemImage: "xmark.circle.fill")
                    .foregroundStyle(Color(.systemRed))
                    .transition(Motion.inlineStatus(reduceMotion: reduceMotion))
                    .accessibilityLabel("Commit error: \(error)")
                    .accessibilityIdentifier("statusLabel")
            }

            if viewModel.commitOutcome == .success {
                Label("Commit created successfully.", systemImage: "checkmark.circle.fill")
                    .foregroundStyle(Color(.systemGreen))
                    .transition(Motion.inlineStatus(reduceMotion: reduceMotion))
                    .accessibilityLabel("Commit status: Commit created successfully.")
                    .accessibilityIdentifier("commitSuccessStatus")
            }
        }
        .font(.caption)
        .motion(Motion.feedback, reduceMotion: reduceMotion, value: state)
    }
}

private struct InlineStatusState: Equatable {
    let hasUnresolvedConflicts: Bool
    let warning: String?
    let error: String?
    let outcome: OpOutcome
}
