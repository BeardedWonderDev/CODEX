import Foundation
import CoreData
import Combine

/// ViewModel for managing item transfer workflow between farm locations
@MainActor
class ItemTransferViewModel: ObservableObject {

    // MARK: - Published Properties

    @Published var availableLocations: [Location] = []
    @Published var availableItems: [InventoryItem] = []
    @Published var transferHistory: [Transfer] = []

    // Transfer form state
    @Published var sourceLocation: Location?
    @Published var destinationLocation: Location?
    @Published var selectedItem: InventoryItem?
    @Published var transferQuantity: String = "1"
    @Published var notes: String = ""

    // UI state
    @Published var isLoading: Bool = false
    @Published var isTransferring: Bool = false
    @Published var showingSuccessAlert: Bool = false
    @Published var errorMessage: String?

    // Transfer progress
    @Published var currentStep: TransferStep = .selectItem
    @Published var completedTransfer: Transfer?

    // MARK: - Dependencies

    private let transferService: TransferService
    private let locationRepository: LocationRepository
    private let inventoryRepository: InventoryRepository

    private var cancellables = Set<AnyCancellable>()

    // MARK: - Initialization

    init(transferService: TransferService,
         locationRepository: LocationRepository,
         inventoryRepository: InventoryRepository) {
        self.transferService = transferService
        self.locationRepository = locationRepository
        self.inventoryRepository = inventoryRepository

        setupBindings()
    }

    // MARK: - Setup

    private func setupBindings() {
        // Update available items when source location changes
        $sourceLocation
            .sink { [weak self] location in
                Task { @MainActor in
                    await self?.loadAvailableItems()
                }
            }
            .store(in: &cancellables)

        // Reset transfer quantity when selected item changes
        $selectedItem
            .sink { [weak self] _ in
                self?.transferQuantity = "1"
            }
            .store(in: &cancellables)

        // Monitor transfer service state
        transferService.$isTransferring
            .receive(on: DispatchQueue.main)
            .assign(to: \.isTransferring, on: self)
            .store(in: &cancellables)
    }

    // MARK: - Data Loading

    func loadInitialData() async {
        isLoading = true
        defer { isLoading = false }

        await loadAvailableLocations()
        await loadAvailableItems()
    }

    private func loadAvailableLocations() async {
        do {
            availableLocations = try await locationRepository.fetchAllLocations()
        } catch {
            errorMessage = "Failed to load locations: \(error.localizedDescription)"
        }
    }

    private func loadAvailableItems() async {
        do {
            if let sourceLocation = sourceLocation {
                // Load items from specific location
                availableItems = try await locationRepository.fetchInventoryItems(for: sourceLocation)
            } else {
                // Load all items (for new assignments)
                availableItems = try await inventoryRepository.fetchAllItems()
            }
        } catch {
            errorMessage = "Failed to load items: \(error.localizedDescription)"
        }
    }

    func loadTransferHistory() async {
        guard let item = selectedItem else { return }

        do {
            transferHistory = try await transferService.fetchTransferHistory(for: item)
        } catch {
            errorMessage = "Failed to load transfer history: \(error.localizedDescription)"
        }
    }

    // MARK: - Transfer Workflow

    var transferQuantityInt: Int32 {
        Int32(transferQuantity) ?? 1
    }

    var canProceedToNextStep: Bool {
        switch currentStep {
        case .selectItem:
            return selectedItem != nil
        case .chooseDestination:
            return destinationLocation != nil
        case .confirmTransfer:
            return canExecuteTransfer
        case .completed:
            return false
        }
    }

    var canExecuteTransfer: Bool {
        guard let item = selectedItem,
              let destination = destinationLocation,
              transferQuantityInt > 0 else {
            return false
        }

        // For transfers from existing locations, check quantity availability
        if let source = sourceLocation {
            return item.quantity >= transferQuantityInt && destination != source
        }

        // For new item assignments, always allow
        return true
    }

