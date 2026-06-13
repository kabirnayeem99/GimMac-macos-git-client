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
        // Hug the SwiftUI content so `sizeThatFits` (below) can report a finite
        // intrinsic size to SwiftUI's layout. Without this the representable has
        // no intrinsic size and the parent HStack lets it expand to fill, which
        // overlaps the adjacent repository button and pushes the sync card off.
        host.sizingOptions = [.intrinsicContentSize]

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

    /// Report the SwiftUI content's natural size up to the parent layout. The
    /// label declares its own height/width (`ToolbarCard` is 40pt tall and
    /// `.fixedSize()`), so the container's `fittingSize` hugs it — giving the
    /// branch item the same footprint as the sibling cards instead of stretching.
    func sizeThatFits(_ proposal: ProposedViewSize, nsView: NSView, context: Context) -> CGSize? {
        nsView.fittingSize
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

/// Container that hosts the SwiftUI branch label and owns its toolbar-button
/// chrome in AppKit. Because the label is double-hosted inside an
/// `NSViewRepresentable`, SwiftUI can't reliably track hover/press here, so the
/// rounded hover/press highlight is drawn at the layer level — matching the
/// 6pt radius and opacities of `ToolbarItemStyle` so the branch item is visually
/// identical to the repository/sync items.
private final class ClickableContainerView: NSView {
    /// Matches `ToolbarItemStyle`'s rounded corner radius.
    private static let cornerRadius: CGFloat = 6

    var onClick: (() -> Void)?
    var isEnabled: Bool = true {
        didSet { updateHighlight() }
    }

    private var isHovered = false { didSet { updateHighlight() } }
    private var isPressed = false { didSet { updateHighlight() } }

    override init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        wantsLayer = true
        layer?.cornerRadius = Self.cornerRadius
        layer?.cornerCurve = .continuous
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }

    /// Claim every click inside our bounds so `mouseDown` reaches us instead of
    /// being consumed by the hosted SwiftUI label, which would leave the popover
    /// dead. Tracking areas (below) still drive hover independently.
    override func hitTest(_ point: NSPoint) -> NSView? {
        guard let superview else { return super.hitTest(point) }
        let local = convert(point, from: superview)
        return bounds.contains(local) ? self : nil
    }

    override func mouseDown(with event: NSEvent) {
        guard isEnabled else { return }
        isPressed = true
        onClick?()
    }

    override func mouseUp(with event: NSEvent) {
        isPressed = false
    }

    override func updateTrackingAreas() {
        super.updateTrackingAreas()
        trackingAreas.forEach(removeTrackingArea)
        addTrackingArea(NSTrackingArea(
            rect: bounds,
            options: [.mouseEnteredAndExited, .activeInActiveApp, .inVisibleRect],
            owner: self
        ))
    }

    override func mouseEntered(with event: NSEvent) { isHovered = true }
    override func mouseExited(with event: NSEvent) { isHovered = false }

    private func updateHighlight() {
        let opacity: CGFloat
        if !isEnabled {
            opacity = 0
        } else if isPressed {
            opacity = 0.12
        } else if isHovered {
            opacity = 0.08
        } else {
            opacity = 0
        }
        layer?.backgroundColor = NSColor.labelColor.withAlphaComponent(opacity).cgColor
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
