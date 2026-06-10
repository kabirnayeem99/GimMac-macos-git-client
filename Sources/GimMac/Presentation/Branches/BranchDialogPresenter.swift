import AppKit

/// Single source of truth for presenting branch-related sheets (create, rename,
/// delete, compare, update-from-default, merge, squash-merge, rebase).
///
/// Both the branches popover (`BranchesViewController`) and the main menu bar
/// (`MainSplitViewController`) construct the same dialogs against the same
/// services — they must not duplicate that wiring.
///
/// All side effects flow back through the injected `BranchesViewModel` (for
/// branch CRUD) or the merge/rebase services + `RepositoryStoreViewModel`
/// (for merge/rebase, where they need to refresh the repo screen on success).
@MainActor
final class BranchDialogPresenter {

    private let viewModel: BranchesViewModel
    /// Required only for Merge / Squash / Rebase (refresh after success).
    private let repositoryStore: RepositoryStoreViewModel?
    private let mergeService: MergeBranchProviding?
    private let rebaseService: RebaseProviding?

    /// Where to present the sheets. Resolved lazily via the closure so the
    /// presenter does not capture an `NSWindow` that may not exist yet.
    private let windowProvider: () -> NSWindow?

    init(
        viewModel: BranchesViewModel,
        repositoryStore: RepositoryStoreViewModel? = nil,
        mergeService: MergeBranchProviding? = nil,
        rebaseService: RebaseProviding? = nil,
        windowProvider: @escaping () -> NSWindow?
    ) {
        self.viewModel = viewModel
        self.repositoryStore = repositoryStore
        self.mergeService = mergeService
        self.rebaseService = rebaseService
        self.windowProvider = windowProvider
    }

    // MARK: - Helpers

    private func present(_ controller: NSViewController) {
        guard let window = windowProvider(),
              let host = window.contentViewController else { return }
        host.presentAsSheet(controller)
    }

    private func currentLocalBranch() -> Branch? {
        guard let name = viewModel.currentBranchName else { return nil }
        return viewModel.localBranches.first { $0.name == name }
    }

    // MARK: - Branch CRUD sheets

    func presentCreateBranch() {
        let existing = (viewModel.localBranches + viewModel.remoteBranches).map(\.name)
        let controller = CreateBranchWindowController(
            existingNames: existing,
            availableBranches: viewModel.localBranches
        ) { [weak viewModel] name, startPoint, noTrack in
            guard let viewModel else { return }
            Task { await viewModel.createBranch(named: name, from: startPoint, noTrack: noTrack) }
        }
        present(controller.viewController)
    }

    func presentRenameBranch() {
        guard let branch = currentLocalBranch() else { return }
        presentRenameBranch(for: branch)
    }

    func presentRenameBranch(for branch: Branch) {
        guard branch.isLocal else { return }
        let existing = viewModel.localBranches.map(\.name)
        let controller = RenameBranchWindowController(
            branch: branch,
            existingNames: existing
        ) { [weak viewModel] newName, force in
            Task { await viewModel?.renameBranch(branch, to: newName, force: force) }
        }
        present(controller.viewController)
    }

    func presentDeleteBranch() {
        guard let branch = currentLocalBranch() else { return }
        presentDeleteBranch(for: branch)
    }

    func presentDeleteBranch(for branch: Branch) {
        let controller = DeleteBranchWindowController(branch: branch) { [weak viewModel] deleteRemote in
            guard let viewModel else { return }
            if branch.isLocal {
                Task { await viewModel.deleteLocalBranch(branch, force: true) }
                if deleteRemote, let upstream = branch.upstream {
                    let remote = upstream.split(separator: "/").first.map(String.init) ?? "origin"
                    Task { await viewModel.deleteRemoteBranch(branch, remote: remote) }
                }
            } else if let remote = branch.remoteName {
                Task { await viewModel.deleteRemoteBranch(branch, remote: remote) }
            }
        }
        present(controller.viewController)
    }

    /// Compare a specific branch against the current branch. Used by the
    /// branches popover context menu for a clicked row.
    func presentCompareToBranch(for compareBranch: Branch) {
        guard let compareProvider = viewModel.compareProvider,
              let repositoryURL = viewModel.repositoryURL else { return }
        let currentName = viewModel.currentBranchName ?? ""
        guard let baseBranch = viewModel.localBranches.first(where: { $0.name == currentName })
                ?? viewModel.remoteBranches.first(where: { $0.nameWithoutRemote == currentName })
        else { return }
        let controller = CompareBranchWindowController(
            baseBranch: baseBranch,
            compareBranch: compareBranch,
            compareProvider: compareProvider,
            repositoryURL: repositoryURL
        )
        present(controller.viewController)
    }

