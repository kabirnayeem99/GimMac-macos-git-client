import AppKit

/// Retains a closure so AppKit target/action can drive Swift callbacks without
/// a per-control `@objc` selector on the view controller.
@MainActor
private final class ControlActionTrampoline: NSObject {
    private let handler: (NSControl) -> Void
    init(_ handler: @escaping (NSControl) -> Void) { self.handler = handler }
    @objc func fire(_ sender: NSControl) { handler(sender) }
}

/// Flipped vertical stack so content lays out top-to-bottom inside a scroll view.
@MainActor
private final class FlippedStackView: NSStackView {
    override var isFlipped: Bool { true }
}

/// Base class for a Settings detail pane: a scrollable, top-aligned vertical
/// stack plus form-building helpers (sections, checkboxes, pop-ups, fields).
/// Subclasses override `buildContent()`. Native, idiomatic counterpart of one
/// GitHub Desktop preferences panel.
@MainActor
class SettingsPaneViewController: NSViewController {
    let contentStack: NSStackView = FlippedStackView()
    private let scrollView = NSScrollView()
    private var trampolines: [ControlActionTrampoline] = []

    override func loadView() {
        view = NSView()

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

    override func viewDidLoad() {
        super.viewDidLoad()
        buildContent()
    }

    /// Override to populate `contentStack`.
    func buildContent() {}

    /// Clears and re-runs `buildContent()` — used by panes whose layout changes
    /// in response to a control (e.g. revealing a custom-integration form).
    func rebuildContent() {
        contentStack.arrangedSubviews.forEach { $0.removeFromSuperview() }
        trampolines.removeAll()
        buildContent()
    }

    // MARK: - Builders

    func addHeader(_ title: String) {
        let label = NSTextField(labelWithString: title)
        label.font = .systemFont(ofSize: 28, weight: .bold)
        contentStack.addArrangedSubview(label)
    }

    @discardableResult
    func addSection(_ title: String?, views: [NSView]) -> NSStackView {
        let container = NSStackView()
        container.orientation = .vertical
        container.alignment = .leading
        container.spacing = 10
        if let title {
            let groupTitle = NSTextField(labelWithString: title)
            groupTitle.font = .systemFont(ofSize: 15, weight: .semibold)
            container.addArrangedSubview(groupTitle)
        }
        views.forEach { container.addArrangedSubview($0) }
        container.setContentHuggingPriority(.defaultHigh, for: .vertical)
        contentStack.addArrangedSubview(container)
        return container
    }

    func makeCheckbox(_ title: String, isOn: Bool, onToggle: @escaping (Bool) -> Void) -> NSButton {
        let trampoline = ControlActionTrampoline { control in
            onToggle((control as? NSButton)?.state == .on)
        }
        trampolines.append(trampoline)
        let button = NSButton(checkboxWithTitle: title, target: trampoline, action: #selector(ControlActionTrampoline.fire(_:)))
        button.state = isOn ? .on : .off
        return button
    }

    func makePopUp(titles: [String], selectedIndex: Int, onSelect: @escaping (Int) -> Void) -> NSPopUpButton {
        let trampoline = ControlActionTrampoline { control in
            onSelect((control as? NSPopUpButton)?.indexOfSelectedItem ?? 0)
        }
        trampolines.append(trampoline)
        let popup = NSPopUpButton()
        popup.addItems(withTitles: titles)
        if titles.indices.contains(selectedIndex) {
            popup.selectItem(at: selectedIndex)
        }
        popup.target = trampoline
        popup.action = #selector(ControlActionTrampoline.fire(_:))
        popup.translatesAutoresizingMaskIntoConstraints = false
        popup.widthAnchor.constraint(equalToConstant: 260).isActive = true
        return popup
    }

    func makeTextField(
        text: String,
        placeholder: String,
        width: CGFloat = 340,
        onCommit: @escaping (String) -> Void
    ) -> NSTextField {
        let trampoline = ControlActionTrampoline { control in
            onCommit((control as? NSTextField)?.stringValue ?? "")
        }
        trampolines.append(trampoline)
        let field = NSTextField(string: text)
        field.placeholderString = placeholder
        field.controlSize = .large
        field.target = trampoline
        field.action = #selector(ControlActionTrampoline.fire(_:))
        field.translatesAutoresizingMaskIntoConstraints = false
        field.widthAnchor.constraint(equalToConstant: width).isActive = true
        return field
    }

    func makeButton(_ title: String, onClick: @escaping () -> Void) -> NSButton {
        let trampoline = ControlActionTrampoline { _ in onClick() }
        trampolines.append(trampoline)
        let button = NSButton(title: title, target: trampoline, action: #selector(ControlActionTrampoline.fire(_:)))
        button.bezelStyle = .rounded
        return button
    }

    func labeledRow(_ labelText: String, control: NSView, labelWidth: CGFloat = 200) -> NSStackView {
        let stack = NSStackView()
        stack.orientation = .horizontal
        stack.spacing = 12
        let label = NSTextField(labelWithString: labelText)
        label.translatesAutoresizingMaskIntoConstraints = false
        label.widthAnchor.constraint(equalToConstant: labelWidth).isActive = true
        stack.addArrangedSubview(label)
        stack.addArrangedSubview(control)
        return stack
    }

    func makeNote(_ text: String, width: CGFloat = 460) -> NSTextField {
        let label = NSTextField(wrappingLabelWithString: text)
        label.textColor = .secondaryLabelColor
        label.font = .systemFont(ofSize: 12)
        label.translatesAutoresizingMaskIntoConstraints = false
        label.widthAnchor.constraint(equalToConstant: width).isActive = true
        return label
    }
}
