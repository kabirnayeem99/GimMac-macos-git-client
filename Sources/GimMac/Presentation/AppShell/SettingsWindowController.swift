import AppKit

@MainActor
private enum SettingsPane: String, CaseIterable {
    case integrations = "Integrations"
    case copilot = "Copilot"
    case git = "Git"
    case appearance = "Appearance"
    case notifications = "Notifications"
    case prompts = "Prompts"
    case advanced = "Advanced"
    case accessibility = "Accessibility"

    var symbolName: String {
        switch self {
        case .integrations: return "square.stack.3d.up"
        case .copilot: return "sparkles"
        case .git: return "point.topleft.down.curvedto.point.bottomright.up"
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
    init() {
        let rootViewController = SettingsRootViewController()
        let window = NSWindow(contentViewController: rootViewController)
        window.title = "Settings"
        window.setContentSize(NSSize(width: 960, height: 620))
        window.styleMask = [.titled, .closable]
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
    private let supportsCopilot = false
    private lazy var panes: [SettingsPane] = {
        SettingsPane.allCases.filter { supportsCopilot || $0 != .copilot }
    }()

    private let sidebarController = SidebarViewController()
    private let detailController = SettingsDetailViewController()

    override func viewDidLoad() {
        super.viewDidLoad()

        let sidebarItem = NSSplitViewItem(sidebarWithViewController: sidebarController)
        sidebarItem.minimumThickness = 220
        sidebarItem.maximumThickness = 300
        sidebarItem.preferredThicknessFraction = 0.28
        sidebarItem.canCollapse = false
        addSplitViewItem(sidebarItem)

        let detailItem = NSSplitViewItem(viewController: detailController)
        detailItem.minimumThickness = 520
        detailItem.canCollapse = false
        addSplitViewItem(detailItem)

        sidebarController.onSelectionChanged = { [weak self] index in
            guard let self, panes.indices.contains(index) else { return }
            detailController.configure(for: panes[index])
        }
        sidebarController.configure(with: panes)
        detailController.configure(for: panes.first ?? .integrations)
        sidebarController.selectFirstItem()
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
        tableView.target = self
        tableView.action = #selector(selectionDidChange)
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

    @objc
    private func selectionDidChange() {
        onSelectionChanged?(tableView.selectedRow)
    }
}

@MainActor
private final class FlippedStackView: NSStackView {
    override var isFlipped: Bool { true }
}

@MainActor
private final class SettingsDetailViewController: NSViewController {
    private let contentStack = FlippedStackView()
    private let scrollView = NSScrollView()

    override func loadView() {
        view = NSView()
        view.translatesAutoresizingMaskIntoConstraints = false

        scrollView.translatesAutoresizingMaskIntoConstraints = false
        scrollView.hasVerticalScroller = true
        scrollView.drawsBackground = false
        scrollView.autohidesScrollers = true

        contentStack.orientation = .vertical
        contentStack.alignment = .leading
        contentStack.spacing = 16
        contentStack.edgeInsets = NSEdgeInsets(top: 24, left: 24, bottom: 24, right: 24)
        contentStack.translatesAutoresizingMaskIntoConstraints = false

        scrollView.documentView = contentStack
        view.addSubview(scrollView)

        NSLayoutConstraint.activate([
            scrollView.topAnchor.constraint(equalTo: view.topAnchor),
            scrollView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            scrollView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            scrollView.bottomAnchor.constraint(equalTo: view.bottomAnchor),

            contentStack.topAnchor.constraint(equalTo: scrollView.contentView.topAnchor),
            contentStack.leadingAnchor.constraint(equalTo: scrollView.contentView.leadingAnchor),
            contentStack.trailingAnchor.constraint(equalTo: scrollView.contentView.trailingAnchor),
            contentStack.bottomAnchor.constraint(lessThanOrEqualTo: scrollView.contentView.bottomAnchor)
        ])
    }

    func configure(for pane: SettingsPane) {
        contentStack.arrangedSubviews.forEach { $0.removeFromSuperview() }
        contentStack.addArrangedSubview(makeHeader(title: pane.rawValue))

        switch pane {
        case .integrations:
            addGroup("Integrations", rows: [
                .popUp("External Editor", ["None", "Xcode", "VS Code", "Nova"]),
                .popUp("Shell / terminal", ["Terminal.app", "iTerm2"]),
                .check("Enable custom editor"),
                .text("Custom editor path"),
                .check("Enable custom shell"),
                .text("Custom shell path")
            ])
        case .copilot:
            addGroup("Copilot", rows: [
                .popUp("Models", ["GPT-5.2", "GPT-5.4"]),
                .popUp("Providers", ["OpenAI", "Local Provider"]),
                .popUp("Commit message generation model", ["GPT-5.2", "GPT-5.4"]),
                .button("Add custom provider")
            ])
        case .git:
            addGroup("Author", rows: [.text("Name"), .text("Email")])
            addGroup("Default branch", rows: [.text("Default branch name for new repositories")])
            addGroup("Hooks", rows: [
                .check("Load shell environment for Git hooks"),
                .check("Cache hook environment variables")
            ])
        case .appearance:
            addGroup("Theme", rows: [.popUp("Theme", ["System", "Light", "Dark"])])
            addGroup("Formatting", rows: [
                .popUp("Date format", ["Locale default", "YYYY-MM-DD", "MM/DD/YYYY"]),
                .popUp("Time format", ["Locale default", "24-hour", "12-hour"]),
                .popUp("Number format", ["Locale default", "1,234.56", "1 234,56"]),
                .check("Prefer absolute dates")
            ])
            addGroup("Diff", rows: [.stepper("Tab size", value: 4)])
        case .notifications:
            addGroup("Notifications", rows: [
                .check("Enable desktop notifications"),
                .note("Permission/settings hints")
            ])
        case .prompts:
            addGroup("Prompts", rows: [
                .check("Confirmation dialogs before destructive actions"),
                .popUp("When switching branches with uncommitted changes", ["Ask every time", "Stash automatically", "Block switch"]),
                .check("Commit length warning")
            ])
        case .advanced:
            addGroup("Advanced", rows: [
                .check("Background repository indicators"),
                .check("Usage stats"),
                .button("Network and credentials"),
                .button("Git Credential Manager"),
                .note("Windows OpenSSH option appears on Windows only")
            ])
        case .accessibility:
            addGroup("Accessibility", rows: [
                .check("Underline links"),
                .check("Show check marks beside diff line numbers")
            ])
        }
    }

    private enum Row {
        case text(String)
        case popUp(String, [String])
        case check(String)
        case stepper(String, value: Int)
        case button(String)
        case note(String)
    }

    private func makeHeader(title: String) -> NSView {
        let label = NSTextField(labelWithString: title)
        label.font = .systemFont(ofSize: 28, weight: .bold)
        return label
    }

    private func addGroup(_ title: String, rows: [Row]) {
        let container = NSStackView()
        container.orientation = .vertical
        container.alignment = .leading
        container.spacing = 10

        let groupTitle = NSTextField(labelWithString: title)
        groupTitle.font = .systemFont(ofSize: 15, weight: .semibold)
        container.addArrangedSubview(groupTitle)

        for row in rows {
            container.addArrangedSubview(makeRow(row))
        }

        container.setContentHuggingPriority(.defaultHigh, for: .vertical)
        contentStack.addArrangedSubview(container)
    }

    private func makeRow(_ row: Row) -> NSView {
        switch row {
        case .text(let labelText):
            let stack = NSStackView()
            stack.orientation = .horizontal
            stack.spacing = 12
            stack.addArrangedSubview(fixedLabel(labelText))
            let field = NSTextField(string: "")
            field.placeholderString = labelText
            field.controlSize = .large
            field.translatesAutoresizingMaskIntoConstraints = false
            field.widthAnchor.constraint(equalToConstant: 340).isActive = true
            stack.addArrangedSubview(field)
            return stack
        case .popUp(let labelText, let values):
            let stack = NSStackView()
            stack.orientation = .horizontal
            stack.spacing = 12
            stack.addArrangedSubview(fixedLabel(labelText))
            let popup = NSPopUpButton()
            popup.addItems(withTitles: values)
            popup.translatesAutoresizingMaskIntoConstraints = false
            popup.widthAnchor.constraint(equalToConstant: 260).isActive = true
            stack.addArrangedSubview(popup)
            return stack
        case .check(let labelText):
            return NSButton(checkboxWithTitle: labelText, target: nil, action: nil)
        case .stepper(let labelText, let value):
            let stack = NSStackView()
            stack.orientation = .horizontal
            stack.spacing = 12
            stack.addArrangedSubview(fixedLabel(labelText))
            let field = NSTextField(labelWithString: "\(value)")
            field.alignment = .center
            field.translatesAutoresizingMaskIntoConstraints = false
            field.widthAnchor.constraint(equalToConstant: 36).isActive = true
            let stepper = NSStepper()
            stepper.integerValue = value
            stack.addArrangedSubview(field)
            stack.addArrangedSubview(stepper)
            return stack
        case .button(let title):
            return NSButton(title: title, target: nil, action: nil)
        case .note(let text):
            let label = NSTextField(labelWithString: text)
            label.textColor = .secondaryLabelColor
            return label
        }
    }

    private func fixedLabel(_ text: String) -> NSTextField {
        let label = NSTextField(labelWithString: text)
        label.translatesAutoresizingMaskIntoConstraints = false
        label.widthAnchor.constraint(equalToConstant: 280).isActive = true
        return label
    }
}
