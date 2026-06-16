import AppKit
import Observation
import SwiftUI

/// Stash management sheet: lists every stash with apply / pop / drop actions.
///
/// Reads state from an injected `StashManagementViewModel` (protocol-typed
/// dependencies — never concrete services). Observation is set up via
/// `withObservationTracking` so the view re-renders whenever the VM publishes.
/// Mirrors the structure of `BranchesViewController`.
@MainActor
final class StashManagementViewController: NSViewController {

    private enum Column {
        static let message = NSUserInterfaceItemIdentifier("StashMessage")
        static let branch = NSUserInterfaceItemIdentifier("StashBranch")
        static let date = NSUserInterfaceItemIdentifier("StashDate")
    }

    private let viewModel: StashManagementViewModel

    private let titleLabel = NSTextField(labelWithString: "Stashes")
    private let tableView = NSTableView()
    private let scrollView = NSScrollView()
    private let emptyLabel = NSTextField(labelWithString: "No stashes")
    private let progressIndicator = NSProgressIndicator()
    private let loadingPlaceholderHost = NSHostingView(rootView: LoadingPlaceholder(title: "Loading stashes…"))
    private let applyButton = NSButton(title: "Apply", target: nil, action: nil)
    private let applyStatusImageView = NSImageView()
    private let popButton = NSButton(title: "Pop", target: nil, action: nil)
    private let popStatusImageView = NSImageView()
    private let dropButton = NSButton(title: "Drop", target: nil, action: nil)
    private let dropStatusImageView = NSImageView()
    private let doneButton = NSButton(title: "Done", target: nil, action: nil)

    private var renderedStashes: [StashEntry] = []

