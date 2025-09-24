import SwiftUI
import CoreLocation

/// SwiftUI List view for browsing farm locations with inventory summaries
/// Provides consistent navigation, VoiceOver support, and Dynamic Type compatibility
public struct LocationListView: View {

    // MARK: - Properties
    @StateObject private var viewModel = LocationListViewModel()
    @State private var showingMapView = false

    // MARK: - Body
    public var body: some View {
        NavigationView {
            VStack(spacing: 0) {
                // Search Bar
                SearchBar(text: $viewModel.searchText)
                    .padding(.horizontal)
                    .padding(.top, 8)

                // Statistics Header
                if !viewModel.locations.isEmpty {
                    LocationStatisticsHeader(statistics: viewModel.locationStatistics)
                        .padding(.horizontal)
                        .padding(.vertical, 8)
                }

                // Content
                if viewModel.isLoading {
                    LoadingView()
                } else if viewModel.filteredLocations.isEmpty {
                    EmptyStateView(
                        hasLocations: !viewModel.locations.isEmpty,
                        searchText: viewModel.searchText
                    ) {
                        viewModel.showAddLocation()
                    }
                } else {
                    LocationList()
                }
            }
            .navigationTitle("Locations")
            .navigationBarTitleDisplayMode(.large)
            .toolbar {
                ToolbarItemGroup(placement: .navigationBarTrailing) {
                    Button(action: { showingMapView = true }) {
                        Image(systemName: "map")
                            .accessibilityLabel("Show map view")
                    }
                    .disabled(viewModel.locations.isEmpty)

                    Button(action: { viewModel.showAddLocation() }) {
                        Image(systemName: "plus")
                            .accessibilityLabel("Add new location")
                    }
                }

                ToolbarItem(placement: .navigationBarLeading) {
                    if viewModel.isLoading {
                        ProgressView()
                            .scaleEffect(0.8)
                    }
                }
            }
            .refreshable {
                await refreshLocations()
            }
            .sheet(isPresented: $viewModel.showingAddLocation) {
                AddLocationView { newLocation in
                    viewModel.hideAddLocation()
                    viewModel.refreshLocations()
                }
            }
            .sheet(isPresented: $showingMapView) {
                LocationMapView(
                    locations: viewModel.locations,
                    selectedLocation: $viewModel.selectedLocation
                )
            }
            .alert("Delete Location", isPresented: $viewModel.showingDeleteConfirmation) {
                Button("Cancel", role: .cancel) {
                    viewModel.cancelDeleteLocation()
                }
                Button("Delete", role: .destructive) {
                    viewModel.confirmDeleteLocation()
                }
            } message: {
                if let location = viewModel.locationToDelete {
                    Text(viewModel.deletionWarningMessage(for: location))
                }
            }
            .alert("Error", isPresented: .constant(viewModel.errorMessage != nil)) {
                Button("OK") {
                    viewModel.clearError()
                }
            } message: {
                if let errorMessage = viewModel.errorMessage {
                    Text(errorMessage)
                }
            }
        }
        .environmentObject(viewModel)
    }

    // MARK: - Subviews

    @ViewBuilder
    private func LocationList() -> some View {
        List {
            ForEach(viewModel.groupedLocations, id: \.0) { section, locations in
                Section(header: Text(section)) {
                    ForEach(locations, id: \.id) { location in
                        LocationRowView(location: location)
                            .onTapGesture {
                                viewModel.selectLocation(location)
                            }
                            .swipeActions(edge: .trailing, allowsFullSwipe: false) {
                                Button("Delete", role: .destructive) {
                                    if viewModel.canDelete(location) {
                                        viewModel.prepareDeleteLocation(location)
                                    }
                                }
                                .disabled(!viewModel.canDelete(location))
                            }
                            .contextMenu {
                                Button(action: { viewModel.selectLocation(location) }) {
                                    Label("View Details", systemImage: "info.circle")
                                }

                                if viewModel.canDelete(location) {
                                    Button(action: { viewModel.prepareDeleteLocation(location) }) {
                                        Label("Delete", systemImage: "trash")
                                    }
                                }
                            }
                    }
                }
            }
        }
        .listStyle(PlainListStyle())
    }

    @ViewBuilder
    private func LoadingView() -> some View {
        VStack {
            Spacer()
            ProgressView("Loading locations...")
                .progressViewStyle(CircularProgressViewStyle(tint: .blue))
            Spacer()
        }
    }

