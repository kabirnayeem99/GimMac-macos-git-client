import SwiftUI

/// Repository picker control hosted by the unified window toolbar's `repository`
/// item. Extracted verbatim from the former `TopToolbar` so the toolbar item can
/// host the same SwiftUI menu without a duplicate implementation.
struct RepositoryMenuButton: View {
    let viewModel: RepositoryStoreViewModel
    let openRepositoryAction: () -> Void
    let selectRepositoryAction: (UUID) -> Void
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    private var repositoryDisplayName: String {
        viewModel.selectedRepository?.displayName ?? "No Repository"
    }

    /// Path of the repository currently open, used to flag the matching row in
    /// the list. `selectedRepository` is a `Repository` (a URL); saved rows are
    /// `StoredRepository` (a path string) — match on the resolved file path.
    private var selectedPath: String? {
        viewModel.selectedRepository?.url.standardizedFileURL.path
    }

    /// Collapse the user's home prefix to `~` so the full path stays legible in
    /// the row's hover tooltip.
    private func abbreviatedPath(_ path: String) -> String {
        (path as NSString).abbreviatingWithTildeInPath
    }

    /// Single-line row title; flags a repo that has gone missing on disk.
    private func rowTitle(_ repository: StoredRepository) -> String {
        repository.existsOnDisk ? repository.name : "\(repository.name) (Missing)"
    }

    var body: some View {
        Menu {
            if viewModel.savedRepositories.isEmpty {
                Text("No Saved Repositories")
            } else {
                Section("Recent") {
                    ForEach(viewModel.savedRepositories) { repository in
                        let isCurrent = repository.url.standardizedFileURL.path == selectedPath
                        Button {
                            selectRepositoryAction(repository.id)
                        } label: {
                            // Native single-line row. The leading checkmark lives in
                            // the menu's standard selection gutter; missing repos are
                            // tagged inline and disabled.
                            if isCurrent {
                                Label(rowTitle(repository), systemImage: "checkmark")
                            } else {
                                Text(rowTitle(repository))
                            }
                        }
                        .disabled(!repository.existsOnDisk)
                        .help(abbreviatedPath(repository.path))
                    }
                }
            }

            Divider()

            Button("Open Repository…") {
                openRepositoryAction()
            }
        } label: {
            // Leading title-style pulldown: the current repository name reads as
            // the window's subject (like Finder's folder title) and doubles as
            // the picker. Borderless, with a small disclosure chevron.
            HStack(spacing: 5) {
                Image(systemName: "folder")
                    .font(.system(size: 13, weight: .regular))
                    .foregroundStyle(.secondary)

                Text(repositoryDisplayName)
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(.primary)
                    .lineLimit(1)
                    .id(repositoryDisplayName)
                    .transition(.opacity)

                Image(systemName: "chevron.down")
                    .font(.system(size: 9, weight: .semibold))
                    .foregroundStyle(.secondary)
            }
            .frame(height: 28)
            .padding(.horizontal, 12)
            .toolbarItemStyle()
            .motion(Motion.feedback, reduceMotion: reduceMotion, value: repositoryDisplayName)
            .help(viewModel.selectedRepository?.url.path ?? "No repository selected")
        }
        .buttonStyle(.plain)
        .menuIndicator(.hidden) // Manual chevron is better placed
        .fixedSize()
    }
}