    private static let dateFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .short
        return formatter
    }()

    // MARK: - Init

    init(viewModel: StashManagementViewModel) {
        self.viewModel = viewModel
        super.init(nibName: nil, bundle: nil)
    }

    required init?(coder: NSCoder) { fatalError("init(coder:) is not supported") }

    // MARK: - Lifecycle

    override func loadView() {
        let container = NSView(frame: NSRect(x: 0, y: 0, width: 520, height: 420))
        container.autoresizingMask = [.width, .height]
        self.view = container
        buildLayout(in: container)
        configureTable()
    }

    override func viewDidAppear() {
        super.viewDidAppear()
        observe()
        Task { await viewModel.load() }
    }

    // MARK: - Layout

    private func buildLayout(in container: NSView) {
        titleLabel.translatesAutoresizingMaskIntoConstraints = false
        titleLabel.font = NSFont.systemFont(ofSize: 14, weight: .semibold)

        scrollView.translatesAutoresizingMaskIntoConstraints = false
        scrollView.hasVerticalScroller = true
        scrollView.borderType = .bezelBorder
        scrollView.documentView = tableView

        emptyLabel.translatesAutoresizingMaskIntoConstraints = false
        emptyLabel.textColor = .secondaryLabelColor
        emptyLabel.alignment = .center
        emptyLabel.isHidden = true

        loadingPlaceholderHost.translatesAutoresizingMaskIntoConstraints = false
        loadingPlaceholderHost.isHidden = true

        progressIndicator.translatesAutoresizingMaskIntoConstraints = false
        progressIndicator.style = .spinning
        progressIndicator.controlSize = .small
        progressIndicator.isDisplayedWhenStopped = false

        for button in [applyButton, popButton, dropButton, doneButton] {
            button.translatesAutoresizingMaskIntoConstraints = false
            button.bezelStyle = .rounded
            button.target = self
        }
        applyButton.action = #selector(applyTapped(_:))
        popButton.action = #selector(popTapped(_:))
        dropButton.action = #selector(dropTapped(_:))
        dropButton.hasDestructiveAction = true
        doneButton.action = #selector(doneTapped(_:))
        doneButton.keyEquivalent = "\r"

        for imageView in [applyStatusImageView, popStatusImageView, dropStatusImageView] {
            imageView.translatesAutoresizingMaskIntoConstraints = false
            imageView.contentTintColor = .systemGreen
            imageView.alphaValue = 0
            imageView.isHidden = true
        }

        for subview in [titleLabel, scrollView, emptyLabel, loadingPlaceholderHost, progressIndicator,
                        applyButton, popButton, dropButton, doneButton] {
            container.addSubview(subview)
        }
        for imageView in [applyStatusImageView, popStatusImageView, dropStatusImageView] {
            container.addSubview(imageView)
        }

        NSLayoutConstraint.activate([
            titleLabel.topAnchor.constraint(equalTo: container.topAnchor, constant: 16),
            titleLabel.leadingAnchor.constraint(equalTo: container.leadingAnchor, constant: 16),

            progressIndicator.centerYAnchor.constraint(equalTo: titleLabel.centerYAnchor),
            progressIndicator.trailingAnchor.constraint(equalTo: container.trailingAnchor, constant: -16),

            scrollView.topAnchor.constraint(equalTo: titleLabel.bottomAnchor, constant: 10),
            scrollView.leadingAnchor.constraint(equalTo: container.leadingAnchor, constant: 16),
            scrollView.trailingAnchor.constraint(equalTo: container.trailingAnchor, constant: -16),
            scrollView.bottomAnchor.constraint(equalTo: applyButton.topAnchor, constant: -12),

            emptyLabel.centerXAnchor.constraint(equalTo: scrollView.centerXAnchor),
            emptyLabel.centerYAnchor.constraint(equalTo: scrollView.centerYAnchor),

            loadingPlaceholderHost.topAnchor.constraint(equalTo: scrollView.topAnchor),
            loadingPlaceholderHost.leadingAnchor.constraint(equalTo: scrollView.leadingAnchor),
            loadingPlaceholderHost.trailingAnchor.constraint(equalTo: scrollView.trailingAnchor),
            loadingPlaceholderHost.bottomAnchor.constraint(equalTo: scrollView.bottomAnchor),

            applyButton.leadingAnchor.constraint(equalTo: container.leadingAnchor, constant: 16),
            applyButton.bottomAnchor.constraint(equalTo: container.bottomAnchor, constant: -16),

            applyStatusImageView.leadingAnchor.constraint(equalTo: applyButton.trailingAnchor, constant: 6),
            applyStatusImageView.centerYAnchor.constraint(equalTo: applyButton.centerYAnchor),
            applyStatusImageView.widthAnchor.constraint(equalToConstant: 14),
            applyStatusImageView.heightAnchor.constraint(equalToConstant: 14),

            popButton.leadingAnchor.constraint(equalTo: applyStatusImageView.trailingAnchor, constant: 12),
            popButton.centerYAnchor.constraint(equalTo: applyButton.centerYAnchor),

            popStatusImageView.leadingAnchor.constraint(equalTo: popButton.trailingAnchor, constant: 6),
            popStatusImageView.centerYAnchor.constraint(equalTo: popButton.centerYAnchor),
            popStatusImageView.widthAnchor.constraint(equalToConstant: 14),
            popStatusImageView.heightAnchor.constraint(equalToConstant: 14),

            dropButton.leadingAnchor.constraint(equalTo: popStatusImageView.trailingAnchor, constant: 12),
            dropButton.centerYAnchor.constraint(equalTo: applyButton.centerYAnchor),

            dropStatusImageView.leadingAnchor.constraint(equalTo: dropButton.trailingAnchor, constant: 6),
            dropStatusImageView.centerYAnchor.constraint(equalTo: dropButton.centerYAnchor),
            dropStatusImageView.widthAnchor.constraint(equalToConstant: 14),
            dropStatusImageView.heightAnchor.constraint(equalToConstant: 14),

            doneButton.trailingAnchor.constraint(equalTo: container.trailingAnchor, constant: -16),
            doneButton.centerYAnchor.constraint(equalTo: applyButton.centerYAnchor)
        ])
    }

    private func configureTable() {
        tableView.rowHeight = 22
        tableView.allowsMultipleSelection = false
        tableView.usesAlternatingRowBackgroundColors = true
        tableView.style = .plain
        tableView.delegate = self
        tableView.dataSource = self
        tableView.target = self
        tableView.doubleAction = #selector(applyTapped(_:))

        addColumn(Column.message, title: "Message", width: 240)
        addColumn(Column.branch, title: "Branch", width: 120)
        addColumn(Column.date, title: "Date", width: 130)
    }

    private func addColumn(_ id: NSUserInterfaceItemIdentifier, title: String, width: CGFloat) {
        let column = NSTableColumn(identifier: id)
        column.title = title
        column.width = width
        tableView.addTableColumn(column)
    }

    // MARK: - Observation

    private func observe() {
        withObservationTracking { [weak self] in
            guard let self else { return }
            _ = self.viewModel.stashes
            _ = self.viewModel.isLoading
            _ = self.viewModel.errorMessage
            _ = self.viewModel.activeAction
            _ = self.viewModel.completedAction
        } onChange: { [weak self] in
            Task { @MainActor in
                self?.render()
                self?.observe()
            }
        }
        render()
    }

    private func render() {
        if viewModel.isLoading {
            progressIndicator.startAnimation(nil)
        } else {
            progressIndicator.stopAnimation(nil)
        }

        if viewModel.stashes != renderedStashes {
            let selectedIDs = selectedStashIDs()
            let visibleOrigin = scrollView.contentView.bounds.origin
            let previousStashes = renderedStashes
            renderedStashes = viewModel.stashes
            let restoredSelection = tableView.animatedReload(
                old: previousStashes,
                new: renderedStashes,
                idKeyPath: \.id,
                preservingSelection: selectedIDs
            )
            tableView.selectRowIndexes(restoredSelection, byExtendingSelection: false)
            scrollView.contentView.scroll(to: visibleOrigin)
            scrollView.reflectScrolledClipView(scrollView.contentView)
        }

        loadingPlaceholderHost.isHidden = !viewModel.isLoading
        emptyLabel.isHidden = viewModel.isLoading || !renderedStashes.isEmpty
        updateButtonState()
        renderActionFeedback()

        if let message = viewModel.errorMessage, !message.isEmpty {
            presentErrorIfNeeded(message)
        }
    }

    private func updateButtonState() {
        let hasSelection = tableView.selectedRow >= 0 && renderedStashes.indices.contains(tableView.selectedRow)
        let actionsEnabled = hasSelection && !viewModel.isLoading && viewModel.activeAction == nil
        applyButton.isEnabled = actionsEnabled
        popButton.isEnabled = actionsEnabled
        dropButton.isEnabled = actionsEnabled

        let alpha: CGFloat = actionsEnabled ? 1 : 0.45
        applyButton.animateAlpha(to: alpha)
        popButton.animateAlpha(to: alpha)
        dropButton.animateAlpha(to: alpha)
    }

    private var presentedErrors: Set<String> = []

    @objc private func applyTapped(_ sender: Any?) {
        guard viewModel.activeAction == nil else { return }
        guard let entry = selectedStash() else { return }
        Task { await viewModel.apply(entry) }
    }

    @objc private func popTapped(_ sender: Any?) {
        guard viewModel.activeAction == nil else { return }
        guard let entry = selectedStash() else { return }
        Task { await viewModel.pop(entry) }
    }

    @objc private func dropTapped(_ sender: Any?) {
        guard viewModel.activeAction == nil else { return }
        guard let entry = selectedStash() else { return }
        let alert = NSAlert()
        alert.messageText = "Drop this stash?"
        alert.informativeText = "“\(entry.message)” will be permanently removed. This cannot be undone."
        alert.alertStyle = .warning
        alert.addButton(withTitle: "Drop")
        alert.addButton(withTitle: "Cancel")

        let perform: (NSApplication.ModalResponse) -> Void = { [weak self] response in
            guard response == .alertFirstButtonReturn else { return }
            Task { await self?.viewModel.drop(entry) }
        }

        if let window = view.window {
            alert.beginSheetModal(for: window, completionHandler: perform)
        } else {
            perform(alert.runModal())
        }
    }

    @objc private func doneTapped(_ sender: Any?) {
        dismiss(nil)
    }
}

