import AppKit

/// Modal sheet for cloning a remote repository. Hands the user's selection
/// back to the host via a completion block so the controller stays free of
/// services. Mirrors `CreateBranchWindowController` in shape.
@MainActor
final class CloneRepositoryWindowController {
    typealias Completion = (_ url: String, _ destination: URL) -> Void

    let viewController: NSViewController

    init(completion: @escaping Completion) {
        self.viewController = CloneRepositorySheetViewController(completion: completion)
    }
}

private final class CloneRepositorySheetViewController: NSViewController {
    private let completion: CloneRepositoryWindowController.Completion

    private let urlField = NSTextField()
    private let destinationField = NSTextField()
    private let chooseButton = NSButton(title: "Choose…", target: nil, action: nil)
    private let cloneButton = NSButton(title: "Clone", target: nil, action: nil)
    private let cancelButton = NSButton(title: "Cancel", target: nil, action: nil)

    init(completion: @escaping CloneRepositoryWindowController.Completion) {
        self.completion = completion
        super.init(nibName: nil, bundle: nil)
    }
    required init?(coder: NSCoder) { fatalError("init(coder:) is not supported") }

    override func loadView() {
        let container = NSView(frame: NSRect(x: 0, y: 0, width: 460, height: 200))
        self.view = container

        let title = NSTextField(labelWithString: "Clone Repository")
        title.font = NSFont.systemFont(ofSize: 14, weight: .semibold)
        title.translatesAutoresizingMaskIntoConstraints = false

        let urlLabel = NSTextField(labelWithString: "Repository URL")
        urlLabel.translatesAutoresizingMaskIntoConstraints = false

        urlField.placeholderString = "https://github.com/owner/repo.git"
        urlField.translatesAutoresizingMaskIntoConstraints = false
        urlField.delegate = self

        let destinationLabel = NSTextField(labelWithString: "Local Path")
        destinationLabel.translatesAutoresizingMaskIntoConstraints = false

        destinationField.placeholderString = "/Users/you/Projects/repo"
        destinationField.translatesAutoresizingMaskIntoConstraints = false
        destinationField.delegate = self

        chooseButton.translatesAutoresizingMaskIntoConstraints = false
        chooseButton.bezelStyle = .rounded
        chooseButton.target = self
        chooseButton.action = #selector(chooseDestination(_:))

        cloneButton.translatesAutoresizingMaskIntoConstraints = false
        cloneButton.bezelStyle = .rounded
        cloneButton.keyEquivalent = "\r"
        cloneButton.target = self
        cloneButton.action = #selector(performClone(_:))
        cloneButton.isEnabled = false
        cloneButton.alphaValue = 0.5

        cancelButton.translatesAutoresizingMaskIntoConstraints = false
        cancelButton.bezelStyle = .rounded
        cancelButton.keyEquivalent = "\u{1b}"
        cancelButton.target = self
        cancelButton.action = #selector(cancel(_:))

        for v in [title, urlLabel, urlField, destinationLabel, destinationField, chooseButton, cloneButton, cancelButton] {
            container.addSubview(v)
        }

        NSLayoutConstraint.activate([
            title.topAnchor.constraint(equalTo: container.topAnchor, constant: 16),
            title.leadingAnchor.constraint(equalTo: container.leadingAnchor, constant: 16),

            urlLabel.topAnchor.constraint(equalTo: title.bottomAnchor, constant: 12),
            urlLabel.leadingAnchor.constraint(equalTo: container.leadingAnchor, constant: 16),

            urlField.topAnchor.constraint(equalTo: urlLabel.bottomAnchor, constant: 4),
            urlField.leadingAnchor.constraint(equalTo: container.leadingAnchor, constant: 16),
            urlField.trailingAnchor.constraint(equalTo: container.trailingAnchor, constant: -16),

            destinationLabel.topAnchor.constraint(equalTo: urlField.bottomAnchor, constant: 10),
            destinationLabel.leadingAnchor.constraint(equalTo: container.leadingAnchor, constant: 16),

            destinationField.topAnchor.constraint(equalTo: destinationLabel.bottomAnchor, constant: 4),
            destinationField.leadingAnchor.constraint(equalTo: container.leadingAnchor, constant: 16),
            destinationField.trailingAnchor.constraint(equalTo: chooseButton.leadingAnchor, constant: -8),

            chooseButton.centerYAnchor.constraint(equalTo: destinationField.centerYAnchor),
            chooseButton.trailingAnchor.constraint(equalTo: container.trailingAnchor, constant: -16),

            cloneButton.trailingAnchor.constraint(equalTo: container.trailingAnchor, constant: -16),
            cloneButton.bottomAnchor.constraint(equalTo: container.bottomAnchor, constant: -16),

            cancelButton.trailingAnchor.constraint(equalTo: cloneButton.leadingAnchor, constant: -8),
            cancelButton.bottomAnchor.constraint(equalTo: container.bottomAnchor, constant: -16)
        ])
    }