    func presentCompareToBranch() {
        guard let compareProvider = viewModel.compareProvider,
              let repositoryURL = viewModel.repositoryURL,
              let baseBranch = currentLocalBranch() else { return }

        presentBranchPicker(
            title: "Compare to Branch",
            actionTitle: "Compare",
            excludingCurrent: true
        ) { [weak self] selected in
            guard let self else { return }
            let controller = CompareBranchWindowController(
                baseBranch: baseBranch,
                compareBranch: selected,
                compareProvider: compareProvider,
                repositoryURL: repositoryURL
            )
            self.present(controller.viewController)
        }
    }

    func presentUpdateFromDefault() {
        guard let branch = currentLocalBranch() else { return }
        presentUpdateFromDefault(for: branch)
    }

    func presentUpdateFromDefault(for branch: Branch) {
        let controller = UpdateFromDefaultSheetController(branch: branch) { [weak viewModel] rebase in
            Task { await viewModel?.updateBranchFromDefault(branch, rebase: rebase) }
        }
        present(controller.viewController)
    }

    // MARK: - Merge / Rebase

    func presentMergeIntoCurrent() {
        guard let repositoryURL = viewModel.repositoryURL, mergeService != nil else { return }
        presentBranchPicker(
            title: "Merge into Current Branch",
            actionTitle: "Merge",
            excludingCurrent: true
        ) { [weak self] branch in
            guard let self else { return }
            Task { await self.runMerge(branch: branch, squash: false, repositoryURL: repositoryURL) }
        }
    }

    func presentSquashAndMerge() {
        guard let repositoryURL = viewModel.repositoryURL, mergeService != nil else { return }
        presentBranchPicker(
            title: "Squash and Merge into Current Branch",
            actionTitle: "Squash and Merge",
            excludingCurrent: true
        ) { [weak self] branch in
            guard let self else { return }
            Task { await self.runMerge(branch: branch, squash: true, repositoryURL: repositoryURL) }
        }
    }

    func presentRebase() {
        guard let repositoryURL = viewModel.repositoryURL,
              let target = currentLocalBranch(),
              rebaseService != nil else { return }
        presentBranchPicker(
            title: "Rebase Current Branch",
            actionTitle: "Rebase",
            excludingCurrent: true
        ) { [weak self] base in
            guard let self else { return }
            Task { await self.runRebase(base: base, target: target, repositoryURL: repositoryURL) }
        }
    }

    private func runMerge(branch: Branch, squash: Bool, repositoryURL: URL) async {
        guard let mergeService else { return }
        do {
            let outcome: MergeOutcome
            if squash {
                outcome = try await mergeService.squashMerge(
                    branch: branch.name, noVerify: false, in: repositoryURL
                )
            } else {
                outcome = try await mergeService.merge(
                    branch: branch.name, noVerify: false, in: repositoryURL
                )
            }
            await repositoryStore?.refreshRepositoryScreenData()
            await viewModel.loadBranches()
            showMergeOutcome(outcome, branch: branch.name)
        } catch {
            showError(title: "Merge failed", message: error.localizedDescription)
        }
    }

    private func runRebase(base: Branch, target: Branch, repositoryURL: URL) async {
        guard let rebaseService else { return }
        do {
            let outcome = try await rebaseService.rebase(
                base: base.name, target: target.name, in: repositoryURL
            )
            await repositoryStore?.refreshRepositoryScreenData()
            await viewModel.loadBranches()
            if outcome == .conflicts {
                showError(
                    title: "Rebase paused",
                    message: "Resolve conflicts, then run continue/skip/abort from the terminal."
                )
            }
        } catch {
            showError(title: "Rebase failed", message: error.localizedDescription)
        }
    }

    private func showMergeOutcome(_ outcome: MergeOutcome, branch: String) {
        switch outcome {
        case .success:
            return
        case .alreadyUpToDate:
            showInfo(title: "Already up to date", message: "Nothing to merge from \(branch).")
        case .conflicts:
            showError(
                title: "Merge has conflicts",
                message: "Resolve conflicts in the working tree, then commit or abort."
            )
        }
    }

    private func showError(title: String, message: String) {
        let alert = NSAlert()
        alert.messageText = title
        alert.informativeText = message
        alert.alertStyle = .warning
        if let window = windowProvider() {
            alert.beginSheetModal(for: window, completionHandler: nil)
        } else {
            alert.runModal()
        }
    }

