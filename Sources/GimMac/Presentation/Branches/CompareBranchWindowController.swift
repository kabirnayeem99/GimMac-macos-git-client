import AppKit

/// Sheet that shows ahead/behind commit counts and the diverging commits
/// between a base branch (current) and a compare branch (selected).
///
/// The comparison is kicked off immediately on `viewDidAppear` using the
/// injected `BranchCompareProviding` service — no VM layer needed for a
/// read-only, short-lived sheet.
@MainActor
final class CompareBranchWindowController {
    let viewController: NSViewController

    init(
        baseBranch: Branch,
        compareBranch: Branch,
        compareProvider: BranchCompareProviding,
        repositoryURL: URL
    ) {
        self.viewController = CompareBranchSheetViewController(
            baseBranch: baseBranch,
            compareBranch: compareBranch,
            compareProvider: compareProvider,
            repositoryURL: repositoryURL
        )
    }
}

// MARK: - Sheet view controller

private final class CompareBranchSheetViewController: NSViewController {
    private let baseBranch: Branch
    private let compareBranch: Branch
    private let compareProvider: BranchCompareProviding
    private let repositoryURL: URL

    private let spinner = NSProgressIndicator()
    private let aheadBehindLabel = NSTextField(labelWithString: "")
    private let tableView = NSTableView()
    private let scrollView = NSScrollView()
    private let doneButton = NSButton(title: "Done", target: nil, action: nil)

    private var commits: [Commit] = []
    private var comparisonTask: Task<Void, Never>?

    init(
        baseBranch: Branch,
        compareBranch: Branch,
        compareProvider: BranchCompareProviding,
        repositoryURL: URL
    ) {
        self.baseBranch = baseBranch
        self.compareBranch = compareBranch
        self.compareProvider = compareProvider
        self.repositoryURL = repositoryURL
        super.init(nibName: nil, bundle: nil)
    }

    required init?(coder: NSCoder) { fatalError("init(coder:) is not supported") }

    // MARK: - Layout

    override func loadView() {
        let container = NSView(frame: NSRect(x: 0, y: 0, width: 460, height: 360))
        self.view = container

        let title = NSTextField(labelWithString: "Compare Branches")
        title.font = NSFont.systemFont(ofSize: 14, weight: .semibold)
        title.translatesAutoresizingMaskIntoConstraints = false

        let subtitle = NSTextField(
            labelWithString: "\(compareBranch.name)  ←  \(baseBranch.name)"
        )
        subtitle.font = NSFont.monospacedSystemFont(ofSize: 12, weight: .regular)
        subtitle.textColor = .secondaryLabelColor
        subtitle.translatesAutoresizingMaskIntoConstraints = false

        aheadBehindLabel.font = NSFont.systemFont(ofSize: 12)
        aheadBehindLabel.translatesAutoresizingMaskIntoConstraints = false

        spinner.style = .spinning
        spinner.controlSize = .small
        spinner.isDisplayedWhenStopped = false
        spinner.translatesAutoresizingMaskIntoConstraints = false

        scrollView.translatesAutoresizingMaskIntoConstraints = false
        scrollView.hasVerticalScroller = true
        scrollView.borderType = .bezelBorder
        scrollView.documentView = tableView

        tableView.headerView = nil
        tableView.rowHeight = 40
        tableView.allowsMultipleSelection = false
        tableView.gridStyleMask = []
        tableView.style = .plain
        tableView.backgroundColor = .clear
        tableView.dataSource = self
        tableView.delegate = self

        let shaColumn = NSTableColumn(identifier: NSUserInterfaceItemIdentifier("SHA"))
        shaColumn.width = 60
        tableView.addTableColumn(shaColumn)

        let summaryColumn = NSTableColumn(identifier: NSUserInterfaceItemIdentifier("Summary"))
        summaryColumn.resizingMask = .autoresizingMask
        tableView.addTableColumn(summaryColumn)

        doneButton.translatesAutoresizingMaskIntoConstraints = false
        doneButton.bezelStyle = .rounded
        doneButton.keyEquivalent = "\r"
        doneButton.target = self
        doneButton.action = #selector(done(_:))

        for v in [title, subtitle, aheadBehindLabel, spinner, scrollView, doneButton] {
            container.addSubview(v)
        }

        NSLayoutConstraint.activate([
            title.topAnchor.constraint(equalTo: container.topAnchor, constant: 16),
            title.leadingAnchor.constraint(equalTo: container.leadingAnchor, constant: 16),

            subtitle.topAnchor.constraint(equalTo: title.bottomAnchor, constant: 4),
            subtitle.leadingAnchor.constraint(equalTo: container.leadingAnchor, constant: 16),

            aheadBehindLabel.topAnchor.constraint(equalTo: subtitle.bottomAnchor, constant: 8),
            aheadBehindLabel.leadingAnchor.constraint(equalTo: container.leadingAnchor, constant: 16),

            spinner.centerYAnchor.constraint(equalTo: aheadBehindLabel.centerYAnchor),
            spinner.leadingAnchor.constraint(equalTo: container.leadingAnchor, constant: 16),

            scrollView.topAnchor.constraint(equalTo: aheadBehindLabel.bottomAnchor, constant: 8),
            scrollView.leadingAnchor.constraint(equalTo: container.leadingAnchor, constant: 16),
            scrollView.trailingAnchor.constraint(equalTo: container.trailingAnchor, constant: -16),
            scrollView.bottomAnchor.constraint(equalTo: doneButton.topAnchor, constant: -12),

            doneButton.trailingAnchor.constraint(equalTo: container.trailingAnchor, constant: -16),
            doneButton.bottomAnchor.constraint(equalTo: container.bottomAnchor, constant: -16)
        ])
    }

