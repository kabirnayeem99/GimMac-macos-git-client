import Foundation

// Domain model for the "Create Repository" flow. Native equivalent of GitHub
// Desktop's `create-repository` (`create-repository.tsx`), which runs only two
// git commands — `git init` and an initial `add`+`commit` — and writes the
// README / .gitignore / LICENSE / .gitattributes / description files directly.
// We mirror that split: pure file writes live behind `RepositoryScaffolding`;
// the two git commands stay behind their existing providers;
// `RepositoryCreating` orchestrates the whole pipeline.

/// User-chosen options for scaffolding a brand-new repository. Native
/// equivalent of GitHub Desktop's `create-repository` form state.
struct RepositoryCreationOptions: Equatable, Sendable {
    /// Repository name. Used for the README title, LICENSE `{project}` token,
    /// and (by the caller) the destination folder name.
    var name: String
    /// Optional description — written into the README body and `.git/description`.
    var description: String?
    /// Write a default `README.md`.
    var includeReadme: Bool
    /// Name of a `.gitignore` template from `RepositoryTemplateCatalog`, or
    /// `nil` for no `.gitignore`.
    var gitIgnoreTemplateName: String?
    /// Name of a `LicenseTemplate`, or `nil` for no `LICENSE`.
    var licenseName: String?
    /// Stage and commit the scaffolded files as an "Initial commit". Skipped
    /// automatically when nothing was scaffolded (mirrors GitHub Desktop's
    /// `files.length > 0` guard).
    var makeInitialCommit: Bool

    init(
        name: String,
        description: String? = nil,
        includeReadme: Bool = false,
        gitIgnoreTemplateName: String? = nil,
        licenseName: String? = nil,
        makeInitialCommit: Bool = true
    ) {
        self.name = name
        self.description = description
        self.includeReadme = includeReadme
        self.gitIgnoreTemplateName = gitIgnoreTemplateName
        self.licenseName = licenseName
        self.makeInitialCommit = makeInitialCommit
    }
}

/// A license the user can attach to a new repository. Mirrors GitHub Desktop's
/// `ILicense`. `body` carries `{token}` / `[token]` placeholders substituted at
/// write time via `LicenseFields`.
struct LicenseTemplate: Equatable, Sendable, Identifiable {
    var id: String { name }
    /// Human-readable name, e.g. "MIT License". Also the value stored in
    /// `RepositoryCreationOptions.licenseName`.
    let name: String
    /// Whether to surface this license at the top of the picker.
    let featured: Bool
    /// Raw template text including unsubstituted placeholders.
    let body: String
}

/// Values substituted into a `LicenseTemplate.body` — e.g. `{fullname}`,
/// `{year}`, `{project}`. Mirrors GitHub Desktop's `ILicenseFields`.
struct LicenseFields: Equatable, Sendable {
    let fullname: String
    let email: String
    let project: String
    let year: String
}