    private func showInfo(title: String, message: String) {
        let alert = NSAlert()
        alert.messageText = title
        alert.informativeText = message
        alert.alertStyle = .informational
        if let window = windowProvider() {
            alert.beginSheetModal(for: window, completionHandler: nil)
        } else {
            alert.runModal()
        }
    }

    // MARK: - Minimal branch picker

    /// Inline branch-selection sheet used by Merge/Squash/Rebase/Compare. We
    /// keep this minimal — a single popup of local branches — rather than
    /// shipping a full branch browser, but it is fully functional (not a
    /// placeholder) and routes through the existing services.
    private func presentBranchPicker(
        title: String,
        actionTitle: String,
        excludingCurrent: Bool,
        completion: @escaping (Branch) -> Void
    ) {
        var candidates = viewModel.localBranches
        if excludingCurrent, let current = viewModel.currentBranchName {
            candidates.removeAll { $0.name == current }
        }
        guard !candidates.isEmpty else {
            showError(title: title, message: "No other local branches are available.")
            return
        }
        let picker = BranchPickerSheetController(
            title: title,
            actionTitle: actionTitle,
            branches: candidates,
            completion: completion
        )
        present(picker.viewController)
    }
}

// MARK: - Branch picker sheet

@MainActor
private final class BranchPickerSheetController {
    let viewController: NSViewController

    init(
        title: String,
        actionTitle: String,
        branches: [Branch],
        completion: @escaping (Branch) -> Void
    ) {
        self.viewController = BranchPickerSheetViewController(
            title: title,
            actionTitle: actionTitle,
            branches: branches,
            completion: completion
        )
    }
}

private final class BranchPickerSheetViewController: NSViewController {
    private let titleText: String
    private let actionTitle: String
    private let branches: [Branch]
    private let completion: (Branch) -> Void

    private let popup = NSPopUpButton()

    init(
        title: String,
        actionTitle: String,
        branches: [Branch],
        completion: @escaping (Branch) -> Void
    ) {
        self.titleText = title
        self.actionTitle = actionTitle
        self.branches = branches
        self.completion = completion
        super.init(nibName: nil, bundle: nil)
    }

    required init?(coder: NSCoder) { fatalError("init(coder:) is not supported") }

    override func loadView() {
        let container = NSView(frame: NSRect(x: 0, y: 0, width: 360, height: 150))
        self.view = container

        let titleLabel = NSTextField(labelWithString: titleText)
        titleLabel.font = NSFont.systemFont(ofSize: 14, weight: .semibold)
        titleLabel.translatesAutoresizingMaskIntoConstraints = false

        popup.translatesAutoresizingMaskIntoConstraints = false
        popup.removeAllItems()
        popup.addItems(withTitles: branches.map(\.name))

        let confirm = NSButton(title: actionTitle, target: self, action: #selector(confirm(_:)))
        confirm.translatesAutoresizingMaskIntoConstraints = false
        confirm.bezelStyle = .rounded
        confirm.keyEquivalent = "\r"

        let cancel = NSButton(title: "Cancel", target: self, action: #selector(cancel(_:)))
        cancel.translatesAutoresizingMaskIntoConstraints = false
        cancel.bezelStyle = .rounded
        cancel.keyEquivalent = "\u{1b}"

        container.addSubview(titleLabel)
        container.addSubview(popup)
        container.addSubview(confirm)
        container.addSubview(cancel)

        NSLayoutConstraint.activate([
            titleLabel.topAnchor.constraint(equalTo: container.topAnchor, constant: 16),
            titleLabel.leadingAnchor.constraint(equalTo: container.leadingAnchor, constant: 16),
            titleLabel.trailingAnchor.constraint(equalTo: container.trailingAnchor, constant: -16),

            popup.topAnchor.constraint(equalTo: titleLabel.bottomAnchor, constant: 16),
            popup.leadingAnchor.constraint(equalTo: container.leadingAnchor, constant: 16),
            popup.trailingAnchor.constraint(equalTo: container.trailingAnchor, constant: -16),

            confirm.trailingAnchor.constraint(equalTo: container.trailingAnchor, constant: -16),
            confirm.bottomAnchor.constraint(equalTo: container.bottomAnchor, constant: -16),

            cancel.trailingAnchor.constraint(equalTo: confirm.leadingAnchor, constant: -8),
            cancel.bottomAnchor.constraint(equalTo: container.bottomAnchor, constant: -16)
        ])
    }

    @objc private func confirm(_ sender: Any?) {
        let index = popup.indexOfSelectedItem
        guard branches.indices.contains(index) else { return }
        let branch = branches[index]
        dismiss(nil)
        completion(branch)
    }

    @objc private func cancel(_ sender: Any?) {
        dismiss(nil)
    }
}
