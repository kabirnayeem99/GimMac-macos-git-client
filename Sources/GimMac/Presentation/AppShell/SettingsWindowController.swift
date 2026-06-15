import AppKit

@MainActor
private enum SettingsPane: String, CaseIterable {
    case git = "Git"
    case integrations = "Integrations"
    case appearance = "Appearance"
    case notifications = "Notifications"
    case prompts = "Prompts"
    case advanced = "Advanced"
    case accessibility = "Accessibility"

    var symbolName: String {
        switch self {
        case .git: return "point.topleft.down.curvedto.point.bottomright.up"
        case .integrations: return "square.stack.3d.up"
        case .appearance: return "paintbrush"
        case .notifications: return "bell"
        case .prompts: return "questionmark.circle"
        case .advanced: return "gearshape.2"
        case .accessibility: return "figure.roll"
        }
    }
}

@MainActor
final class SettingsWindowController: NSWindowController {
    init(environment: SettingsEnvironment) {
        let rootViewController = SettingsRootViewController(environment: environment)
        let window = NSWindow(contentViewController: rootViewController)
        window.title = "Settings"
        window.setContentSize(NSSize(width: 960, height: 620))
        window.styleMask = [.titled, .closable, .resizable]
        window.identifier = NSUserInterfaceItemIdentifier("gimmac.settings.window")
        window.collectionBehavior.remove(.fullScreenPrimary)
        window.collectionBehavior.remove(.fullScreenAuxiliary)
        window.standardWindowButton(.zoomButton)?.isEnabled = false
        window.standardWindowButton(.miniaturizeButton)?.isEnabled = false
        super.init(window: window)
        shouldCascadeWindows = true
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
}

@MainActor
private final class SettingsRootViewController: NSSplitViewController {
    private let panes = SettingsPane.allCases
    private let environment: SettingsEnvironment
    private let sidebarController = SidebarViewController()
    private let detailContainer = NSViewController()

    /// Pane view controllers are built lazily and cached so state (e.g. loaded
    /// Git config, custom-integration forms) survives re-selection.
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

@MainActor
private final class SidebarViewController: NSViewController, NSTableViewDataSource, NSTableViewDelegate {
    var onSelectionChanged: ((Int) -> Void)?
    private var panes: [SettingsPane] = []

    private let tableView = NSTableView()

    override func loadView() {
        view = NSView()
        let scrollView = NSScrollView()
        scrollView.translatesAutoresizingMaskIntoConstraints = false
        scrollView.hasVerticalScroller = true

        let column = NSTableColumn(identifier: NSUserInterfaceItemIdentifier("settingsPaneColumn"))
        tableView.addTableColumn(column)
        tableView.headerView = nil
        tableView.rowHeight = 32
        tableView.delegate = self
        tableView.dataSource = self
        tableView.style = .sourceList
        scrollView.documentView = tableView

        view.addSubview(scrollView)
        NSLayoutConstraint.activate([
            scrollView.topAnchor.constraint(equalTo: view.topAnchor),
            scrollView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            scrollView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            scrollView.bottomAnchor.constraint(equalTo: view.bottomAnchor)
        ])
    }

    func configure(with panes: [SettingsPane]) {
        self.panes = panes
        tableView.reloadData()
    }

    func selectFirstItem() {
        guard !panes.isEmpty else { return }
        tableView.selectRowIndexes(IndexSet(integer: 0), byExtendingSelection: false)
        onSelectionChanged?(0)
    }

    func numberOfRows(in tableView: NSTableView) -> Int {
        panes.count
    }

    func tableView(_ tableView: NSTableView, viewFor tableColumn: NSTableColumn?, row: Int) -> NSView? {
        let pane = panes[row]
        let identifier = NSUserInterfaceItemIdentifier("settingsPaneCell")

        let cell = (tableView.makeView(withIdentifier: identifier, owner: self) as? NSTableCellView) ?? {
            let created = NSTableCellView()
            created.identifier = identifier

            let icon = NSImageView()
            icon.translatesAutoresizingMaskIntoConstraints = false
            icon.identifier = NSUserInterfaceItemIdentifier("icon")

            let label = NSTextField(labelWithString: "")
            label.translatesAutoresizingMaskIntoConstraints = false
            label.identifier = NSUserInterfaceItemIdentifier("label")

            created.addSubview(icon)
            created.addSubview(label)

            NSLayoutConstraint.activate([
                icon.leadingAnchor.constraint(equalTo: created.leadingAnchor, constant: 10),
                icon.centerYAnchor.constraint(equalTo: created.centerYAnchor),
                icon.widthAnchor.constraint(equalToConstant: 16),
                icon.heightAnchor.constraint(equalToConstant: 16),
                label.leadingAnchor.constraint(equalTo: icon.trailingAnchor, constant: 10),
                label.centerYAnchor.constraint(equalTo: created.centerYAnchor),
                label.trailingAnchor.constraint(equalTo: created.trailingAnchor, constant: -8)
            ])
            created.textField = label
            return created
        }()

        let icon = cell.subviews.first { $0.identifier?.rawValue == "icon" } as? NSImageView
        icon?.image = NSImage(systemSymbolName: pane.symbolName, accessibilityDescription: pane.rawValue)
        icon?.contentTintColor = .secondaryLabelColor
        cell.textField?.stringValue = pane.rawValue
        return cell
    }

    func tableViewSelectionDidChange(_ notification: Notification) {
        let selectedRow = tableView.selectedRow
        if selectedRow >= 0 {
            onSelectionChanged?(selectedRow)
        }
    }
}