    func proceedToNextStep() {
        switch currentStep {
        case .selectItem:
            currentStep = .chooseDestination
        case .chooseDestination:
            currentStep = .confirmTransfer
        case .confirmTransfer:
            Task {
                await executeTransfer()
            }
        case .completed:
            break
        }
    }

    func goBackToPreviousStep() {
        switch currentStep {
        case .selectItem:
            break
        case .chooseDestination:
            currentStep = .selectItem
        case .confirmTransfer:
            currentStep = .chooseDestination
        case .completed:
            currentStep = .confirmTransfer
        }
    }

    // MARK: - Transfer Execution

    func executeTransfer() async {
        guard let item = selectedItem,
              let destination = destinationLocation else {
            errorMessage = "Please select both an item and destination location"
            return
        }

        do {
            let transfer = try await transferService.transferItem(
                item,
                from: sourceLocation,
                to: destination,
                quantity: transferQuantityInt,
                notes: notes.isEmpty ? nil : notes
            )

            completedTransfer = transfer
            currentStep = .completed
            showingSuccessAlert = true

            // Refresh data after successful transfer
            await loadAvailableItems()
            await loadTransferHistory()

        } catch {
            errorMessage = "Transfer failed: \(error.localizedDescription)"
        }
    }

    // MARK: - Form Management

    func resetTransferForm() {
        sourceLocation = nil
        destinationLocation = nil
        selectedItem = nil
        transferQuantity = "1"
        notes = ""
        currentStep = .selectItem
        completedTransfer = nil
        errorMessage = nil
        showingSuccessAlert = false

        // Clear derived data
        availableItems = []
        transferHistory = []
    }

    func startNewTransfer() {
        resetTransferForm()
        Task {
            await loadInitialData()
        }
    }

    // MARK: - Validation

    var transferValidationMessage: String? {
        guard let item = selectedItem else {
            return nil
        }

        if transferQuantityInt <= 0 {
            return "Transfer quantity must be greater than 0"
        }

        if let source = sourceLocation {
            if item.quantity < transferQuantityInt {
                return "Not enough items available. Only \(item.quantity) \(item.unit) available."
            }
        }

        if let destination = destinationLocation,
           let source = sourceLocation,
           destination == source {
            return "Source and destination locations must be different"
        }

        return nil
    }

    // MARK: - Computed Properties

    var transferSummary: String {
        guard let item = selectedItem else {
            return "No item selected"
        }

        let itemName = item.name
        let quantity = "\(transferQuantityInt) \(item.unit)"
        let fromLocation = sourceLocation?.name ?? "New Stock"
        let toLocation = destinationLocation?.name ?? "No destination"

        return "Transfer \(quantity) of \(itemName) from \(fromLocation) to \(toLocation)"
    }

    var stepProgress: Double {
        switch currentStep {
        case .selectItem:
            return 0.25
        case .chooseDestination:
            return 0.5
        case .confirmTransfer:
            return 0.75
        case .completed:
            return 1.0
        }
    }

    var stepTitle: String {
        switch currentStep {
        case .selectItem:
            return "Select Item"
        case .chooseDestination:
            return "Choose Destination"
        case .confirmTransfer:
            return "Confirm Transfer"
        case .completed:
            return "Transfer Complete"
        }
    }

    var stepDescription: String {
        switch currentStep {
        case .selectItem:
            return "Choose the item you want to transfer"
        case .chooseDestination:
            return "Select the destination location"
        case .confirmTransfer:
            return "Review and confirm the transfer details"
        case .completed:
            return "Transfer has been completed successfully"
        }
    }
}

// MARK: - Transfer Steps

enum TransferStep: Int, CaseIterable {
    case selectItem = 0
    case chooseDestination = 1
    case confirmTransfer = 2
    case completed = 3

    var title: String {
        switch self {
        case .selectItem: return "Select Item"
        case .chooseDestination: return "Choose Destination"
        case .confirmTransfer: return "Confirm Transfer"
        case .completed: return "Complete"
        }
    }
}