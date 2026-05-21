import SwiftUI

struct MainContent: View {
    let viewModel: RepositoryStoreViewModel

    private struct RemoteSuggestion {
        let title: String
        let subtitle: String
        let button: String
    }

    private var remoteAction: RemoteSuggestion? {
        switch viewModel.primaryAction {
        case .push(let remote, let n):
            return RemoteSuggestion(
                title: "Push \(n) commit\(n == 1 ? "" : "s") to \(remote)",
                subtitle: "You have \(n) local commit\(n == 1 ? "" : "s") waiting to be pushed.",
                button: "Push \(remote)"
            )
        case .pull(let remote, let n):
            return RemoteSuggestion(
                title: "Pull \(n) commit\(n == 1 ? "" : "s") from \(remote)",
                subtitle: "The remote has changes not yet on your machine.",
                button: "Pull \(remote)"
            )
        case .forcePush(let remote, let n):
            return RemoteSuggestion(
                title: "Force push \(n) commit\(n == 1 ? "" : "s") to \(remote)",
                subtitle: "Your branch has diverged from \(remote).",
                button: "Force push \(remote)"
            )
        case .sync(let remote, let ahead, let behind):
            return RemoteSuggestion(
                title: "Sync with \(remote)",
                subtitle: "Ahead by \(ahead), behind by \(behind).",
                button: "Sync \(remote)"
            )
        case .fetch(let remote):
            return RemoteSuggestion(
                title: "Fetch from \(remote)",
                subtitle: "Check \(remote) for new commits.",
                button: "Fetch \(remote)"
            )
        case .publishRepository:
            return RemoteSuggestion(
                title: "Publish this repository",
                subtitle: "This repository only exists locally. Publish it to a remote to share your work.",
                button: "Publish repository"
            )
        case .publishBranch(let remote):
            return RemoteSuggestion(
                title: "Publish branch to \(remote)",
                subtitle: "This branch has no upstream yet.",
                button: "Publish branch"
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
            button: "View stash"
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
                    if let suggestion = stashHighlight ?? remoteAction {
                        SuggestionCard(
                            title: suggestion.title,
                            subtitle: suggestion.subtitle,
                            hint: "Available from the toolbar.",
                            button: suggestion.button,
                            highlighted: true
                        )
                    }

                    SuggestionCard(
                        title: "Open the repository in your editor",
                        subtitle: "Select your preferred editor in Settings.",
                        hint: "Repository menu or \u{2318}\u{21E7}A.",
                        button: "Open in VS Code"
                    )

                    SuggestionCard(
                        title: "View repository files in Finder",
                        subtitle: nil,
                        hint: "Repository menu or \u{2318}\u{21E7}F.",
                        button: "Show in Finder"
                    )

                    SuggestionCard(
                        title: "Open the repository page in your browser",
                        subtitle: nil,
                        hint: "Repository menu or \u{2318}\u{21E7}G.",
                        button: "View Remote"
                    )
                }
                .background(.regularMaterial)
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
        .background(Color(NSColor.textBackgroundColor))
    }
}