    @objc private func chooseDestination(_ sender: Any?) {
        let panel = NSOpenPanel()
        panel.title = "Choose Destination Folder"
        panel.message = "Select the parent folder. The repository will be cloned into a subfolder named after the URL."
        panel.prompt = "Choose"
        panel.canChooseFiles = false
        panel.canChooseDirectories = true
        panel.canCreateDirectories = true
        panel.allowsMultipleSelection = false
        let handle: (NSApplication.ModalResponse) -> Void = { [weak self] response in
            guard let self, response == .OK, let parent = panel.url else { return }
            let folderName = self.defaultFolderName(forURL: self.urlField.stringValue)
            let destination = parent.appendingPathComponent(folderName, isDirectory: true)
            self.animateDestinationChange(destination.path)
            self.updateCloneEnabled()
        }
        if let window = view.window {
            panel.beginSheetModal(for: window, completionHandler: handle)
        } else {
            handle(panel.runModal())
        }
    }

    @objc private func performClone(_ sender: Any?) {
        let url = urlField.stringValue.trimmingCharacters(in: .whitespacesAndNewlines)
        let path = destinationField.stringValue.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !url.isEmpty, !path.isEmpty else { return }
        let destination = URL(fileURLWithPath: path, isDirectory: true)
        completion(url, destination)

        cloneButton.title = "Cloning…"
        cloneButton.isEnabled = false
        let delay = AppKitMotion.reduceMotion ? 0.0 : 0.35
        DispatchQueue.main.asyncAfter(deadline: .now() + delay) { [weak self] in
            self?.dismiss(nil)
        }
    }

    @objc private func cancel(_ sender: Any?) {
        dismiss(nil)
    }

    /// Derive the default destination folder name from a clone URL by
    /// stripping a trailing `.git` and any path separators.
    private func defaultFolderName(forURL urlString: String) -> String {
        let trimmed = urlString.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return "repository" }
        var last = (trimmed as NSString).lastPathComponent
        if last.hasSuffix(".git") {
            last = String(last.dropLast(4))
        }
        return last.isEmpty ? "repository" : last
    }

    fileprivate func updateCloneEnabled() {
        let urlOK = !urlField.stringValue.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
        let pathOK = !destinationField.stringValue.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
        let enabled = urlOK && pathOK
        cloneButton.isEnabled = enabled
        cloneButton.animateAlpha(to: enabled ? 1 : 0.5)
    }

    private func animateDestinationChange(_ path: String) {
        let reduceMotion = AppKitMotion.reduceMotion
        guard destinationField.stringValue != path else { return }
        guard !reduceMotion else {
            destinationField.stringValue = path
            return
        }
        destinationField.animateAlpha(to: 0, duration: AppKitMotion.feedback) { [weak self] in
            self?.destinationField.stringValue = path
            self?.destinationField.animateAlpha(to: 1, duration: AppKitMotion.feedback)
        }
    }
}

extension CloneRepositorySheetViewController: NSTextFieldDelegate {
    func controlTextDidChange(_ obj: Notification) {
        updateCloneEnabled()
    }
}
