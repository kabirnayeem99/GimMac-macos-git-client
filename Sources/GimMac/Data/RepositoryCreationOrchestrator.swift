import Foundation

/// Drives the full "Create Repository" pipeline by composing the existing git
/// providers with the file-scaffolding service. Native equivalent of GitHub
/// Desktop's `createRepository` (`create-repository.tsx`):
///
/// 1. `git init` (default branch from global config — `RepositoryInitProviding`)
/// 2. write `README.md`            (if requested)
/// 3. write `.gitignore`           (if a template was chosen)
/// 4. write `.git/description`     (if a description was given)
/// 5. write `LICENSE`              (if a license was chosen)
/// 6. write `.gitattributes`
/// 7. `git add -A -- .` + `git commit -m "Initial commit"` (if anything was
///    scaffolded and an initial commit was requested)
///
/// The commit is skipped when nothing was scaffolded, mirroring GitHub Desktop's
/// `files.length > 0` guard — a bare `git init` produces no files to commit.
final class RepositoryCreationOrchestrator: RepositoryCreating, Sendable {
    private let initProvider: RepositoryInitProviding
    private let scaffolding: RepositoryScaffolding
    private let catalog: RepositoryTemplateCatalog
    private let commitProvider: CommitProviding
    private let configReader: GitConfigReading
    private let currentYear: @Sendable () -> String

    init(
        initProvider: RepositoryInitProviding,
        scaffolding: RepositoryScaffolding,
        catalog: RepositoryTemplateCatalog,
        commitProvider: CommitProviding,
        configReader: GitConfigReading,
        currentYear: @escaping @Sendable () -> String = {
            String(Calendar.current.component(.year, from: Date()))
        }
    ) {
        self.initProvider = initProvider
        self.scaffolding = scaffolding
        self.catalog = catalog
        self.commitProvider = commitProvider
        self.configReader = configReader
        self.currentYear = currentYear
    }

    func createRepository(with options: RepositoryCreationOptions, at directoryURL: URL) async throws {
        // Ensure the destination exists (GitHub Desktop's `mkdir({recursive})`).
        try FileManager.default.createDirectory(at: directoryURL, withIntermediateDirectories: true)

        // 1. git init
        try await initProvider.initRepository(at: directoryURL)

        var didScaffoldAnyFile = false

        // 2. README
        if options.includeReadme {
            try await scaffolding.writeReadme(
                name: options.name,
                description: options.description,
                in: directoryURL
            )
            didScaffoldAnyFile = true
        }

        // 3. .gitignore
        if let templateName = options.gitIgnoreTemplateName {
            let contents = try await catalog.gitIgnoreTemplate(named: templateName)
            try await scaffolding.writeGitIgnore(contents: contents, in: directoryURL)
            didScaffoldAnyFile = true
        }

        // 4. .git/description (not a working-tree file; never affects the commit)
        if let description = options.description?.trimmingCharacters(in: .whitespacesAndNewlines),
           !description.isEmpty {
            try await scaffolding.writeGitDescription(description, in: directoryURL)
        }

        // 5. LICENSE
        if let licenseName = options.licenseName,
           let license = await catalog.licenses().first(where: { $0.name == licenseName }) {
            let fields = await licenseFields(project: options.name)
            try await scaffolding.writeLicense(license, fields: fields, in: directoryURL)
            didScaffoldAnyFile = true
        }

        // 6. .gitattributes
        try await scaffolding.writeGitAttributes(in: directoryURL)
        didScaffoldAnyFile = true

        // 7. Initial commit — stage everything (`git add -A -- .`) and commit.
        if options.makeInitialCommit && didScaffoldAnyFile {
            try await commitProvider.commit(
                in: directoryURL,
                paths: ["."],
                summary: "Initial commit",
                description: nil,
                options: CommitOptions()
            )
        }
    }

    /// Resolve license author fields from global git config; missing values
    /// fall back to empty strings (GitHub Desktop does the same).
    private func licenseFields(project: String) async -> LicenseFields {
        let name = ((try? await configReader.globalUserName()) ?? nil) ?? ""
        let email = ((try? await configReader.globalUserEmail()) ?? nil) ?? ""
        return LicenseFields(fullname: name, email: email, project: project, year: currentYear())
    }
}
