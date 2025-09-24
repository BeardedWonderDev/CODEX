import Foundation
import CoreData
import CoreLocation

@objc(Location)
public class Location: NSManagedObject {

}

extension Location {

    @nonobjc public class func fetchRequest() -> NSFetchRequest<Location> {
        return NSFetchRequest<Location>(entityName: "Location")
    }

    @NSManaged public var id: UUID
    @NSManaged public var name: String
    @NSManaged public var locationDescription: String?
    @NSManaged public var address: String?
    @NSManaged public var latitude: Double
    @NSManaged public var longitude: Double
    @NSManaged public var isActive: Bool
    @NSManaged public var createdAt: Date
    @NSManaged public var updatedAt: Date

    // Relationships
    @NSManaged public var items: NSSet?
    @NSManaged public var incomingTransfers: NSSet?
    @NSManaged public var outgoingTransfers: NSSet?

}

// MARK: Generated accessors for items
extension Location {

    @objc(addItemsObject:)
    @NSManaged public func addToItems(_ value: InventoryItem)

    @objc(removeItemsObject:)
    @NSManaged public func removeFromItems(_ value: InventoryItem)

    @objc(addItems:)
    @NSManaged public func addToItems(_ values: NSSet)

    @objc(removeItems:)
    @NSManaged public func removeFromItems(_ values: NSSet)

}

// MARK: Generated accessors for incomingTransfers
extension Location {

    @objc(addIncomingTransfersObject:)
    @NSManaged public func addToIncomingTransfers(_ value: Transfer)

    @objc(removeIncomingTransfersObject:)
    @NSManaged public func removeFromIncomingTransfers(_ value: Transfer)

    @objc(addIncomingTransfers:)
    @NSManaged public func addToIncomingTransfers(_ values: NSSet)

    @objc(removeIncomingTransfers:)
    @NSManaged public func removeFromIncomingTransfers(_ values: NSSet)

}

// MARK: Generated accessors for outgoingTransfers
extension Location {

    @objc(addOutgoingTransfersObject:)
    @NSManaged public func addToOutgoingTransfers(_ value: Transfer)

    @objc(removeOutgoingTransfersObject:)
    @NSManaged public func removeFromOutgoingTransfers(_ value: Transfer)

    @objc(addOutgoingTransfers:)
    @NSManaged public func addToOutgoingTransfers(_ values: NSSet)

    @objc(removeOutgoingTransfers:)
    @NSManaged public func removeFromOutgoingTransfers(_ values: NSSet)

}

extension Location: Identifiable {

}

// MARK: - Convenience Methods
extension Location {

    /// Get CLLocationCoordinate2D for map usage
    var coordinate: CLLocationCoordinate2D {
        return CLLocationCoordinate2D(latitude: latitude, longitude: longitude)
    }

    /// Set coordinates from CLLocationCoordinate2D
    func setCoordinate(_ coordinate: CLLocationCoordinate2D) {
        self.latitude = coordinate.latitude
        self.longitude = coordinate.longitude
        self.updatedAt = Date()
    }

    /// Get distance to another location in meters
    func distance(to location: Location) -> CLLocationDistance {
        let fromLocation = CLLocation(latitude: self.latitude, longitude: self.longitude)
        let toLocation = CLLocation(latitude: location.latitude, longitude: location.longitude)
        return fromLocation.distance(from: toLocation)
    }

    /// Check if location has items
    var hasItems: Bool {
        return (items?.count ?? 0) > 0
    }

    /// Get array of inventory items
    var itemsArray: [InventoryItem] {
        let set = items as? Set<InventoryItem> ?? []
        return Array(set).sorted { $0.name < $1.name }
    }

    /// Get count of items at this location
    var itemCount: Int {
        return items?.count ?? 0
    }

    /// Get array of incoming transfers
    var incomingTransfersArray: [Transfer] {
        let set = incomingTransfers as? Set<Transfer> ?? []
        return Array(set).sorted { $0.transferDate > $1.transferDate }
    }

    /// Get array of outgoing transfers
    var outgoingTransfersArray: [Transfer] {
        let set = outgoingTransfers as? Set<Transfer> ?? []
        return Array(set).sorted { $0.transferDate > $1.transferDate }
    }

    /// Get count of all transfers (incoming and outgoing)
    var totalTransferCount: Int {
        return (incomingTransfers?.count ?? 0) + (outgoingTransfers?.count ?? 0)
    }

    /// Validate location data
    func validate() throws {
        guard !name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            throw LocationError.invalidData("Location name cannot be empty")
        }
        guard CLLocationCoordinate2DIsValid(coordinate) else {
            throw LocationError.invalidCoordinates("GPS coordinates are invalid")
        }
    }
}

