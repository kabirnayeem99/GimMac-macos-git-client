import CoreData
import Foundation

extension CoreDataRepositoryPersistence {
    /// Converts a persisted `NSManagedObject` into the domain `StoredRepository`
    /// value, deriving the display name from the path when necessary.
    internal static func toStoredRepository(_ object: NSManagedObject) -> StoredRepository {
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
            existsOnDisk: FileExistenceCache.shared.exists(atPath: path)
        )
    }

    /// Resolves a repository path to a stable, absolute form by removing symlinks
    /// and standardizing the file URL. This ensures the same directory opened
    /// through different paths shares one persistence record.
    internal func canonicalize(_ path: String) -> String {
        URL(fileURLWithPath: path, isDirectory: true)
            .resolvingSymlinksInPath()
            .standardizedFileURL
            .path
    }
}

/// Short-TTL cache for `FileManager.fileExists` lookups. Repository lists are
/// re-fetched frequently (e.g. on every refresh) and re-stat the same paths
/// each time; a small TTL avoids redundant syscalls while staying fresh
/// enough to notice a repository being deleted or restored.
private final class FileExistenceCache: @unchecked Sendable {
    static let shared = FileExistenceCache()

    private let ttl: TimeInterval = 2
    private let lock = NSLock()
    private var entries: [String: (exists: Bool, expiresAt: Date)] = [:]

    func exists(atPath path: String) -> Bool {
        let now = Date()
        lock.lock()
        if let cached = entries[path], cached.expiresAt > now {
            lock.unlock()
            return cached.exists
        }
        lock.unlock()

        let exists = FileManager.default.fileExists(atPath: path)
        lock.lock()
        entries[path] = (exists, now.addingTimeInterval(ttl))
        lock.unlock()
        return exists
    }
}
