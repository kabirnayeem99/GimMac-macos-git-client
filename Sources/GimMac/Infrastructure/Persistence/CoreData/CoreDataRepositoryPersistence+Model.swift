import CoreData
import Foundation

extension CoreDataRepositoryPersistence {
    /// Builds the `NSManagedObjectModel` in code so the persistence layer is
    /// self-contained and does not depend on a bundled `.xcdatamodeld`.
    internal static func makeModel() -> NSManagedObjectModel {
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
