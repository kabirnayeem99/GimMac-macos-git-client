import Foundation

/// Loads bundled scaffolding templates. The Data layer reads these from the app
/// bundle; the catalog is directory-driven so additional templates require no
/// code change. Native equivalent of GitHub Desktop's `gitignores.ts` /
/// `licenses.ts`, which read from a bundled `static/` directory.
protocol RepositoryTemplateCatalog: Sendable {
    /// Names of the available `.gitignore` templates (sorted).
    func gitIgnoreTemplateNames() async -> [String]
    /// Raw text of a named `.gitignore` template.
    /// - Throws: `GitAppError.scaffoldingFailed` if the template is unknown.
    func gitIgnoreTemplate(named name: String) async throws -> String
    /// Available licenses, featured first then alphabetical.
    func licenses() async -> [LicenseTemplate]
}

/// Writes scaffold files into a freshly-initialised repository. Pure file
/// writes — no git command is run. Native equivalent of GitHub Desktop's
/// `writeDefaultReadme` / `writeGitIgnore` / `writeGitAttributes` /
/// `writeLicense` / `writeGitDescription`.
protocol RepositoryScaffolding: Sendable {
    /// Write `README.md` as `# <name>` plus an optional description paragraph.
    func writeReadme(name: String, description: String?, in directoryURL: URL) async throws
    /// Write the given `.gitignore` contents to the repository root.
    func writeGitIgnore(contents: String, in directoryURL: URL) async throws
    /// Write `.gitattributes` with `* text=auto` LF normalization.
    func writeGitAttributes(in directoryURL: URL) async throws
    /// Write `LICENSE` from the template with `fields` substituted.
    func writeLicense(_ license: LicenseTemplate, fields: LicenseFields, in directoryURL: URL) async throws
    /// Write `.git/description`.
    func writeGitDescription(_ description: String, in directoryURL: URL) async throws
}

/// Full create-repository pipeline: `git init`, scaffold the chosen files, then
/// an optional "Initial commit". Native equivalent of GitHub Desktop's
/// `createRepository` (`create-repository.tsx`).
protocol RepositoryCreating: Sendable {
    func createRepository(with options: RepositoryCreationOptions, at directoryURL: URL) async throws
}
