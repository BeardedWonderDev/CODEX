import Foundation
import CoreData

@objc(InventoryTransaction)
public class InventoryTransaction: NSManagedObject {

}

extension InventoryTransaction {

    @nonobjc public class func fetchRequest() -> NSFetchRequest<InventoryTransaction> {
        return NSFetchRequest<InventoryTransaction>(entityName: "InventoryTransaction")
    }

    @NSManaged public var id: UUID
    @NSManaged public var previousQuantity: Int32
    @NSManaged public var newQuantity: Int32
    @NSManaged public var changeAmount: Int32
    @NSManaged public var reason: String
    @NSManaged public var timestamp: Date
    @NSManaged public var notes: String?

    // Relationships
    @NSManaged public var item: InventoryItem?

}

extension InventoryTransaction: Identifiable {

}

// MARK: - Convenience Methods
extension InventoryTransaction {

    /// Transaction type based on change amount
    enum TransactionType {
        case addition
        case reduction
        case adjustment
    }

    var transactionType: TransactionType {
        if changeAmount > 0 {
            return .addition
        } else if changeAmount < 0 {
            return .reduction
        } else {
            return .adjustment
        }
    }

    /// Human-readable transaction description
    var transactionDescription: String {
        switch transactionType {
        case .addition:
            return "Added \(abs(changeAmount)) units"
        case .reduction:
            return "Removed \(abs(changeAmount)) units"
        case .adjustment:
            return "Quantity adjusted"
        }
    }

    /// Formatted change amount with sign
    var formattedChangeAmount: String {
        let sign = changeAmount >= 0 ? "+" : ""
        return "\(sign)\(changeAmount)"
    }

    /// Formatted timestamp
    var formattedTimestamp: String {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .short
        return formatter.string(from: timestamp)
    }
}