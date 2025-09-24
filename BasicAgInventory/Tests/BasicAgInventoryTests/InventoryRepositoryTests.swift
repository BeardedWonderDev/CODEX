import XCTest
import CoreData
@testable import BasicAgInventory

final class InventoryRepositoryTests: XCTestCase {

    var repository: InventoryRepository!
    var persistenceController: PersistenceController!

    override func setUpWithError() throws {
        // Create an in-memory store for testing
        persistenceController = PersistenceController(inMemory: true)
        repository = InventoryRepository(persistenceController: persistenceController)
    }

    override func tearDownWithError() throws {
        repository = nil
        persistenceController = nil
    }

    func testCreateItem() throws {
        // Given
        let itemData = InventoryItemData(
            name: "Test Tractor",
            description: "A test tractor for farming",
            category: "Equipment",
            quantity: 1,
            unit: "unit",
            minimumStock: 1,
            purchasePrice: 50000.0
        )

        // When
        let expectation = XCTestExpectation(description: "Create item")
        var createdItem: InventoryItem?
        var error: Error?

        repository.createItem(itemData)
            .sink(
                receiveCompletion: { completion in
                    if case .failure(let err) = completion {
                        error = err
                    }
                    expectation.fulfill()
                },
                receiveValue: { item in
                    createdItem = item
                }
            )
            .store(in: &cancellables)

        wait(for: [expectation], timeout: 5.0)

        // Then
        XCTAssertNil(error, "Should not have error")
        XCTAssertNotNil(createdItem, "Should create item")
        XCTAssertEqual(createdItem?.name, "Test Tractor")
        XCTAssertEqual(createdItem?.category, "Equipment")
        XCTAssertEqual(createdItem?.quantity, 1)
        XCTAssertTrue(createdItem?.isActive == true)
    }

    func testFetchAllItems() throws {
        // Given - Create some test items first
        let itemData1 = InventoryItemData(name: "Item 1", category: "Category A", quantity: 10, unit: "units")
        let itemData2 = InventoryItemData(name: "Item 2", category: "Category B", quantity: 5, unit: "units")

        let createExpectation = XCTestExpectation(description: "Create items")
        createExpectation.expectedFulfillmentCount = 2

        repository.createItem(itemData1)
            .sink(receiveCompletion: { _ in createExpectation.fulfill() }, receiveValue: { _ in })
            .store(in: &cancellables)

        repository.createItem(itemData2)
            .sink(receiveCompletion: { _ in createExpectation.fulfill() }, receiveValue: { _ in })
            .store(in: &cancellables)

        wait(for: [createExpectation], timeout: 5.0)

        // When
        let fetchExpectation = XCTestExpectation(description: "Fetch items")
        var fetchedItems: [InventoryItem] = []
        var error: Error?

        repository.fetchAllItems()
            .sink(
                receiveCompletion: { completion in
                    if case .failure(let err) = completion {
                        error = err
                    }
                    fetchExpectation.fulfill()
                },
                receiveValue: { items in
                    fetchedItems = items
                }
            )
            .store(in: &cancellables)

        wait(for: [fetchExpectation], timeout: 5.0)

        // Then
        XCTAssertNil(error, "Should not have error")
        XCTAssertEqual(fetchedItems.count, 2, "Should fetch 2 items")
        XCTAssertTrue(fetchedItems.contains { $0.name == "Item 1" })
        XCTAssertTrue(fetchedItems.contains { $0.name == "Item 2" })
    }

    func testSearchItems() throws {
        // Given
        let itemData = InventoryItemData(
            name: "John Deere Tractor",
            description: "Heavy duty farming tractor",
            category: "Equipment",
            quantity: 1,
            unit: "unit"
        )

        let createExpectation = XCTestExpectation(description: "Create item")
        repository.createItem(itemData)
            .sink(receiveCompletion: { _ in createExpectation.fulfill() }, receiveValue: { _ in })
            .store(in: &cancellables)

        wait(for: [createExpectation], timeout: 5.0)

        // When
        let searchExpectation = XCTestExpectation(description: "Search items")
        var searchResults: [InventoryItem] = []
        var error: Error?

        repository.searchItems(query: "John")
            .sink(
                receiveCompletion: { completion in
                    if case .failure(let err) = completion {
                        error = err
                    }
                    searchExpectation.fulfill()
                },
                receiveValue: { items in
                    searchResults = items
                }
            )
            .store(in: &cancellables)

        wait(for: [searchExpectation], timeout: 5.0)

        // Then
        XCTAssertNil(error, "Should not have error")
        XCTAssertEqual(searchResults.count, 1, "Should find 1 item")
        XCTAssertEqual(searchResults.first?.name, "John Deere Tractor")
    }

    func testUpdateQuantity() throws {
        // Given
        let itemData = InventoryItemData(name: "Test Item", category: "Test", quantity: 10, unit: "units")

        let createExpectation = XCTestExpectation(description: "Create item")
        var createdItem: InventoryItem?

        repository.createItem(itemData)
            .sink(
                receiveCompletion: { _ in createExpectation.fulfill() },
                receiveValue: { item in createdItem = item }
            )
            .store(in: &cancellables)

        wait(for: [createExpectation], timeout: 5.0)

        guard let item = createdItem else {
            XCTFail("Failed to create item")
            return
        }

        // When
        let updateExpectation = XCTestExpectation(description: "Update quantity")
        var updatedItem: InventoryItem?
        var error: Error?

        repository.updateQuantity(for: item, newQuantity: 15, reason: "Test update")
            .sink(
                receiveCompletion: { completion in
                    if case .failure(let err) = completion {
                        error = err
                    }
                    updateExpectation.fulfill()
                },
                receiveValue: { item in
                    updatedItem = item
                }
            )
            .store(in: &cancellables)

        wait(for: [updateExpectation], timeout: 5.0)

        // Then
        XCTAssertNil(error, "Should not have error")
        XCTAssertNotNil(updatedItem, "Should return updated item")
        XCTAssertEqual(updatedItem?.quantity, 15, "Should update quantity")
    }

    func testDeleteItem() throws {
        // Given
        let itemData = InventoryItemData(name: "Test Item", category: "Test", quantity: 1, unit: "unit")

        let createExpectation = XCTestExpectation(description: "Create item")
        var createdItem: InventoryItem?

        repository.createItem(itemData)
            .sink(
                receiveCompletion: { _ in createExpectation.fulfill() },
                receiveValue: { item in createdItem = item }
            )
            .store(in: &cancellables)

        wait(for: [createExpectation], timeout: 5.0)

        guard let item = createdItem else {
            XCTFail("Failed to create item")
            return
        }

        // When
        let deleteExpectation = XCTestExpectation(description: "Delete item")
        var error: Error?

        repository.deleteItem(item)
            .sink(
                receiveCompletion: { completion in
                    if case .failure(let err) = completion {
                        error = err
                    }
                    deleteExpectation.fulfill()
                },
                receiveValue: { _ in }
            )
            .store(in: &cancellables)

        wait(for: [deleteExpectation], timeout: 5.0)

        // Then
        XCTAssertNil(error, "Should not have error")
        XCTAssertFalse(item.isActive, "Should mark item as inactive")
    }

    // MARK: - Helper Properties

    private var cancellables = Set<AnyCancellable>()
}

// Import Combine for tests
import Combine