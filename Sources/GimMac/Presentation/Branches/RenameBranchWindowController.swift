import AppKit

/// Sheet for renaming a local branch. Live-validates the new name; warns when
/// the branch has an upstream (remote rename is not performed automatically).
@MainActor
final class RenameBranchWindowController {
    typealias Completion = (_ newName: String, _ force: Bool) -> Void

    let viewController: NSViewController

    init(branch: Branch, existingNames: [String], completion: @escaping Completion) {
        self.viewController = RenameBranchSheetViewController(
            branch: branch,
            existingNames: existingNames,
            completion: completion
        )
    }
}

private final class RenameBranchSheetViewController: NSViewController {
    private let branch: Branch
    private let existingNames: [String]
    private let completion: RenameBranchWindowController.Completion

    private let nameField = NSTextField()
    private let validationLabel = NSTextField(labelWithString: "")
    private let renameButton = NSButton(title: "Rename", target: nil, action: nil)

    init(branch: Branch, existingNames: [String], completion: @escaping RenameBranchWindowController.Completion) {
        self.branch = branch
        self.existingNames = existingNames.filter { $0 != branch.name }
        self.completion = completion
        super.init(nibName: nil, bundle: nil)
    }
    required init?(coder: NSCoder) { fatalError("init(coder:) is not supported") }

    override func loadView() {
        let container = NSView(frame: NSRect(x: 0, y: 0, width: 380, height: 200))
        self.view = container

        let title = NSTextField(labelWithString: "Rename Branch")
        title.font = NSFont.systemFont(ofSize: 14, weight: .semibold)
        title.translatesAutoresizingMaskIntoConstraints = false

        let currentLabel = NSTextField(labelWithString: "Current: \(branch.name)")
        currentLabel.translatesAutoresizingMaskIntoConstraints = false
        currentLabel.lineBreakMode = .byTruncatingMiddle

        let newLabel = NSTextField(labelWithString: "New name")
        newLabel.translatesAutoresizingMaskIntoConstraints = false

        nameField.translatesAutoresizingMaskIntoConstraints = false
        nameField.stringValue = branch.name
        nameField.delegate = self

        validationLabel.font = NSFont.systemFont(ofSize: 11)
        validationLabel.textColor = .systemRed
        validationLabel.translatesAutoresizingMaskIntoConstraints = false

        let warningLabel = NSTextField(wrappingLabelWithString: "")
        warningLabel.font = NSFont.systemFont(ofSize: 11)
        warningLabel.textColor = .secondaryLabelColor
        warningLabel.translatesAutoresizingMaskIntoConstraints = false
        if branch.upstream != nil {
            warningLabel.stringValue = "This branch tracks \(branch.upstream ?? ""). The remote branch will not be renamed."
        }

        renameButton.translatesAutoresizingMaskIntoConstraints = false
        renameButton.bezelStyle = .rounded
        renameButton.keyEquivalent = "\r"
        renameButton.target = self
        renameButton.action = #selector(rename(_:))
        renameButton.isEnabled = false

        let cancelButton = NSButton(title: "Cancel", target: self, action: #selector(cancel(_:)))
        cancelButton.translatesAutoresizingMaskIntoConstraints = false
        cancelButton.bezelStyle = .rounded
        cancelButton.keyEquivalent = "\u{1b}"

        for v in [title, currentLabel, newLabel, nameField, validationLabel, warningLabel, renameButton, cancelButton] {
            container.addSubview(v)
        }

        NSLayoutConstraint.activate([
            title.topAnchor.constraint(equalTo: container.topAnchor, constant: 16),
            title.leadingAnchor.constraint(equalTo: container.leadingAnchor, constant: 16),

            currentLabel.topAnchor.constraint(equalTo: title.bottomAnchor, constant: 10),
            currentLabel.leadingAnchor.constraint(equalTo: container.leadingAnchor, constant: 16),
            currentLabel.trailingAnchor.constraint(equalTo: container.trailingAnchor, constant: -16),

            newLabel.topAnchor.constraint(equalTo: currentLabel.bottomAnchor, constant: 10),
            newLabel.leadingAnchor.constraint(equalTo: container.leadingAnchor, constant: 16),

            nameField.topAnchor.constraint(equalTo: newLabel.bottomAnchor, constant: 4),
            nameField.leadingAnchor.constraint(equalTo: container.leadingAnchor, constant: 16),
            nameField.trailingAnchor.constraint(equalTo: container.trailingAnchor, constant: -16),

            validationLabel.topAnchor.constraint(equalTo: nameField.bottomAnchor, constant: 2),
            validationLabel.leadingAnchor.constraint(equalTo: nameField.leadingAnchor),

            warningLabel.topAnchor.constraint(equalTo: validationLabel.bottomAnchor, constant: 4),
            warningLabel.leadingAnchor.constraint(equalTo: container.leadingAnchor, constant: 16),
            warningLabel.trailingAnchor.constraint(equalTo: container.trailingAnchor, constant: -16),

            renameButton.trailingAnchor.constraint(equalTo: container.trailingAnchor, constant: -16),
            renameButton.bottomAnchor.constraint(equalTo: container.bottomAnchor, constant: -16),

            cancelButton.trailingAnchor.constraint(equalTo: renameButton.leadingAnchor, constant: -8),
            cancelButton.bottomAnchor.constraint(equalTo: container.bottomAnchor, constant: -16)
        ])
    }

    @objc private func rename(_ sender: Any?) {
        let trimmed = nameField.stringValue.trimmingCharacters(in: .whitespaces)
        guard BranchesViewModel.validateBranchName(trimmed, existing: existingNames).isValid,
              trimmed != branch.name else { return }
        completion(trimmed, false)
        dismiss(nil)
    }

    @objc private func cancel(_ sender: Any?) {
        dismiss(nil)
    }
}

extension RenameBranchSheetViewController: NSTextFieldDelegate {
    func controlTextDidChange(_ obj: Notification) {
        let trimmed = nameField.stringValue.trimmingCharacters(in: .whitespaces)
        let validation = BranchesViewModel.validateBranchName(trimmed, existing: existingNames)
        switch validation {
        case .valid where trimmed != branch.name:
            validationLabel.stringValue = ""
            renameButton.isEnabled = true
        case .valid:
            validationLabel.stringValue = ""
            renameButton.isEnabled = false
        case .invalid(let reason):
            validationLabel.stringValue = trimmed.isEmpty ? "" : reason
            renameButton.isEnabled = false
        }
    }
}
