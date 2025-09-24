import Foundation
import Combine
import SwiftUI

@MainActor
public final class InventoryListViewModel: ObservableObject {

    // MARK: - Published Properties
    @Published public var items: [InventoryItem] = []
    @Published public var filteredItems: [InventoryItem] = []
    @Published public var searchText: String = "" {
        didSet {
            performSearch()
        }
    }
    @Published public var selectedCategory: String = "All" {
        didSet {
            applyFilters()
        }
    }
    @Published public var selectedLocation: Location? {
        didSet {
            applyFilters()
        }
    }
    @Published public var showLowStockOnly: Bool = false {
        didSet {
            applyFilters()
        }
    }
    @Published public var showExpiredOnly: Bool = false {
        didSet {
            applyFilters()
        }
    }

    // UI State
    @Published public var isLoading: Bool = false
    @Published public var errorMessage: String?
    @Published public var showingAddItem: Bool = false
    @Published public var showingFilters: Bool = false

    // Filter Options
    @Published public var categories: [String] = ["All"]
    @Published public var locations: [Location] = []

    // MARK: - Private Properties
    private let inventoryRepository: InventoryRepositoryProtocol
    private let locationRepository: LocationRepositoryProtocol
    private var cancellables = Set<AnyCancellable>()
    private var searchCancellable: AnyCancellable?

    // MARK: - Initialization
    public init(
        inventoryRepository: InventoryRepositoryProtocol = InventoryRepository(),
        locationRepository: LocationRepositoryProtocol = LocationRepository()
    ) {
        self.inventoryRepository = inventoryRepository
        self.locationRepository = locationRepository

        setupSearchDebouncing()
        loadInitialData()
    }

    // MARK: - Public Methods

    public func loadData() {
        isLoading = true
        errorMessage = nil

        Publishers.CombineLatest3(
            inventoryRepository.fetchAllItems(),
            inventoryRepository.getAllCategories(),
            locationRepository.fetchAllLocations()
        )
        .receive(on: DispatchQueue.main)
        .sink(
            receiveCompletion: { [weak self] completion in
                self?.isLoading = false
                if case .failure(let error) = completion {
                    self?.errorMessage = error.localizedDescription
                }
            },
            receiveValue: { [weak self] items, categories, locations in
                self?.items = items
                self?.categories = ["All"] + categories
                self?.locations = locations
                self?.applyFilters()
            }
        )
        .store(in: &cancellables)
    }

    public func refreshData() {
        loadData()
    }

    public func deleteItem(_ item: InventoryItem) {
        inventoryRepository.deleteItem(item)
            .receive(on: DispatchQueue.main)
            .sink(
                receiveCompletion: { [weak self] completion in
                    if case .failure(let error) = completion {
                        self?.errorMessage = error.localizedDescription
                    }
                },
                receiveValue: { [weak self] _ in
                    self?.loadData() // Refresh data after deletion
                }
            )
            .store(in: &cancellables)
    }

    public func updateQuantity(for item: InventoryItem, newQuantity: Int32, reason: String = "Manual adjustment") {
        inventoryRepository.updateQuantity(for: item, newQuantity: newQuantity, reason: reason)
            .receive(on: DispatchQueue.main)
            .sink(
                receiveCompletion: { [weak self] completion in
                    if case .failure(let error) = completion {
                        self?.errorMessage = error.localizedDescription
                    }
                },
                receiveValue: { [weak self] updatedItem in
                    // Update the item in our local array
                    if let index = self?.items.firstIndex(where: { $0.id == updatedItem.id }) {
                        self?.items[index] = updatedItem
                        self?.applyFilters()
                    }
                }
            )
            .store(in: &cancellables)
    }

    public func incrementQuantity(for item: InventoryItem, by amount: Int32 = 1) {
        let newQuantity = item.quantity + amount
        updateQuantity(for: item, newQuantity: newQuantity, reason: "Increment by \(amount)")
    }

    public func decrementQuantity(for item: InventoryItem, by amount: Int32 = 1) {
        let newQuantity = max(0, item.quantity - amount)
        updateQuantity(for: item, newQuantity: newQuantity, reason: "Decrement by \(amount)")
    }

    public func clearFilters() {
        selectedCategory = "All"
        selectedLocation = nil
        showLowStockOnly = false
        showExpiredOnly = false
        searchText = ""
    }

    // MARK: - Computed Properties

    public var hasFiltersApplied: Bool {
        return selectedCategory != "All" ||
               selectedLocation != nil ||
               showLowStockOnly ||
               showExpiredOnly ||
               !searchText.isEmpty
    }

    public var lowStockCount: Int {
        return items.filter { $0.isLowStock }.count
    }

    public var expiredItemsCount: Int {
        return items.filter { $0.isExpired }.count
    }

    public var totalItemsCount: Int {
        return items.count
    }

    // MARK: - Private Methods

    private func setupSearchDebouncing() {
        // Debounce search to avoid excessive API calls
        searchCancellable = $searchText
            .debounce(for: .milliseconds(300), scheduler: RunLoop.main)
            .sink { [weak self] _ in
                self?.performSearch()
            }
    }

    private func loadInitialData() {
        loadData()
    }

    private func performSearch() {
        guard !searchText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            applyFilters()
            return
        }

        inventoryRepository.searchItems(query: searchText)
            .receive(on: DispatchQueue.main)
            .sink(
                receiveCompletion: { [weak self] completion in
                    if case .failure(let error) = completion {
                        self?.errorMessage = error.localizedDescription
                    }
                },
                receiveValue: { [weak self] searchResults in
                    self?.items = searchResults
                    self?.applyFilters()
                }
            )
            .store(in: &cancellables)
    }

    private func applyFilters() {
        var filtered = items

        // Apply category filter
        if selectedCategory != "All" {
            filtered = filtered.filter { $0.category == selectedCategory }
        }

        // Apply location filter
        if let selectedLocation = selectedLocation {
            filtered = filtered.filter { $0.location == selectedLocation }
        }

        // Apply low stock filter
        if showLowStockOnly {
            filtered = filtered.filter { $0.isLowStock }
        }

        // Apply expired items filter
        if showExpiredOnly {
            filtered = filtered.filter { $0.isExpired }
        }

        filteredItems = filtered
    }
}