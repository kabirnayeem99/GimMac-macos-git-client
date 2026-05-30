import AppKit

@MainActor
final class RepositorySettingsWindowController: NSWindowController {
    private let viewModel: RepositorySettingsViewModel

    init(viewModel: RepositorySettingsViewModel) {
        self.viewModel = viewModel
        let contentVC = RepositorySettingsViewController(viewModel: viewModel)
        let window = NSWindow(contentViewController: contentVC)
        window.title = "Repository Settings"
        window.setContentSize(NSSize(width: 560, height: 400))
        window.styleMask = [.titled, .closable]
        window.identifier = NSUserInterfaceItemIdentifier("gimmac.repositorySettings.window")
        window.standardWindowButton(.zoomButton)?.isEnabled = false
        window.standardWindowButton(.miniaturizeButton)?.isEnabled = false
        window.isRestorable = false
        super.init(window: window)
        shouldCascadeWindows = false
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
}

// MARK: - Content ViewController

@MainActor
private final class RepositorySettingsViewController: NSViewController {
    private let viewModel: RepositorySettingsViewModel
    private let tabView = NSTabView()
    private var observation: NSKeyValueObservation?

    // Remote tab controls
    private weak var remoteURLField: NSTextField?
    private weak var saveRemoteButton: NSButton?
    private weak var remoteStatusLabel: NSTextField?

    // Default branch tab controls
    private weak var branchNameField: NSTextField?
    private weak var renameBranchButton: NSButton?

    // LFS tab controls
    private weak var lfsStatusLabel: NSTextField?
    private weak var lfsInitButton: NSButton?

    // Error / success banner
    private weak var bannerLabel: NSTextField?

    init(viewModel: RepositorySettingsViewModel) {
        self.viewModel = viewModel
        super.init(nibName: nil, bundle: nil)
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func loadView() {
        view = NSView()
        view.translatesAutoresizingMaskIntoConstraints = false

        tabView.translatesAutoresizingMaskIntoConstraints = false
        tabView.tabViewType = .topTabsBezelBorder

        tabView.addTabViewItem(buildRemoteTab())
        tabView.addTabViewItem(buildDefaultBranchTab())
        tabView.addTabViewItem(buildLFSTab())
        tabView.addTabViewItem(buildOpenInTab())

        let banner = NSTextField(labelWithString: "")
        banner.translatesAutoresizingMaskIntoConstraints = false
        banner.textColor = .systemRed
        banner.font = .systemFont(ofSize: 12)
        banner.lineBreakMode = .byWordWrapping
        banner.maximumNumberOfLines = 2
        banner.isHidden = true
        bannerLabel = banner

        view.addSubview(tabView)
        view.addSubview(banner)

        NSLayoutConstraint.activate([
            tabView.topAnchor.constraint(equalTo: view.topAnchor, constant: 12),
            tabView.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 16),
            tabView.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -16),
            tabView.bottomAnchor.constraint(equalTo: banner.topAnchor, constant: -8),

            banner.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 20),
            banner.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -20),
            banner.bottomAnchor.constraint(equalTo: view.bottomAnchor, constant: -12),
            banner.heightAnchor.constraint(greaterThanOrEqualToConstant: 16),