    override func viewDidAppear() {
        super.viewDidAppear()
        comparisonTask?.cancel()
        comparisonTask = Task { [weak self] in
            await self?.runComparison()
        }
    }

    override func viewWillDisappear() {
        comparisonTask?.cancel()
        comparisonTask = nil
        super.viewWillDisappear()
    }

    // MARK: - Comparison

    private func runComparison() async {
        spinner.startAnimation(nil)
        aheadBehindLabel.stringValue = ""
        aheadBehindLabel.textColor = .labelColor
        defer {
            spinner.stopAnimation(nil)
            if Task.isCancelled {
                comparisonTask = nil
            }
        }

        do {
            let result = try await compareProvider.compareBranches(
                base: baseBranch,
                compare: compareBranch,
                in: repositoryURL
            )
            guard !Task.isCancelled else { return }
            let ab = result.aheadBehind
            aheadBehindLabel.stringValue =
                "\(compareBranch.name) is \(ab.ahead) ahead, \(ab.behind) behind \(baseBranch.name)"
            commits = result.commits
            tableView.reloadData()
        } catch {
            guard !Task.isCancelled else { return }
            aheadBehindLabel.stringValue = error.localizedDescription
            aheadBehindLabel.textColor = .systemRed
        }
        comparisonTask = nil
    }

    @objc private func done(_ sender: Any?) {
        dismiss(nil)
    }
}

// MARK: - Table

extension CompareBranchSheetViewController: NSTableViewDataSource, NSTableViewDelegate {
    func numberOfRows(in tableView: NSTableView) -> Int { commits.count }

    func tableView(_ tableView: NSTableView, viewFor tableColumn: NSTableColumn?, row: Int) -> NSView? {
        guard commits.indices.contains(row) else { return nil }
        let commit = commits[row]

        let identifier = tableColumn?.identifier ?? NSUserInterfaceItemIdentifier("Cell")
        let cell: NSTableCellView
        if let reused = tableView.makeView(withIdentifier: identifier, owner: self) as? NSTableCellView {
            cell = reused
        } else {
            cell = NSTableCellView()
            cell.identifier = identifier
            let tf = NSTextField(labelWithString: "")
            tf.translatesAutoresizingMaskIntoConstraints = false
            cell.addSubview(tf)
            cell.textField = tf
            NSLayoutConstraint.activate([
                tf.leadingAnchor.constraint(equalTo: cell.leadingAnchor, constant: 4),
                tf.trailingAnchor.constraint(equalTo: cell.trailingAnchor, constant: -4),
                tf.centerYAnchor.constraint(equalTo: cell.centerYAnchor)
            ])
        }

        switch tableColumn?.identifier.rawValue {
        case "SHA":
            cell.textField?.stringValue = commit.shortHash
            cell.textField?.font = NSFont.monospacedSystemFont(ofSize: 11, weight: .regular)
            cell.textField?.textColor = .secondaryLabelColor
        default:
            cell.textField?.stringValue = commit.summary
            cell.textField?.font = NSFont.systemFont(ofSize: 12)
            cell.textField?.textColor = .labelColor
        }

        return cell
    }
}
