import Foundation
import CoreData
import Combine

public protocol InventoryRepositoryProtocol {
    func fetchAllItems() -> AnyPublisher<[InventoryItem], Error>
    func fetchItems(predicate: NSPredicate?) -> AnyPublisher<[InventoryItem], Error>
    func searchItems(query: String) -> AnyPublisher<[InventoryItem], Error>
    func createItem(_ item: InventoryItemData) -> AnyPublisher<InventoryItem, Error>
    func updateItem(_ item: InventoryItem, with data: InventoryItemData) -> AnyPublisher<InventoryItem, Error>
    func deleteItem(_ item: InventoryItem) -> AnyPublisher<Void, Error>
    func updateQuantity(for item: InventoryItem, newQuantity: Int32, reason: String) -> AnyPublisher<InventoryItem, Error>
    func getAllCategories() -> AnyPublisher<[String], Error>
}

public struct InventoryItemData {
    public let name: String
    public let description: String?
    public let category: String
    public let quantity: Int32
    public let unit: String
    public let minimumStock: Int32
    public let purchasePrice: Double
    public let purchaseDate: Date?
    public let expirationDate: Date?
    public let notes: String?
    public let imageData: Data?
    public let locationId: UUID?

    public init(
        name: String,
        description: String? = nil,
        category: String,
        quantity: Int32,
        unit: String,
        minimumStock: Int32 = 0,
        purchasePrice: Double = 0.0,
        purchaseDate: Date? = nil,
        expirationDate: Date? = nil,
        notes: String? = nil,
        imageData: Data? = nil,
        locationId: UUID? = nil
    ) {
        self.name = name
        self.description = description
        self.category = category
        self.quantity = quantity
        self.unit = unit
        self.minimumStock = minimumStock
        self.purchasePrice = purchasePrice
        self.purchaseDate = purchaseDate
        self.expirationDate = expirationDate
        self.notes = notes
        self.imageData = imageData
        self.locationId = locationId
    }
}

public final class InventoryRepository: ObservableObject, InventoryRepositoryProtocol {

    private let persistenceController: PersistenceController
    private let context: NSManagedObjectContext

    public init(persistenceController: PersistenceController = .shared) {
        self.persistenceController = persistenceController
        self.context = persistenceController.viewContext
    }

    // MARK: - Fetch Operations

    public func fetchAllItems() -> AnyPublisher<[InventoryItem], Error> {
        return fetchItems(predicate: NSPredicate(format: "isActive == true"))
    }

    public func fetchItems(predicate: NSPredicate? = nil) -> AnyPublisher<[InventoryItem], Error> {
        return Future<[InventoryItem], Error> { promise in
            let request: NSFetchRequest<InventoryItem> = InventoryItem.fetchRequest()
            request.predicate = predicate
            request.sortDescriptors = [
                NSSortDescriptor(keyPath: \InventoryItem.name, ascending: true)
            ]

            do {
                let items = try self.context.fetch(request)
                promise(.success(items))
            } catch {
                promise(.failure(error))
            }
        }
        .eraseToAnyPublisher()
    }

    public func searchItems(query: String) -> AnyPublisher<[InventoryItem], Error> {
        guard !query.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            return fetchAllItems()
        }

        let predicate = NSCompoundPredicate(andPredicateWithSubpredicates: [
            NSPredicate(format: "isActive == true"),
            NSCompoundPredicate(orPredicateWithSubpredicates: [
                NSPredicate(format: "name CONTAINS[cd] %@", query),
                NSPredicate(format: "itemDescription CONTAINS[cd] %@", query),
                NSPredicate(format: "category CONTAINS[cd] %@", query),
                NSPredicate(format: "notes CONTAINS[cd] %@", query)
            ])
        ])

