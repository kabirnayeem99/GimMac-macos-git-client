import AppKit

@MainActor
final class SidebarViewController: NSViewController, NSTableViewDataSource, NSTableViewDelegate {
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