private extension StashManagementViewController {
    func presentErrorIfNeeded(_ message: String) {
        guard !presentedErrors.contains(message) else { return }
        presentedErrors.insert(message)
        let alert = NSAlert()
        alert.messageText = "Stash operation failed"
        alert.informativeText = message
        alert.alertStyle = .warning
        alert.runModal()
        viewModel.errorMessage = nil
        presentedErrors.remove(message)
    }

    func selectedStash() -> StashEntry? {
        let row = tableView.selectedRow
        guard renderedStashes.indices.contains(row) else { return nil }
        return renderedStashes[row]
    }

    func selectedStashIDs() -> Set<String> {
        guard let selected = selectedStash() else { return [] }
        return [selected.id]
    }

    func renderActionFeedback() {
        updateStatusImageView(applyStatusImageView, active: viewModel.activeAction == .apply, completed: viewModel.completedAction == .apply)
        updateStatusImageView(popStatusImageView, active: viewModel.activeAction == .pop, completed: viewModel.completedAction == .pop)
        updateStatusImageView(dropStatusImageView, active: viewModel.activeAction == .drop, completed: viewModel.completedAction == .drop)
    }

    func updateStatusImageView(_ imageView: NSImageView, active: Bool, completed: Bool) {
        if completed {
            let image = NSImage(systemSymbolName: "checkmark.circle.fill", accessibilityDescription: "Completed")
            if let image {
                imageView.isHidden = false
                imageView.setSymbolImage(image)
                imageView.animateAlpha(to: 1)
            }
            return
        }

        if active {
            let image = NSImage(systemSymbolName: "ellipsis.circle", accessibilityDescription: "Working")
            if let image {
                imageView.isHidden = false
                imageView.image = image
                imageView.contentTintColor = .secondaryLabelColor
                imageView.animateAlpha(to: 1)
            }
            return
        }

        imageView.contentTintColor = .systemGreen
        imageView.animateAlpha(to: 0)
        if AppKitMotion.reduceMotion {
            imageView.isHidden = true
        } else {
            Task { @MainActor [weak imageView] in
                try? await Task.sleep(for: .seconds(AppKitMotion.feedback))
                imageView?.isHidden = true
            }
        }
    }
}

