import AppKit

@MainActor
enum AboutWindowFactory {
    static func makeAboutPanel() -> NSPanel {
        let panel = NSPanel(
            contentRect: NSRect(x: 0, y: 0, width: 420, height: 540),
            styleMask: [.titled, .closable],
            backing: .buffered,
            defer: false
        )
        panel.title = "About GimMac"
        panel.isReleasedWhenClosed = false
        panel.center()
        panel.backgroundColor = NSColor(calibratedWhite: 0.09, alpha: 1)

        let content = NSView()
        panel.contentView = content

        let stack = NSStackView()
        stack.orientation = .vertical
        stack.alignment = .centerX
        stack.spacing = 14
        stack.translatesAutoresizingMaskIntoConstraints = false
        content.addSubview(stack)

        let iconView = NSImageView()
        iconView.image = NSApp.applicationIconImage ?? NSImage(named: "AppIcon")
        iconView.imageScaling = .scaleProportionallyUpOrDown
        iconView.wantsLayer = true
        iconView.layer?.cornerRadius = 22
        iconView.layer?.masksToBounds = true
        iconView.translatesAutoresizingMaskIntoConstraints = false
        NSLayoutConstraint.activate([
            iconView.widthAnchor.constraint(equalToConstant: 144),
            iconView.heightAnchor.constraint(equalToConstant: 144)
        ])

        let appNameLabel = NSTextField(labelWithString: "GimMac")
        appNameLabel.font = .systemFont(ofSize: 32, weight: .bold)
        appNameLabel.textColor = .white

        let taglineLabel = NSTextField(labelWithString: "The Native macOS Git Experience")
        taglineLabel.font = .systemFont(ofSize: 14, weight: .medium)
        taglineLabel.textColor = NSColor(calibratedWhite: 0.85, alpha: 1)

        let versionLabel = NSTextField(labelWithString: "GimMac version 0.1")
        versionLabel.font = .systemFont(ofSize: 12, weight: .semibold)
        versionLabel.textColor = NSColor(calibratedWhite: 0.85, alpha: 1)

        let copyrightLabel = NSTextField(
            labelWithString: "© 2026 GimMac Contributors.\nAll Rights Reserved."
        )
        copyrightLabel.font = .systemFont(ofSize: 10, weight: .medium)
        copyrightLabel.textColor = NSColor(calibratedWhite: 0.75, alpha: 1)
        copyrightLabel.alignment = .center
        copyrightLabel.lineBreakMode = .byWordWrapping
        copyrightLabel.maximumNumberOfLines = 2

        stack.addArrangedSubview(iconView)
        stack.addArrangedSubview(appNameLabel)
        stack.addArrangedSubview(taglineLabel)
        stack.addArrangedSubview(versionLabel)
        stack.addArrangedSubview(NSView(frame: NSRect(x: 0, y: 0, width: 1, height: 8)))
        stack.addArrangedSubview(copyrightLabel)

        NSLayoutConstraint.activate([
            stack.centerXAnchor.constraint(equalTo: content.centerXAnchor),
            stack.centerYAnchor.constraint(equalTo: content.centerYAnchor)
        ])

        return panel
    }
}
