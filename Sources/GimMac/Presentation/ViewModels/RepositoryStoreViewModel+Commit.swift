import Foundation

// Commit creation, undo, co-author management, and amend toggling.

@MainActor
extension RepositoryStoreViewModel {
    func commitChanges() async {
        guard canCommitChanges, !hasUnresolvedConflicts, let repository = selectedRepository else {
            logger.warning(
                "Commit guard failed — nothing to do",
                category: .commit,
                metadata: [
                    "canCommit": "\(canCommitChanges)",
                    "hasConflicts": "\(hasUnresolvedConflicts)",
                    "hasRepository": "\(selectedRepository != nil)"
                ]
            )
            return
        }

        let summary = commitForm.trimmedSummary
        let description = commitForm.trimmedDescription
        let pathsToCommit = changedFilesHandler.checkedPaths.sorted()

        logger.info(
            "Commit started",
            category: .commit,
            metadata: [
                "repository": repository.url.lastPathComponent,
                "files": "\(pathsToCommit.count)",
                "amend": "\(commitForm.isAmendMode)",
                "skipHooks": "\(commitForm.skipHooks)",
                "signOff": "\(commitForm.signOff)"
            ]
        )

        commitForm.setCommitting(true)
        errorMessage = nil
        defer { commitForm.setCommitting(false) }

        let options = CommitOptions(
            skipHooks: commitForm.skipHooks,
            signOff: commitForm.signOff,
            isAmend: commitForm.isAmendMode,
            coAuthors: commitForm.coAuthors
        )

        do {
            try await commitProvider.commit(
                in: repository.url,
                paths: pathsToCommit,
                summary: summary,
                description: description.isEmpty ? nil : description,
                options: options
            )
            logger.info("Commit succeeded", category: .commit)
            commitForm.reset()
            await refreshRepositoryScreenData()
        } catch {
            logger.error(
                "Commit failed",
                category: .commit,
                metadata: ["error": error.localizedDescription]
            )
            errorMessage = error.localizedDescription
        }
    }

    func undoCommit() async {
        guard let repository = selectedRepository else { return }
        errorMessage = nil
        do {
            try await commitProvider.undoLastCommit(in: repository.url)
            await refreshRepositoryScreenData()
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    /// Parse and add a `Name <email>` token to the commit's co-author list.
    /// Returns false when the token is malformed (so the UI can flag it).
    @discardableResult
    func addCoAuthor(from token: String) -> Bool {
        guard let author = CommitAuthor.parse(token) else { return false }
        commitForm.addCoAuthor(author)
        return true
    }

    func removeCoAuthor(_ author: CommitAuthor) {
        commitForm.removeCoAuthor(author)
    }

    func toggleAmendMode() {
        commitForm.toggleAmend()
        logger.info("Amend mode toggled", category: .commit, metadata: ["enabled": "\(commitForm.isAmendMode)"])
        if commitForm.isAmendMode, let last = commits.first {
            commitForm.reset()
            commitForm.prefill(summary: last.summary, body: last.body)
        }
    }
}
