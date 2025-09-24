import SwiftUI
import CoreData

/// Detailed view for a farm location showing inventory and transfer options
struct LocationDetailView: View {

    let location: Location
    @StateObject private var viewModel: LocationDetailViewModel

    @State private var showingTransferView = false
    @State private var showingMapView = false

    init(location: Location,
         locationRepository: LocationRepository,
         transferService: TransferService) {
        self.location = location
        self._viewModel = StateObject(wrappedValue:
            LocationDetailViewModel(
                location: location,
                locationRepository: locationRepository,
                transferService: transferService
            )
        )
    }

    var body: some View {
        ScrollView {
            LazyVStack(spacing: 20) {
                // Location header
                locationHeader

                // Quick actions
                quickActions

                // Inventory section
                inventorySection

                // Recent transfers section
                recentTransfersSection

                // Location statistics
                statisticsSection
            }
            .padding()
        }
        .navigationTitle(location.name)
        .navigationBarTitleDisplayMode(.large)
        .task {
            await viewModel.loadLocationData()
        }
        .refreshable {
            await viewModel.loadLocationData()
        }
        .sheet(isPresented: $showingTransferView) {
            ItemTransferView(
                transferService: viewModel.transferService,
                locationRepository: viewModel.locationRepository,
                inventoryRepository: viewModel.inventoryRepository
            )
        }
        .sheet(isPresented: $showingMapView) {
            NavigationView {
                LocationMapView(locations: [location], selectedLocation: .constant(location))
                    .navigationTitle("Location Map")
                    .navigationBarTitleDisplayMode(.inline)
                    .toolbar {
                        ToolbarItem(placement: .navigationBarTrailing) {
                            Button("Done") {
                                showingMapView = false
                            }
                        }
                    }
            }
        }
    }

    // MARK: - Location Header

    @ViewBuilder
    private var locationHeader: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text(location.name)
                        .font(.title2)
                        .fontWeight(.bold)

                    Text(location.locationDescription)
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                        .lineLimit(3)
                }

                Spacer()

                // Inventory count badge
                Text("\(viewModel.inventoryItems.count)")
                    .font(.title2)
                    .fontWeight(.bold)
                    .foregroundColor(.white)
                    .frame(width: 40, height: 40)
                    .background(Circle().fill(.blue))
                    .accessibilityLabel("\(viewModel.inventoryItems.count) items")
            }

            // GPS coordinates
            if location.latitude != 0 && location.longitude != 0 {
                HStack {
                    Image(systemName: "location.fill")
                        .foregroundColor(.blue)
                    Text("GPS: \(String(format: "%.6f", location.latitude)), \(String(format: "%.6f", location.longitude))")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }
        }
        .padding()
        .background(Color(.systemGroupedBackground))
        .cornerRadius(12)
    }

    // MARK: - Quick Actions

    @ViewBuilder
    private var quickActions: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Quick Actions")
                .font(.headline)

            HStack(spacing: 16) {
                ActionButton(
                    icon: "arrow.right.arrow.left",
                    title: "Transfer Item",
                    subtitle: "Move items to/from this location"
                ) {
                    showingTransferView = true
                }

                ActionButton(
                    icon: "map",
                    title: "View on Map",
                    subtitle: "See location coordinates"
                ) {
                    showingMapView = true
                }
            }
        }
    }

    // MARK: - Inventory Section

    @ViewBuilder
    private var inventorySection: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("Inventory Items")
                    .font(.headline)

                Spacer()

                if !viewModel.inventoryItems.isEmpty {
                    NavigationLink("View All") {
                        LocationInventoryListView(
                            location: location,
                            items: viewModel.inventoryItems
                        )
                    }
                    .font(.subheadline)
                }
            }

            if viewModel.isLoading {
                ProgressView("Loading inventory...")
                    .frame(maxWidth: .infinity)
                    .padding()
            } else if viewModel.inventoryItems.isEmpty {
                EmptyInventoryView()
            } else {
                LazyVStack(spacing: 8) {
                    ForEach(Array(viewModel.inventoryItems.prefix(5))) { item in
                        InventoryItemRow(item: item)
                    }

                    if viewModel.inventoryItems.count > 5 {
                        NavigationLink("View \(viewModel.inventoryItems.count - 5) more items") {
                            LocationInventoryListView(
                                location: location,
                                items: viewModel.inventoryItems
                            )
                        }
                        .font(.subheadline)
                        .padding(.top, 8)
                    }
                }
            }
        }
    }

    // MARK: - Recent Transfers Section

    @ViewBuilder
    private var recentTransfersSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("Recent Transfers")
                    .font(.headline)

                Spacer()

                if !viewModel.recentTransfers.isEmpty {
                    NavigationLink("View All") {
                        TransferHistoryView(
                            transfers: viewModel.recentTransfers,
                            location: location
                        )
                    }
                    .font(.subheadline)
                }
            }

            if viewModel.recentTransfers.isEmpty {
                Text("No recent transfers")
                    .foregroundColor(.secondary)
                    .frame(maxWidth: .infinity)
                    .padding()
            } else {
                LazyVStack(spacing: 8) {
                    ForEach(Array(viewModel.recentTransfers.prefix(3))) { transfer in
                        TransferProgressView(transfer: transfer)
                    }
                }
            }
        }
    }

    // MARK: - Statistics Section

    @ViewBuilder
    private var statisticsSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Statistics")
                .font(.headline)

            if let stats = viewModel.transferStats {
                LazyVGrid(columns: [
                    GridItem(.flexible()),
                    GridItem(.flexible())
                ], spacing: 12) {
                    StatCard(
                        title: "Items In",
                        value: "\(stats.incomingCount)",
                        subtitle: "\(stats.totalIncomingQuantity) total",
                        color: .green
                    )

                    StatCard(
                        title: "Items Out",
                        value: "\(stats.outgoingCount)",
                        subtitle: "\(stats.totalOutgoingQuantity) total",
                        color: .orange
                    )

                    StatCard(
                        title: "Net Transfer",
                        value: stats.netTransferQuantity >= 0 ? "+\(stats.netTransferQuantity)" : "\(stats.netTransferQuantity)",
                        subtitle: "items gained/lost",
                        color: stats.netTransferQuantity >= 0 ? .blue : .red
                    )

                    StatCard(
                        title: "Current Items",
                        value: "\(viewModel.inventoryItems.count)",
                        subtitle: "active inventory",
                        color: .purple
                    )
                }
            }
        }
    }
}