// MARK: - NSTableViewDataSource / Delegate

extension StashManagementViewController: NSTableViewDataSource, NSTableViewDelegate {
    func numberOfRows(in tableView: NSTableView) -> Int {
        renderedStashes.count
    }

    func tableView(_ tableView: NSTableView, viewFor tableColumn: NSTableColumn?, row: Int) -> NSView? {
        guard let tableColumn, renderedStashes.indices.contains(row) else { return nil }
        let entry = renderedStashes[row]
        let text: String
        switch tableColumn.identifier {
        case Column.message: text = entry.message
        case Column.branch: text = entry.branchName
        case Column.date: text = entry.createdAt.map { Self.dateFormatter.string(from: $0) } ?? "—"
        default: text = ""
        }
        return Self.makeCell(reuse: tableColumn.identifier, in: tableView, owner: self, text: text)
    }

    private static func makeCell(
        reuse identifier: NSUserInterfaceItemIdentifier,
        in tableView: NSTableView,
        owner: Any?,
        text: String
    ) -> NSTableCellView {
        let cell: NSTableCellView
        if let reused = tableView.makeView(withIdentifier: identifier, owner: owner) as? NSTableCellView {
            cell = reused
        } else {
            cell = NSTableCellView()
            let field = NSTextField(labelWithString: "")
            field.translatesAutoresizingMaskIntoConstraints = false
            field.lineBreakMode = .byTruncatingTail
            cell.addSubview(field)
            cell.textField = field
            cell.identifier = identifier
            NSLayoutConstraint.activate([
                field.leadingAnchor.constraint(equalTo: cell.leadingAnchor, constant: 2),
                field.trailingAnchor.constraint(equalTo: cell.trailingAnchor, constant: -2),
                field.centerYAnchor.constraint(equalTo: cell.centerYAnchor)
            ])
        }
        cell.textField?.stringValue = text
        return cell
    }

    func tableViewSelectionDidChange(_ notification: Notification) {
        updateButtonState()
    }
}
