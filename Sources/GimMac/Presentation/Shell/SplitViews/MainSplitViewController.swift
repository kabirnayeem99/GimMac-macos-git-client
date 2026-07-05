import AppKit
import SwiftUI
import Observation

@MainActor
final class MainSplitViewController: NSViewController {
    private let viewModel: RepositoryStoreViewModel
    private let mergeService: MergeBranchProviding
    private let rebaseService: RebaseProviding
    private let settingsStore: any AppSettingsStoring

    /// Owns the window's native unified toolbar. Built lazily so its closures can
    /// capture `self`; installed once a window is available (`viewWillAppear`).
    private lazy var toolbarController = MainToolbarController(
        viewModel: viewModel,
        openRepositoryAction: { [weak self] in
            self?.openRepositoryTapped()
        },
        newRepositoryAction: { [weak self] in
            self?.menuNewRepository(nil)
        },
        cloneRepositoryAction: { [weak self] in
            self?.menuCloneRepository(nil)
        },
        selectRepositoryAction: { [weak self] id in
            Task {
                await self?.viewModel.selectPersistedRepository(id: id)
            }
        }
    )

    init(
        viewModel: RepositoryStoreViewModel,
        mergeService: MergeBranchProviding,
        rebaseService: RebaseProviding,
        settingsStore: any AppSettingsStoring
    ) {
        self.viewModel = viewModel
        self.mergeService = mergeService
        self.rebaseService = rebaseService
        self.settingsStore = settingsStore
        super.init(nibName: nil, bundle: nil)
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func loadView() {
        let hostingView = NSHostingView(
            rootView: RepositoryScreen(
                viewModel: viewModel,
                openRepositoryAction: { [weak self] in
                    self?.openRepositoryTapped()
                }
            )
        )
        hostingView.translatesAutoresizingMaskIntoConstraints = false
        view = hostingView
    }

    override func viewWillAppear() {
        super.viewWillAppear()
        // The window only exists once the view is in the hierarchy; install the
        // unified toolbar here. `install(on:)` is idempotent across re-appears.
        if let window = view.window {
            toolbarController.install(on: window)
        }
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        Task { [weak self] in
            await self?.viewModel.bootstrapRepositorySelectionOnLaunch()
            await self?.applyUITestRepositoryIfPresent()
        }
    }

    private func applyUITestRepositoryIfPresent() async {
        let environment = ProcessInfo.processInfo.environment
        guard let path = environment["GIMMAC_UI_TEST_REPO_PATH"], !path.isEmpty else {
            return
        }

        await viewModel.selectRepository(at: URL(fileURLWithPath: path, isDirectory: true))
    }

    private func openRepositoryTapped() {
        let panel = makeRepositoryOpenPanel()
        presentRepositoryPanel(panel)
    }

    private func makeRepositoryOpenPanel() -> NSOpenPanel {
        let panel = NSOpenPanel()
        panel.title = "Choose Repository"
        panel.message = "Select a local Git repository."
        panel.prompt = "Open Repository"
        panel.canChooseFiles = false
        panel.canChooseDirectories = true
        panel.canCreateDirectories = false
        panel.allowsMultipleSelection = false
        panel.resolvesAliases = true
        panel.treatsFilePackagesAsDirectories = false
        panel.showsTagField = false
        panel.directoryURL = defaultRepositoryDirectoryURL()
        return panel
    }

    private func defaultRepositoryDirectoryURL() -> URL {
        if let selectedRepository = viewModel.selectedRepository {
            return selectedRepository.url.deletingLastPathComponent()
        }

        return FileManager.default.homeDirectoryForCurrentUser
    }

    private func presentRepositoryPanel(_ panel: NSOpenPanel) {
        let handleSelection: (NSApplication.ModalResponse) -> Void = { [weak self] response in
            guard response == .OK, let url = panel.url else {
                return
            }

            Task { [weak self] in
                await self?.viewModel.selectRepository(at: url)
            }
        }

        if let window = view.window {
            panel.beginSheetModal(for: window, completionHandler: handleSelection)
            return
        }

        handleSelection(panel.runModal())
    }

    // MARK: - Menu bar routing
    //
    // Stored state for the lazy branch dialog presenter. The actual handlers
    // live in the extension below so this class stays under SwiftLint's
    // type-body limit.

    private var _menuBranchDialogPresenter: BranchDialogPresenter?
    private var _menuBranchesViewModel: BranchesViewModel?
}

// MARK: - Menu bar routing

@MainActor
extension MainSplitViewController {