            view.widthAnchor.constraint(equalToConstant: 560),
            view.heightAnchor.constraint(equalToConstant: 400)
        ])
    }

    override func viewDidAppear() {
        super.viewDidAppear()
        installObservation()
        Task { await viewModel.loadRemoteURL() }
        Task { await viewModel.checkLFSAvailability() }
    }

    // MARK: - Observable state → UI

    private func installObservation() {
        // Poll ViewModel state via withObservationTracking each cycle.
        trackState()
    }

    private func trackState() {
        withObservationTracking {
            syncUIFromViewModel()
        } onChange: { [weak self] in
            Task { @MainActor [weak self] in self?.trackState() }
        }
    }

    private func syncUIFromViewModel() {
        remoteURLField?.stringValue = viewModel.pendingRemoteURL
        remoteStatusLabel?.isHidden = !viewModel.isLoadingRemote
        saveRemoteButton?.isEnabled = !viewModel.isSavingRemote && !viewModel.isLoadingRemote

        branchNameField?.stringValue = viewModel.newBranchName
        renameBranchButton?.isEnabled = !viewModel.isSavingBranch

        lfsStatusLabel?.stringValue = viewModel.isLoadingLFS
            ? "Checking LFS status…"
            : (viewModel.lfsAvailable ? "Git LFS is installed and available." : "Git LFS is not installed.")
        lfsInitButton?.isHidden = viewModel.lfsAvailable || viewModel.isLoadingLFS
        lfsInitButton?.isEnabled = !viewModel.isInitializingLFS

        if let error = viewModel.errorMessage {
            bannerLabel?.textColor = .systemRed
            bannerLabel?.stringValue = error
            bannerLabel?.isHidden = false
        } else if let success = viewModel.successMessage {
            bannerLabel?.textColor = .systemGreen
            bannerLabel?.stringValue = success
            bannerLabel?.isHidden = false
        } else {
            bannerLabel?.isHidden = true
        }
    }

    // MARK: - Tab builders

    private func buildRemoteTab() -> NSTabViewItem {
        let item = NSTabViewItem()
        item.label = "Remote"

        let container = NSStackView()
        container.orientation = .vertical
        container.alignment = .leading
        container.spacing = 12
        container.edgeInsets = NSEdgeInsets(top: 20, left: 20, bottom: 20, right: 20)
        container.translatesAutoresizingMaskIntoConstraints = false

        container.addArrangedSubview(sectionTitle("Primary Remote (origin)"))
        container.addArrangedSubview(note("The URL Git pushes to and fetches from."))

        let field = NSTextField(string: "")
        field.placeholderString = "https://github.com/owner/repo.git"
        field.translatesAutoresizingMaskIntoConstraints = false
        field.widthAnchor.constraint(equalToConstant: 460).isActive = true
        field.target = self
        field.action = #selector(remoteURLChanged(_:))
        remoteURLField = field
        container.addArrangedSubview(field)

        let loadingLabel = NSTextField(labelWithString: "Loading…")
        loadingLabel.textColor = .secondaryLabelColor
        loadingLabel.font = .systemFont(ofSize: 12)
        remoteStatusLabel = loadingLabel
        container.addArrangedSubview(loadingLabel)

        let saveButton = NSButton(title: "Save Remote URL", target: self, action: #selector(saveRemoteTapped))
        saveButton.bezelStyle = .rounded
        saveButton.keyEquivalent = "\r"
        saveRemoteButton = saveButton
        container.addArrangedSubview(saveButton)

        wrap(container, in: item)
        return item
    }

    private func buildDefaultBranchTab() -> NSTabViewItem {
        let item = NSTabViewItem()
        item.label = "Default Branch"

        let container = NSStackView()
        container.orientation = .vertical
        container.alignment = .leading
        container.spacing = 12
        container.edgeInsets = NSEdgeInsets(top: 20, left: 20, bottom: 20, right: 20)
        container.translatesAutoresizingMaskIntoConstraints = false

        container.addArrangedSubview(sectionTitle("Rename Current Branch"))
        container.addArrangedSubview(note("Renames the local branch using `git branch -M`. This does not push to the remote."))

        let row = NSStackView()
        row.orientation = .horizontal
        row.spacing = 8
        let fromLabel = NSTextField(labelWithString: "From:")
        fromLabel.translatesAutoresizingMaskIntoConstraints = false
        fromLabel.widthAnchor.constraint(equalToConstant: 48).isActive = true
        let fromValue = NSTextField(labelWithString: viewModel.currentBranchName)
        fromValue.textColor = .secondaryLabelColor
        row.addArrangedSubview(fromLabel)
        row.addArrangedSubview(fromValue)
        container.addArrangedSubview(row)

        let toRow = NSStackView()
        toRow.orientation = .horizontal
        toRow.spacing = 8
        let toLabel = NSTextField(labelWithString: "To:")
        toLabel.translatesAutoresizingMaskIntoConstraints = false
        toLabel.widthAnchor.constraint(equalToConstant: 48).isActive = true
        let nameField = NSTextField(string: viewModel.currentBranchName)
        nameField.translatesAutoresizingMaskIntoConstraints = false
        nameField.widthAnchor.constraint(equalToConstant: 280).isActive = true
        nameField.target = self
        nameField.action = #selector(branchNameChanged(_:))
        branchNameField = nameField
        toRow.addArrangedSubview(toLabel)
        toRow.addArrangedSubview(nameField)
        container.addArrangedSubview(toRow)

        let renameButton = NSButton(title: "Rename Branch", target: self, action: #selector(renameBranchTapped))
        renameButton.bezelStyle = .rounded
        renameBranchButton = renameButton
        container.addArrangedSubview(renameButton)

        wrap(container, in: item)
        return item
    }

    private func buildLFSTab() -> NSTabViewItem {
        let item = NSTabViewItem()
        item.label = "Git LFS"

        let container = NSStackView()
        container.orientation = .vertical
        container.alignment = .leading
        container.spacing = 12
        container.edgeInsets = NSEdgeInsets(top: 20, left: 20, bottom: 20, right: 20)
        container.translatesAutoresizingMaskIntoConstraints = false

        container.addArrangedSubview(sectionTitle("Large File Storage"))
        container.addArrangedSubview(note("Git LFS replaces large files with text pointers inside Git. Requires git-lfs installed on your system."))

        let statusLabel = NSTextField(labelWithString: "Checking LFS status…")
        statusLabel.textColor = .secondaryLabelColor
        lfsStatusLabel = statusLabel
        container.addArrangedSubview(statusLabel)

        let initButton = NSButton(title: "Initialize Git LFS", target: self, action: #selector(initLFSTapped))
        initButton.bezelStyle = .rounded
        initButton.isHidden = true
        lfsInitButton = initButton
        container.addArrangedSubview(initButton)

        wrap(container, in: item)
        return item
    }

    private func buildOpenInTab() -> NSTabViewItem {
        let item = NSTabViewItem()
        item.label = "Open In"

        let container = NSStackView()
        container.orientation = .vertical
        container.alignment = .leading
        container.spacing = 12
        container.edgeInsets = NSEdgeInsets(top: 20, left: 20, bottom: 20, right: 20)
        container.translatesAutoresizingMaskIntoConstraints = false

        container.addArrangedSubview(sectionTitle("Open Repository In"))
        container.addArrangedSubview(note("Launch an external application at this repository's path."))

        let terminalButton = NSButton(title: "Open in Terminal", target: self, action: #selector(openTerminalTapped))
        terminalButton.bezelStyle = .rounded
        container.addArrangedSubview(terminalButton)

        let editorButton = NSButton(title: "Open in External Editor", target: self, action: #selector(openEditorTapped))
        editorButton.bezelStyle = .rounded
        container.addArrangedSubview(editorButton)

        wrap(container, in: item)
        return item
    }

    // MARK: - Actions

    @objc private func remoteURLChanged(_ sender: NSTextField) {
        viewModel.pendingRemoteURL = sender.stringValue
    }

    @objc private func branchNameChanged(_ sender: NSTextField) {
        viewModel.newBranchName = sender.stringValue
    }

    @objc private func saveRemoteTapped() {
        viewModel.errorMessage = nil
        viewModel.successMessage = nil
        Task { await viewModel.saveRemoteURL() }
    }

    @objc private func renameBranchTapped() {
        viewModel.errorMessage = nil
        viewModel.successMessage = nil
        Task { await viewModel.renameCurrentBranch() }
    }

    @objc private func initLFSTapped() {
        viewModel.errorMessage = nil
        viewModel.successMessage = nil
        Task { await viewModel.initializeLFS() }
    }

    @objc private func openTerminalTapped() {
        viewModel.openInTerminal()
    }

    @objc private func openEditorTapped() {
        viewModel.errorMessage = nil
        viewModel.openInExternalEditor()
    }

    // MARK: - Helpers

    private func sectionTitle(_ text: String) -> NSTextField {
        let label = NSTextField(labelWithString: text)
        label.font = .systemFont(ofSize: 15, weight: .semibold)
        return label
    }

    private func note(_ text: String) -> NSTextField {
        let label = NSTextField(wrappingLabelWithString: text)
        label.textColor = .secondaryLabelColor
        label.font = .systemFont(ofSize: 12)
        label.translatesAutoresizingMaskIntoConstraints = false
        label.widthAnchor.constraint(equalToConstant: 460).isActive = true
        return label
    }

    private func wrap(_ stack: NSStackView, in item: NSTabViewItem) {
        let host = NSView()
        host.translatesAutoresizingMaskIntoConstraints = false
        host.addSubview(stack)
        NSLayoutConstraint.activate([
            stack.topAnchor.constraint(equalTo: host.topAnchor),
            stack.leadingAnchor.constraint(equalTo: host.leadingAnchor),
            stack.trailingAnchor.constraint(equalTo: host.trailingAnchor),
            stack.bottomAnchor.constraint(lessThanOrEqualTo: host.bottomAnchor)
        ])
        item.view = host
    }
}
