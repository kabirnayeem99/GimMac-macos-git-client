import AppKit

@MainActor
final class SettingsRootViewController: NSSplitViewController {
    private let panes = SettingsPane.allCases
    private let environment: SettingsEnvironment
    private let sidebarController = SidebarViewController()
    private let detailContainer = NSViewController()

    /// Pane view controllers are built lazily and cached so state survives re-selection.
    private var paneControllers: [SettingsPane: NSViewController] = [:]
    private var currentPaneController: NSViewController?

    init(environment: SettingsEnvironment) {
        self.environment = environment
        super.init(nibName: nil, bundle: nil)
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func loadView() {
        super.loadView()
        detailContainer.view = NSView()
    }

    override func viewDidLoad() {
        super.viewDidLoad()

        let sidebarItem = NSSplitViewItem(sidebarWithViewController: sidebarController)
        sidebarItem.minimumThickness = 220
        sidebarItem.maximumThickness = 300
        sidebarItem.preferredThicknessFraction = 0.28
        sidebarItem.canCollapse = false
        addSplitViewItem(sidebarItem)

        let detailItem = NSSplitViewItem(viewController: detailContainer)
        detailItem.minimumThickness = 520
        detailItem.canCollapse = false
        addSplitViewItem(detailItem)

        sidebarController.onSelectionChanged = { [weak self] index in
            guard let self, panes.indices.contains(index) else { return }
            show(panes[index])
        }
        sidebarController.configure(with: panes)
        sidebarController.selectFirstItem()
    }

    private func show(_ pane: SettingsPane) {
        let controller = paneControllers[pane] ?? {
            let created = makeController(for: pane)
            paneControllers[pane] = created
            return created
        }()
        guard controller !== currentPaneController else { return }

        let outgoing = currentPaneController
        currentPaneController = controller

        detailContainer.addChild(controller)
        controller.view.translatesAutoresizingMaskIntoConstraints = false
        detailContainer.view.addSubview(controller.view)
        NSLayoutConstraint.activate([
            controller.view.topAnchor.constraint(equalTo: detailContainer.view.topAnchor),
            controller.view.leadingAnchor.constraint(equalTo: detailContainer.view.leadingAnchor),
            controller.view.trailingAnchor.constraint(equalTo: detailContainer.view.trailingAnchor),
            controller.view.bottomAnchor.constraint(equalTo: detailContainer.view.bottomAnchor)
        ])

        if let outgoing {
            NSView.crossfade(out: outgoing.view, in: controller.view) { [weak outgoing] in
                outgoing?.view.removeFromSuperview()
                outgoing?.removeFromParent()
            }
        } else {
            controller.view.alphaValue = 1
        }
    }

    private func makeController(for pane: SettingsPane) -> NSViewController {
        switch pane {
        case .git:
            return GitSettingsPaneController(viewModel: environment.makeGitViewModel())
        case .integrations:
            return IntegrationsSettingsPaneController(viewModel: environment.makeIntegrationsViewModel())
        case .appearance:
            return AppearanceSettingsPaneController(viewModel: environment.makeAppearanceViewModel())
        case .notifications:
            return NotificationsSettingsPaneController(viewModel: environment.makeNotificationsViewModel())
        case .prompts:
            return PromptsSettingsPaneController(viewModel: environment.makePromptsViewModel())
        case .advanced:
            return AdvancedSettingsPaneController(viewModel: environment.makeAdvancedViewModel())
        case .accessibility:
            return AccessibilitySettingsPaneController(viewModel: environment.makeAccessibilityViewModel())
        }
    }
}
