import Foundation

/// A terminal application that can open a repository directory. Native
/// equivalent of GitHub Desktop's `Shell` (`lib/shells/darwin.ts`), reduced to
/// what GimMac launches via `NSWorkspace`.
struct TerminalShell: Equatable, Hashable, Sendable {
    let name: String
    let bundleIdentifier: String
    let appURL: URL
}

/// Discovers installed terminal apps and launches one at a repository path.
/// Mirrors `ExternalEditorServiceProtocol`; the concrete implementation lives in
/// the App layer because it uses `NSWorkspace`.
@MainActor
protocol ShellServiceProtocol: AnyObject {
    func availableShells() -> [TerminalShell]
    func launch(shell: TerminalShell, at repositoryURL: URL)
}
