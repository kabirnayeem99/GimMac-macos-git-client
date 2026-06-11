import AppKit

/// Discovers installed terminal apps via their bundle identifiers and opens a
/// repository directory in the chosen one. Mirrors
/// `NSWorkspaceExternalEditorService`. Native equivalent of GitHub Desktop's
/// `lib/shells/darwin.ts`.
@MainActor
final class NSWorkspaceShellService: ShellServiceProtocol {

    private static let knownShells: [(name: String, bundleIdentifier: String)] = [
        ("Terminal", "com.apple.Terminal"),
        ("iTerm2", "com.googlecode.iterm2"),
        ("Hyper", "co.zeit.hyper"),
        ("Warp", "dev.warp.Warp-Stable"),
        ("Alacritty", "org.alacritty"),
        ("kitty", "net.kovidgoyal.kitty"),
        ("WezTerm", "com.github.wez.wezterm"),
        ("Ghostty", "com.mitchellh.ghostty"),
        ("Tabby", "org.tabby"),
    ]

    func availableShells() -> [TerminalShell] {
        Self.knownShells.compactMap { name, bundleID in
            guard let url = NSWorkspace.shared.urlForApplication(withBundleIdentifier: bundleID) else {
                return nil
            }
            return TerminalShell(name: name, bundleIdentifier: bundleID, appURL: url)
        }
    }

    func launch(shell: TerminalShell, at repositoryURL: URL) {
        let config = NSWorkspace.OpenConfiguration()
        config.activates = true
        NSWorkspace.shared.open(
            [repositoryURL],
            withApplicationAt: shell.appURL,
            configuration: config,
            completionHandler: nil
        )
    }
}
