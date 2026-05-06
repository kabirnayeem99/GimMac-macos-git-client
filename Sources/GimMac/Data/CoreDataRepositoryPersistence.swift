import CoreData
import Foundation

private enum RepositoryEntity {
    static let name = "RepositoryRecord"
}

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
        container.loadPersistentStores { _, error in
            if let error {
                assertionFailure("Failed to load repository store: \(error)")
            }
        }
        container.viewContext.mergePolicy = NSMergePolicy(merge: .mergeByPropertyObjectTrumpMergePolicyType)
        container.viewContext.automaticallyMergesChangesFromParent = true
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

    private func canonicalize(_ path: String) -> String {
        URL(fileURLWithPath: path, isDirectory: true)
            .resolvingSymlinksInPath()
            .standardizedFileURL
            .path
    }

    private func performRead<T>(_ block: @Sendable @escaping (NSManagedObjectContext) throws -> T) async throws -> T {
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

    private func performWrite<T>(_ block: @Sendable @escaping (NSManagedObjectContext) throws -> T) async throws -> T {
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

    private static func toStoredRepository(_ object: NSManagedObject) -> StoredRepository {
        let path = object.value(forKey: "path") as? String ?? ""
        return StoredRepository(
            id: object.value(forKey: "id") as? UUID ?? UUID(),
            name: object.value(forKey: "name") as? String ?? URL(fileURLWithPath: path).lastPathComponent,
            path: path,
            gitIdentifier: object.value(forKey: "gitIdentifier") as? String,
            currentlySelected: object.value(forKey: "currentlySelected") as? Bool ?? false,
            lastOpenedAt: object.value(forKey: "lastOpenedAt") as? Date ?? .distantPast,
            createdAt: object.value(forKey: "createdAt") as? Date ?? .distantPast,
            updatedAt: object.value(forKey: "updatedAt") as? Date ?? .distantPast,
            existsOnDisk: FileManager.default.fileExists(atPath: path)
        )
    }

    private static func makeModel() -> NSManagedObjectModel {
        let model = NSManagedObjectModel()
        let entity = NSEntityDescription()
        entity.name = RepositoryEntity.name
        entity.managedObjectClassName = NSStringFromClass(NSManagedObject.self)

        func attribute(
            _ name: String,
            type: NSAttributeType,
            optional: Bool
        ) -> NSAttributeDescription {
            let attr = NSAttributeDescription()
            attr.name = name
            attr.attributeType = type
            attr.isOptional = optional
            return attr
        }

        let id = attribute("id", type: .UUIDAttributeType, optional: false)
        let name = attribute("name", type: .stringAttributeType, optional: false)
        let path = attribute("path", type: .stringAttributeType, optional: false)
        let gitIdentifier = attribute("gitIdentifier", type: .stringAttributeType, optional: true)
        let currentlySelected = attribute("currentlySelected", type: .booleanAttributeType, optional: false)
        let lastOpenedAt = attribute("lastOpenedAt", type: .dateAttributeType, optional: false)
        let createdAt = attribute("createdAt", type: .dateAttributeType, optional: false)
        let updatedAt = attribute("updatedAt", type: .dateAttributeType, optional: false)

        entity.properties = [id, name, path, gitIdentifier, currentlySelected, lastOpenedAt, createdAt, updatedAt]
        entity.uniquenessConstraints = [["path"]]
        entity.indexes = [
            NSFetchIndexDescription(
                name: "idx_path",
                elements: [NSFetchIndexElementDescription(property: path, collationType: .binary)]
            ),
            NSFetchIndexDescription(
                name: "idx_last_opened_at",
                elements: [NSFetchIndexElementDescription(property: lastOpenedAt, collationType: .binary)]
            ),
            NSFetchIndexDescription(
                name: "idx_currently_selected",
                elements: [NSFetchIndexElementDescription(property: currentlySelected, collationType: .binary)]
            )
        ]
        model.entities = [entity]
        return model
    }
}
