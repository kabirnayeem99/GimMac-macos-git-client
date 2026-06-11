import AppKit
import Observation

/// Git pane: global author identity and the default branch name for new
/// repositories, plus a shortcut to edit the global Git config file. Native
/// equivalent of GitHub Desktop's `Git` preferences panel. Reads/writes via
/// `GitSettingsViewModel`.
@MainActor
final class GitSettingsPaneController: SettingsPaneViewController {
    private let viewModel: GitSettingsViewModel

    private weak var nameField: NSTextField?
    private weak var emailField: NSTextField?
    private weak var branchField: NSTextField?
    private weak var validationLabel: NSTextField?
    private weak var bannerLabel: NSTextField?
    private weak var saveButton: NSButton?

    init(viewModel: GitSettingsViewModel) {
        self.viewModel = viewModel
        super.init(nibName: nil, bundle: nil)
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }

    override func buildContent() {
        addHeader("Git")

        let name = makeTextField(text: viewModel.committerName, placeholder: "Name") { [weak self] in
            self?.viewModel.committerName = $0
            self?.refreshValidation()
        }
        let email = makeTextField(text: viewModel.committerEmail, placeholder: "you@example.com") { [weak self] in
            self?.viewModel.committerEmail = $0
        }
        nameField = name
        emailField = email

        let validation = NSTextField(labelWithString: "")
        validation.textColor = .systemRed
        validation.font = .systemFont(ofSize: 12)
        validation.isHidden = true
        validationLabel = validation

        addSection("Author", views: [
            labeledRow("Name", control: name),
            labeledRow("Email", control: email),
            validation
        ])

        let branch = makeTextField(text: viewModel.defaultBranch, placeholder: "main") { [weak self] in
            self?.viewModel.defaultBranch = $0
        }
        branchField = branch
        addSection("Default branch", views: [
            labeledRow("Default branch name for new repositories", control: branch, labelWidth: 280),
            makeNote("This name is used by Git when initializing new repositories. A common "
                     + "alternative is \"master\".")
        ])

        let save = makeButton("Save") { [weak self] in
            guard let self else { return }
            Task { await self.viewModel.save() }
        }
        save.keyEquivalent = "\r"
        saveButton = save

        let editConfig = makeButton("Edit Global Git Config…") { [weak self] in
            self?.openGlobalGitConfig()
        }

        let banner = NSTextField(labelWithString: "")
        banner.font = .systemFont(ofSize: 12)
        banner.isHidden = true
        bannerLabel = banner

        addSection(nil, views: [
            {
                let row = NSStackView()
                row.orientation = .horizontal
                row.spacing = 12
                row.addArrangedSubview(save)
                row.addArrangedSubview(editConfig)
                return row
            }(),
            banner
        ])
    }

    override func viewDidAppear() {
        super.viewDidAppear()
        trackState()
        Task { [weak self] in
            await self?.viewModel.load()
            self?.syncFieldsFromViewModel()
        }
    }

    // MARK: - Observation

    private func trackState() {
        withObservationTracking {
            syncStatus()
        } onChange: { [weak self] in
            Task { @MainActor [weak self] in self?.trackState() }
        }
    }

    /// Mirrors validation, banner, and busy state. Field text is populated
    /// separately (only after load) so user typing is never clobbered.
    private func syncStatus() {
        refreshValidation()
        saveButton?.isEnabled = !viewModel.isSaving && viewModel.nameValidationMessage == nil

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

    private func refreshValidation() {
        if let message = viewModel.nameValidationMessage {
            validationLabel?.stringValue = message
            validationLabel?.isHidden = false
        } else {
            validationLabel?.isHidden = true
        }
    }

    private func syncFieldsFromViewModel() {
        nameField?.stringValue = viewModel.committerName
        emailField?.stringValue = viewModel.committerEmail
        branchField?.stringValue = viewModel.defaultBranch
    }

    private func openGlobalGitConfig() {
        let configURL = FileManager.default.homeDirectoryForCurrentUser
            .appendingPathComponent(".gitconfig")
        if !FileManager.default.fileExists(atPath: configURL.path) {
            FileManager.default.createFile(atPath: configURL.path, contents: nil)
        }
        NSWorkspace.shared.open(configURL)
    }
}
