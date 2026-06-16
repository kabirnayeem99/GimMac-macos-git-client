import Foundation
import Observation

/// Drives the branches panel UI.
///
/// Data-source trace for each property is documented inline so the read path
/// is obvious without grepping the whole codebase.
///
/// Architecture rules honored:
/// - No `AppKit` import.
/// - All state mutations on `@MainActor`.
/// - All async work runs through injected service protocols.
/// - Services are protocol types — never concrete.
@MainActor
@Observable
final class BranchesViewModel {

    // MARK: - State

    /// Local working branches.
    /// Source chain: `git for-each-ref refs/heads` → `BranchForEachRefParser`
    /// → `BranchProviding.fetchBranches` → here.
    private(set) var localBranches: [Branch] = []

    /// Remote tracking branches.
    /// Source chain: `git for-each-ref refs/remotes` → `BranchForEachRefParser`
    /// → `BranchProviding.fetchBranches` → here. `origin/HEAD` is filtered out
    /// by the parser.
    private(set) var remoteBranches: [Branch] = []

    /// Short name of the currently checked-out branch, for current-row marking.
    private(set) var currentBranchName: String?

    var selectedTab: BranchesTab = .localBranches
    var searchQuery: String = ""

    private(set) var isLoading: Bool = false
    var errorMessage: String?

    /// When non-nil, the UI should present the stash-and-switch sheet for the
    /// pending branch. The VM remembers the dirty-file count + target branch.
    private(set) var stashGuardNeeded: StashGuard?

    /// Branch currently being acted on for checkout/update, for inline progress.
    private(set) var pendingBranchName: String?

    /// Transient success/failure feedback after a branch operation.
    private(set) var lastOutcome: OpOutcome = .none

    /// Tracks the delayed reset of `lastOutcome` so overlapping operations
    /// don't clear a newer result early.
    private var outcomeResetTask: Task<Void, Never>?
    private var repositoryGeneration: Int = 0

    struct StashGuard: Equatable {
        let pendingBranch: Branch
        let dirtyFileCount: Int
    }

    /// Computed list shown in the table, after tab + search filters.
    var filteredBranches: [Branch] {
        let source: [Branch]
        switch selectedTab {
        case .localBranches:
            source = localBranches
        case .remoteBranches:
            source = remoteBranches
        }
        let query = searchQuery.trimmingCharacters(in: .whitespacesAndNewlines)
        if query.isEmpty {
            return source.sorted { $0.tip.date > $1.tip.date }
        }
        let lower = query.lowercased()
        return source
            .filter { $0.name.lowercased().contains(lower) }
            .sorted { $0.tip.date > $1.tip.date }
    }

    // MARK: - Dependencies

    private let branchProvider: BranchProviding
    private let branchOperator: BranchOperating
    private let statusProvider: StatusProviding
    let compareProvider: BranchCompareProviding?
    let updateFromDefaultProvider: UpdateFromDefaultProviding?

    /// Repository the panel operates on. Set by the host before `loadBranches`.
    var repositoryURL: URL?

    init(
        branchProvider: BranchProviding,
        branchOperator: BranchOperating,
        statusProvider: StatusProviding,
        compareProvider: BranchCompareProviding? = nil,
        updateFromDefaultProvider: UpdateFromDefaultProviding? = nil
    ) {
        self.branchProvider = branchProvider
        self.branchOperator = branchOperator
        self.statusProvider = statusProvider
        self.compareProvider = compareProvider
        self.updateFromDefaultProvider = updateFromDefaultProvider
    }

    /// Local branches sorted by most-recent tip first. Used by toolbar pull-down
    /// menus that surface a short list of switch targets without opening the full
    /// branch browser.
    var recentBranches: [Branch] {
        localBranches.sorted { $0.tip.date > $1.tip.date }
    }

    // MARK: - Actions

    func setRepository(_ url: URL?, currentBranchName: String?) {
        repositoryGeneration += 1
        self.repositoryURL = url
        self.currentBranchName = currentBranchName
        stashGuardNeeded = nil
        pendingBranchName = nil
    }

