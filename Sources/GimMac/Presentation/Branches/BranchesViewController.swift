import AppKit
import Observation

/// Hosts the branches panel: tab control, search field, table, "New Branch" button.
///
/// Reads state from an injected `BranchesViewModel` (protocol-typed
/// dependencies — never concrete services). Observation is set up via
/// `withObservationTracking` so the view re-renders whenever the VM publishes.
final class BranchesViewController: NSViewController {

    private let viewModel: BranchesViewModel

    private let tabControl = NSSegmentedControl()
    private let searchField = NSSearchField()
    private let tableView = NSTableView()
    private let scrollView = NSScrollView()
    private let newBranchButton = NSButton(title: "New Branch", target: nil, action: nil)
    private let progressIndicator = NSProgressIndicator()

    private var renderedBranches: [Branch] = []

    // MARK: - Init

    init(viewModel: BranchesViewModel) {
        self.viewModel = viewModel
        super.init(nibName: nil, bundle: nil)
    }

    required init?(coder: NSCoder) { fatalError("init(coder:) is not supported") }

    // MARK: - Lifecycle

    override func loadView() {
        let container = NSView(frame: NSRect(x: 0, y: 0, width: 360, height: 480))
        container.autoresizingMask = [.width, .height]
        self.view = container
        buildLayout(in: container)
        wireActions()
        configureTable()
    }

    override func viewDidAppear() {
        super.viewDidAppear()
        observe()
        Task { await viewModel.loadBranches() }
    }

    // MARK: - Layout

    private func buildLayout(in container: NSView) {
        tabControl.translatesAutoresizingMaskIntoConstraints = false
        tabControl.segmentStyle = .texturedSquare
        tabControl.segmentCount = BranchesTab.allCases.count
        tabControl.setLabel("Local", forSegment: 0)
        tabControl.setLabel("Remote", forSegment: 1)
        tabControl.selectedSegment = viewModel.selectedTab.rawValue
        tabControl.target = self
        tabControl.action = #selector(tabChanged(_:))

        searchField.translatesAutoresizingMaskIntoConstraints = false
        searchField.placeholderString = "Filter"
        searchField.target = self
        searchField.action = #selector(searchChanged(_:))

        scrollView.translatesAutoresizingMaskIntoConstraints = false
        scrollView.hasVerticalScroller = true
        scrollView.borderType = .noBorder
        scrollView.drawsBackground = false
        scrollView.documentView = tableView

        newBranchButton.translatesAutoresizingMaskIntoConstraints = false
        newBranchButton.bezelStyle = .rounded
        newBranchButton.target = self
        newBranchButton.action = #selector(presentCreateBranch(_:))

        progressIndicator.translatesAutoresizingMaskIntoConstraints = false
        progressIndicator.style = .spinning
        progressIndicator.controlSize = .small
        progressIndicator.isDisplayedWhenStopped = false

        container.addSubview(tabControl)
        container.addSubview(searchField)
        container.addSubview(scrollView)
        container.addSubview(newBranchButton)
        container.addSubview(progressIndicator)

        NSLayoutConstraint.activate([
            tabControl.topAnchor.constraint(equalTo: container.topAnchor, constant: 10),
            tabControl.leadingAnchor.constraint(equalTo: container.leadingAnchor, constant: 12),
            tabControl.trailingAnchor.constraint(equalTo: container.trailingAnchor, constant: -12),

            searchField.topAnchor.constraint(equalTo: tabControl.bottomAnchor, constant: 8),
            searchField.leadingAnchor.constraint(equalTo: container.leadingAnchor, constant: 12),
            searchField.trailingAnchor.constraint(equalTo: container.trailingAnchor, constant: -12),

            scrollView.topAnchor.constraint(equalTo: searchField.bottomAnchor, constant: 8),
            scrollView.leadingAnchor.constraint(equalTo: container.leadingAnchor, constant: 8),
            scrollView.trailingAnchor.constraint(equalTo: container.trailingAnchor, constant: -8),
            scrollView.bottomAnchor.constraint(equalTo: newBranchButton.topAnchor, constant: -8),

            newBranchButton.leadingAnchor.constraint(equalTo: container.leadingAnchor, constant: 12),
            newBranchButton.bottomAnchor.constraint(equalTo: container.bottomAnchor, constant: -10),

            progressIndicator.centerYAnchor.constraint(equalTo: newBranchButton.centerYAnchor),
            progressIndicator.trailingAnchor.constraint(equalTo: container.trailingAnchor, constant: -16)
        ])
    }

