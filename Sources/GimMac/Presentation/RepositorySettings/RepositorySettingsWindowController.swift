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
    private var isRemoteFieldVisible: Bool = true
    private var isRemoteStatusVisible: Bool = false

    // Default branch tab controls
    private weak var branchNameField: NSTextField?
    private weak var renameBranchButton: NSButton?
    private weak var currentBranchLabel: NSTextField?

    // LFS tab controls
    private weak var lfsStatusLabel: NSTextField?
    private weak var lfsInitButton: NSButton?

    // Open In tab controls
    private weak var terminalButton: NSButton?
    private weak var editorButton: NSButton?
    private var terminalButtonOriginalTitle: String?
    private var editorButtonOriginalTitle: String?

    // Error / success banner
    private weak var bannerLabel: NSTextField?
    private var bannerDismissWorkItem: DispatchWorkItem?
    private var lastSuccessMessage: String?
    private var lastErrorMessage: String?
    private var lastAction: RepositorySettingsAction?

    private enum RepositorySettingsAction {
        case saveRemote, renameBranch, initializeLFS
    }

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
        if !(remoteURLField?.currentEditor() != nil) {
            remoteURLField?.stringValue = viewModel.pendingRemoteURL
        }
        saveRemoteButton?.isEnabled = canSaveRemoteURL

        let remoteLoading = viewModel.isLoadingRemote
        let fieldShouldBeVisible = !remoteLoading
        if isRemoteFieldVisible != fieldShouldBeVisible {
            remoteURLField?.fadeBanner(visible: fieldShouldBeVisible)
            isRemoteFieldVisible = fieldShouldBeVisible
        }
        let statusShouldBeVisible = remoteLoading
        if isRemoteStatusVisible != statusShouldBeVisible {
            remoteStatusLabel?.fadeBanner(visible: statusShouldBeVisible)
            isRemoteStatusVisible = statusShouldBeVisible
        }

        currentBranchLabel?.stringValue = viewModel.currentBranchName
        if !(branchNameField?.currentEditor() != nil) {
            branchNameField?.stringValue = viewModel.newBranchName
        }
        renameBranchButton?.isEnabled = canRenameBranch

        updateLFSStatus()
        lfsInitButton?.isHidden = viewModel.lfsAvailable || viewModel.isLoadingLFS
        lfsInitButton?.isEnabled = !viewModel.isInitializingLFS

        syncBanner()
    }

    private func updateLFSStatus() {
        let newText = viewModel.isLoadingLFS
            ? "Checking LFS status…"
            : (viewModel.lfsAvailable ? "Git LFS is installed and available." : "Git LFS is not installed.")
        guard lfsStatusLabel?.stringValue != newText else { return }
        if AppKitMotion.reduceMotion {
            lfsStatusLabel?.stringValue = newText
        } else {
            lfsStatusLabel?.animateAlpha(to: 0, duration: AppKitMotion.feedback) { [weak self] in
                self?.lfsStatusLabel?.stringValue = newText
                self?.lfsStatusLabel?.animateAlpha(to: 1, duration: AppKitMotion.feedback)
            }
        }
    }

    private func syncBanner() {
        bannerDismissWorkItem?.cancel()
        bannerDismissWorkItem = nil

        let newError = viewModel.errorMessage
        let newSuccess = viewModel.successMessage

        if let error = newError, error != lastErrorMessage {
            bannerLabel?.textColor = .systemRed
            bannerLabel?.stringValue = error
            bannerLabel?.fadeBanner(visible: true)
            lastErrorMessage = error
            lastSuccessMessage = nil
        } else if let success = newSuccess, success != lastSuccessMessage {
            bannerLabel?.textColor = .systemGreen
            bannerLabel?.stringValue = success
            bannerLabel?.fadeBanner(visible: true)
            lastSuccessMessage = success
            lastErrorMessage = nil
            flashSuccessFeedback()
            if let banner = bannerLabel {
                bannerDismissWorkItem = AppKitMotion.scheduleAutoDismiss(for: banner)
            }
        } else if newError == nil, newSuccess == nil {
            bannerLabel?.fadeBanner(visible: false)
            lastErrorMessage = nil
            lastSuccessMessage = nil
        }
    }

    private func flashSuccessFeedback() {
        let button: NSButton?
        switch lastAction {
        case .saveRemote:
            button = saveRemoteButton
        case .renameBranch:
            button = renameBranchButton
        case .initializeLFS:
            button = lfsInitButton
        case .none:
            button = nil
        }
        lastAction = nil
        guard let button, !AppKitMotion.reduceMotion else { return }
        let originalTitle = button.title
        button.title = "Saved"
        button.animateAlpha(to: 0.7, duration: AppKitMotion.feedback) { [weak button] in
            button?.animateAlpha(to: 1, duration: AppKitMotion.feedback)
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) { [weak button] in
            button?.title = originalTitle
        }
    }

    // MARK: - Actions

    @objc private func remoteURLChanged(_ sender: NSTextField) {
        viewModel.pendingRemoteURL = sender.stringValue
        syncUIFromViewModel()
    }

    @objc private func branchNameChanged(_ sender: NSTextField) {
        viewModel.newBranchName = sender.stringValue
        syncUIFromViewModel()
    }

    @objc private func saveRemoteTapped() {
        viewModel.errorMessage = nil
        viewModel.successMessage = nil
        lastAction = .saveRemote
        Task { await viewModel.saveRemoteURL() }
    }

    @objc private func renameBranchTapped() {
        viewModel.errorMessage = nil
        viewModel.successMessage = nil
        lastAction = .renameBranch
        Task { await viewModel.renameCurrentBranch() }
    }

    @objc private func initLFSTapped() {
        viewModel.errorMessage = nil
        viewModel.successMessage = nil
        lastAction = .initializeLFS
        Task { await viewModel.initializeLFS() }
    }

    @objc private func openTerminalTapped() {
        viewModel.openInTerminal()
        confirmOpenIn(button: terminalButton, originalTitle: terminalButtonOriginalTitle)
    }

    @objc private func openEditorTapped() {
        viewModel.errorMessage = nil
        viewModel.openInExternalEditor()
        confirmOpenIn(button: editorButton, originalTitle: editorButtonOriginalTitle)
    }

    private func confirmOpenIn(button: NSButton?, originalTitle: String?) {
        guard let button, let originalTitle, !AppKitMotion.reduceMotion else { return }
        button.title = "\(originalTitle) ✓"
        button.animateAlpha(to: 0.6, duration: AppKitMotion.feedback) { [weak button] in
            button?.animateAlpha(to: 1, duration: AppKitMotion.feedback)
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.8) { [weak button] in
            button?.title = originalTitle
        }
    }
}

