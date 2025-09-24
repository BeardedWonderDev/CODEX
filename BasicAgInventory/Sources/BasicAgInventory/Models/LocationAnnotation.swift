import Foundation
import MapKit
import CoreLocation

/// MapKit annotation for displaying farm locations on map views
/// Provides visual representation of Location entities with item count information
public class LocationAnnotation: NSObject, MKAnnotation {

    // MARK: - Properties
    public let location: Location

    // MARK: - MKAnnotation Protocol
    public var coordinate: CLLocationCoordinate2D {
        return location.coordinate
    }

    public var title: String? {
        return location.name
    }

    public var subtitle: String? {
        let itemCount = location.itemCount
        if itemCount == 0 {
            return "No items"
        } else if itemCount == 1 {
            return "1 item"
        } else {
            return "\(itemCount) items"
        }
    }

    // MARK: - Initialization
    public init(location: Location) {
        self.location = location
        super.init()
    }

    // MARK: - Convenience Properties

    /// Get location ID for identification
    public var locationId: UUID {
        return location.id
    }

    /// Get location description for detail views
    public var locationDescription: String {
        return location.locationDescription ?? ""
    }

    /// Get formatted coordinates for display
    public var formattedCoordinates: String {
        let latitude = String(format: "%.6f", coordinate.latitude)
        let longitude = String(format: "%.6f", coordinate.longitude)
        return "\(latitude), \(longitude)"
    }

    /// Get location address if available
    public var address: String? {
        return location.address
    }

    /// Check if location has inventory items
    public var hasItems: Bool {
        return location.hasItems
    }

    /// Get detailed item information for annotation callout
    public var itemSummary: String {
        let itemCount = location.itemCount
        if itemCount == 0 {
            return "No items stored at this location"
        } else {
            let items = location.itemsArray
            if itemCount <= 3 {
                let itemNames = items.prefix(3).map { $0.name }.joined(separator: ", ")
                return "Items: \(itemNames)"
            } else {
                let firstThree = items.prefix(3).map { $0.name }.joined(separator: ", ")
                return "Items: \(firstThree) and \(itemCount - 3) more"
            }
        }
    }

    /// Get transfer activity summary
    public var transferSummary: String {
        let transferCount = location.totalTransferCount
        if transferCount == 0 {
            return "No transfer history"
        } else if transferCount == 1 {
            return "1 transfer recorded"
        } else {
            return "\(transferCount) transfers recorded"
        }
    }
}

// MARK: - Hashable and Equatable
extension LocationAnnotation {

    public override func isEqual(_ object: Any?) -> Bool {
        guard let other = object as? LocationAnnotation else { return false }
        return self.location.id == other.location.id
    }

    public override var hash: Int {
        return location.id.hashValue
    }
}

// MARK: - Map Clustering Support
extension LocationAnnotation {

    /// Cluster identifier for map annotation clustering
    public var clusteringIdentifier: String {
        // Use same identifier for all farm locations to enable clustering
        return "FarmLocationCluster"
    }
}