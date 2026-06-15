import AppKit

/// Single row in the branches table.
///
/// Layout:
/// ```
/// [•/✓] feature/foo          [↑2 ↓1]   commit subject…
///                          ^ ahead/behind badges (only when upstream tracked)
/// ```
final class BranchCellView: NSTableCellView {
    static let reuseIdentifier = NSUserInterfaceItemIdentifier("BranchCellView")
    static let rowHeight: CGFloat = 44

    private let currentIndicator = NSImageView()
    private let pendingIndicator = NSProgressIndicator()
    private let nameLabel = NSTextField(labelWithString: "")
    private let subjectLabel = NSTextField(labelWithString: "")
    private let aheadBehindLabel = NSTextField(labelWithString: "")

    override init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        configure()
    }

    required init?(coder: NSCoder) {
        super.init(coder: coder)
        configure()
    }

    private func configure() {
        translatesAutoresizingMaskIntoConstraints = false

        currentIndicator.translatesAutoresizingMaskIntoConstraints = false
        currentIndicator.imageScaling = .scaleProportionallyDown
        currentIndicator.contentTintColor = .systemBlue
        currentIndicator.wantsLayer = true

        pendingIndicator.translatesAutoresizingMaskIntoConstraints = false
        pendingIndicator.style = .spinning
        pendingIndicator.controlSize = .small
        pendingIndicator.isDisplayedWhenStopped = false

        nameLabel.font = NSFont.systemFont(ofSize: 13, weight: .semibold)
        nameLabel.lineBreakMode = .byTruncatingTail
        nameLabel.translatesAutoresizingMaskIntoConstraints = false

        subjectLabel.font = NSFont.systemFont(ofSize: 11)
        subjectLabel.textColor = .secondaryLabelColor
        subjectLabel.lineBreakMode = .byTruncatingTail
        subjectLabel.translatesAutoresizingMaskIntoConstraints = false

        aheadBehindLabel.font = NSFont.systemFont(ofSize: 11, weight: .medium)
        aheadBehindLabel.textColor = .secondaryLabelColor
        aheadBehindLabel.alignment = .right
        aheadBehindLabel.translatesAutoresizingMaskIntoConstraints = false

        addSubview(currentIndicator)
        addSubview(pendingIndicator)
        addSubview(nameLabel)
        addSubview(subjectLabel)
        addSubview(aheadBehindLabel)

        NSLayoutConstraint.activate([
            currentIndicator.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 8),
            currentIndicator.centerYAnchor.constraint(equalTo: centerYAnchor),
            currentIndicator.widthAnchor.constraint(equalToConstant: 14),
            currentIndicator.heightAnchor.constraint(equalToConstant: 14),

            pendingIndicator.centerXAnchor.constraint(equalTo: currentIndicator.centerXAnchor),
            pendingIndicator.centerYAnchor.constraint(equalTo: currentIndicator.centerYAnchor),
            pendingIndicator.widthAnchor.constraint(equalToConstant: 12),
            pendingIndicator.heightAnchor.constraint(equalToConstant: 12),

            nameLabel.leadingAnchor.constraint(equalTo: currentIndicator.trailingAnchor, constant: 4),
            nameLabel.topAnchor.constraint(equalTo: topAnchor, constant: 6),
            nameLabel.trailingAnchor.constraint(lessThanOrEqualTo: aheadBehindLabel.leadingAnchor, constant: -8),

            subjectLabel.leadingAnchor.constraint(equalTo: nameLabel.leadingAnchor),
            subjectLabel.topAnchor.constraint(equalTo: nameLabel.bottomAnchor, constant: 2),
            subjectLabel.trailingAnchor.constraint(lessThanOrEqualTo: aheadBehindLabel.leadingAnchor, constant: -8),
            subjectLabel.bottomAnchor.constraint(lessThanOrEqualTo: bottomAnchor, constant: -6),

            aheadBehindLabel.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -8),
            aheadBehindLabel.centerYAnchor.constraint(equalTo: centerYAnchor)
        ])
    }

    func configure(with branch: Branch, isCurrent: Bool, isPending: Bool, showSuccess: Bool) {
        nameLabel.stringValue = branch.name
        nameLabel.font = NSFont.systemFont(ofSize: 13, weight: isCurrent ? .bold : .semibold)
        subjectLabel.stringValue = "\(branch.tip.shortSHA)  \(branch.tip.summary)"

        if isPending {
            pendingIndicator.isHidden = false
            pendingIndicator.startAnimation(nil)
            currentIndicator.isHidden = true
        } else {
            pendingIndicator.stopAnimation(nil)
            pendingIndicator.isHidden = true

            let targetImage: NSImage?
            let targetTint: NSColor?
            if showSuccess {
                targetImage = NSImage(systemSymbolName: "checkmark.circle.fill", accessibilityDescription: "Success")
                targetTint = .systemGreen
            } else if isCurrent {
                targetImage = NSImage(systemSymbolName: "circle.fill", accessibilityDescription: "Current branch")
                targetTint = .systemBlue
            } else {
                targetImage = nil
                targetTint = nil
            }

            if let targetImage {
                if currentIndicator.isHidden {
                    currentIndicator.isHidden = false
                    currentIndicator.alphaValue = 0
                    currentIndicator.image = targetImage
                    currentIndicator.contentTintColor = targetTint
                    currentIndicator.animateAlpha(to: 1)
                } else {
                    currentIndicator.setSymbolImage(targetImage, contentTransition: !AppKitMotion.reduceMotion)
                    currentIndicator.contentTintColor = targetTint
                }
            } else if !currentIndicator.isHidden {
                currentIndicator.animateAlpha(to: 0)
                if AppKitMotion.reduceMotion {
                    currentIndicator.isHidden = true
                } else {
                    Task { @MainActor [currentIndicator] in
                        try? await Task.sleep(for: .seconds(AppKitMotion.feedback))
                        currentIndicator.isHidden = true
                    }
                }
            }
        }

        // Ahead/behind badges only meaningful for tracked local branches —
        // populated when the compare data is available. For the MVP cell we
        // show the upstream short name as a hint when present.
        if let upstream = branch.upstream, branch.isLocal {
            aheadBehindLabel.stringValue = upstream
        } else {
            aheadBehindLabel.stringValue = ""
        }
    }
}

private extension NSView {
    func animateAlpha(to target: CGFloat) {
        guard !AppKitMotion.reduceMotion else {
            alphaValue = target
            return
        }
        NSAnimationContext.runAnimationGroup { context in
            context.duration = AppKitMotion.feedback
            context.timingFunction = CAMediaTimingFunction(name: .easeInEaseOut)
            animator().alphaValue = target
        }
    }
}
