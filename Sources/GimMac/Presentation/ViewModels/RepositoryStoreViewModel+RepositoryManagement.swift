import AppKit
import Foundation

// Repository lifecycle: init, clone, remove (forget), and open-in-shell.
//
// Architecture note: AppKit's `NSWorkspace` is used here to launch the system
// Terminal at the repo path — a one-line OS integration that matches the
// existing `revealInFinder` pattern.

@MainActor
extension RepositoryStoreViewModel {
    /// `git init` a new repository in `directoryURL`, then select it. Native
    /// equivalent of GitHub Desktop's `create-repository` menu event.
    func createRepository(at directoryURL: URL) async {
        guard let provider = repositoryInitProvider else {
            errorMessage = "Repository init service is unavailable."
            return
        }
        errorMessage = nil
        do {
            try await provider.initRepository(at: directoryURL)
            await selectRepository(at: directoryURL)
        } catch {
            logger.error(
                "Repository init failed",
                category: .repository,
                metadata: ["error": error.localizedDescription]
            )
            errorMessage = error.localizedDescription
        }
    }

    /// Load picker data for the Create Repository sheet from the template
    /// catalog: `( .gitignore template names, licenses )`. Empty when no
    /// catalog is wired.
    func loadRepositoryCreationTemplates() async -> ([String], [LicenseTemplate]) {
        guard let catalog = templateCatalog else { return ([], []) }
        async let names = catalog.gitIgnoreTemplateNames()
        async let licenses = catalog.licenses()
        return await (names, licenses)
    }

    /// Run the full create-repository pipeline (`git init` → scaffold chosen
    /// files → "Initial commit"), then select the new repository. Native
    /// equivalent of GitHub Desktop's `createRepository` form submit.
    func createRepository(with options: RepositoryCreationOptions, at directoryURL: URL) async {
        guard let creator = repositoryCreator else {
            errorMessage = "Repository creation service is unavailable."
            return
        }
        isLoading = true
        errorMessage = nil
        do {
            try await creator.createRepository(with: options, at: directoryURL)
            isLoading = false
            await selectRepository(at: directoryURL)
        } catch {
            isLoading = false
            logger.error(
                "Repository creation failed",
                category: .repository,
                metadata: ["error": error.localizedDescription]
            )
            errorMessage = error.localizedDescription
        }
    }

    /// `git clone` `url` into `destinationURL`, then select it. Native
    /// equivalent of GitHub Desktop's `clone-repository` menu event.
    func cloneRepository(from url: String, to destinationURL: URL) async {
        guard let provider = repositoryCloneProvider else {
            errorMessage = "Clone service is unavailable."
            return
        }
        isLoading = true
        errorMessage = nil
        do {
            try await provider.clone(from: url, to: destinationURL)
            isLoading = false
            await selectRepository(at: destinationURL)
        } catch {
            isLoading = false
            logger.error(
                "Repository clone failed",
                category: .repository,
                metadata: ["error": error.localizedDescription]
            )
            errorMessage = error.localizedDescription
        }
    }

    /// Forget the currently selected repository. Does not delete files on
    /// disk — mirrors GitHub Desktop's `remove-repository` menu item.
    func removeSelectedRepository() async {
        guard let repo = selectedRepository else { return }
        let canonicalPath = URL(fileURLWithPath: repo.url.path, isDirectory: true)
            .resolvingSymlinksInPath()
            .standardizedFileURL
            .path
        guard let stored = savedRepositories.first(where: {
            let storedPath = URL(fileURLWithPath: $0.path, isDirectory: true)
                .resolvingSymlinksInPath()
                .standardizedFileURL
                .path
            return storedPath == canonicalPath
        }) else { return }

        errorMessage = nil
        do {
            try await repositoryPersistence.removeRepository(id: stored.id)
            selectedRepository = nil
            resetPerRepositoryState()
            await loadSavedRepositories()
            // Promote the next most-recently-opened repository, if any.
            if let next = savedRepositories.first(where: { $0.existsOnDisk }) {
                await selectPersistedRepository(id: next.id)
            }
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    /// Open the selected repository in the configured shell integration.
    func openInShell() {
        guard let repo = selectedRepository else { return }
        
        let defaults = UserDefaults.standard
        let useCustomShell = defaults.bool(forKey: "io.github.kabirnayeem99.gimmac.settings.useCustomShell")
        
        if useCustomShell,
           let data = defaults.data(forKey: "io.github.kabirnayeem99.gimmac.settings.customShell"),
           let custom = try? JSONDecoder().decode(CustomIntegration.self, from: data),
           !custom.path.isEmpty {
            let appURL = URL(fileURLWithPath: custom.path)
            let config = NSWorkspace.OpenConfiguration()
            config.activates = true
            
            var args: [String] = []
            let rawArgs = custom.arguments.split(whereSeparator: { $0.isWhitespace }).map(String.init)
            for arg in rawArgs {
                if arg.contains(CustomIntegration.targetPathArgument) {
                    args.append(arg.replacingOccurrences(of: CustomIntegration.targetPathArgument, with: repo.url.path))
                } else {
                    args.append(arg)
                }
            }
            config.arguments = args
            NSWorkspace.shared.open([repo.url], withApplicationAt: appURL, configuration: config, completionHandler: nil)
            return
        }
        
        // Predefined shell selection
        let shellURL: URL
        if let bundleID = defaults.string(forKey: "io.github.kabirnayeem99.gimmac.settings.selectedShellBundleID"),
           let appURL = NSWorkspace.shared.urlForApplication(withBundleIdentifier: bundleID) {
            shellURL = appURL
        } else {
            // Default fallback
            shellURL = URL(fileURLWithPath: "/System/Applications/Utilities/Terminal.app")
        }
        
        let config = NSWorkspace.OpenConfiguration()
        config.activates = true
        NSWorkspace.shared.open([repo.url], withApplicationAt: shellURL, configuration: config, completionHandler: nil)
    }
}
