import Foundation
import Combine
import SwiftUI
import PhotosUI

#if os(iOS)
import UIKit
#elseif os(macOS)
import AppKit
#endif

@MainActor
public final class AddEditItemViewModel: ObservableObject {

    // MARK: - Published Properties
    @Published public var name: String = ""
    @Published public var itemDescription: String = ""
    @Published public var category: String = ""
    @Published public var quantity: String = "0"
    @Published public var unit: String = "units"
    @Published public var minimumStock: String = "0"
    @Published public var purchasePrice: String = "0.00"
    @Published public var purchaseDate: Date = Date()
    @Published public var hasPurchaseDate: Bool = false
    @Published public var expirationDate: Date = Date().addingTimeInterval(86400 * 365) // 1 year from now
    @Published public var hasExpirationDate: Bool = false
    @Published public var notes: String = ""
    @Published public var selectedLocation: Location?

    // Image handling
    @Published public var selectedPhotoItem: PhotosPickerItem?
    #if os(iOS)
    @Published public var itemImage: UIImage?
    #elseif os(macOS)
    @Published public var itemImage: NSImage?
    #endif
    @Published public var showingImagePicker: Bool = false

    // UI State
    @Published public var isLoading: Bool = false
    @Published public var errorMessage: String?
    @Published public var validationErrors: [ValidationError] = []

    // Data
    @Published public var categories: [String] = []
    @Published public var locations: [Location] = []
    @Published public var commonUnits: [String] = [
        "units", "kg", "lbs", "liters", "gallons", "tons", "bags", "boxes", "pallets"
    ]

    // MARK: - Private Properties
    private let inventoryRepository: InventoryRepositoryProtocol
    private let locationRepository: LocationRepositoryProtocol
    private var cancellables = Set<AnyCancellable>()

    // Edit mode
    private var editingItem: InventoryItem?
    public var isEditMode: Bool { editingItem != nil }

    // MARK: - Initialization

    public init(
        inventoryRepository: InventoryRepositoryProtocol = InventoryRepository(),
        locationRepository: LocationRepositoryProtocol = LocationRepository(),
        item: InventoryItem? = nil
    ) {
        self.inventoryRepository = inventoryRepository
        self.locationRepository = locationRepository
        self.editingItem = item

        if let item = item {
            setupForEditing(item: item)
        }

        setupPhotoPickerObserver()
        loadInitialData()
    }

    // MARK: - Public Methods

    public func saveItem() async {
        guard validateForm() else { return }

        isLoading = true
        errorMessage = nil

        do {
            let itemData = try createItemData()

            if let editingItem = editingItem {
                // Update existing item
                _ = try await inventoryRepository.updateItem(editingItem, with: itemData).async()
            } else {
                // Create new item
                _ = try await inventoryRepository.createItem(itemData).async()
            }

            isLoading = false
        } catch {
            isLoading = false
            errorMessage = error.localizedDescription
        }
    }

    public func resetForm() {
        name = ""
        itemDescription = ""
        category = ""
        quantity = "0"
        unit = "units"
        minimumStock = "0"
        purchasePrice = "0.00"
        purchaseDate = Date()
        hasPurchaseDate = false
        expirationDate = Date().addingTimeInterval(86400 * 365)
        hasExpirationDate = false
        notes = ""
        selectedLocation = nil
        itemImage = nil
        selectedPhotoItem = nil
        validationErrors = []
        errorMessage = nil
    }

    public func addCategory(_ newCategory: String) {
        let trimmedCategory = newCategory.trimmingCharacters(in: .whitespacesAndNewlines)
        if !trimmedCategory.isEmpty && !categories.contains(trimmedCategory) {
            categories.append(trimmedCategory)
            categories.sort()
            category = trimmedCategory
        }
    }

    // MARK: - Computed Properties

    public var isFormValid: Bool {
        return !name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty &&
               !category.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty &&
               Int32(quantity) != nil &&
               Double(purchasePrice) != nil
    }

    public var formattedTitle: String {
        return isEditMode ? "Edit Item" : "Add New Item"
    }

    // MARK: - Private Methods

    private func setupForEditing(item: InventoryItem) {
        name = item.name
        itemDescription = item.itemDescription ?? ""
        category = item.category
        quantity = String(item.quantity)
        unit = item.unit
        minimumStock = String(item.minimumStock)
        purchasePrice = String(format: "%.2f", item.purchasePrice)

        if let purchaseDate = item.purchaseDate {
            self.purchaseDate = purchaseDate
            self.hasPurchaseDate = true
        }

        if let expirationDate = item.expirationDate {
            self.expirationDate = expirationDate
            self.hasExpirationDate = true
        }

        notes = item.notes ?? ""
        selectedLocation = item.location

        if let imageData = item.imageData {
            #if os(iOS)
            itemImage = UIImage(data: imageData)
            #elseif os(macOS)
            itemImage = NSImage(data: imageData)
            #endif
        }
    }

