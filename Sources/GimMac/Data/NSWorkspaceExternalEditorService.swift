import AppKit

@MainActor
final class NSWorkspaceExternalEditorService: ExternalEditorServiceProtocol {

    private static let knownEditors: [(name: String, bundleIdentifier: String)] = [
        ("Xcode", "com.apple.dt.Xcode"),
        ("Visual Studio Code", "com.microsoft.VSCode"),
        ("Visual Studio Code (Insiders)", "com.microsoft.VSCodeInsiders"),
        ("VSCodium", "com.vscodium"),
        ("Cursor", "com.todesktop.230313mzl4w4u92"),
        ("Windsurf", "com.exafunction.windsurf"),
        ("Zed", "dev.zed.Zed"),
        ("Zed (Preview)", "dev.zed.Zed-Preview"),
        ("Nova", "com.panic.Nova"),
        ("Sublime Text", "com.sublimetext.4"),
        ("Sublime Text 3", "com.sublimetext.3"),
        ("Sublime Text 2", "com.sublimetext.2"),
        ("BBEdit", "com.barebones.bbedit"),
        ("TextMate", "com.macromates.TextMate"),
        ("Emacs", "org.gnu.Emacs"),
        ("MacVim", "org.vim.MacVim"),
        ("VimR", "com.qvacua.VimR"),
        ("IntelliJ IDEA", "com.jetbrains.intellij"),
        ("IntelliJ IDEA CE", "com.jetbrains.intellij.ce"),
        ("PyCharm", "com.jetbrains.PyCharm"),
        ("PyCharm CE", "com.jetbrains.pycharm.ce"),
        ("WebStorm", "com.jetbrains.WebStorm"),
        ("GoLand", "com.jetbrains.goland"),
        ("CLion", "com.jetbrains.CLion"),
        ("Rider", "com.jetbrains.rider"),
        ("RubyMine", "com.jetbrains.RubyMine"),
        ("Android Studio", "com.google.android.studio"),
        ("Fleet", "Fleet.app"),
    ]

    func availableEditors() -> [ExternalEditor] {
        Self.knownEditors.compactMap { name, bundleID in
            guard let url = NSWorkspace.shared.urlForApplication(withBundleIdentifier: bundleID) else {
                return nil
            }
            return ExternalEditor(name: name, bundleIdentifier: bundleID, appURL: url)
        }
    }

    func launch(editor: ExternalEditor, at repositoryURL: URL) {
        let config = NSWorkspace.OpenConfiguration()
        config.activates = true
        NSWorkspace.shared.open(
            [repositoryURL],
            withApplicationAt: editor.appURL,
            configuration: config,
            completionHandler: nil
        )
    }
}
