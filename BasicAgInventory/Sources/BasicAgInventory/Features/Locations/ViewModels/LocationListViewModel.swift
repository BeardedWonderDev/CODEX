import Foundation
import SwiftUI
import Combine
import CoreLocation

/// ViewModel for managing location list state and operations
/// Provides reactive UI updates with location loading under 1 second following MVVM pattern
@MainActor
public class LocationListViewModel: ObservableObject {

    // MARK: - Published Properties
    @Published public var locations: [Location] = []
    @Published public var isLoading = false
    @Published public var errorMessage: String?
    @Published public var searchText = ""
    @Published public var selectedLocation: Location?
    @Published public var showingAddLocation = false
    @Published public var showingDeleteConfirmation = false
    @Published public var locationToDelete: Location?

    // MARK: - Dependencies
    private let locationRepository: LocationRepositoryProtocol
    private let locationService: LocationService
    private var cancellables = Set<AnyCancellable>()

    // MARK: - Computed Properties

    /// Filtered locations based on search text
    public var filteredLocations: [Location] {
        if searchText.isEmpty {
            return locations
        } else {
            return locations.filter { location in
                location.name.localizedCaseInsensitiveContains(searchText) ||
                location.locationDescription?.localizedCaseInsensitiveContains(searchText) == true ||
                location.address?.localizedCaseInsensitiveContains(searchText) == true
            }
        }
    }

    /// Total number of locations
    public var totalLocationCount: Int {
        return locations.count
    }

    /// Total number of items across all locations
    public var totalItemCount: Int {
        return locations.reduce(0) { total, location in
            total + location.itemCount
        }
    }

    /// Check if any locations have items
    public var hasLocationsWithItems: Bool {
        return locations.contains { $0.hasItems }
    }

    // MARK: - Initialization

    public init(
        locationRepository: LocationRepositoryProtocol = LocationRepository(),
        locationService: LocationService = LocationService()
    ) {
        self.locationRepository = locationRepository
        self.locationService = locationService
        setupBindings()
        loadLocations()
    }

    // MARK: - Setup

    private func setupBindings() {
        // React to search text changes with debounce for performance
        $searchText
            .debounce(for: .milliseconds(300), scheduler: RunLoop.main)
            .removeDuplicates()
            .sink { _ in
                // Search is handled by computed property filteredLocations
                // This ensures UI updates when search text changes
            }
            .store(in: &cancellables)
    }

    // MARK: - Public Methods

    /// Load all locations from repository
    public func loadLocations() {
        isLoading = true
        errorMessage = nil

        locationRepository.fetchAllLocations()
            .receive(on: DispatchQueue.main)
            .sink(
                receiveCompletion: { [weak self] completion in
                    self?.isLoading = false
                    if case .failure(let error) = completion {
                        self?.errorMessage = error.localizedDescription
                    }
                },
                receiveValue: { [weak self] locations in
                    self?.locations = locations
                }
            )
            .store(in: &cancellables)
    }

    /// Refresh locations list
    public func refreshLocations() {
        loadLocations()
    }

    /// Search locations by query
    public func searchLocations(query: String) {
        guard !query.isEmpty else {
            loadLocations()
            return
        }

        isLoading = true
        errorMessage = nil

        locationRepository.searchLocations(query: query)
            .receive(on: DispatchQueue.main)
            .sink(
                receiveCompletion: { [weak self] completion in
                    self?.isLoading = false
                    if case .failure(let error) = completion {
                        self?.errorMessage = error.localizedDescription
                    }
                },
                receiveValue: { [weak self] locations in
                    self?.locations = locations
                }
            )
            .store(in: &cancellables)
    }

    /// Select a location
    public func selectLocation(_ location: Location) {
        selectedLocation = location
    }

    /// Clear selection
    public func clearSelection() {
        selectedLocation = nil
    }

    /// Show add location view
    public func showAddLocation() {
        showingAddLocation = true
    }

    /// Hide add location view
    public func hideAddLocation() {
        showingAddLocation = false
    }

    /// Prepare for location deletion
    public func prepareDeleteLocation(_ location: Location) {
        locationToDelete = location
        showingDeleteConfirmation = true
    }

    /// Cancel location deletion
    public func cancelDeleteLocation() {
        locationToDelete = nil
        showingDeleteConfirmation = false
    }

    /// Delete the selected location
    public func confirmDeleteLocation() {
        guard let location = locationToDelete else { return }

        isLoading = true
        errorMessage = nil

        locationRepository.deleteLocation(location)
            .receive(on: DispatchQueue.main)
            .sink(
                receiveCompletion: { [weak self] completion in
                    self?.isLoading = false
                    self?.showingDeleteConfirmation = false
                    self?.locationToDelete = nil

                    if case .failure(let error) = completion {
                        self?.errorMessage = error.localizedDescription
                    }
                },
                receiveValue: { [weak self] _ in
                    // Refresh locations after successful deletion
                    self?.loadLocations()
                }
            )
            .store(in: &cancellables)
    }

    /// Get location by ID
    public func location(with id: UUID) -> Location? {
        return locations.first { $0.id == id }
    }

    /// Check if location can be deleted (no items)
    public func canDelete(_ location: Location) -> Bool {
        return !location.hasItems
    }

    /// Get deletion warning message for location
    public func deletionWarningMessage(for location: Location) -> String {
        if location.hasItems {
            let itemCount = location.itemCount
            return "Cannot delete '\(location.name)' because it contains \(itemCount) inventory item\(itemCount == 1 ? "" : "s"). Move or remove all items first."
        } else {
            return "Are you sure you want to delete '\(location.name)'? This action cannot be undone."
        }
    }

    /// Clear any error message
    public func clearError() {
        errorMessage = nil
    }

    /// Get locations grouped by first letter for sectioned display
    public var groupedLocations: [(String, [Location])] {
        let grouped = Dictionary(grouping: filteredLocations) { location in
            String(location.name.prefix(1).uppercased())
        }

        return grouped.sorted { $0.key < $1.key }
            .map { (key, value) in
                (key, value.sorted { $0.name < $1.name })
            }
    }

    /// Get locations for map display
    public var locationsForMap: [LocationAnnotation] {
        return filteredLocations.map { LocationAnnotation(location: $0) }
    }

    /// Handle location service errors
    public func handleLocationServiceError(_ error: Error) {
        if let locationError = error as? LocationError {
            errorMessage = locationError.localizedDescription
        } else {
            errorMessage = "Location service error: \(error.localizedDescription)"
        }
    }

    /// Get location statistics summary
    public var locationStatistics: LocationStatistics {
        let totalLocations = locations.count
        let locationsWithItems = locations.filter { $0.hasItems }.count
        let emptyLocations = totalLocations - locationsWithItems
        let totalItems = totalItemCount
        let averageItemsPerLocation = totalLocations > 0 ? Double(totalItems) / Double(totalLocations) : 0

        return LocationStatistics(
            totalLocations: totalLocations,
            locationsWithItems: locationsWithItems,
            emptyLocations: emptyLocations,
            totalItems: totalItems,
            averageItemsPerLocation: averageItemsPerLocation
        )
    }
}

// MARK: - Supporting Types

public struct LocationStatistics {
    public let totalLocations: Int
    public let locationsWithItems: Int
    public let emptyLocations: Int
    public let totalItems: Int
    public let averageItemsPerLocation: Double

    public var formattedAverageItems: String {
        return String(format: "%.1f", averageItemsPerLocation)
    }
}