    @ViewBuilder
    private func EmptyStateView(
        hasLocations: Bool,
        searchText: String,
        onAddLocation: @escaping () -> Void
    ) -> some View {
        VStack(spacing: 20) {
            Spacer()

            Image(systemName: hasLocations ? "magnifyingglass" : "location")
                .font(.system(size: 60))
                .foregroundColor(.gray)

            VStack(spacing: 8) {
                Text(hasLocations ? "No Results" : "No Locations")
                    .font(.title2)
                    .fontWeight(.semibold)

                Text(hasLocations
                     ? "No locations match '\(searchText)'"
                     : "Add your first farm location to get started")
                    .font(.body)
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
            }

            if !hasLocations {
                Button("Add Location") {
                    onAddLocation()
                }
                .buttonStyle(.borderedProminent)
            }

            Spacer()
        }
        .padding()
    }

    // MARK: - Private Methods

    private func refreshLocations() async {
        await withCheckedContinuation { continuation in
            viewModel.refreshLocations()
            // Simple delay to allow for network/database operations
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                continuation.resume()
            }
        }
    }

    // MARK: - Initialization

    public init() {}
}

// MARK: - Supporting Views

/// Search bar component for location filtering
private struct SearchBar: View {
    @Binding var text: String

    var body: some View {
        HStack {
            HStack {
                Image(systemName: "magnifyingglass")
                    .foregroundColor(.secondary)

                TextField("Search locations", text: $text)
                    .textFieldStyle(PlainTextFieldStyle())

                if !text.isEmpty {
                    Button(action: { text = "" }) {
                        Image(systemName: "xmark.circle.fill")
                            .foregroundColor(.secondary)
                    }
                }
            }
            .padding(8)
            .background(Color(.systemGray6))
            .cornerRadius(10)
        }
    }
}

/// Statistics header showing location summary
private struct LocationStatisticsHeader: View {
    let statistics: LocationStatistics

    var body: some View {
        HStack(spacing: 20) {
            StatisticView(
                title: "Total",
                value: "\(statistics.totalLocations)",
                systemImage: "location"
            )

            StatisticView(
                title: "With Items",
                value: "\(statistics.locationsWithItems)",
                systemImage: "archivebox"
            )

            StatisticView(
                title: "Items",
                value: "\(statistics.totalItems)",
                systemImage: "cube.box"
            )

            Spacer()
        }
        .padding()
        .background(Color(.systemGray6))
        .cornerRadius(10)
    }
}

/// Individual statistic display component
private struct StatisticView: View {
    let title: String
    let value: String
    let systemImage: String

    var body: some View {
        VStack(alignment: .center, spacing: 4) {
            Image(systemName: systemImage)
                .foregroundColor(.blue)
                .font(.caption)

            Text(value)
                .font(.title3)
                .fontWeight(.semibold)

            Text(title)
                .font(.caption2)
                .foregroundColor(.secondary)
        }
        .frame(minWidth: 60)
    }
}

/// Individual location row component
private struct LocationRowView: View {
    let location: Location

    var body: some View {
        HStack {
            VStack(alignment: .leading, spacing: 4) {
                // Location name
                Text(location.name)
                    .font(.headline)
                    .foregroundColor(.primary)

                // Description or address
                if let description = location.locationDescription, !description.isEmpty {
                    Text(description)
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                        .lineLimit(2)
                } else if let address = location.address, !address.isEmpty {
                    Text(address)
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                        .lineLimit(2)
                }

                // Coordinates
                HStack(spacing: 4) {
                    Image(systemName: "location.circle")
                        .font(.caption)
                        .foregroundColor(.blue)

                    Text(String(format: "%.4f, %.4f", location.latitude, location.longitude))
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }

            Spacer()

            VStack(alignment: .trailing, spacing: 8) {
                // Item count badge
                HStack(spacing: 4) {
                    Text("\(location.itemCount)")
                        .font(.title3)
                        .fontWeight(.semibold)
                        .foregroundColor(location.hasItems ? .primary : .secondary)

                    Image(systemName: "cube.box")
                        .font(.caption)
                        .foregroundColor(location.hasItems ? .blue : .secondary)
                }

                // Status indicator
                if location.hasItems {
                    Text("Active")
                        .font(.caption)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 2)
                        .background(Color.green.opacity(0.2))
                        .foregroundColor(.green)
                        .cornerRadius(6)
                } else {
                    Text("Empty")
                        .font(.caption)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 2)
                        .background(Color.gray.opacity(0.2))
                        .foregroundColor(.gray)
                        .cornerRadius(6)
                }
            }
        }
        .padding(.vertical, 4)
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(location.name), \(location.itemCount) items")
        .accessibilityHint("Double tap to view details")
    }
}

// MARK: - Preview

struct LocationListView_Previews: PreviewProvider {
    static var previews: some View {
        LocationListView()
    }
}