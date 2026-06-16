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
            existsOnDisk: FileManager.default.fileExists(atPath: path)
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
