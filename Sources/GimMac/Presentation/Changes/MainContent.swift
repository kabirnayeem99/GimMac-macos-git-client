import AppKit
import SwiftUI

struct MainContent: View {
    let viewModel: RepositoryStoreViewModel

    private struct RemoteSuggestion {
        let title: String
        let subtitle: String
        let button: String
        let action: () -> Void
    }

    private func runPrimaryAction() {
        Task { await viewModel.performPrimaryAction() }
    }

    private var remoteAction: RemoteSuggestion? {
        switch viewModel.primaryAction {
        case .push(let remote, let n):
            return RemoteSuggestion(
                title: String(AttributedString(localized: "Push ^[\(n) commit](inflect: true) to \(remote)").characters),
                subtitle: String(AttributedString(localized: "You have ^[\(n) local commit](inflect: true) waiting to be pushed.").characters),
                button: "Push \(remote)",
                action: runPrimaryAction
            )
        case .pull(let remote, let n):
            return RemoteSuggestion(
                title: String(AttributedString(localized: "Pull ^[\(n) commit](inflect: true) from \(remote)").characters),
                subtitle: "The remote has changes not yet on your machine.",
                button: "Pull \(remote)",
                action: runPrimaryAction
            )
        case .forcePush(let remote, let n):
            return RemoteSuggestion(
                title: String(AttributedString(localized: "Force push ^[\(n) commit](inflect: true) to \(remote)").characters),
                subtitle: "Your branch has diverged from \(remote).",
                button: "Force push \(remote)",
                action: runPrimaryAction
            )
        case .sync(let remote, let ahead, let behind):
            return RemoteSuggestion(
                title: "Sync with \(remote)",
                subtitle: "Ahead by \(ahead), behind by \(behind).",
                button: "Sync \(remote)",
                action: runPrimaryAction
            )
        case .fetch(let remote):
            return RemoteSuggestion(
                title: "Fetch from \(remote)",
                subtitle: "Check \(remote) for new commits.",
                button: "Fetch \(remote)",
                action: runPrimaryAction
            )
        case .publishRepository:
            return RemoteSuggestion(
                title: "Publish this repository",
                subtitle: "This repository only exists locally. Publish it to a remote to share your work.",
                button: "Publish repository",
                action: runPrimaryAction
            )
        case .publishBranch(let remote):
            return RemoteSuggestion(
                title: "Publish branch to \(remote)",
                subtitle: "This branch has no upstream yet.",
                button: "Publish branch",
                action: runPrimaryAction
            )
        case .commit, .merge, .rebase, .cherryPick:
            return nil
        }
    }

    private var stashHighlight: RemoteSuggestion? {
        guard viewModel.stashEntry != nil, viewModel.changedFilesCount == 0 else { return nil }
        return RemoteSuggestion(
            title: "View stashed changes",
            subtitle: "You have work-in-progress changes saved in a stash.",
            button: "View stash",
            action: {
                NSApp.sendAction(
                    Selector(("menuManageStashes:")),
                    to: nil,
                    from: nil
                )
            }
        )
    }

    private var headerTitle: String {
        if viewModel.stashEntry != nil && viewModel.changedFilesCount == 0 {
            return "Stashed changes available"
        }
        return "No local changes"
    }

    private var headerSubtitle: String {
        if viewModel.stashEntry != nil && viewModel.changedFilesCount == 0 {
            return "You have work-in-progress saved in a stash. Restore it or continue with another action."
        }
        return "There are no uncommitted changes in this repository. Choose an action below to continue."
    }

    private var headerIcon: String {
        if viewModel.stashEntry != nil && viewModel.changedFilesCount == 0 {
            return "tray.full"
        }
        return "tray"
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                HeaderSection(
                    title: headerTitle,
                    subtitle: headerSubtitle,
                    icon: headerIcon
                )

                VStack(spacing: 0) {
                    if let stash = stashHighlight {
                        SuggestionCard(
                            title: stash.title,
                            subtitle: stash.subtitle,
                            hint: "Available from the toolbar.",
                            button: stash.button,
                            highlighted: true,
                            action: stash.action
                        )
                    }

                    if let remote = remoteAction {
                        SuggestionCard(
                            title: remote.title,
                            subtitle: remote.subtitle,
                            hint: "Available from the toolbar.",
                            button: remote.button,
                            highlighted: true,
                            action: remote.action
                        )
                    }

                    SuggestionCard(
                        title: "Open the repository in your editor",
                        subtitle: "Select your preferred editor in Settings.",
                        hint: "Repository menu or \u{2318}\u{21E7}A.",
                        button: "Open in \(viewModel.selectedEditorName ?? "Editor")",
                        action: { viewModel.openInExternalEditor(path: "") }
                    )

                    SuggestionCard(
                        title: "View repository files in Finder",
                        subtitle: nil,
                        hint: "Repository menu or \u{2318}\u{21E7}F.",
                        button: "Show in Finder",
                        action: { viewModel.openWithDefaultProgram(path: "") }
                    )
                }
                .liquidGlassBackground(
                    fallbackMaterial: .regular,
                    in: RoundedRectangle(cornerRadius: 12, style: .continuous)
                )
                .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                .overlay {
                    RoundedRectangle(cornerRadius: 12, style: .continuous)
                        .stroke(Color(NSColor.separatorColor), lineWidth: 1)
                }

                Spacer(minLength: 24)
            }
            .padding(.horizontal, 64)
            .padding(.top, 44)
            .padding(.bottom, 32)
            .frame(maxWidth: 860, alignment: .leading)
            .frame(maxWidth: .infinity)
        }
        .background(Color(NSColor.windowBackgroundColor))
    }
}
