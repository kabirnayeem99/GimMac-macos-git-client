import AppKit

@MainActor
final class MainSplitViewController: NSSplitViewController {
    private let viewModel: RepositoryStoreViewModel
    private var observationTask: Task<Void, Never>?

    private let repositoryButton = NSButton(title: "Open Repository", target: nil, action: nil)
    private let branchLabel = NSTextField(labelWithString: "No repository selected")
    private let statusLabel = NSTextField(labelWithString: "")

    init(viewModel: RepositoryStoreViewModel) {
        self.viewModel = viewModel
        super.init(nibName: nil, bundle: nil)
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        splitView.dividerStyle = .thin

        setupHeader()
        setupSplitLayout()
        bindViewModel()
        applyUITestRepositoryIfPresent()
    }

    private func setupHeader() {
        let header = NSStackView()
        header.orientation = .horizontal
        header.spacing = 12
        header.alignment = .centerY
        header.translatesAutoresizingMaskIntoConstraints = false

        repositoryButton.target = self
        repositoryButton.action = #selector(openRepositoryTapped)
        repositoryButton.identifier = NSUserInterfaceItemIdentifier("openRepositoryButton")
        repositoryButton.setAccessibilityIdentifier("openRepositoryButton")

        branchLabel.identifier = NSUserInterfaceItemIdentifier("branchLabel")
        branchLabel.setAccessibilityIdentifier("branchLabel")
        statusLabel.textColor = .secondaryLabelColor
        statusLabel.identifier = NSUserInterfaceItemIdentifier("statusLabel")
        statusLabel.setAccessibilityIdentifier("statusLabel")

        header.addArrangedSubview(repositoryButton)
        header.addArrangedSubview(branchLabel)
        header.addArrangedSubview(statusLabel)
        view.addSubview(header)

        NSLayoutConstraint.activate([
            header.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 12),
            header.trailingAnchor.constraint(lessThanOrEqualTo: view.trailingAnchor, constant: -12),
            header.topAnchor.constraint(equalTo: view.topAnchor, constant: 10)
        ])
    }

    private func setupSplitLayout() {
        addSplitPane(title: "Repositories", identifier: "repoPane")
        addSplitPane(title: "Changes", identifier: "changesPane")
        addSplitPane(title: "Diff", identifier: "diffPane")
        addSplitPane(title: "Commit", identifier: "commitPane")

        splitViewItems[0].minimumThickness = 180
        splitViewItems[1].minimumThickness = 200
        splitViewItems[2].minimumThickness = 320
        splitViewItems[3].minimumThickness = 220

        splitView.translatesAutoresizingMaskIntoConstraints = false
        NSLayoutConstraint.activate([
            splitView.topAnchor.constraint(equalTo: view.topAnchor, constant: 44),
            splitView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            splitView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            splitView.bottomAnchor.constraint(equalTo: view.bottomAnchor)
        ])
    }

    private func addSplitPane(title: String, identifier: String) {
        let vc = NSViewController()
        let label = NSTextField(labelWithString: title)
        label.font = NSFont.systemFont(ofSize: 20, weight: .semibold)
        label.translatesAutoresizingMaskIntoConstraints = false
        vc.view = NSView()
        vc.view.addSubview(label)
        vc.view.identifier = NSUserInterfaceItemIdentifier(identifier)
        NSLayoutConstraint.activate([
            label.centerXAnchor.constraint(equalTo: vc.view.centerXAnchor),
            label.centerYAnchor.constraint(equalTo: vc.view.centerYAnchor)
        ])
        let item = NSSplitViewItem(viewController: vc)
        addSplitViewItem(item)
    }

    private func bindViewModel() {
        observationTask = Task { [weak self] in
            guard let self else { return }
            while !Task.isCancelled {
                self.branchLabel.stringValue = self.viewModel.repositoryState.branchDisplayText
                if self.viewModel.isLoading {
                    self.statusLabel.stringValue = "Loading repository..."
                } else if let error = self.viewModel.errorMessage {
                    self.statusLabel.stringValue = error
                } else if let repo = self.viewModel.selectedRepository {
                    self.statusLabel.stringValue = repo.displayName
                } else {
                    self.statusLabel.stringValue = ""
                }
                try? await Task.sleep(nanoseconds: 200_000_000)
            }
        }
    }

    private func applyUITestRepositoryIfPresent() {
        let environment = ProcessInfo.processInfo.environment
        guard let path = environment["GIMMAC_UI_TEST_REPO_PATH"], !path.isEmpty else {
            return
        }
        Task { [weak self] in
            await self?.viewModel.selectRepository(at: URL(fileURLWithPath: path, isDirectory: true))
        }
    }

    @objc
    private func openRepositoryTapped() {
        let panel = NSOpenPanel()
        panel.canChooseFiles = false
        panel.canChooseDirectories = true
        panel.allowsMultipleSelection = false
        panel.prompt = "Open"
        panel.message = "Select a local Git repository."

        guard let window = view.window else {
            return
        }

        panel.beginSheetModal(for: window) { [weak self] response in
            guard response == .OK, let url = panel.url else {
                return
            }
            Task { [weak self] in
                await self?.viewModel.selectRepository(at: url)
            }
        }
    }

    deinit {
        observationTask?.cancel()
    }
}
