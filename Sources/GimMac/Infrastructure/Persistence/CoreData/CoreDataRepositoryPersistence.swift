import CoreData
import Foundation

internal enum RepositoryEntity {
    static let name = "RepositoryRecord"
}

/// Core Data-backed persistence for recently-opened repositories. Loads its own
/// managed-object model programmatically so the model file does not need to be
/// bundled as a resource.
final class CoreDataRepositoryPersistence: RepositoryPersistenceProviding, @unchecked Sendable {
    private let container: NSPersistentContainer
    private let gitClient: GitClientProtocol

    init(
        gitClient: GitClientProtocol,
        storeURL: URL? = nil,
        inMemory: Bool = false
    ) {
        self.gitClient = gitClient
        let model = Self.makeModel()
        container = NSPersistentContainer(name: "RepositoryStore", managedObjectModel: model)

        let description = NSPersistentStoreDescription()
        if inMemory {
            description.type = NSInMemoryStoreType
        } else {
            let base = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first
                ?? FileManager.default.homeDirectoryForCurrentUser
            let dir = base.appendingPathComponent("GimMac", isDirectory: true)
            try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
            description.type = NSSQLiteStoreType
            description.url = storeURL ?? dir.appendingPathComponent("RepositoryStore.sqlite")
        }
        description.shouldInferMappingModelAutomatically = true
        description.shouldMigrateStoreAutomatically = true
        container.persistentStoreDescriptions = [description]

        // SQLite store loads synchronously, so the completion handler runs before
        // `loadPersistentStores` returns and we can capture any failure here.
        var loadFailure: Error?
        container.loadPersistentStores { _, error in
            loadFailure = error
        }
        // A corrupt or incompatible on-disk store should not crash the app
        // (`assertionFailure` aborts debug builds). Destroy the backing files and
        // reload once; if it still fails, persistence is degraded but reads/writes
        // surface as thrown errors that callers already handle.
        if loadFailure != nil, !inMemory, let storeURL = description.url {
            Self.destroyStore(at: storeURL)
            container.loadPersistentStores { _, _ in }
        }

        container.viewContext.mergePolicy = NSMergePolicy(merge: .mergeByPropertyObjectTrumpMergePolicyType)
        container.viewContext.automaticallyMergesChangesFromParent = true
    }

    /// Removes a SQLite store and its WAL/SHM sidecar files so a fresh store can
    /// be created in its place.
    private static func destroyStore(at storeURL: URL) {
        let fileManager = FileManager.default
        for suffix in ["", "-wal", "-shm"] {
            let url = suffix.isEmpty
                ? storeURL
                : storeURL.deletingLastPathComponent()
                    .appendingPathComponent(storeURL.lastPathComponent + suffix)
            try? fileManager.removeItem(at: url)
        }
    }

    func saveOrUpdateRepository(path: String) async throws -> StoredRepository {
        let canonicalPath = canonicalize(path)
        let headHash = try await readHeadHash(path: canonicalPath)
        let now = Date()
        let selectedObjectID: NSManagedObjectID = try await performWrite { context in
            let record = try self.fetchOrCreateByPath(canonicalPath, in: context, now: now)
            record.setValue(URL(fileURLWithPath: canonicalPath).lastPathComponent, forKey: "name")
            record.setValue(canonicalPath, forKey: "path")
            record.setValue(headHash, forKey: "gitIdentifier")
            record.setValue(now, forKey: "lastOpenedAt")
            record.setValue(now, forKey: "updatedAt")
            try self.clearSelection(except: record, in: context)
            record.setValue(true, forKey: "currentlySelected")
            try context.save()
            return record.objectID
        }

        return try await fetchStoredRepository(objectID: selectedObjectID)
    }

    func getAllRepositoriesSortedByLastOpened() async throws -> [StoredRepository] {
        try await performRead { context in
            let request = NSFetchRequest<NSManagedObject>(entityName: RepositoryEntity.name)
            request.sortDescriptors = [NSSortDescriptor(key: "lastOpenedAt", ascending: false)]
            return try context.fetch(request).map(Self.toStoredRepository)
        }
    }

    func getCurrentlySelectedRepository() async throws -> StoredRepository? {
        try await performRead { context in
            let request = NSFetchRequest<NSManagedObject>(entityName: RepositoryEntity.name)
            request.predicate = NSPredicate(format: "currentlySelected == YES")
            request.fetchLimit = 1
            return try context.fetch(request).first.map(Self.toStoredRepository)
        }
    }

