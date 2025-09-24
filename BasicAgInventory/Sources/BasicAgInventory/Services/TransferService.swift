import Foundation
import CoreData
import Combine

/// Service for managing item transfers between farm locations
/// Handles transfer validation, execution, and audit trail creation
@MainActor
class TransferService: ObservableObject {

    private let context: NSManagedObjectContext
    private let inventoryRepository: InventoryRepository
    private let locationRepository: LocationRepository

    @Published var isTransferring: Bool = false
    @Published var lastTransferError: Error?

    init(context: NSManagedObjectContext,
         inventoryRepository: InventoryRepository,
         locationRepository: LocationRepository) {
        self.context = context
        self.inventoryRepository = inventoryRepository
        self.locationRepository = locationRepository
    }

    /// Transfer items between locations with complete audit trail
    func transferItem(
        _ item: InventoryItem,
        from sourceLocation: Location?,
        to destinationLocation: Location,
        quantity: Int32,
        notes: String? = nil
    ) async throws -> Transfer {

        guard quantity > 0 else {
            throw TransferError.invalidQuantity
        }

        // Validate source has sufficient quantity for transfer
        if let source = sourceLocation {
            guard item.quantity >= quantity else {
                throw TransferError.insufficientQuantity
            }
        }

        isTransferring = true
        lastTransferError = nil

        do {
            let transfer = try await createTransfer(
                item: item,
                from: sourceLocation,
                to: destinationLocation,
                quantity: quantity,
                notes: notes
            )

            try await executeTransfer(transfer)

            isTransferring = false
            return transfer

        } catch {
            isTransferring = false
            lastTransferError = error
            throw error
        }
    }

    /// Create transfer record with validation
    private func createTransfer(
        item: InventoryItem,
        from sourceLocation: Location?,
        to destinationLocation: Location,
        quantity: Int32,
        notes: String?
    ) async throws -> Transfer {

        return try await context.perform {
            let transfer = Transfer(context: self.context)
            transfer.id = UUID()
            transfer.inventoryItem = item
            transfer.fromLocation = sourceLocation
            transfer.toLocation = destinationLocation
            transfer.quantity = quantity
            transfer.notes = notes
            transfer.transferDate = Date()
            transfer.transferStatus = .pending
            transfer.initiatedBy = "Current User" // TODO: Replace with actual user system

            try transfer.validate()
            try self.context.save()

            return transfer
        }
    }

    /// Execute the transfer and update inventory quantities
    private func executeTransfer(_ transfer: Transfer) async throws {

        try await context.perform {
            guard let item = transfer.inventoryItem,
                  let destinationLocation = transfer.toLocation else {
                throw TransferError.transferFailed
            }

            if let sourceLocation = transfer.fromLocation {
                // Transfer from existing location
                try self.executeLocationToLocationTransfer(
                    item: item,
                    from: sourceLocation,
                    to: destinationLocation,
                    transfer: transfer
                )
            } else {
                // New item assignment
                try self.executeNewItemAssignment(
                    item: item,
                    to: destinationLocation,
                    transfer: transfer
                )
            }

            // Mark transfer as completed
            transfer.transferStatus = .completed
            transfer.transferDate = Date()

            // Update item timestamp
            item.updatedAt = Date()

            try self.context.save()
        }
    }

    /// Handle transfer between two existing locations
    private func executeLocationToLocationTransfer(
        item: InventoryItem,
        from sourceLocation: Location,
        to destinationLocation: Location,
        transfer: Transfer
    ) throws {

        let transferQuantity = transfer.quantity

        if item.quantity == transferQuantity {
            // Moving entire quantity - just change location
            item.location = destinationLocation

        } else if item.quantity > transferQuantity {
            // Partial transfer - need to split the item
            item.quantity -= transferQuantity

            // Create new item record at destination
            let newItem = InventoryItem(context: context)
            newItem.id = UUID()
            newItem.name = item.name
            newItem.itemDescription = item.itemDescription
            newItem.category = item.category
            newItem.quantity = transferQuantity
            newItem.unit = item.unit
            newItem.minimumThreshold = item.minimumThreshold
            newItem.location = destinationLocation
            newItem.createdAt = Date()
            newItem.updatedAt = Date()

            // Update transfer to reference the new item
            transfer.inventoryItem = newItem

        } else {
            throw TransferError.insufficientQuantity
        }
    }

    /// Handle new item assignment to a location
    private func executeNewItemAssignment(
        item: InventoryItem,
        to destinationLocation: Location,
        transfer: Transfer
    ) throws {

        item.location = destinationLocation
        item.quantity = transfer.quantity
    }

    /// Fetch transfer history for an item
    func fetchTransferHistory(for item: InventoryItem) async throws -> [Transfer] {
        return try await context.perform {
            let request: NSFetchRequest<Transfer> = Transfer.fetchRequest()
            request.predicate = NSPredicate(format: "inventoryItem == %@", item)
            request.sortDescriptors = [NSSortDescriptor(keyPath: \Transfer.transferDate, ascending: false)]

            return try self.context.fetch(request)
        }
    }

    /// Fetch all transfers for a location
    func fetchTransfers(for location: Location, limit: Int? = nil) async throws -> [Transfer] {
        return try await context.perform {
            let request: NSFetchRequest<Transfer> = Transfer.fetchRequest()

            // Include transfers both from and to the location
            let fromPredicate = NSPredicate(format: "fromLocation == %@", location)
            let toPredicate = NSPredicate(format: "toLocation == %@", location)
            request.predicate = NSCompoundPredicate(orPredicateWithSubpredicates: [fromPredicate, toPredicate])

            request.sortDescriptors = [NSSortDescriptor(keyPath: \Transfer.transferDate, ascending: false)]

            if let limit = limit {
                request.fetchLimit = limit
            }

            return try self.context.fetch(request)
        }
    }

    /// Cancel a pending transfer
    func cancelTransfer(_ transfer: Transfer) async throws {
        try await context.perform {
            guard transfer.transferStatus == .pending else {
                throw TransferError.transferFailed
            }

            transfer.transferStatus = .cancelled
            try self.context.save()
        }
    }

    /// Get transfer statistics for reporting
    func getTransferStatistics(for location: Location) async throws -> TransferStatistics {
        let transfers = try await fetchTransfers(for: location)

        let incomingTransfers = transfers.filter { $0.toLocation == location && $0.transferStatus == .completed }
        let outgoingTransfers = transfers.filter { $0.fromLocation == location && $0.transferStatus == .completed }

        let totalIncoming = incomingTransfers.reduce(0) { $0 + Int($1.quantity) }
        let totalOutgoing = outgoingTransfers.reduce(0) { $0 + Int($1.quantity) }

        return TransferStatistics(
            location: location,
            incomingCount: incomingTransfers.count,
            outgoingCount: outgoingTransfers.count,
            totalIncomingQuantity: totalIncoming,
            totalOutgoingQuantity: totalOutgoing,
            netTransferQuantity: totalIncoming - totalOutgoing
        )
    }
}

/// Transfer statistics for reporting
struct TransferStatistics {
    let location: Location
    let incomingCount: Int
    let outgoingCount: Int
    let totalIncomingQuantity: Int
    let totalOutgoingQuantity: Int
    let netTransferQuantity: Int

    var totalTransfers: Int {
        incomingCount + outgoingCount
    }
}