    func loadBranches() async {
        guard let repositoryURL else { return }
        let generation = repositoryGeneration
        isLoading = true
        errorMessage = nil
        defer {
            if isCurrentRepositoryTarget(repositoryURL, generation: generation) {
                isLoading = false
            }
        }

        do {
            let branches = try await branchProvider.fetchBranches(in: repositoryURL)
            guard isCurrentRepositoryTarget(repositoryURL, generation: generation) else { return }
            self.localBranches = branches.filter { $0.isLocal }
            self.remoteBranches = branches.filter { !$0.isLocal }
        } catch {
            guard isCurrentRepositoryTarget(repositoryURL, generation: generation) else { return }
            errorMessage = (error as? GitAppError)?.localizedDescription ?? error.localizedDescription
        }
    }

    func createBranch(named name: String, from startPoint: BranchStartPoint, noTrack: Bool = false) async {
        guard let repositoryURL else { return }
        errorMessage = nil
        do {
            _ = try await branchOperator.createBranch(
                named: name,
                from: startPoint,
                noTrack: noTrack,
                in: repositoryURL
            )
            await loadBranches()
            setOutcome(.success)
        } catch {
            errorMessage = (error as? GitAppError)?.localizedDescription ?? error.localizedDescription
            setOutcome(.failure)
        }
    }

    /// Switch to a branch with a stash guard.
    /// If the working tree is dirty, sets `stashGuardNeeded` and returns — the
    /// host UI must show the sheet and call `resolveStashGuard(_:)` with the
    /// user's decision.
    func switchBranch(to branch: Branch) async {
        guard let repositoryURL else { return }
        let generation = repositoryGeneration
        errorMessage = nil
        pendingBranchName = branch.name
        defer {
            if isCurrentRepositoryTarget(repositoryURL, generation: generation) {
                pendingBranchName = nil
            }
        }
        do {
            let status = try await statusProvider.fetchStatus(in: repositoryURL)
            guard isCurrentRepositoryTarget(repositoryURL, generation: generation) else { return }
            if status.isEmpty {
                try await branchOperator.switchBranch(to: branch, in: repositoryURL)
                guard isCurrentRepositoryTarget(repositoryURL, generation: generation) else { return }
                self.currentBranchName = branch.isLocal ? branch.name : branch.nameWithoutRemote
                await loadBranches()
                guard isCurrentRepositoryTarget(repositoryURL, generation: generation) else { return }
                setOutcome(.success)
            } else {
                guard isCurrentRepositoryTarget(repositoryURL, generation: generation) else { return }
                self.stashGuardNeeded = StashGuard(pendingBranch: branch, dirtyFileCount: status.count)
            }
        } catch {
            guard isCurrentRepositoryTarget(repositoryURL, generation: generation) else { return }
            errorMessage = (error as? GitAppError)?.localizedDescription ?? error.localizedDescription
            setOutcome(.failure)
        }
    }

    /// Apply the user's stash-guard decision. The host is responsible for the
    /// actual stash / discard side effects via its own services — the VM only
    /// performs the switch once the host has resolved the dirty state.
    func resolveStashGuard(_ action: DirtyWorkingTreeAction, performSwitch: Bool = true) async {
        guard let pending = stashGuardNeeded?.pendingBranch else { return }
        guard let repositoryURL else {
            stashGuardNeeded = nil
            return
        }
        let generation = repositoryGeneration
        defer {
            if isCurrentRepositoryTarget(repositoryURL, generation: generation) {
                stashGuardNeeded = nil
            }
        }
        guard performSwitch, action != .cancel else { return }
        pendingBranchName = pending.name
        defer {
            if isCurrentRepositoryTarget(repositoryURL, generation: generation) {
                pendingBranchName = nil
            }
        }
        do {
            try await branchOperator.switchBranch(to: pending, in: repositoryURL)
            guard isCurrentRepositoryTarget(repositoryURL, generation: generation) else { return }
            self.currentBranchName = pending.isLocal ? pending.name : pending.nameWithoutRemote
            await loadBranches()
            guard isCurrentRepositoryTarget(repositoryURL, generation: generation) else { return }
            setOutcome(.success)
        } catch {
            guard isCurrentRepositoryTarget(repositoryURL, generation: generation) else { return }
            errorMessage = (error as? GitAppError)?.localizedDescription ?? error.localizedDescription
            setOutcome(.failure)
        }
    }

    private func isCurrentRepositoryTarget(_ url: URL, generation: Int) -> Bool {
        repositoryGeneration == generation && repositoryURL == url
    }