        return fetchItems(predicate: predicate)
    }

    // MARK: - Create Operations

    public func createItem(_ itemData: InventoryItemData) -> AnyPublisher<InventoryItem, Error> {
        return Future<InventoryItem, Error> { promise in
            let item = InventoryItem(context: self.context)
            item.id = UUID()
            item.name = itemData.name
            item.itemDescription = itemData.description
            item.category = itemData.category
            item.quantity = itemData.quantity
            item.unit = itemData.unit
            item.minimumStock = itemData.minimumStock
            item.purchasePrice = itemData.purchasePrice
            item.purchaseDate = itemData.purchaseDate
            item.expirationDate = itemData.expirationDate
            item.notes = itemData.notes
            item.imageData = itemData.imageData
            item.isActive = true
            item.createdAt = Date()
            item.updatedAt = Date()

            // Set location if provided
            if let locationId = itemData.locationId {
                item.location = self.fetchLocation(by: locationId)
            }

            // Create initial transaction
            item.updateQuantity(to: itemData.quantity, reason: "Initial inventory", context: self.context)

            do {
                try self.context.save()
                promise(.success(item))
            } catch {
                promise(.failure(error))
            }
        }
        .eraseToAnyPublisher()
    }

    // MARK: - Update Operations

    public func updateItem(_ item: InventoryItem, with data: InventoryItemData) -> AnyPublisher<InventoryItem, Error> {
        return Future<InventoryItem, Error> { promise in
            let oldQuantity = item.quantity

            item.name = data.name
            item.itemDescription = data.description
            item.category = data.category
            item.unit = data.unit
            item.minimumStock = data.minimumStock
            item.purchasePrice = data.purchasePrice
            item.purchaseDate = data.purchaseDate
            item.expirationDate = data.expirationDate
            item.notes = data.notes
            item.imageData = data.imageData
            item.updatedAt = Date()

            // Update location if changed
            if let locationId = data.locationId {
                item.location = self.fetchLocation(by: locationId)
            } else {
                item.location = nil
            }

            // Update quantity with transaction if changed
            if oldQuantity != data.quantity {
                item.updateQuantity(to: data.quantity, reason: "Item update", context: self.context)
            }

            do {
                try self.context.save()
                promise(.success(item))
            } catch {
                promise(.failure(error))
            }
        }
        .eraseToAnyPublisher()
    }

    public func updateQuantity(for item: InventoryItem, newQuantity: Int32, reason: String) -> AnyPublisher<InventoryItem, Error> {
        return Future<InventoryItem, Error> { promise in
            item.updateQuantity(to: newQuantity, reason: reason, context: self.context)

            do {
                try self.context.save()
                promise(.success(item))
            } catch {
                promise(.failure(error))
            }
        }
        .eraseToAnyPublisher()
    }

    // MARK: - Delete Operations

    public func deleteItem(_ item: InventoryItem) -> AnyPublisher<Void, Error> {
        return Future<Void, Error> { promise in
            // Soft delete - mark as inactive
            item.isActive = false
            item.updatedAt = Date()

            do {
                try self.context.save()
                promise(.success(()))
            } catch {
                promise(.failure(error))
            }
        }
        .eraseToAnyPublisher()
    }

    // MARK: - Helper Methods

    private func fetchLocation(by id: UUID) -> Location? {
        let request: NSFetchRequest<Location> = Location.fetchRequest()
        request.predicate = NSPredicate(format: "id == %@ AND isActive == true", id as CVarArg)
        request.fetchLimit = 1

        return try? context.fetch(request).first
    }

    // MARK: - Batch Operations

    public func fetchLowStockItems() -> AnyPublisher<[InventoryItem], Error> {
        let predicate = NSPredicate(format: "isActive == true AND quantity <= minimumStock")
        return fetchItems(predicate: predicate)
    }

    public func fetchExpiredItems() -> AnyPublisher<[InventoryItem], Error> {
        let predicate = NSPredicate(format: "isActive == true AND expirationDate < %@", Date() as CVarArg)
        return fetchItems(predicate: predicate)
    }

    public func fetchItemsByCategory(_ category: String) -> AnyPublisher<[InventoryItem], Error> {
        let predicate = NSPredicate(format: "isActive == true AND category ==[cd] %@", category)
        return fetchItems(predicate: predicate)
    }

    public func fetchItemsByLocation(_ location: Location) -> AnyPublisher<[InventoryItem], Error> {
        let predicate = NSPredicate(format: "isActive == true AND location == %@", location)
        return fetchItems(predicate: predicate)
    }

    public func getAllCategories() -> AnyPublisher<[String], Error> {
        return Future<[String], Error> { promise in
            let request: NSFetchRequest<InventoryItem> = InventoryItem.fetchRequest()
            request.predicate = NSPredicate(format: "isActive == true")
            request.propertiesToFetch = ["category"]
            request.returnsDistinctResults = true
            request.resultType = .dictionaryResultType

            do {
                let results = try self.context.fetch(request) as? [[String: Any]] ?? []
                let categories = results.compactMap { $0["category"] as? String }.sorted()
                promise(.success(categories))
            } catch {
                promise(.failure(error))
            }
        }
        .eraseToAnyPublisher()
    }
}