// MARK: - Tab builders

@MainActor
private extension RepositorySettingsViewController {

    func buildRemoteTab() -> NSTabViewItem {
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
        loadingLabel.isHidden = true
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

    func buildDefaultBranchTab() -> NSTabViewItem {
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
        currentBranchLabel = fromValue
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

    func buildLFSTab() -> NSTabViewItem {
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

    func buildOpenInTab() -> NSTabViewItem {
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
        self.terminalButton = terminalButton
        self.terminalButtonOriginalTitle = terminalButton.title
        container.addArrangedSubview(terminalButton)

        let editorButton = NSButton(title: "Open in External Editor", target: self, action: #selector(openEditorTapped))
        editorButton.bezelStyle = .rounded
        self.editorButton = editorButton
        self.editorButtonOriginalTitle = editorButton.title
        container.addArrangedSubview(editorButton)

        wrap(container, in: item)
        return item
    }

    // MARK: - Helpers

    func sectionTitle(_ text: String) -> NSTextField {
        let label = NSTextField(labelWithString: text)
        label.font = .systemFont(ofSize: 15, weight: .semibold)
        return label
    }

    func note(_ text: String) -> NSTextField {
        let label = NSTextField(wrappingLabelWithString: text)
        label.textColor = .secondaryLabelColor
        label.font = .systemFont(ofSize: 12)
        label.translatesAutoresizingMaskIntoConstraints = false
        label.widthAnchor.constraint(equalToConstant: 460).isActive = true
        return label
    }

    func wrap(_ stack: NSStackView, in item: NSTabViewItem) {
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

    var canSaveRemoteURL: Bool {
        let trimmed = viewModel.pendingRemoteURL.trimmingCharacters(in: .whitespacesAndNewlines)
        return !viewModel.isSavingRemote && !viewModel.isLoadingRemote && !trimmed.isEmpty && trimmed != viewModel.remoteURL
    }

    var canRenameBranch: Bool {
        let trimmed = viewModel.newBranchName.trimmingCharacters(in: .whitespacesAndNewlines)
        return !viewModel.isSavingBranch && !trimmed.isEmpty && trimmed != viewModel.currentBranchName
    }
}
