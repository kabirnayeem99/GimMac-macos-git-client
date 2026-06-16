import Foundation

/// A terminal application that can open a repository directory. Native
/// equivalent of GitHub Desktop's `Shell` (`lib/shells/darwin.ts`), reduced to
/// what GimMac launches via `NSWorkspace`.
struct TerminalShell: Equatable, Hashable, Sendable {
    let name: String
    let bundleIdentifier: String
    let appURL: URL
}
