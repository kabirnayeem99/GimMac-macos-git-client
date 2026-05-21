import AppKit

/// Confirmation sheet for branch deletion. Local + remote-tracking branches are
/// covered by the same UI — the host wires the right service call based on the
/// branch type.
@MainActor
final class DeleteBranchWindowController {
    typealias Completion = (_ alsoDeleteRemote: Bool) -> Void

    let viewController: NSViewController

    init(branch: Branch, completion: @escaping Completion) {
        self.viewController = DeleteBranchSheetViewController(branch: branch, completion: completion)
    }
}

private final class DeleteBranchSheetViewController: NSViewController {
    private let branch: Branch
    private let completion: DeleteBranchWindowController.Completion
    private let deleteRemoteCheckbox = NSButton(checkboxWithTitle: "Also delete remote tracking branch", target: nil, action: nil)

    init(branch: Branch, completion: @escaping DeleteBranchWindowController.Completion) {
        self.branch = branch
        self.completion = completion
        super.init(nibName: nil, bundle: nil)
    }
    required init?(coder: NSCoder) { fatalError("init(coder:) is not supported") }

    override func loadView() {
        let container = NSView(frame: NSRect(x: 0, y: 0, width: 380, height: 170))
        self.view = container

        let title = NSTextField(labelWithString: "Delete Branch")
        title.font = NSFont.systemFont(ofSize: 14, weight: .semibold)
        title.translatesAutoresizingMaskIntoConstraints = false

        let body = NSTextField(wrappingLabelWithString: "Are you sure you want to delete '\(branch.name)'? This action cannot be undone.")
        body.translatesAutoresizingMaskIntoConstraints = false

        deleteRemoteCheckbox.translatesAutoresizingMaskIntoConstraints = false
        deleteRemoteCheckbox.isHidden = !(branch.isLocal && branch.upstream != nil)
        deleteRemoteCheckbox.state = .off

        let deleteButton = NSButton(title: "Delete", target: self, action: #selector(confirm(_:)))
        deleteButton.translatesAutoresizingMaskIntoConstraints = false
        deleteButton.bezelStyle = .rounded
        deleteButton.keyEquivalent = "\r"
        deleteButton.hasDestructiveAction = true

        let cancelButton = NSButton(title: "Cancel", target: self, action: #selector(cancel(_:)))
        cancelButton.translatesAutoresizingMaskIntoConstraints = false
        cancelButton.bezelStyle = .rounded
        cancelButton.keyEquivalent = "\u{1b}"

        for v in [title, body, deleteRemoteCheckbox, deleteButton, cancelButton] {
            container.addSubview(v)
        }

        NSLayoutConstraint.activate([
            title.topAnchor.constraint(equalTo: container.topAnchor, constant: 16),
            title.leadingAnchor.constraint(equalTo: container.leadingAnchor, constant: 16),

            body.topAnchor.constraint(equalTo: title.bottomAnchor, constant: 8),
            body.leadingAnchor.constraint(equalTo: container.leadingAnchor, constant: 16),
            body.trailingAnchor.constraint(equalTo: container.trailingAnchor, constant: -16),

            deleteRemoteCheckbox.topAnchor.constraint(equalTo: body.bottomAnchor, constant: 12),
            deleteRemoteCheckbox.leadingAnchor.constraint(equalTo: container.leadingAnchor, constant: 16),

            deleteButton.trailingAnchor.constraint(equalTo: container.trailingAnchor, constant: -16),
            deleteButton.bottomAnchor.constraint(equalTo: container.bottomAnchor, constant: -16),

            cancelButton.trailingAnchor.constraint(equalTo: deleteButton.leadingAnchor, constant: -8),
            cancelButton.bottomAnchor.constraint(equalTo: container.bottomAnchor, constant: -16)
        ])
    }

    @objc private func confirm(_ sender: Any?) {
        completion(deleteRemoteCheckbox.state == .on)
        dismiss(nil)
    }

    @objc private func cancel(_ sender: Any?) {
        dismiss(nil)
    }
}