    func deleteLocalBranch(_ branch: Branch, force: Bool = false) async {
        guard let repositoryURL else { return }
        errorMessage = nil
        do {
            try await branchOperator.deleteLocalBranch(branch, force: force, in: repositoryURL)
            await loadBranches()
            setOutcome(.success)
        } catch {
            errorMessage = (error as? GitAppError)?.localizedDescription ?? error.localizedDescription
            setOutcome(.failure)
        }
    }

    func deleteRemoteBranch(_ branch: Branch, remote: String) async {
        guard let repositoryURL else { return }
        errorMessage = nil
        do {
            try await branchOperator.deleteRemoteBranch(branch, remote: remote, in: repositoryURL)
            await loadBranches()
            setOutcome(.success)
        } catch {
            errorMessage = (error as? GitAppError)?.localizedDescription ?? error.localizedDescription
            setOutcome(.failure)
        }
    }

    func renameBranch(_ branch: Branch, to newName: String, force: Bool = false) async {
        guard let repositoryURL else { return }
        errorMessage = nil
        do {
            _ = try await branchOperator.renameBranch(branch, to: newName, force: force, in: repositoryURL)
            if currentBranchName == branch.name {
                currentBranchName = newName
            }
            await loadBranches()
            setOutcome(.success)
        } catch {
            errorMessage = (error as? GitAppError)?.localizedDescription ?? error.localizedDescription
            setOutcome(.failure)
        }
    }

    /// Update the current branch from the repo's default branch via merge or
    /// rebase. Requires `updateFromDefaultProvider` — no-op when nil.
    func updateBranchFromDefault(_ branch: Branch, rebase: Bool) async {
        guard let repositoryURL, let provider = updateFromDefaultProvider else { return }
        isLoading = true
        errorMessage = nil
        pendingBranchName = branch.name
        defer { isLoading = false; pendingBranchName = nil }
        do {
            if rebase {
                try await provider.rebaseOntoDefaultBranch(branch, in: repositoryURL)
            } else {
                try await provider.mergeDefaultBranch(into: branch, in: repositoryURL)
            }
            await loadBranches()
            setOutcome(.success)
        } catch {
            errorMessage = (error as? GitAppError)?.localizedDescription ?? error.localizedDescription
            setOutcome(.failure)
        }
    }

    // MARK: - Outcome feedback

    private func setOutcome(_ outcome: OpOutcome) {
        outcomeResetTask?.cancel()
        lastOutcome = outcome
        guard outcome != .none else { return }
        outcomeResetTask = Task { [weak self] in
            try? await Task.sleep(for: .seconds(1.2))
            guard let self, !Task.isCancelled else { return }
            self.lastOutcome = .none
        }
    }

    // MARK: - Validation helpers

    /// Live validation for the create / rename name fields.
    /// Mirrors `git check-ref-format --branch` rules (a subset, evaluated locally
    /// so the user gets instant feedback without invoking git on every keystroke).
    static func validateBranchName(_ rawName: String, existing: [String] = []) -> BranchNameValidation {
        let name = rawName.trimmingCharacters(in: .whitespaces)
        if name.isEmpty { return .invalid(reason: "Name is required") }
        if name.hasPrefix("-") { return .invalid(reason: "Cannot start with '-'") }
        if name.hasPrefix("/") || name.hasSuffix("/") { return .invalid(reason: "Cannot start or end with '/'") }
        if name.contains("//") { return .invalid(reason: "Cannot contain '//'") }
        if name.contains("..") { return .invalid(reason: "Cannot contain '..'") }
        if name.contains("@{") { return .invalid(reason: "Cannot contain '@{'") }
        let forbiddenChars: Set<Character> = [" ", "~", "^", ":", "?", "*", "[", "\\"]
        if name.contains(where: { forbiddenChars.contains($0) }) {
            return .invalid(reason: "Contains a forbidden character")
        }
        if existing.contains(name) {
            return .invalid(reason: "A branch with this name already exists")
        }
        return .valid
    }
}

enum BranchNameValidation: Equatable {
    case valid
    case invalid(reason: String)

    var isValid: Bool { self == .valid }
    var reason: String? {
        if case .invalid(let r) = self { return r }
        return nil
    }
}
