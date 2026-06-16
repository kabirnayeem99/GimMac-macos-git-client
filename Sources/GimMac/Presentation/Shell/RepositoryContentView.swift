import AppKit

/// Hosts both the Changes and History native split controllers and switches
/// between them without recreating either one.
///
/// Keeping the controllers alive preserves user-adjusted divider positions and
/// first-responder state across tab switches. The switch animation is a
/// directional slide; it degrades to a crossfade under Reduce Motion.
@MainActor
final class RepositoryContentViewController: NSViewController {
    private let viewModel: RepositoryStoreViewModel

    private let changesController: ChangesSplitViewController
    private let historyController: HistorySplitViewController

    private var currentTab: Int = 0

    // Active when the corresponding tab is on-screen.
    private var changesLeading: NSLayoutConstraint?
    private var changesTrailing: NSLayoutConstraint?
    private var historyLeading: NSLayoutConstraint?
    private var historyTrailing: NSLayoutConstraint?

    // Preserves first responder per tab so switching back restores focus.
    private var savedFirstResponders: [Int: NSView] = [:]

    init(viewModel: RepositoryStoreViewModel) {
        self.viewModel = viewModel
        self.changesController = ChangesSplitViewController(viewModel: viewModel)
        self.historyController = HistorySplitViewController(viewModel: viewModel)
        super.init(nibName: nil, bundle: nil)

        addChild(changesController)
        addChild(historyController)
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func loadView() {
        let container = NSView(frame: NSRect(x: 0, y: 0, width: 800, height: 600))
        container.translatesAutoresizingMaskIntoConstraints = false
        container.wantsLayer = true
        container.layer?.masksToBounds = true
        view = container

        changesController.view.translatesAutoresizingMaskIntoConstraints = false
        historyController.view.translatesAutoresizingMaskIntoConstraints = false

        container.addSubview(changesController.view)
        container.addSubview(historyController.view)

        changesLeading = changesController.view.leadingAnchor.constraint(equalTo: container.leadingAnchor)
        changesTrailing = changesController.view.trailingAnchor.constraint(equalTo: container.trailingAnchor)
        historyLeading = historyController.view.leadingAnchor.constraint(equalTo: container.leadingAnchor)
        historyTrailing = historyController.view.trailingAnchor.constraint(equalTo: container.trailingAnchor)

        NSLayoutConstraint.activate([
            changesController.view.topAnchor.constraint(equalTo: container.topAnchor),
            changesController.view.bottomAnchor.constraint(equalTo: container.bottomAnchor),
            changesLeading!,
            changesTrailing!,

            historyController.view.topAnchor.constraint(equalTo: container.topAnchor),
            historyController.view.bottomAnchor.constraint(equalTo: container.bottomAnchor),
            historyLeading!,
            historyTrailing!
        ])

        historyController.view.isHidden = true
        applyTabConstraints(changesOffset: 0, historyOffset: container.bounds.width)
    }

    func showTab(_ tab: Int, animated: Bool) {
        guard tab != currentTab else { return }

        saveFirstResponder(for: currentTab)

        let outgoingTab = currentTab
        currentTab = tab

        let container = view
        let width = max(container.bounds.width, 1)

        let outgoing = outgoingTab == 0 ? changesController.view : historyController.view
        let incoming = tab == 0 ? changesController.view : historyController.view

        // Bring the incoming view above the outgoing one for the duration of the
        // switch so overlapping content layers correctly.
        container.addSubview(incoming, positioned: .above, relativeTo: outgoing)

        let showingChanges = tab == 0

        let postChanges: CGFloat = showingChanges ? 0 : -width
        let postHistory: CGFloat = showingChanges ? width : 0

        let preChanges: CGFloat = showingChanges ? -width : 0
        let preHistory: CGFloat = showingChanges ? 0 : width

        if !animated {
            applyTabConstraints(changesOffset: postChanges, historyOffset: postHistory)
            incoming.alphaValue = 1
            outgoing.alphaValue = 1
            incoming.isHidden = false
            outgoing.isHidden = true
            restoreFirstResponder(for: tab)
            return
        }

        incoming.isHidden = false
        incoming.alphaValue = 0.96
        outgoing.alphaValue = 1

        applyTabConstraints(changesOffset: preChanges, historyOffset: preHistory)
        container.layoutSubtreeIfNeeded()

        if AppKitMotion.reduceMotion {
            NSAnimationContext.runAnimationGroup { context in
                context.duration = AppKitMotion.snappy
                context.timingFunction = CAMediaTimingFunction(name: .easeInEaseOut)

                incoming.animator().alphaValue = 1
                outgoing.animator().alphaValue = 0
            } completionHandler: { [weak self] in
                Task { @MainActor [weak self] in
                    guard let self else { return }

                    outgoing.isHidden = true
                    outgoing.alphaValue = 1
                    incoming.alphaValue = 1

                    self.applyTabConstraints(
                        changesOffset: postChanges,
                        historyOffset: postHistory
                    )

                    self.restoreFirstResponder(for: tab)
                }
            }

            return
        }

        NSAnimationContext.runAnimationGroup { context in
            context.duration = AppKitMotion.spatial
            context.timingFunction = CAMediaTimingFunction(name: .easeInEaseOut)
            context.allowsImplicitAnimation = true

            applyTabConstraints(changesOffset: postChanges, historyOffset: postHistory)

            incoming.animator().alphaValue = 1
            outgoing.animator().alphaValue = 0.98
            container.animator().layoutSubtreeIfNeeded()
        } completionHandler: { [weak self] in
            Task { @MainActor [weak self] in
                guard let self else { return }

                outgoing.isHidden = true
                outgoing.alphaValue = 1
                incoming.alphaValue = 1

                self.applyTabConstraints(
                    changesOffset: postChanges,
                    historyOffset: postHistory
                )

                self.restoreFirstResponder(for: tab)
            }
        }
    }

    // MARK: - First responder preservation

    private func rootView(for tab: Int) -> NSView {
        tab == 0 ? changesController.view : historyController.view
    }

    private func saveFirstResponder(for tab: Int) {
        guard let window = view.window,
              let responder = window.firstResponder as? NSView else { return }
        let root = rootView(for: tab)
        if responder.isDescendant(of: root) {
            savedFirstResponders[tab] = responder
        }
    }

    private func restoreFirstResponder(for tab: Int) {
        guard let window = view.window else { return }
        let root = rootView(for: tab)
        if let saved = savedFirstResponders[tab],
           saved.isDescendant(of: root),
           saved.acceptsFirstResponder,
           !saved.isHidden {
            window.makeFirstResponder(saved)
        } else if let current = window.firstResponder as? NSView,
                  !current.isDescendant(of: root) {
            // Drop focus rather than leaving it on the hidden tab.
            window.makeFirstResponder(nil)
        }
    }

    /// Positions the Changes and History views by their leading (and trailing)
    /// horizontal offsets. At rest, the active view is at `0` and the inactive
    /// view is one container width off-screen.
    private func applyTabConstraints(changesOffset: CGFloat, historyOffset: CGFloat) {
        changesLeading?.constant = changesOffset
        changesTrailing?.constant = changesOffset
        historyLeading?.constant = historyOffset
        historyTrailing?.constant = historyOffset
    }
}