    private func configureTable() {
        tableView.headerView = nil
        tableView.rowHeight = BranchCellView.rowHeight
        tableView.intercellSpacing = NSSize(width: 0, height: 2)
        tableView.allowsMultipleSelection = false
        tableView.gridStyleMask = []
        tableView.style = .plain
        tableView.usesAutomaticRowHeights = false
        tableView.backgroundColor = .clear
        tableView.delegate = self
        tableView.dataSource = self
        tableView.menu = makeContextMenu()
        tableView.target = self
        tableView.doubleAction = #selector(rowDoubleClicked(_:))

        let column = NSTableColumn(identifier: NSUserInterfaceItemIdentifier("Branch"))
        column.resizingMask = .autoresizingMask
        tableView.addTableColumn(column)
    }

    private func wireActions() {
        // Wired in buildLayout — kept here as a hook for future controls.
    }

    // MARK: - Observation

    private func observe() {
        withObservationTracking { [weak self] in
            guard let self else { return }
            _ = self.viewModel.filteredBranches
            _ = self.viewModel.selectedTab
            _ = self.viewModel.isLoading
            _ = self.viewModel.errorMessage
            _ = self.viewModel.stashGuardNeeded
            _ = self.viewModel.currentBranchName
        } onChange: { [weak self] in
            Task { @MainActor in
                self?.render()
                self?.observe()
            }
        }
        render()
    }

    private func render() {
        tabControl.selectedSegment = viewModel.selectedTab.rawValue
        if viewModel.isLoading {
            progressIndicator.startAnimation(nil)
        } else {
            progressIndicator.stopAnimation(nil)
        }
        let newRows = viewModel.filteredBranches
        if newRows != renderedBranches {
            renderedBranches = newRows
            tableView.reloadData()
        }
        if let guardState = viewModel.stashGuardNeeded {
            presentStashGuard(guardState)
        }
        if let message = viewModel.errorMessage, !message.isEmpty {
            presentErrorIfNeeded(message)
        }
    }

    private var presentedErrors: Set<String> = []
    private func presentErrorIfNeeded(_ message: String) {
        guard !presentedErrors.contains(message) else { return }
        presentedErrors.insert(message)
        let alert = NSAlert()
        alert.messageText = "Branch operation failed"
        alert.informativeText = message
        alert.alertStyle = .warning
        alert.runModal()
        viewModel.errorMessage = nil
        presentedErrors.remove(message)
    }

    // MARK: - Actions

    @objc private func tabChanged(_ sender: NSSegmentedControl) {
        if let tab = BranchesTab(rawValue: sender.selectedSegment) {
            viewModel.selectedTab = tab
        }
    }

    @objc private func searchChanged(_ sender: NSSearchField) {
        viewModel.searchQuery = sender.stringValue
        render()
    }

    @objc private func presentCreateBranch(_ sender: Any?) {
        let existing = (viewModel.localBranches + viewModel.remoteBranches).map(\.name)
        let controller = CreateBranchWindowController(
            existingNames: existing,
            availableBranches: viewModel.localBranches
        ) { [weak self] name, startPoint, noTrack in
            guard let self else { return }
            Task { await self.viewModel.createBranch(named: name, from: startPoint, noTrack: noTrack) }
        }
        presentAsSheet(controller.viewController)
    }

    @objc private func rowDoubleClicked(_ sender: Any?) {
        let row = tableView.clickedRow
        guard renderedBranches.indices.contains(row) else { return }
        let branch = renderedBranches[row]
        Task { await viewModel.switchBranch(to: branch) }
    }

    // MARK: - Context menu

