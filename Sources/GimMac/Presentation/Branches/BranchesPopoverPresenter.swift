import AppKit
import SwiftUI

/// SwiftUI wrapper that displays `content` as a clickable button which presents
/// `BranchesViewController` in an `NSPopover` when tapped. Used by `TopToolbar`
/// to make the branch card interactive without dragging the entire feature into
/// SwiftUI.
struct BranchesPopoverButton<Label: View>: NSViewRepresentable {
    let viewModelFactory: () -> BranchesViewModel?
    let label: () -> Label

    @Environment(\.isEnabled) private var isEnabled

    func makeNSView(context: Context) -> NSView {
        let host = NSHostingView(rootView: label())
        host.translatesAutoresizingMaskIntoConstraints = false

        let container = ClickableContainerView(frame: .zero)
        container.translatesAutoresizingMaskIntoConstraints = false
        container.addSubview(host)
        NSLayoutConstraint.activate([
            host.leadingAnchor.constraint(equalTo: container.leadingAnchor),
            host.trailingAnchor.constraint(equalTo: container.trailingAnchor),
            host.topAnchor.constraint(equalTo: container.topAnchor),
            host.bottomAnchor.constraint(equalTo: container.bottomAnchor)
        ])

        container.onClick = { [weak container] in
            guard let container, container.isEnabled else { return }
            context.coordinator.present(from: container)
        }
        return container
    }

    func updateNSView(_ nsView: NSView, context: Context) {
        if let host = nsView.subviews.first as? NSHostingView<Label> {
            host.rootView = label()
        }
        if let container = nsView as? ClickableContainerView {
            container.isEnabled = isEnabled
            container.alphaValue = isEnabled ? 1.0 : 0.5
        }
        context.coordinator.viewModelFactory = viewModelFactory
    }

    func makeCoordinator() -> Coordinator {
        Coordinator(viewModelFactory: viewModelFactory)
    }

    @MainActor
    final class Coordinator: NSObject, NSPopoverDelegate {
        var viewModelFactory: () -> BranchesViewModel?
        private var popover: NSPopover?

        init(viewModelFactory: @escaping () -> BranchesViewModel?) {
            self.viewModelFactory = viewModelFactory
        }

        func present(from view: NSView) {
            if let existing = popover, existing.isShown {
                existing.close()
                return
            }
            guard let viewModel = viewModelFactory() else { return }
            let controller = BranchesViewController(viewModel: viewModel)
            let popover = NSPopover()
            popover.contentViewController = controller
            popover.behavior = .transient
            popover.delegate = self
            popover.contentSize = NSSize(width: 360, height: 480)
            self.popover = popover
            popover.show(relativeTo: view.bounds, of: view, preferredEdge: .maxY)
        }

        func popoverDidClose(_ notification: Notification) {
            popover = nil
        }
    }
}

/// Tiny container that swallows a click without stealing keyboard focus,
/// because `NSButton` styling would override the SwiftUI label visuals.
private final class ClickableContainerView: NSView {
    var onClick: (() -> Void)?
    var isEnabled: Bool = true

    override func mouseDown(with event: NSEvent) {
        guard isEnabled else { return }
        onClick?()
    }

    override func resetCursorRects() {
        if isEnabled {
            addCursorRect(bounds, cursor: .pointingHand)
        } else {
            addCursorRect(bounds, cursor: .arrow)
        }
    }

    override var isFlipped: Bool { false }
}
