import Foundation
import CoreData
import Combine
import CoreLocation

public protocol LocationRepositoryProtocol {
    func fetchAllLocations() -> AnyPublisher<[Location], Error>
    func fetchLocations(predicate: NSPredicate?) -> AnyPublisher<[Location], Error>
    func createLocation(_ locationData: LocationData) -> AnyPublisher<Location, Error>
    func updateLocation(_ location: Location, with data: LocationData) -> AnyPublisher<Location, Error>
    func deleteLocation(_ location: Location) -> AnyPublisher<Void, Error>
    func fetchLocation(by id: UUID) -> AnyPublisher<Location?, Error>
    func fetchInventoryItems(for location: Location) -> AnyPublisher<[InventoryItem], Error>
    func validateLocationData(_ data: LocationData) throws
}

public struct LocationData {
    public let name: String
    public let description: String?
    public let address: String?
    public let latitude: Double
    public let longitude: Double

    public init(
        name: String,
        description: String? = nil,
        address: String? = nil,
        latitude: Double = 0.0,
        longitude: Double = 0.0
    ) {
        self.name = name
        self.description = description
        self.address = address
        self.latitude = latitude
        self.longitude = longitude
    }

    public init(
        name: String,
        description: String? = nil,
        address: String? = nil,
        coordinate: CLLocationCoordinate2D
    ) {
        self.name = name
        self.description = description
        self.address = address
        self.latitude = coordinate.latitude
        self.longitude = coordinate.longitude
    }
}

public final class LocationRepository: ObservableObject, LocationRepositoryProtocol {

    private let persistenceController: PersistenceController
    private let context: NSManagedObjectContext

    public init(persistenceController: PersistenceController = .shared) {
        self.persistenceController = persistenceController
        self.context = persistenceController.viewContext
    }

    // MARK: - Fetch Operations

    public func fetchAllLocations() -> AnyPublisher<[Location], Error> {
        return fetchLocations(predicate: NSPredicate(format: "isActive == true"))
    }

    public func fetchLocations(predicate: NSPredicate? = nil) -> AnyPublisher<[Location], Error> {
        return Future<[Location], Error> { promise in
            let request: NSFetchRequest<Location> = Location.fetchRequest()
            request.predicate = predicate
            request.sortDescriptors = [
                NSSortDescriptor(keyPath: \Location.name, ascending: true)
            ]

            do {
                let locations = try self.context.fetch(request)
                promise(.success(locations))
            } catch {
                promise(.failure(error))
            }
        }
        .eraseToAnyPublisher()
    }

    // MARK: - Create Operations

    public func createLocation(_ locationData: LocationData) -> AnyPublisher<Location, Error> {
        return Future<Location, Error> { promise in
            do {
                // Validate location data
                try self.validateLocationData(locationData)

                let location = Location(context: self.context)
                location.id = UUID()
                location.name = locationData.name
                location.locationDescription = locationData.description
                location.address = locationData.address
                location.latitude = locationData.latitude
                location.longitude = locationData.longitude
                location.isActive = true
                location.createdAt = Date()
                location.updatedAt = Date()

                try location.validate()
                try self.context.save()
                promise(.success(location))
            } catch {
                promise(.failure(error))
            }
        }
        .eraseToAnyPublisher()
    }

    // MARK: - Update Operations

    public func updateLocation(_ location: Location, with data: LocationData) -> AnyPublisher<Location, Error> {
        return Future<Location, Error> { promise in
            location.name = data.name
            location.locationDescription = data.description
            location.address = data.address
            location.latitude = data.latitude
            location.longitude = data.longitude
            location.updatedAt = Date()

            do {
                try self.context.save()
                promise(.success(location))
            } catch {
                promise(.failure(error))
            }
        }
        .eraseToAnyPublisher()
    }

    // MARK: - Delete Operations

    public func deleteLocation(_ location: Location) -> AnyPublisher<Void, Error> {
        return Future<Void, Error> { promise in
            // Check if location has items
            if location.hasItems {
                let error = LocationError.hasItems("Cannot delete location with existing inventory items")
                promise(.failure(error))
                return
            }

            // Soft delete - mark as inactive
            location.isActive = false
            location.updatedAt = Date()

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

    public func fetchLocation(by id: UUID) -> AnyPublisher<Location?, Error> {
        return Future<Location?, Error> { promise in
            let request: NSFetchRequest<Location> = Location.fetchRequest()
            request.predicate = NSPredicate(format: "id == %@ AND isActive == true", id as CVarArg)
            request.fetchLimit = 1

            do {
                let location = try self.context.fetch(request).first
                promise(.success(location))
            } catch {
                promise(.failure(error))
            }
        }
        .eraseToAnyPublisher()
    }

    public func searchLocations(query: String) -> AnyPublisher<[Location], Error> {
        guard !query.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            return fetchAllLocations()
        }

        let predicate = NSCompoundPredicate(andPredicateWithSubpredicates: [
            NSPredicate(format: "isActive == true"),
            NSCompoundPredicate(orPredicateWithSubpredicates: [
                NSPredicate(format: "name CONTAINS[cd] %@", query),
                NSPredicate(format: "locationDescription CONTAINS[cd] %@", query),
                NSPredicate(format: "address CONTAINS[cd] %@", query)
            ])
        ])

        return fetchLocations(predicate: predicate)
    }

    public func fetchInventoryItems(for location: Location) -> AnyPublisher<[InventoryItem], Error> {
        return Future<[InventoryItem], Error> { promise in
            let request: NSFetchRequest<InventoryItem> = InventoryItem.fetchRequest()
            request.predicate = NSPredicate(format: "location == %@ AND isActive == true", location)
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

    public func validateLocationData(_ data: LocationData) throws {
        // Validate name
        guard !data.name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            throw LocationError.invalidData("Location name cannot be empty")
        }

        // Validate coordinates
        let coordinate = CLLocationCoordinate2D(latitude: data.latitude, longitude: data.longitude)
        guard CLLocationCoordinate2DIsValid(coordinate) else {
            throw LocationError.invalidCoordinates("GPS coordinates are invalid")
        }

        // Check for reasonable coordinate ranges (rough global bounds)
        guard data.latitude >= -90 && data.latitude <= 90 else {
            throw LocationError.invalidCoordinates("Latitude must be between -90 and 90 degrees")
        }

        guard data.longitude >= -180 && data.longitude <= 180 else {
            throw LocationError.invalidCoordinates("Longitude must be between -180 and 180 degrees")
        }
    }
}

// MARK: - Location Errors

public enum LocationError: Error, LocalizedError {
    case hasItems(String)
    case invalidCoordinates(String)
    case invalidData(String)

    public var errorDescription: String? {
        switch self {
        case .hasItems(let message),
             .invalidCoordinates(let message),
             .invalidData(let message):
            return message
        }
    }
}