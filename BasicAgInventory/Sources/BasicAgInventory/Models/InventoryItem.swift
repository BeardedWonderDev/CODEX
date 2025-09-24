import Foundation
import CoreData

@objc(InventoryItem)
public class InventoryItem: NSManagedObject {

}

extension InventoryItem {

    @nonobjc public class func fetchRequest() -> NSFetchRequest<InventoryItem> {
        return NSFetchRequest<InventoryItem>(entityName: "InventoryItem")
    }

    @NSManaged public var id: UUID
    @NSManaged public var name: String
    @NSManaged public var itemDescription: String?
    @NSManaged public var category: String
    @NSManaged public var quantity: Int32
    @NSManaged public var unit: String
    @NSManaged public var minimumStock: Int32
    @NSManaged public var purchasePrice: Double
    @NSManaged public var purchaseDate: Date?
    @NSManaged public var expirationDate: Date?
    @NSManaged public var notes: String?
    @NSManaged public var imageData: Data?
    @NSManaged public var createdAt: Date
    @NSManaged public var updatedAt: Date
    @NSManaged public var isActive: Bool

    // Location relationships
    @NSManaged public var location: Location?

    // Transaction history
    @NSManaged public var transactions: NSSet?

    // Transfer history
    @NSManaged public var transfers: NSSet?

}

// MARK: Generated accessors for transactions
extension InventoryItem {

    @objc(addTransactionsObject:)
    @NSManaged public func addToTransactions(_ value: InventoryTransaction)

    @objc(removeTransactionsObject:)
    @NSManaged public func removeFromTransactions(_ value: InventoryTransaction)

    @objc(addTransactions:)
    @NSManaged public func addToTransactions(_ values: NSSet)

    @objc(removeTransactions:)
    @NSManaged public func removeFromTransactions(_ values: NSSet)

}

// MARK: Generated accessors for transfers
extension InventoryItem {

    @objc(addTransfersObject:)
    @NSManaged public func addToTransfers(_ value: Transfer)

    @objc(removeTransfersObject:)
    @NSManaged public func removeFromTransfers(_ value: Transfer)

    @objc(addTransfers:)
    @NSManaged public func addToTransfers(_ values: NSSet)

    @objc(removeTransfers:)
    @NSManaged public func removeFromTransfers(_ values: NSSet)

}

extension InventoryItem: Identifiable {

}

// MARK: - Convenience Methods
extension InventoryItem {

    /// Check if item is low on stock
    var isLowStock: Bool {
        return quantity <= minimumStock
    }

    /// Check if item is expired
    var isExpired: Bool {
        guard let expirationDate = expirationDate else { return false }
        return expirationDate < Date()
    }

    /// Formatted quantity with unit
    var formattedQuantity: String {
        return "\(quantity) \(unit)"
    }

    /// Update quantity and create transaction record
    func updateQuantity(to newQuantity: Int32, reason: String, context: NSManagedObjectContext) {
        let oldQuantity = self.quantity
        self.quantity = newQuantity
        self.updatedAt = Date()

        // Create transaction record
        let transaction = InventoryTransaction(context: context)
        transaction.id = UUID()
        transaction.item = self
        transaction.previousQuantity = oldQuantity
        transaction.newQuantity = newQuantity
        transaction.changeAmount = newQuantity - oldQuantity
        transaction.reason = reason
        transaction.timestamp = Date()
    }

    /// Increment quantity
    func incrementQuantity(by amount: Int32 = 1, reason: String = "Manual increment", context: NSManagedObjectContext) {
        updateQuantity(to: quantity + amount, reason: reason, context: context)
    }

    /// Decrement quantity
    func decrementQuantity(by amount: Int32 = 1, reason: String = "Manual decrement", context: NSManagedObjectContext) {
        let newQuantity = max(0, quantity - amount) // Prevent negative quantities
        updateQuantity(to: newQuantity, reason: reason, context: context)
    }

    /// Get array of transfers
    var transfersArray: [Transfer] {
        let set = transfers as? Set<Transfer> ?? []
        return Array(set).sorted { $0.transferDate > $1.transferDate }
    }

    /// Get location name for display
    var locationName: String {
        return location?.name ?? "No Location"
    }

    /// Check if item can be transferred (has sufficient quantity)
    func canTransfer(quantity transferQuantity: Int32) -> Bool {
        return self.quantity >= transferQuantity
    }
}