import AppKit

/// Integrations pane: external editor and shell selection, with optional custom
/// (path + arguments) integrations. Native equivalent of GitHub Desktop's
/// `Integrations` preferences panel.
@MainActor
final class IntegrationsSettingsPaneController: SettingsPaneViewController {
    private let viewModel: IntegrationsSettingsViewModel
    private static let customOptionTitle = "Configure custom…"

    init(viewModel: IntegrationsSettingsViewModel) {
        self.viewModel = viewModel
        super.init(nibName: nil, bundle: nil)
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }

    override func buildContent() {
        viewModel.reloadAvailableIntegrations()
        addHeader("Integrations")
        buildEditorSection()
        buildShellSection()
    }

    // MARK: - Editor

    private func buildEditorSection() {
        let names = viewModel.availableEditors.map(\.name)
        let titles = names + [Self.customOptionTitle]
        let selectedIndex: Int
        if viewModel.useCustomEditor {
            selectedIndex = titles.count - 1
        } else {
            selectedIndex = viewModel.availableEditors
                .firstIndex { $0.bundleIdentifier == viewModel.selectedEditorBundleID } ?? 0
        }

        var views: [NSView] = [
            labeledRow("Open with", control: makePopUp(titles: titles, selectedIndex: selectedIndex) { [weak self] index in
                guard let self else { return }
                if index == titles.count - 1 {
                    viewModel.useCustomEditor = true
                } else {
                    viewModel.useCustomEditor = false
                    viewModel.selectedEditorBundleID = viewModel.availableEditors[index].bundleIdentifier
                }
                rebuildWithFade()
            })
        ]

        if viewModel.availableEditors.isEmpty {
            views.append(makeNote("No supported editors found on this Mac."))
        }

        if viewModel.useCustomEditor {
            views.append(contentsOf: customIntegrationForm(
                integration: viewModel.customEditor,
                onChange: { [weak self] in self?.viewModel.customEditor = $0 }
            ))
        }

        addSection("External Editor", views: views)
    }

    // MARK: - Shell

    private func buildShellSection() {
        let names = viewModel.availableShells.map(\.name)
        let titles = names + [Self.customOptionTitle]
        let selectedIndex: Int
        if viewModel.useCustomShell {
            selectedIndex = titles.count - 1
        } else {
            selectedIndex = viewModel.availableShells
                .firstIndex { $0.bundleIdentifier == viewModel.selectedShellBundleID } ?? 0
        }

        var views: [NSView] = [
            labeledRow("Open with", control: makePopUp(titles: titles, selectedIndex: selectedIndex) { [weak self] index in
                guard let self else { return }
                if index == titles.count - 1 {
                    viewModel.useCustomShell = true
                } else {
                    viewModel.useCustomShell = false
                    viewModel.selectedShellBundleID = viewModel.availableShells[index].bundleIdentifier
                }
                rebuildWithFade()
            })
        ]

        if viewModel.availableShells.isEmpty {
            views.append(makeNote("No supported terminal apps found on this Mac."))
        }

        if viewModel.useCustomShell {
            views.append(contentsOf: customIntegrationForm(
                integration: viewModel.customShell,
                onChange: { [weak self] in self?.viewModel.customShell = $0 }
            ))
        }

        addSection("Shell", views: views)
    }

    // MARK: - Custom integration form

    /// Path + arguments form for a custom editor/shell. `%TARGET_PATH%` is
    /// substituted with the repository path at launch time.
    private func customIntegrationForm(
        integration: CustomIntegration,
        onChange: @escaping (CustomIntegration) -> Void
    ) -> [NSView] {
        var current = integration

        let pathField = makeTextField(text: integration.path, placeholder: "/Applications/MyEditor.app", width: 300) { path in
            current.path = path
            onChange(current)
        }

        let chooseButton = makeButton("Choose…") { [weak self] in
            guard let self, let url = self.chooseApplication() else { return }
            current.path = url.path
            current.bundleID = Bundle(url: url)?.bundleIdentifier
            pathField.stringValue = url.path
            onChange(current)
        }

        let pathRow = NSStackView()
        pathRow.orientation = .horizontal
        pathRow.spacing = 8
        pathRow.addArrangedSubview(pathField)
        pathRow.addArrangedSubview(chooseButton)

        let argsField = makeTextField(text: integration.arguments, placeholder: CustomIntegration.targetPathArgument, width: 300) { args in
            current.arguments = args
            onChange(current)
        }

        return [
            labeledRow("Path", control: pathRow),
            labeledRow("Arguments", control: argsField),
            makeNote("Use \(CustomIntegration.targetPathArgument) where the repository path should be inserted.")
        ]
    }

    private func chooseApplication() -> URL? {
        let panel = NSOpenPanel()
        panel.canChooseFiles = true
        panel.canChooseDirectories = false
        panel.allowsMultipleSelection = false
        panel.allowedContentTypes = [.application]
        panel.directoryURL = URL(fileURLWithPath: "/Applications")
        return panel.runModal() == .OK ? panel.url : nil
    }

    private func rebuildWithFade() {
        guard !AppKitMotion.reduceMotion else {
            rebuildContent()
            return
        }
        contentStack.animateAlpha(to: 0, duration: AppKitMotion.feedback) { [weak self] in
            self?.rebuildContent()
            self?.contentStack.layoutSubtreeIfNeeded()
            self?.contentStack.animateAlpha(to: 1, duration: AppKitMotion.feedback)
        }
    }
}