// MARK: - Supporting Views

struct ActionButton: View {
    let icon: String
    let title: String
    let subtitle: String
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            VStack(spacing: 8) {
                Image(systemName: icon)
                    .font(.title2)
                    .foregroundColor(.blue)

                VStack(spacing: 2) {
                    Text(title)
                        .font(.headline)
                        .foregroundColor(.primary)

                    Text(subtitle)
                        .font(.caption)
                        .foregroundColor(.secondary)
                        .multilineTextAlignment(.center)
                        .lineLimit(2)
                }
            }
            .frame(maxWidth: .infinity)
            .padding()
            .background(Color(.systemGray6))
            .cornerRadius(12)
        }
        .buttonStyle(PlainButtonStyle())
    }
}

struct EmptyInventoryView: View {
    var body: some View {
        VStack(spacing: 12) {
            Image(systemName: "archivebox")
                .font(.system(size: 40))
                .foregroundColor(.gray)

            Text("No Items")
                .font(.headline)
                .foregroundColor(.secondary)

            Text("Transfer items to this location to get started")
                .font(.subheadline)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity)
        .padding()
        .background(Color(.systemGray6))
        .cornerRadius(12)
    }
}

struct StatCard: View {
    let title: String
    let value: String
    let subtitle: String
    let color: Color

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(title)
                .font(.caption)
                .foregroundColor(.secondary)

            Text(value)
                .font(.title2)
                .fontWeight(.bold)
                .foregroundColor(color)

            Text(subtitle)
                .font(.caption2)
                .foregroundColor(.secondary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding()
        .background(Color(.systemGray6))
        .cornerRadius(8)
    }
}

// MARK: - View Model

@MainActor
class LocationDetailViewModel: ObservableObject {
    @Published var inventoryItems: [InventoryItem] = []
    @Published var recentTransfers: [Transfer] = []
    @Published var transferStats: TransferStatistics?
    @Published var isLoading = false

    let location: Location
    let locationRepository: LocationRepository
    let transferService: TransferService
    let inventoryRepository: InventoryRepository

    init(location: Location,
         locationRepository: LocationRepository,
         transferService: TransferService) {
        self.location = location
        self.locationRepository = locationRepository
        self.transferService = transferService
        self.inventoryRepository = InventoryRepository(context: locationRepository.context)
    }

    func loadLocationData() async {
        isLoading = true
        defer { isLoading = false }

        async let itemsTask = loadInventoryItems()
        async let transfersTask = loadRecentTransfers()
        async let statsTask = loadTransferStatistics()

        await itemsTask
        await transfersTask
        await statsTask
    }

    private func loadInventoryItems() async {
        do {
            inventoryItems = try await locationRepository.fetchInventoryItems(for: location)
        } catch {
            print("Failed to load inventory items: \(error)")
        }
    }

    private func loadRecentTransfers() async {
        do {
            recentTransfers = try await transferService.fetchTransfers(for: location, limit: 10)
        } catch {
            print("Failed to load recent transfers: \(error)")
        }
    }

    private func loadTransferStatistics() async {
        do {
            transferStats = try await transferService.getTransferStatistics(for: location)
        } catch {
            print("Failed to load transfer statistics: \(error)")
        }
    }
}

// MARK: - Preview

#Preview {
    NavigationView {
        LocationDetailView(
            location: Location(context: PersistenceController.preview.container.viewContext),
            locationRepository: LocationRepository(context: PersistenceController.preview.container.viewContext),
            transferService: TransferService(
                context: PersistenceController.preview.container.viewContext,
                inventoryRepository: InventoryRepository(context: PersistenceController.preview.container.viewContext),
                locationRepository: LocationRepository(context: PersistenceController.preview.container.viewContext)
            )
        )
    }
}