    private func setupPhotoPickerObserver() {
        $selectedPhotoItem
            .compactMap { $0 }
            .sink { [weak self] photoItem in
                Task { @MainActor in
                    await self?.loadImage(from: photoItem)
                }
            }
            .store(in: &cancellables)
    }

    @MainActor
    private func loadImage(from photoItem: PhotosPickerItem) async {
        do {
            if let data = try await photoItem.loadTransferable(type: Data.self) {
                #if os(iOS)
                if let image = UIImage(data: data) {
                    self.itemImage = image
                }
                #elseif os(macOS)
                if let image = NSImage(data: data) {
                    self.itemImage = image
                }
                #endif
            }
        } catch {
            self.errorMessage = "Failed to load selected image: \(error.localizedDescription)"
        }
    }

    private func loadInitialData() {
        Publishers.CombineLatest(
            inventoryRepository.getAllCategories(),
            locationRepository.fetchAllLocations()
        )
        .receive(on: DispatchQueue.main)
        .sink(
            receiveCompletion: { [weak self] completion in
                if case .failure(let error) = completion {
                    self?.errorMessage = error.localizedDescription
                }
            },
            receiveValue: { [weak self] categories, locations in
                self?.categories = categories
                self?.locations = locations
            }
        )
        .store(in: &cancellables)
    }

    private func validateForm() -> Bool {
        validationErrors = []

        // Name validation
        if name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            validationErrors.append(ValidationError(field: "name", message: "Item name is required"))
        }

        // Category validation
        if category.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            validationErrors.append(ValidationError(field: "category", message: "Category is required"))
        }

        // Quantity validation
        guard let quantityValue = Int32(quantity), quantityValue >= 0 else {
            validationErrors.append(ValidationError(field: "quantity", message: "Quantity must be a valid non-negative number"))
            return false
        }

        // Minimum stock validation
        guard let minimumStockValue = Int32(minimumStock), minimumStockValue >= 0 else {
            validationErrors.append(ValidationError(field: "minimumStock", message: "Minimum stock must be a valid non-negative number"))
            return false
        }

        // Purchase price validation
        guard let priceValue = Double(purchasePrice), priceValue >= 0 else {
            validationErrors.append(ValidationError(field: "purchasePrice", message: "Purchase price must be a valid non-negative number"))
            return false
        }

        // Date validation
        if hasExpirationDate && hasPurchaseDate && expirationDate <= purchaseDate {
            validationErrors.append(ValidationError(field: "expirationDate", message: "Expiration date must be after purchase date"))
        }

        return validationErrors.isEmpty
    }

    private func createItemData() throws -> InventoryItemData {
        guard let quantityValue = Int32(quantity),
              let minimumStockValue = Int32(minimumStock),
              let priceValue = Double(purchasePrice) else {
            throw ValidationError(field: "general", message: "Invalid number format")
        }

        let imageData: Data?
        #if os(iOS)
        imageData = itemImage?.jpegData(compressionQuality: 0.8)
        #elseif os(macOS)
        if let image = itemImage,
           let tiff = image.tiffRepresentation,
           let bitmapRep = NSBitmapImageRep(data: tiff) {
            imageData = bitmapRep.representation(using: .jpeg, properties: [.compressionFactor: 0.8])
        } else {
            imageData = nil
        }
        #endif

        return InventoryItemData(
            name: name.trimmingCharacters(in: .whitespacesAndNewlines),
            description: itemDescription.isEmpty ? nil : itemDescription.trimmingCharacters(in: .whitespacesAndNewlines),
            category: category.trimmingCharacters(in: .whitespacesAndNewlines),
            quantity: quantityValue,
            unit: unit,
            minimumStock: minimumStockValue,
            purchasePrice: priceValue,
            purchaseDate: hasPurchaseDate ? purchaseDate : nil,
            expirationDate: hasExpirationDate ? expirationDate : nil,
            notes: notes.isEmpty ? nil : notes.trimmingCharacters(in: .whitespacesAndNewlines),
            imageData: imageData,
            locationId: selectedLocation?.id
        )
    }
}

// MARK: - Validation Error

public struct ValidationError: Error, Identifiable {
    public let id = UUID()
    public let field: String
    public let message: String

    public init(field: String, message: String) {
        self.field = field
        self.message = message
    }
}

// MARK: - Publisher Extension

extension AnyPublisher {
    func async() async throws -> Output {
        try await withCheckedThrowingContinuation { continuation in
            var cancellable: AnyCancellable?
            cancellable = first()
                .sink(
                    receiveCompletion: { completion in
                        switch completion {
                        case .finished:
                            break
                        case .failure(let error):
                            continuation.resume(throwing: error)
                        }
                        cancellable?.cancel()
                    },
                    receiveValue: { value in
                        continuation.resume(returning: value)
                        cancellable?.cancel()
                    }
                )
        }
    }
}