    /// Resolve (or build) the shared dialog presenter. Returns nil when the
    /// branches services have not been injected — menu validation will then
    /// disable the items.
    private func menuBranchDialogPresenter() -> BranchDialogPresenter? {
        if let presenter = _menuBranchDialogPresenter { return presenter }
        guard let branchesVM = viewModel.makeBranchesViewModel() else { return nil }
        _menuBranchesViewModel = branchesVM
        // Load the branches list so subsequent dialogs have data to work with.
        Task { await branchesVM.loadBranches() }
        let presenter = BranchDialogPresenter(
            viewModel: branchesVM,
            repositoryStore: viewModel,
            mergeService: mergeService,
            rebaseService: rebaseService,
            windowProvider: { [weak self] in self?.view.window }
        )
        _menuBranchDialogPresenter = presenter
        return presenter
    }

    private func refreshBranchesAndPresent(_ present: @escaping (BranchDialogPresenter) -> Void) {
        guard let presenter = menuBranchDialogPresenter(),
              let branchesVM = _menuBranchesViewModel else { return }
        // Re-sync repository URL + current branch from the store, then refresh
        // the list before showing the sheet so it reflects the latest state.
        let currentName: String?
        if case .valid(let summary) = viewModel.tip { currentName = summary.name } else { currentName = nil }
        branchesVM.setRepository(viewModel.selectedRepository?.url, currentBranchName: currentName)
        Task { @MainActor in
            await branchesVM.loadBranches()
            present(presenter)
        }
    }

    // Repository

    /// Push handler. Dispatches to either a normal push or a force push based
    /// on `showForcePushOption` at the moment of invocation — `validateMenuItem`
    /// keeps the label in sync.
    @objc func menuPush(_ sender: Any?) {
        if viewModel.showForcePushOption {
            Task { await viewModel.performForcePush() }
        } else {
            Task { await viewModel.performPrimaryAction() }
        }
    }

    @objc func menuPull(_ sender: Any?) {
        Task { await viewModel.pull() }
    }

    @objc func menuFetch(_ sender: Any?) {
        Task { await viewModel.fetch() }
    }

    @objc func menuShowInFinder(_ sender: Any?) {
        guard let repo = viewModel.selectedRepository else { return }
        NSWorkspace.shared.activateFileViewerSelecting([repo.url])
    }

    @objc func menuOpenInShell(_ sender: Any?) {
        viewModel.openInShell()
    }

    // File

    @objc func menuAddLocalRepository(_ sender: Any?) {
        openRepositoryTapped()
    }

    @objc func menuNewRepository(_ sender: Any?) {
        let controller = CreateRepositoryWindowController(
            loadTemplates: { [weak self] in
                await self?.viewModel.loadRepositoryCreationTemplates() ?? ([], [])
            },
            onCreate: { [weak self] options, destination in
                await self?.viewModel.createRepository(with: options, at: destination) ?? false
            }
        )
        presentAsSheet(controller.viewController)
    }

    @objc func menuCloneRepository(_ sender: Any?) {
        let controller = CloneRepositoryWindowController { [weak self] url, destination in
            Task { [weak self] in
                await self?.viewModel.cloneRepository(from: url, to: destination)
            }
        }
        presentAsSheet(controller.viewController)
    }

    @objc func menuRemoveRepository(_ sender: Any?) {
        guard let repo = viewModel.selectedRepository else { return }

        // Confirmation is gated by the Prompts setting (Settings → Prompts).
        guard settingsStore.confirmRepositoryRemoval else {
            Task { await viewModel.removeSelectedRepository() }
            return
        }

        let alert = NSAlert()
        alert.messageText = "Remove \(repo.displayName)?"
        alert.informativeText = "GimMac will forget this repository. Files on disk are not affected."
        alert.alertStyle = .warning
        alert.addButton(withTitle: "Remove")
        alert.addButton(withTitle: "Cancel")

        let perform: (NSApplication.ModalResponse) -> Void = { [weak self] response in
            guard response == .alertFirstButtonReturn else { return }
            Task { await self?.viewModel.removeSelectedRepository() }
        }

        if let window = view.window {
            alert.beginSheetModal(for: window, completionHandler: perform)
        } else {
            perform(alert.runModal())
        }
    }

    // Branch

    @objc func menuNewBranch(_ sender: Any?) {
        refreshBranchesAndPresent { $0.presentCreateBranch() }
    }

    @objc func menuRenameBranch(_ sender: Any?) {
        refreshBranchesAndPresent { $0.presentRenameBranch() }
    }

