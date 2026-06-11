import Foundation

/// Loads `.gitignore` and license templates bundled in the app's `Templates/`
/// resource folder. Native equivalent of GitHub Desktop's `gitignores.ts` /
/// `licenses.ts`, which enumerate a bundled `static/` directory.
///
/// Layout (a blue folder reference, so structure is preserved in the bundle):
/// ```
/// Templates/
///   GitIgnore/<Name>.gitignore
///   Licenses/licenses.json        // [{ "name", "featured", "file" }]
///   Licenses/<file>.txt           // license body with {token} placeholders
/// ```
/// Directory-driven: dropping more `.gitignore` files into `GitIgnore/` (or
/// adding entries to `licenses.json`) extends the catalog with no code change —
/// this is how the full upstream GitHub template set is meant to be vendored in.
///
/// Results are loaded lazily and cached behind an actor for thread safety.
final class BundledRepositoryTemplateCatalog: RepositoryTemplateCatalog, Sendable {
    private let bundle: Bundle
    /// Overrides bundle lookup when set — used by tests to point at a temporary
    /// `Templates/` directory.
    private let templatesRootOverride: URL?
    private let cache = Cache()

    init(bundle: Bundle = .main, templatesRootOverride: URL? = nil) {
        self.bundle = bundle
        self.templatesRootOverride = templatesRootOverride
    }

    func gitIgnoreTemplateNames() async -> [String] {
        await loadGitIgnores().keys.sorted()
    }

    func gitIgnoreTemplate(named name: String) async throws -> String {
        guard let contents = await loadGitIgnores()[name] else {
            throw GitAppError.scaffoldingFailed(
                file: ".gitignore",
                reason: "Unknown .gitignore template: \(name)"
            )
        }
        return contents
    }

    func licenses() async -> [LicenseTemplate] {
        await loadLicenses()
    }

    // MARK: - Loading

    private func loadGitIgnores() async -> [String: String] {
        if let cached = await cache.gitIgnores { return cached }
        let loaded = readGitIgnores()
        await cache.setGitIgnores(loaded)
        return loaded
    }

    private func loadLicenses() async -> [LicenseTemplate] {
        if let cached = await cache.licenses { return cached }
        let loaded = readLicenses()
        await cache.setLicenses(loaded)
        return loaded
    }

    /// Map of template name (basename without `.gitignore`) → contents.
    private func readGitIgnores() -> [String: String] {
        guard let directory = templatesSubdirectory("GitIgnore") else { return [:] }
        let fileManager = FileManager.default
        guard let entries = try? fileManager.contentsOfDirectory(
            at: directory,
            includingPropertiesForKeys: nil
        ) else { return [:] }

        var result: [String: String] = [:]
        for url in entries where url.pathExtension == "gitignore" {
            guard let contents = try? String(contentsOf: url, encoding: .utf8) else { continue }
            let name = url.deletingPathExtension().lastPathComponent
            result[name] = contents
        }
        return result
    }

    private func readLicenses() -> [LicenseTemplate] {
        guard let directory = templatesSubdirectory("Licenses") else { return [] }
        let manifestURL = directory.appendingPathComponent("licenses.json")
        guard
            let data = try? Data(contentsOf: manifestURL),
            let entries = try? JSONDecoder().decode([LicenseManifestEntry].self, from: data)
        else { return [] }

        let templates: [LicenseTemplate] = entries.compactMap { entry in
            let bodyURL = directory.appendingPathComponent(entry.file)
            guard let body = try? String(contentsOf: bodyURL, encoding: .utf8) else { return nil }
            return LicenseTemplate(name: entry.name, featured: entry.featured, body: body)
        }

        // Featured first, then alphabetical — mirrors GitHub Desktop's sort.
        return templates.sorted { lhs, rhs in
            if lhs.featured != rhs.featured { return lhs.featured }
            return lhs.name.localizedCaseInsensitiveCompare(rhs.name) == .orderedAscending
        }
    }

    /// Resolve `Templates/<name>` inside the bundle (folder reference).
    private func templatesSubdirectory(_ name: String) -> URL? {
        if let override = templatesRootOverride {
            return override.appendingPathComponent(name)
        }
        if let url = bundle.url(forResource: name, withExtension: nil, subdirectory: "Templates") {
            return url
        }
        // Fallback: resolve the Templates folder first, then append.
        if let root = bundle.url(forResource: "Templates", withExtension: nil) {
            return root.appendingPathComponent(name)
        }
        return nil
    }
}

/// One entry in `Licenses/licenses.json`.
private struct LicenseManifestEntry: Decodable {
    let name: String
    let featured: Bool
    let file: String
}

/// Caches loaded templates so the bundle is read at most once each.
private actor Cache {
    var gitIgnores: [String: String]?
    var licenses: [LicenseTemplate]?

    func setGitIgnores(_ value: [String: String]) { gitIgnores = value }
    func setLicenses(_ value: [LicenseTemplate]) { licenses = value }
}
