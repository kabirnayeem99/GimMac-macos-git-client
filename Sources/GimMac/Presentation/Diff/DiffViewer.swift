import SwiftUI

struct DiffViewer: View {
    private let lines: [DiffLine] = [
        .context(9, "    settingAction: Selector"),
        .context(10, ") -> NSMenu {"),
        .context(11, "    let mainMenu = NSMenu()"),
        .removed(12, "    "),
        .added(12, "    let appMenuItem = NSMenuItem(title: \"GimMac\", action: nil, keyEquivalent: \"\")"),
        .context(13, "    appMenuItem.submenu = buildAppMenu("),
        .context(14, "        actionTarget: actionTarget,"),
        .context(15, "        settingsAction: settingsAction"),
        .context(18, "    )"),
        .context(20, "    mainMenu.addItem(appMenuItem)"),
        .removed(21, "    "),
        .added(21, "    let fileMenuItem = NSMenuItem(title: \"File\", action: nil, keyEquivalent: \"\")"),
        .context(22, "    fileMenuItem.submenu = buildFileMenu(actionTarget: actionTarget, placeholderAction: placeholderAction)"),
        .context(24, "    mainMenu.addItem(fileMenuItem)"),
        .removed(25, "    "),
        .added(25, "    let editMenuItem = NSMenuItem(title: \"Edit\", action: nil, keyEquivalent: \"\")"),
        .context(26, "    editMenuItem.submenu = buildEditMenu(actionTarget: actionTarget, placeholderAction: placeholderAction)")
    ]

    var body: some View {
        VStack(spacing: 0) {
            DiffHeader()

            ScrollView([.vertical, .horizontal]) {
                LazyVStack(spacing: 0) {
                    ForEach(lines) { line in
                        DiffLineRow(line: line)
                    }
                }
                .font(.system(size: 12, design: .monospaced))
                .padding(.vertical, 8)
            }
            .background(Color(nsColor: .textBackgroundColor))
        }
    }
}