    private func makeContextMenu() -> NSMenu {
        let menu = NSMenu()
        menu.delegate = self
        menu.addItem(withTitle: "Switch to Branch", action: #selector(menuSwitchBranch(_:)), keyEquivalent: "")
        menu.addItem(withTitle: "Rename…", action: #selector(menuRenameBranch(_:)), keyEquivalent: "")
        menu.addItem(withTitle: "Delete…", action: #selector(menuDeleteBranch(_:)), keyEquivalent: "")
        menu.addItem(.separator())
        menu.addItem(withTitle: "Copy Name", action: #selector(menuCopyName(_:)), keyEquivalent: "")
        for item in menu.items { item.target = self }
        return menu
    }

    private func clickedOrSelectedBranch() -> Branch? {
        let row = tableView.clickedRow >= 0 ? tableView.clickedRow : tableView.selectedRow
        guard renderedBranches.indices.contains(row) else { return nil }
        return renderedBranches[row]
    }

    @objc private func menuSwitchBranch(_ sender: Any?) {
        guard let branch = clickedOrSelectedBranch() else { return }
        Task { await viewModel.switchBranch(to: branch) }
    }

    @objc private func menuRenameBranch(_ sender: Any?) {
        guard let branch = clickedOrSelectedBranch(), branch.isLocal else { return }
        let existing = viewModel.localBranches.map(\.name)
        let controller = RenameBranchWindowController(
            branch: branch,
            existingNames: existing
        ) { [weak self] newName, force in
            Task { await self?.viewModel.renameBranch(branch, to: newName, force: force) }
        }
        presentAsSheet(controller.viewController)
    }

    @objc private func menuDeleteBranch(_ sender: Any?) {
        guard let branch = clickedOrSelectedBranch() else { return }
        let controller = DeleteBranchWindowController(branch: branch) { [weak self] deleteRemote in
            guard let self else { return }
            if branch.isLocal {
                Task { await self.viewModel.deleteLocalBranch(branch, force: true) }
                if deleteRemote, let upstream = branch.upstream {
                    let remote = upstream.split(separator: "/").first.map(String.init) ?? "origin"
                    Task { await self.viewModel.deleteRemoteBranch(branch, remote: remote) }
                }
            } else if let remote = branch.remoteName {
                Task { await self.viewModel.deleteRemoteBranch(branch, remote: remote) }
            }
        }
        presentAsSheet(controller.viewController)
    }

    @objc private func menuCopyName(_ sender: Any?) {
        guard let branch = clickedOrSelectedBranch() else { return }
        let pb = NSPasteboard.general
        pb.clearContents()
        pb.setString(branch.name, forType: .string)
    }

    // MARK: - Stash guard

    private var stashGuardPresented = false
    private func presentStashGuard(_ state: BranchesViewModel.StashGuard) {
        guard !stashGuardPresented else { return }
        stashGuardPresented = true
        let controller = StashAndSwitchSheetController(
            branch: state.pendingBranch,
            dirtyFileCount: state.dirtyFileCount
        ) { [weak self] action in
            guard let self else { return }
            self.stashGuardPresented = false
            Task { await self.viewModel.resolveStashGuard(action) }
        }
        presentAsSheet(controller.viewController)
    }
}

// MARK: - NSTableViewDataSource

extension BranchesViewController: NSTableViewDataSource, NSTableViewDelegate {
    func numberOfRows(in tableView: NSTableView) -> Int {
        renderedBranches.count
    }

    func tableView(_ tableView: NSTableView, viewFor tableColumn: NSTableColumn?, row: Int) -> NSView? {
        guard renderedBranches.indices.contains(row) else { return nil }
        let cell: BranchCellView
        if let reused = tableView.makeView(withIdentifier: BranchCellView.reuseIdentifier, owner: self) as? BranchCellView {
            cell = reused
        } else {
            cell = BranchCellView()
            cell.identifier = BranchCellView.reuseIdentifier
        }
        let branch = renderedBranches[row]
        let isCurrent = (viewModel.currentBranchName == branch.name) ||
            (!branch.isLocal && viewModel.currentBranchName == branch.nameWithoutRemote)
        cell.configure(with: branch, isCurrent: isCurrent)
        return cell
    }
}

extension BranchesViewController: NSMenuDelegate {
    func menuWillOpen(_ menu: NSMenu) {
        // Disable "Rename" for remote branches.
        if let rename = menu.items.first(where: { $0.action == #selector(menuRenameBranch(_:)) }) {
            rename.isEnabled = clickedOrSelectedBranch()?.isLocal == true
        }
    }
}
