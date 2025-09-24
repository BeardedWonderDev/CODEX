import CoreData
import Foundation

public final class PersistenceController: ObservableObject {

    // MARK: - Singleton
    public static let shared = PersistenceController()

    // MARK: - Preview/Testing Support
    public static var preview: PersistenceController = {
        let result = PersistenceController(inMemory: true)
        let viewContext = result.container.viewContext

        // Create sample data for previews
        let sampleLocation = Location(context: viewContext)
        sampleLocation.id = UUID()
        sampleLocation.name = "Main Barn"
        sampleLocation.locationDescription = "Primary storage facility"
        sampleLocation.latitude = 40.7128
        sampleLocation.longitude = -74.0060
        sampleLocation.isActive = true
        sampleLocation.createdAt = Date()
        sampleLocation.updatedAt = Date()

        let sampleItem = InventoryItem(context: viewContext)
        sampleItem.id = UUID()
        sampleItem.name = "John Deere Tractor"
        sampleItem.itemDescription = "2020 John Deere 5075E"
        sampleItem.category = "Equipment"
        sampleItem.quantity = 1
        sampleItem.unit = "unit"
        sampleItem.minimumStock = 1
        sampleItem.purchasePrice = 45000.0
        sampleItem.purchaseDate = Date()
        sampleItem.isActive = true
        sampleItem.createdAt = Date()
        sampleItem.updatedAt = Date()
        sampleItem.location = sampleLocation

        do {
            try viewContext.save()
        } catch {
            // Preview data creation failure is non-critical
            print("Failed to create preview data: \(error)")
        }

        return result
    }()

    // MARK: - Core Data Stack
    public lazy var container: NSPersistentContainer = {
        let container = NSPersistentContainer(name: "BasicAgInventory")

        if inMemory {
            container.persistentStoreDescriptions.first?.url = URL(fileURLWithPath: "/dev/null")
        } else {
            // Configure persistent store with encryption
            guard let description = container.persistentStoreDescriptions.first else {
                fatalError("Failed to retrieve a persistent store description.")
            }

            // Enable persistent history tracking
            description.setOption(true as NSNumber, forKey: NSPersistentHistoryTrackingKey)

            #if os(iOS)
            if #available(iOS 13.0, *) {
                description.setOption(true as NSNumber, forKey: NSPersistentStoreRemoteChangeNotificationPostOptionKey)
            }

            // Enable encryption (AES-256) - iOS only
            description.setOption(FileProtectionType.complete as NSString, forKey: NSPersistentStoreFileProtectionKey)
            #endif
        }

        container.loadPersistentStores { _, error in
            if let error = error as NSError? {
                // In production, handle this error appropriately
                print("Core Data error: \(error), \(error.userInfo)")
            }
        }

        // Configure automatic merge policy
        container.viewContext.automaticallyMergesChangesFromParent = true
        container.viewContext.mergePolicy = NSMergeByPropertyObjectTrumpMergePolicy

        return container
    }()

    private let inMemory: Bool

    // MARK: - Initialization
    public init(inMemory: Bool = false) {
        self.inMemory = inMemory
    }

    // MARK: - Context Management

    /// Main thread context for UI operations
    public var viewContext: NSManagedObjectContext {
        return container.viewContext
    }

    /// Create a new background context for data operations
    public func newBackgroundContext() -> NSManagedObjectContext {
        let context = container.newBackgroundContext()
        context.mergePolicy = NSMergeByPropertyObjectTrumpMergePolicy
        return context
    }

    // MARK: - Save Operations

    /// Save the view context
    public func save() {
        let context = container.viewContext

        guard context.hasChanges else { return }

        do {
            try context.save()
        } catch {
            print("Failed to save context: \(error)")
        }
    }

    /// Save a background context
    public func save(context: NSManagedObjectContext) {
        guard context.hasChanges else { return }

        context.perform {
            do {
                try context.save()
            } catch {
                print("Failed to save background context: \(error)")
            }
        }
    }

    /// Perform a background task
    public func performBackgroundTask<T>(_ block: @escaping (NSManagedObjectContext) throws -> T) -> T? {
        let context = newBackgroundContext()
        var result: T?
        var error: Error?

        context.performAndWait {
            do {
                result = try block(context)
                if context.hasChanges {
                    try context.save()
                }
            } catch let taskError {
                error = taskError
            }
        }

        if let error = error {
            print("Background task failed: \(error)")
        }

        return result
    }

    // MARK: - Cleanup

    /// Delete all data (for testing/development)
    public func deleteAllData() {
        let context = container.viewContext

        // Delete all entities
        let entities = ["InventoryItem", "Location", "InventoryTransaction"]

        for entityName in entities {
            let fetchRequest: NSFetchRequest<NSFetchRequestResult> = NSFetchRequest(entityName: entityName)
            let deleteRequest = NSBatchDeleteRequest(fetchRequest: fetchRequest)

            do {
                try context.execute(deleteRequest)
            } catch {
                print("Failed to delete \(entityName): \(error)")
            }
        }

        save()
    }
}