    @objc func menuDeleteBranch(_ sender: Any?) {
        refreshBranchesAndPresent { $0.presentDeleteBranch() }
    }

    @objc func menuCompareToBranch(_ sender: Any?) {
        refreshBranchesAndPresent { $0.presentCompareToBranch() }
    }

    @objc func menuUpdateFromDefault(_ sender: Any?) {
        refreshBranchesAndPresent { $0.presentUpdateFromDefault() }
    }

    @objc func menuMergeIntoCurrent(_ sender: Any?) {
        refreshBranchesAndPresent { $0.presentMergeIntoCurrent() }
    }

    @objc func menuSquashAndMerge(_ sender: Any?) {
        refreshBranchesAndPresent { $0.presentSquashAndMerge() }
    }

    @objc func menuRebase(_ sender: Any?) {
        refreshBranchesAndPresent { $0.presentRebase() }
    }

    @objc func menuStashAllChanges(_ sender: Any?) {
        Task { await viewModel.stashAllChanges() }
    }

    @objc func menuManageStashes(_ sender: Any?) {
        guard let stashVM = viewModel.makeStashManagementViewModel() else { return }
        let controller = StashManagementViewController(viewModel: stashVM)
        presentAsSheet(controller)
    }

    @objc func menuDiscardAllChanges(_ sender: Any?) {
        // Confirmation is gated by the Prompts setting (Settings → Prompts).
        guard settingsStore.confirmDiscardChanges else {
            Task { await viewModel.discardAllChanges() }
            return
        }

        let alert = NSAlert()
        alert.messageText = "Discard all changes?"
        alert.informativeText = "All uncommitted changes in the working tree will be lost. This cannot be undone."
        alert.alertStyle = .warning
        alert.addButton(withTitle: "Discard All")
        alert.addButton(withTitle: "Cancel")

        let perform: (NSApplication.ModalResponse) -> Void = { [weak self] response in
            guard response == .alertFirstButtonReturn else { return }
            Task { await self?.viewModel.discardAllChanges() }
        }

        if let window = view.window {
            alert.beginSheetModal(for: window, completionHandler: perform)
        } else {
            perform(alert.runModal())
        }
    }

    // View

    @objc func menuShowChanges(_ sender: Any?) {
        viewModel.viewTab = 0
    }

    @objc func menuShowHistory(_ sender: Any?) {
        viewModel.viewTab = 1
    }

    // MARK: - Validation
    //
    // Native equivalent of GitHub Desktop's `MenuLabelsEvent`: dynamic title
    // for Push/Force Push and enable/disable for items that require a
    // selected repository or branch services.

    @objc func validateMenuItem(_ menuItem: NSMenuItem) -> Bool {
        let hasRepository = viewModel.selectedRepository != nil
        let hasBranches = viewModel.makeBranchesViewModel() != nil

        switch menuItem.action {
        case MainMenuFactory.pushAction:
            // Dynamic label: "Push" vs "Force Push…". The single `menuPush:`
            // handler dispatches internally based on `showForcePushOption`.
            menuItem.title = viewModel.showForcePushOption ? "Force Push…" : "Push"
            return hasRepository && !viewModel.isSyncing

        case MainMenuFactory.pullAction,
             MainMenuFactory.fetchAction:
            return hasRepository && !viewModel.isSyncing

        case MainMenuFactory.showInFinderAction,
             MainMenuFactory.openInShellAction,
             MainMenuFactory.removeRepositoryAction:
            return hasRepository

        case MainMenuFactory.newRepositoryAction,
             MainMenuFactory.addLocalRepositoryAction,
             MainMenuFactory.cloneRepositoryAction:
            return true

        case MainMenuFactory.newBranchAction,
             MainMenuFactory.renameBranchAction,
             MainMenuFactory.deleteBranchAction,
             MainMenuFactory.compareToBranchAction,
             MainMenuFactory.updateFromDefaultAction,
             MainMenuFactory.mergeIntoCurrentAction,
             MainMenuFactory.squashAndMergeAction,
             MainMenuFactory.rebaseAction:
            return hasRepository && hasBranches

        case MainMenuFactory.stashAllChangesAction,
             MainMenuFactory.discardAllChangesAction,
             MainMenuFactory.manageStashesAction:
            return hasRepository

        case MainMenuFactory.showChangesAction:
            menuItem.state = viewModel.viewTab == 0 ? .on : .off
            return hasRepository

        case MainMenuFactory.showHistoryAction:
            menuItem.state = viewModel.viewTab == 1 ? .on : .off
            return hasRepository

        default:
            return true
        }
    }
}
