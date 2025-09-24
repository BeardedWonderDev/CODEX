import Foundation
import CoreData

@objc(Transfer)
public class Transfer: NSManagedObject {

}

extension Transfer {

    @nonobjc public class func fetchRequest() -> NSFetchRequest<Transfer> {
        return NSFetchRequest<Transfer>(entityName: "Transfer")
    }

    @NSManaged public var id: UUID
    @NSManaged public var quantity: Int32
    @NSManaged public var transferDate: Date
    @NSManaged public var notes: String?
    @NSManaged public var status: String
    @NSManaged public var initiatedBy: String

    // Relationships
    @NSManaged public var inventoryItem: InventoryItem?
    @NSManaged public var fromLocation: Location?
    @NSManaged public var toLocation: Location?

}

extension Transfer: Identifiable {

}

// MARK: - Transfer Status
extension Transfer {

    enum Status: String, CaseIterable {
        case pending = "pending"
        case completed = "completed"
        case cancelled = "cancelled"

        var displayName: String {
            switch self {
            case .pending:
                return "Pending"
            case .completed:
                return "Completed"
            case .cancelled:
                return "Cancelled"
            }
        }
    }

    var transferStatus: Status {
        get {
            return Status(rawValue: status) ?? .pending
        }
        set {
            status = newValue.rawValue
        }
    }
}

// MARK: - Convenience Methods
extension Transfer {

    /// Check if transfer can be completed
    var canComplete: Bool {
        guard let item = inventoryItem else { return false }

        // For new item assignments (no source location), always allow
        guard let fromLocation = fromLocation else { return true }

        // Check if source location has enough items
        return item.quantity >= quantity
    }

    /// Check if transfer is from new inventory (no source location)
    var isNewItemAssignment: Bool {
        return fromLocation == nil
    }

    /// Get transfer description for display
    var transferDescription: String {
        let itemName = inventoryItem?.name ?? "Unknown Item"
        let fromName = fromLocation?.name ?? "New Stock"
        let toName = toLocation?.name ?? "Unknown Location"
        return "\(quantity) × \(itemName): \(fromName) → \(toName)"
    }

    /// Get formatted transfer date
    var formattedTransferDate: String {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .short
        return formatter.string(from: transferDate)
    }

    /// Validate transfer data
    func validate() throws {
        guard let item = inventoryItem else {
            throw TransferError.missingInventoryItem
        }

        guard let destination = toLocation else {
            throw TransferError.missingDestination
        }

        guard quantity > 0 else {
            throw TransferError.invalidQuantity
        }

        // Validate source location has enough items
        if let source = fromLocation {
            guard item.quantity >= quantity else {
                throw TransferError.insufficientQuantity
            }
        }
    }

    /// Execute the transfer (update item quantities and locations)
    func execute() throws {
        try validate()

        guard let item = inventoryItem,
              let destination = toLocation else {
            throw TransferError.transferFailed
        }

        // If moving from existing location, decrease source quantity
        if let source = fromLocation {
            item.quantity -= quantity

            // If all items moved, update item location
            if item.quantity == 0 {
                item.location = destination
                item.quantity = quantity
            }
            // TODO: Handle partial transfers with item splitting
        } else {
            // New item assignment
            item.location = destination
            item.quantity = quantity
        }

        // Update transfer status
        transferStatus = .completed

        // Update timestamps
        item.updatedAt = Date()
    }
}

// MARK: - Transfer Errors
enum TransferError: Error, LocalizedError {
    case missingInventoryItem
    case missingDestination
    case invalidQuantity
    case insufficientQuantity
    case transferFailed

    var errorDescription: String? {
        switch self {
        case .missingInventoryItem:
            return "Inventory item is required for transfer"
        case .missingDestination:
            return "Destination location is required"
        case .invalidQuantity:
            return "Transfer quantity must be greater than 0"
        case .insufficientQuantity:
            return "Not enough items available at source location"
        case .transferFailed:
            return "Transfer could not be completed. Please try again."
        }
    }
}