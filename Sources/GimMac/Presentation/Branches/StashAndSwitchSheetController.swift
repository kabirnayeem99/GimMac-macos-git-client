import AppKit

/// Sheet shown before switching branches when the working tree is dirty.
/// Mirrors GitHub Desktop's `StashAndSwitchBranchDialog`.
@MainActor
final class StashAndSwitchSheetController {
    typealias Completion = (DirtyWorkingTreeAction) -> Void

    let viewController: NSViewController

    init(branch: Branch, dirtyFileCount: Int, completion: @escaping Completion) {
        self.viewController = StashAndSwitchSheetViewController(
            branch: branch,
            dirtyFileCount: dirtyFileCount,
            completion: completion
        )
    }
}

private final class StashAndSwitchSheetViewController: NSViewController {
    private let branch: Branch
    private let dirtyFileCount: Int
    private let completion: StashAndSwitchSheetController.Completion

    init(branch: Branch, dirtyFileCount: Int, completion: @escaping StashAndSwitchSheetController.Completion) {
        self.branch = branch
        self.dirtyFileCount = dirtyFileCount
        self.completion = completion
        super.init(nibName: nil, bundle: nil)
    }
    required init?(coder: NSCoder) { fatalError("init(coder:) is not supported") }

    override func loadView() {
        let container = NSView(frame: NSRect(x: 0, y: 0, width: 420, height: 180))
        self.view = container

        let title = NSTextField(labelWithString: "Switch Branch")
        title.font = NSFont.systemFont(ofSize: 14, weight: .semibold)
        title.translatesAutoresizingMaskIntoConstraints = false

        let fileWord = dirtyFileCount == 1 ? "change" : "changes"
        let body = NSTextField(wrappingLabelWithString:
            "You have \(dirtyFileCount) uncommitted \(fileWord) on the current branch. " +
            "How would you like to proceed before switching to '\(branch.name)'?"
        )
        body.translatesAutoresizingMaskIntoConstraints = false

        let stashButton = NSButton(title: "Stash Changes and Switch", target: self, action: #selector(stash(_:)))
        stashButton.translatesAutoresizingMaskIntoConstraints = false
        stashButton.bezelStyle = .rounded
        stashButton.keyEquivalent = "\r"

        let discardButton = NSButton(title: "Discard Changes and Switch", target: self, action: #selector(discard(_:)))
        discardButton.translatesAutoresizingMaskIntoConstraints = false
        discardButton.bezelStyle = .rounded
        discardButton.hasDestructiveAction = true

        let cancelButton = NSButton(title: "Cancel", target: self, action: #selector(cancel(_:)))
        cancelButton.translatesAutoresizingMaskIntoConstraints = false
        cancelButton.bezelStyle = .rounded
        cancelButton.keyEquivalent = "\u{1b}"

        for v in [title, body, stashButton, discardButton, cancelButton] {
            container.addSubview(v)
        }

        NSLayoutConstraint.activate([
            title.topAnchor.constraint(equalTo: container.topAnchor, constant: 16),
            title.leadingAnchor.constraint(equalTo: container.leadingAnchor, constant: 16),

            body.topAnchor.constraint(equalTo: title.bottomAnchor, constant: 8),
            body.leadingAnchor.constraint(equalTo: container.leadingAnchor, constant: 16),
            body.trailingAnchor.constraint(equalTo: container.trailingAnchor, constant: -16),

            stashButton.trailingAnchor.constraint(equalTo: container.trailingAnchor, constant: -16),
            stashButton.bottomAnchor.constraint(equalTo: container.bottomAnchor, constant: -16),

            discardButton.trailingAnchor.constraint(equalTo: stashButton.leadingAnchor, constant: -8),
            discardButton.bottomAnchor.constraint(equalTo: container.bottomAnchor, constant: -16),

            cancelButton.trailingAnchor.constraint(equalTo: discardButton.leadingAnchor, constant: -8),
            cancelButton.bottomAnchor.constraint(equalTo: container.bottomAnchor, constant: -16)
        ])
    }

    @objc private func stash(_ sender: Any?) {
        completion(.stashChanges)
        dismiss(nil)
    }
    @objc private func discard(_ sender: Any?) {
        completion(.discardChanges)
        dismiss(nil)
    }
    @objc private func cancel(_ sender: Any?) {
        completion(.cancel)
        dismiss(nil)
    }
}