    func selectRepository(id: UUID) async throws -> StoredRepository? {
        let now = Date()
        let selectedObjectID: NSManagedObjectID? = try await performWrite { context in
            let request = NSFetchRequest<NSManagedObject>(entityName: RepositoryEntity.name)
            request.predicate = NSPredicate(format: "id == %@", id as CVarArg)
            request.fetchLimit = 1
            guard let selected = try context.fetch(request).first else {
                return nil
            }

            try self.clearSelection(except: selected, in: context)
            selected.setValue(true, forKey: "currentlySelected")
            selected.setValue(now, forKey: "lastOpenedAt")
            selected.setValue(now, forKey: "updatedAt")
            try context.save()
            return selected.objectID
        }

        guard let selectedObjectID else {
            return nil
        }

        return try await fetchStoredRepository(objectID: selectedObjectID)
    }

    func removeRepository(id: UUID) async throws {
        try await performWrite { context in
            let request = NSFetchRequest<NSManagedObject>(entityName: RepositoryEntity.name)
            request.predicate = NSPredicate(format: "id == %@", id as CVarArg)
            request.fetchLimit = 1
            guard let record = try context.fetch(request).first else { return }
            context.delete(record)
            try context.save()
        }
    }

    func selectMostRecentlyOpenedRepositoryOnLaunch() async throws -> StoredRepository? {
        let repositories = try await getAllRepositoriesSortedByLastOpened()
        for repository in repositories where repository.existsOnDisk {
            return try await selectRepository(id: repository.id)
        }

        return nil
    }

    private func fetchStoredRepository(objectID: NSManagedObjectID) async throws -> StoredRepository {
        try await performRead { context in
            let object = try context.existingObject(with: objectID)
            return Self.toStoredRepository(object)
        }
    }

    private func readHeadHash(path: String) async throws -> String? {
        let url = URL(fileURLWithPath: path, isDirectory: true)
        do {
            let result = try await gitClient.run(["rev-parse", "HEAD"], in: url, timeout: 3)
            let hash = result.stdout.trimmingCharacters(in: .whitespacesAndNewlines)
            return hash.isEmpty ? nil : hash
        } catch {
            return nil
        }
    }

    private func fetchOrCreateByPath(_ path: String, in context: NSManagedObjectContext, now: Date) throws -> NSManagedObject {
        let request = NSFetchRequest<NSManagedObject>(entityName: RepositoryEntity.name)
        request.predicate = NSPredicate(format: "path == %@", path)
        request.fetchLimit = 1
        if let existing = try context.fetch(request).first {
            return existing
        }

        guard let entity = NSEntityDescription.entity(forEntityName: RepositoryEntity.name, in: context) else {
            throw NSError(domain: "CoreDataRepositoryPersistence", code: 1)
        }

        let record = NSManagedObject(entity: entity, insertInto: context)
        record.setValue(UUID(), forKey: "id")
        record.setValue(false, forKey: "currentlySelected")
        record.setValue(now, forKey: "createdAt")
        record.setValue(now, forKey: "updatedAt")
        record.setValue(now, forKey: "lastOpenedAt")
        return record
    }

    private func clearSelection(except selected: NSManagedObject, in context: NSManagedObjectContext) throws {
        let request = NSFetchRequest<NSManagedObject>(entityName: RepositoryEntity.name)
        request.predicate = NSPredicate(format: "currentlySelected == YES AND self != %@", selected)
        let selectedRecords = try context.fetch(request)
        for record in selectedRecords {
            record.setValue(false, forKey: "currentlySelected")
            record.setValue(Date(), forKey: "updatedAt")
        }
    }

    private func performRead<T>(
        _ block: @Sendable @escaping (NSManagedObjectContext) throws -> T
    ) async throws -> T {
        try await withCheckedThrowingContinuation { continuation in
            container.performBackgroundTask { context in
                do {
                    continuation.resume(returning: try block(context))
                } catch {
                    continuation.resume(throwing: error)
                }
            }
        }
    }

    private func performWrite<T>(
        _ block: @Sendable @escaping (NSManagedObjectContext) throws -> T
    ) async throws -> T {
        try await withCheckedThrowingContinuation { continuation in
            container.performBackgroundTask { context in
                do {
                    let value = try block(context)
                    continuation.resume(returning: value)
                } catch {
                    continuation.resume(throwing: error)
                }
            }
        }
    }
}
