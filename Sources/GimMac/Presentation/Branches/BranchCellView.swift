import AppKit

/// Single row in the branches table.
///
/// Layout:
/// ```
/// [•] feature/foo          [↑2 ↓1]   commit subject…
///                          ^ ahead/behind badges (only when upstream tracked)
/// ```
final class BranchCellView: NSTableCellView {
    static let reuseIdentifier = NSUserInterfaceItemIdentifier("BranchCellView")
    static let rowHeight: CGFloat = 44

    private let currentIndicator = NSTextField(labelWithString: "•")
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

        currentIndicator.font = NSFont.boldSystemFont(ofSize: 14)
        currentIndicator.textColor = .systemBlue
        currentIndicator.alignment = .center
        currentIndicator.translatesAutoresizingMaskIntoConstraints = false

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
        addSubview(nameLabel)
        addSubview(subjectLabel)
        addSubview(aheadBehindLabel)

        NSLayoutConstraint.activate([
            currentIndicator.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 8),
            currentIndicator.centerYAnchor.constraint(equalTo: centerYAnchor),
            currentIndicator.widthAnchor.constraint(equalToConstant: 14),

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

    func configure(with branch: Branch, isCurrent: Bool) {
        currentIndicator.isHidden = !isCurrent
        nameLabel.stringValue = branch.name
        nameLabel.font = NSFont.systemFont(ofSize: 13, weight: isCurrent ? .bold : .semibold)
        subjectLabel.stringValue = "\(branch.tip.shortSHA)  \(branch.tip.summary)"
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
