import AppKit

/// Modal sheet for creating a new branch. Hands the user's selection back to
/// the host via a completion block so the controller stays free of services.
@MainActor
final class CreateBranchWindowController {
    typealias Completion = (_ name: String, _ startPoint: BranchStartPoint, _ noTrack: Bool) -> Void

    let viewController: NSViewController

    init(existingNames: [String], availableBranches: [Branch], completion: @escaping Completion) {
        self.viewController = CreateBranchSheetViewController(
            existingNames: existingNames,
            availableBranches: availableBranches,
            completion: completion
        )
    }
}

private final class CreateBranchSheetViewController: NSViewController {
    private let existingNames: [String]
    private let availableBranches: [Branch]
    private let completion: CreateBranchWindowController.Completion

    private let nameField = NSTextField()
    private let validationLabel = NSTextField(labelWithString: "")
    private let startPointPopup = NSPopUpButton()
    private let createButton = NSButton(title: "Create Branch", target: nil, action: nil)
    private let cancelButton = NSButton(title: "Cancel", target: nil, action: nil)

    init(existingNames: [String], availableBranches: [Branch], completion: @escaping CreateBranchWindowController.Completion) {
        self.existingNames = existingNames
        self.availableBranches = availableBranches
        self.completion = completion
        super.init(nibName: nil, bundle: nil)
    }
    required init?(coder: NSCoder) { fatalError("init(coder:) is not supported") }

    override func loadView() {
        let container = NSView(frame: NSRect(x: 0, y: 0, width: 380, height: 200))
        self.view = container

        let title = NSTextField(labelWithString: "Create Branch")
        title.font = NSFont.systemFont(ofSize: 14, weight: .semibold)
        title.translatesAutoresizingMaskIntoConstraints = false

        let nameLabel = NSTextField(labelWithString: "Name")
        nameLabel.translatesAutoresizingMaskIntoConstraints = false

        nameField.placeholderString = "feature/my-branch"
        nameField.translatesAutoresizingMaskIntoConstraints = false
        nameField.delegate = self

        validationLabel.font = NSFont.systemFont(ofSize: 11)
        validationLabel.textColor = .systemRed
        validationLabel.translatesAutoresizingMaskIntoConstraints = false

        let startPointLabel = NSTextField(labelWithString: "Based on")
        startPointLabel.translatesAutoresizingMaskIntoConstraints = false

        startPointPopup.translatesAutoresizingMaskIntoConstraints = false
        startPointPopup.addItem(withTitle: "Current Branch")
        startPointPopup.addItem(withTitle: "Default Branch (origin/HEAD)")
        startPointPopup.addItem(withTitle: "HEAD")
        for branch in availableBranches.sorted(by: { $0.name < $1.name }) {
            startPointPopup.addItem(withTitle: "Branch: \(branch.name)")
            startPointPopup.lastItem?.representedObject = branch
        }

        createButton.translatesAutoresizingMaskIntoConstraints = false
        createButton.bezelStyle = .rounded
        createButton.keyEquivalent = "\r"
        createButton.target = self
        createButton.action = #selector(create(_:))
        createButton.isEnabled = false

        cancelButton.translatesAutoresizingMaskIntoConstraints = false
        cancelButton.bezelStyle = .rounded
        cancelButton.keyEquivalent = "\u{1b}"
        cancelButton.target = self
        cancelButton.action = #selector(cancel(_:))

        for v in [title, nameLabel, nameField, validationLabel, startPointLabel, startPointPopup, createButton, cancelButton] {
            container.addSubview(v)
        }

        NSLayoutConstraint.activate([
            title.topAnchor.constraint(equalTo: container.topAnchor, constant: 16),
            title.leadingAnchor.constraint(equalTo: container.leadingAnchor, constant: 16),

            nameLabel.topAnchor.constraint(equalTo: title.bottomAnchor, constant: 12),
            nameLabel.leadingAnchor.constraint(equalTo: container.leadingAnchor, constant: 16),

            nameField.topAnchor.constraint(equalTo: nameLabel.bottomAnchor, constant: 4),
            nameField.leadingAnchor.constraint(equalTo: container.leadingAnchor, constant: 16),
            nameField.trailingAnchor.constraint(equalTo: container.trailingAnchor, constant: -16),

            validationLabel.topAnchor.constraint(equalTo: nameField.bottomAnchor, constant: 2),
            validationLabel.leadingAnchor.constraint(equalTo: nameField.leadingAnchor),

            startPointLabel.topAnchor.constraint(equalTo: validationLabel.bottomAnchor, constant: 8),
            startPointLabel.leadingAnchor.constraint(equalTo: container.leadingAnchor, constant: 16),

            startPointPopup.topAnchor.constraint(equalTo: startPointLabel.bottomAnchor, constant: 4),
            startPointPopup.leadingAnchor.constraint(equalTo: container.leadingAnchor, constant: 16),
            startPointPopup.trailingAnchor.constraint(equalTo: container.trailingAnchor, constant: -16),

            createButton.trailingAnchor.constraint(equalTo: container.trailingAnchor, constant: -16),
            createButton.bottomAnchor.constraint(equalTo: container.bottomAnchor, constant: -16),

            cancelButton.trailingAnchor.constraint(equalTo: createButton.leadingAnchor, constant: -8),
            cancelButton.bottomAnchor.constraint(equalTo: container.bottomAnchor, constant: -16)
        ])
    }

    @objc private func create(_ sender: Any?) {
        let trimmed = nameField.stringValue.trimmingCharacters(in: .whitespaces)
        guard BranchesViewModel.validateBranchName(trimmed, existing: existingNames).isValid else { return }
        let startPoint: BranchStartPoint
        switch startPointPopup.indexOfSelectedItem {
        case 0: startPoint = .currentBranch
        case 1: startPoint = .defaultBranch
        case 2: startPoint = .head
        default:
            if let branch = startPointPopup.selectedItem?.representedObject as? Branch {
                startPoint = .branch(branch)
            } else {
                startPoint = .currentBranch
            }
        }
        completion(trimmed, startPoint, false)
        dismiss(nil)
    }

    @objc private func cancel(_ sender: Any?) {
        dismiss(nil)
    }
}

extension CreateBranchSheetViewController: NSTextFieldDelegate {
    func controlTextDidChange(_ obj: Notification) {
        let validation = BranchesViewModel.validateBranchName(nameField.stringValue, existing: existingNames)
        switch validation {
        case .valid:
            validationLabel.stringValue = ""
            createButton.isEnabled = true
        case .invalid(let reason):
            validationLabel.stringValue = nameField.stringValue.isEmpty ? "" : reason
            createButton.isEnabled = false
        }
    }
}
