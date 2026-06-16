import Foundation

/// Discovers installed terminal apps and launches one at a repository path.
/// The concrete implementation lives in Infrastructure because it uses `NSWorkspace`.
@MainActor
protocol ShellServiceProtocol: AnyObject {
    func availableShells() -> [TerminalShell]
    func launch(shell: TerminalShell, at repositoryURL: URL)
}
