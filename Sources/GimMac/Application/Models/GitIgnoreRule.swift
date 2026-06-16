import Foundation

/// Builds `.gitignore` rule strings from file paths. Pure string logic —
/// mirrors GitHub Desktop's `escapeGitSpecialCharacters` / rule construction
/// (`gitignore.ts`). The `repositoryURL`-relative paths are escaped so that
/// glob metacharacters in a filename are treated literally.
enum GitIgnoreRule {
    /// Git pattern metacharacters that must be backslash-escaped to match literally.
    private static let specialCharacters: Set<Character> = ["[", "]", "!", "*", "#", "?"]

    /// Escape git special characters (`[ ] ! * # ?`) in a literal path.
    static func escape(_ pattern: String) -> String {
        var result = ""
        result.reserveCapacity(pattern.count)
        for character in pattern {
            if specialCharacters.contains(character) { result.append("\\") }
            result.append(character)
        }
        return result
    }

    /// Rule that ignores a single file by its repo-relative path.
    static func fileRule(forRelativePath path: String) -> String {
        escape(path)
    }

    /// Rule that ignores a folder by its repo-relative path (trailing slash
    /// marks it as a directory).
    static func folderRule(forRelativePath folder: String) -> String {
        escape(folder) + "/"
    }

    /// Rule that ignores every file with the given extension (`*.ext`). The
    /// leading `*` is an intentional glob, so only the extension is escaped.
    static func extensionRule(forExtension fileExtension: String) -> String {
        "*." + escape(fileExtension)
    }

    /// Repo-relative ancestor directories of a path, immediate parent first.
    /// e.g. `a/b/c.txt` → `["a/b", "a"]`. Used to populate the "Ignore Folder" menu.
    static func ancestorFolders(ofRelativePath path: String) -> [String] {
        let directories = path.split(separator: "/").dropLast().map(String.init)
        guard !directories.isEmpty else { return [] }
        return (1...directories.count).reversed().map { directories.prefix($0).joined(separator: "/") }
    }

    /// File extension of a path's last component, or nil when there is none.
    static func fileExtension(ofRelativePath path: String) -> String? {
        let name = path.split(separator: "/").last.map(String.init) ?? path
        guard let dot = name.lastIndex(of: "."), dot != name.startIndex else { return nil }
        let ext = String(name[name.index(after: dot)...])
        return ext.isEmpty ? nil : ext
    }
}
