import AppKit

/// Confirmation sheet for updating the current branch from the repository's
/// default branch. The user picks merge or rebase; the host VM performs the
/// actual Git operation.
@MainActor
final class UpdateFromDefaultSheetController {
    typealias Completion = (_ rebase: Bool) -> Void

    let viewController: NSViewController

    init(branch: Branch, completion: @escaping Completion) {
        self.viewController = UpdateFromDefaultSheetViewController(
            branch: branch,
            completion: completion
        )
    }
}

// MARK: - Sheet view controller

private final class UpdateFromDefaultSheetViewController: NSViewController {
    private let branch: Branch
    private let completion: UpdateFromDefaultSheetController.Completion

    private let mergeRadio = NSButton(radioButtonWithTitle: "Merge — creates a merge commit", target: nil, action: nil)
    private let rebaseRadio = NSButton(radioButtonWithTitle: "Rebase — rewrites history on top of default branch", target: nil, action: nil)
    private let updateButton = NSButton(title: "Update Branch", target: nil, action: nil)

    init(branch: Branch, completion: @escaping UpdateFromDefaultSheetController.Completion) {
        self.branch = branch
        self.completion = completion
        super.init(nibName: nil, bundle: nil)
    }

    required init?(coder: NSCoder) { fatalError("init(coder:) is not supported") }

    override func loadView() {
        let container = NSView(frame: NSRect(x: 0, y: 0, width: 420, height: 210))
        self.view = container

        let title = NSTextField(labelWithString: "Update from Default Branch")
        title.font = NSFont.systemFont(ofSize: 14, weight: .semibold)
        title.translatesAutoresizingMaskIntoConstraints = false

        let body = NSTextField(
            wrappingLabelWithString:
                "Bring '\(branch.name)' up to date by integrating changes from the " +
                "repository's default branch (origin/HEAD or main)."
        )
        body.translatesAutoresizingMaskIntoConstraints = false

        mergeRadio.translatesAutoresizingMaskIntoConstraints = false
        mergeRadio.state = .on
        mergeRadio.target = self
        mergeRadio.action = #selector(strategyChanged(_:))

        rebaseRadio.translatesAutoresizingMaskIntoConstraints = false
        rebaseRadio.state = .off
        rebaseRadio.target = self
        rebaseRadio.action = #selector(strategyChanged(_:))

        updateButton.translatesAutoresizingMaskIntoConstraints = false
        updateButton.bezelStyle = .rounded
        updateButton.keyEquivalent = "\r"
        updateButton.target = self
        updateButton.action = #selector(update(_:))

        let cancelButton = NSButton(title: "Cancel", target: self, action: #selector(cancel(_:)))
        cancelButton.translatesAutoresizingMaskIntoConstraints = false
        cancelButton.bezelStyle = .rounded
        cancelButton.keyEquivalent = "\u{1b}"

        for v in [title, body, mergeRadio, rebaseRadio, updateButton, cancelButton] {
            container.addSubview(v)
        }

        NSLayoutConstraint.activate([
            title.topAnchor.constraint(equalTo: container.topAnchor, constant: 16),
            title.leadingAnchor.constraint(equalTo: container.leadingAnchor, constant: 16),

            body.topAnchor.constraint(equalTo: title.bottomAnchor, constant: 8),
            body.leadingAnchor.constraint(equalTo: container.leadingAnchor, constant: 16),
            body.trailingAnchor.constraint(equalTo: container.trailingAnchor, constant: -16),

            mergeRadio.topAnchor.constraint(equalTo: body.bottomAnchor, constant: 12),
            mergeRadio.leadingAnchor.constraint(equalTo: container.leadingAnchor, constant: 16),

            rebaseRadio.topAnchor.constraint(equalTo: mergeRadio.bottomAnchor, constant: 6),
            rebaseRadio.leadingAnchor.constraint(equalTo: container.leadingAnchor, constant: 16),

            updateButton.trailingAnchor.constraint(equalTo: container.trailingAnchor, constant: -16),
            updateButton.bottomAnchor.constraint(equalTo: container.bottomAnchor, constant: -16),

            cancelButton.trailingAnchor.constraint(equalTo: updateButton.leadingAnchor, constant: -8),
            cancelButton.bottomAnchor.constraint(equalTo: container.bottomAnchor, constant: -16)
        ])
    }

    @objc private func strategyChanged(_ sender: NSButton) {
        if sender === mergeRadio {
            mergeRadio.state = .on
            rebaseRadio.state = .off
        } else {
            mergeRadio.state = .off
            rebaseRadio.state = .on
        }
    }

    @objc private func update(_ sender: Any?) {
        let rebase = rebaseRadio.state == .on
        completion(rebase)
        dismiss(nil)
    }

    @objc private func cancel(_ sender: Any?) {
        dismiss(nil)
    }
}
