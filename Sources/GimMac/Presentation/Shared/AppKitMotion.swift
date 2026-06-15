import AppKit

/// AppKit counterparts to the SwiftUI `Motion` helpers.
///
/// These keep animation durations and the Reduce Motion path consistent across
/// AppKit table views, popovers, and hosted SwiftUI transitions.
enum AppKitMotion {
    static let feedback: TimeInterval = 0.18
    static let snappy: TimeInterval = 0.22
    static let spatial: TimeInterval = 0.32

    /// Whether the user has enabled Reduce Motion at the system level.
    static var reduceMotion: Bool {
        NSWorkspace.shared.accessibilityDisplayShouldReduceMotion
    }
}

// MARK: - View crossfade

extension NSView {
    /// Replace the receiver's alpha from its current value to `targetAlpha` over
    /// `duration`. When Reduce Motion is on the change is instant.
    func animateAlpha(
        to targetAlpha: CGFloat,
        duration: TimeInterval = AppKitMotion.feedback,
        completion: (@MainActor @Sendable () -> Void)? = nil
    ) {
        guard !AppKitMotion.reduceMotion else {
            alphaValue = targetAlpha
            completion?()
            return
        }
        NSAnimationContext.runAnimationGroup { context in
            context.duration = duration
            context.timingFunction = CAMediaTimingFunction(name: .easeInEaseOut)
            animator().alphaValue = targetAlpha
        } completionHandler: {
            MainActor.assumeIsolated {
                completion?()
            }
        }
    }

    /// Fade the view in or out, setting `isHidden` after a fade-out completes.
    /// Suitable for status banners and validation hints. Instant under Reduce Motion.
    func fadeBanner(visible: Bool, duration: TimeInterval = AppKitMotion.feedback) {
        guard !AppKitMotion.reduceMotion else {
            isHidden = !visible
            alphaValue = visible ? 1 : 0
            return
        }
        if visible {
            alphaValue = 0
            isHidden = false
            animateAlpha(to: 1, duration: duration)
        } else {
            animateAlpha(to: 0, duration: duration) { [weak self] in
                self?.isHidden = true
            }
        }
    }

    /// Crossfade between two views by fading `outView` to 0 and `inView` from 0
    /// to 1. The views are assumed to share a superview and frame. Instant under
    /// Reduce Motion.
    static func crossfade(
        out outView: NSView,
        in inView: NSView,
        duration: TimeInterval = AppKitMotion.spatial,
        completion: (@MainActor @Sendable () -> Void)? = nil
    ) {
        guard !AppKitMotion.reduceMotion else {
            outView.isHidden = true
            outView.alphaValue = 0
            inView.isHidden = false
            inView.alphaValue = 1
            completion?()
            return
        }
        inView.alphaValue = 0
        inView.isHidden = false
        NSAnimationContext.runAnimationGroup { context in
            context.duration = duration
            context.timingFunction = CAMediaTimingFunction(name: .easeInEaseOut)
            outView.animator().alphaValue = 0
            inView.animator().alphaValue = 1
        } completionHandler: { [weak outView] in
            MainActor.assumeIsolated {
                outView?.isHidden = true
                completion?()
            }
        }
    }
}

// MARK: - Banner auto-dismiss

extension AppKitMotion {
    /// Schedules a banner fade-out after `interval` and returns a cancellable work item.
    /// Callers should store the item and call `cancel()` when replacing the message.
    @discardableResult
    static func scheduleAutoDismiss(
        for view: NSView,
        after interval: TimeInterval = 3.0
    ) -> DispatchWorkItem {
        let workItem = DispatchWorkItem { [weak view] in
            MainActor.assumeIsolated {
                view?.fadeBanner(visible: false)
            }
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + interval, execute: workItem)
        return workItem
    }
}

// MARK: - Table row diffing

extension NSTableView {
    /// Reconciles the table's rows with a new array of identifiers, animating
    /// insertions and deletions. Falls back to `reloadData()` when Reduce Motion
    /// is enabled, when the diff is large, or when the arrays contain duplicate
    /// identifiers.
    ///
    /// - Parameters:
    ///   - oldRows: The previously rendered rows.
    ///   - newRows: The rows to render now.
    ///   - idKeyPath: A key path to a hashable identifier for each row.
    ///   - selectionIDs: Identifiers that should remain selected after the update.
    /// - Returns: The row indexes that correspond to `selectionIDs` after the update.
    @MainActor
    func animatedReload<Row, ID: Hashable>(
        old oldRows: [Row],
        new newRows: [Row],
        idKeyPath: KeyPath<Row, ID>,
        preservingSelection selectionIDs: Set<ID> = []
    ) -> IndexSet {
        let fallback = { () -> IndexSet in
            self.reloadData()
            var restored = IndexSet()
            for (index, row) in newRows.enumerated() where selectionIDs.contains(row[keyPath: idKeyPath]) {
                restored.insert(index)
            }
            return restored
        }

        guard !AppKitMotion.reduceMotion else { return fallback() }

        let oldIDs = oldRows.map { $0[keyPath: idKeyPath] }
        let newIDs = newRows.map { $0[keyPath: idKeyPath] }

        let diff = newIDs.difference(from: oldIDs)
        let changeCount = diff.count

        // Fall back for large diffs or unexpected duplicates (which would break
        // the simple offset-based application below).
        let noDuplicates = Set(oldIDs).count == oldIDs.count && Set(newIDs).count == newIDs.count
        guard changeCount > 0, changeCount <= 100, noDuplicates else {
            return fallback()
        }

        let removals = diff.compactMap { change -> Int? in
            if case .remove(let offset, _, _) = change { return offset }
            return nil
        }.sorted(by: >)
        let insertions = diff.compactMap { change -> Int? in
            if case .insert(let offset, _, _) = change { return offset }
            return nil
        }.sorted(by: <)

        beginUpdates()
        for offset in removals {
            removeRows(at: IndexSet(integer: offset), withAnimation: .effectGap)
        }
        for offset in insertions {
            insertRows(at: IndexSet(integer: offset), withAnimation: .effectGap)
        }
        endUpdates()

        var restored = IndexSet()
        for (index, row) in newRows.enumerated() where selectionIDs.contains(row[keyPath: idKeyPath]) {
            restored.insert(index)
        }
        return restored
    }
}

// MARK: - Symbol replacement

extension NSImageView {
    /// Sets a new symbol image using `.replace` when available and Reduce Motion
    /// is off; otherwise it swaps instantly with an opacity crossfade.
    func setSymbolImage(_ image: NSImage, contentTransition: Bool = true) {
        guard contentTransition, !AppKitMotion.reduceMotion else {
            self.image = image
            return
        }
        if #available(macOS 14.0, *) {
            self.setSymbolImage(image, contentTransition: .replace)
        } else {
            self.image = image
        }
    }
}
