import SwiftUI

/// Full inventory listing for a specific farm location
struct LocationInventoryListView: View {

    let location: Location
    let items: [InventoryItem]

    @State private var searchText = ""
    @State private var selectedCategory: InventoryCategory = .all

    var body: some View {
        NavigationView {
            VStack(spacing: 0) {
                // Search and filter bar
                VStack(spacing: 12) {
                    // Search bar
                    HStack {
                        Image(systemName: "magnifyingglass")
                            .foregroundColor(.secondary)

                        TextField("Search items...", text: $searchText)
                            .textFieldStyle(PlainTextFieldStyle())
                    }
                    .padding()
                    .background(Color(.systemGray6))
                    .cornerRadius(8)

                    // Category filter
                    CategoryFilterView(selectedCategory: $selectedCategory)
                }
                .padding()

                // Inventory list
                if filteredItems.isEmpty {
                    emptyStateView
                } else {
                    List {
                        ForEach(filteredItems) { item in
                            NavigationLink {
                                ItemDetailView(item: item)
                            } label: {
                                LocationInventoryItemRow(
                                    item: item,
                                    location: location
                                )
                            }
                        }
                    }
                    .listStyle(PlainListStyle())
                }
            }
            .navigationTitle("\(location.name) Inventory")
            .navigationBarTitleDisplayMode(.inline)
        }
    }

    // MARK: - Computed Properties

    private var filteredItems: [InventoryItem] {
        items.filter { item in
            let matchesSearch = searchText.isEmpty ||
                item.name.localizedCaseInsensitiveContains(searchText) ||
                (item.itemDescription?.localizedCaseInsensitiveContains(searchText) ?? false)

            let matchesCategory = selectedCategory == .all ||
                item.inventoryCategory == selectedCategory

            return matchesSearch && matchesCategory
        }
        .sorted { $0.name < $1.name }
    }

    // MARK: - Empty State

    @ViewBuilder
    private var emptyStateView: some View {
        VStack(spacing: 20) {
            Spacer()

            Image(systemName: searchText.isEmpty ? "archivebox" : "magnifyingglass")
                .font(.system(size: 60))
                .foregroundColor(.gray)

            VStack(spacing: 8) {
                Text(searchText.isEmpty ? "No Items" : "No Results")
                    .font(.title2)
                    .fontWeight(.bold)
                    .foregroundColor(.primary)

                Text(searchText.isEmpty ?
                     "This location doesn't have any inventory items yet." :
                     "Try adjusting your search or filter criteria.")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
            }

            Spacer()
        }
        .padding()
    }
}

// MARK: - Location Inventory Item Row

struct LocationInventoryItemRow: View {
    let item: InventoryItem
    let location: Location

    var body: some View {
        HStack(spacing: 12) {
            // Item icon based on category
            Image(systemName: item.inventoryCategory.iconName)
                .font(.title2)
                .foregroundColor(item.inventoryCategory.color)
                .frame(width: 30, height: 30)

            // Item details
            VStack(alignment: .leading, spacing: 4) {
                Text(item.name)
                    .font(.headline)
                    .lineLimit(1)

                if let description = item.itemDescription, !description.isEmpty {
                    Text(description)
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                        .lineLimit(2)
                }

                HStack(spacing: 16) {
                    // Quantity
                    Label("\(item.quantity) \(item.unit)", systemImage: "number")
                        .font(.caption)
                        .foregroundColor(.secondary)

                    // Category
                    Label(item.inventoryCategory.displayName, systemImage: "tag")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }

            Spacer()

            // Stock status indicator
            stockStatusIndicator
        }
        .padding(.vertical, 4)
        .accessibilityElement(children: .combine)
        .accessibilityLabel(accessibilityLabel)
    }

    // MARK: - Stock Status

    @ViewBuilder
    private var stockStatusIndicator: some View {
        VStack(alignment: .trailing, spacing: 4) {
            Text("\(item.quantity)")
                .font(.headline)
                .fontWeight(.bold)
                .foregroundColor(stockStatusColor)

            Text(item.unit.uppercased())
                .font(.caption2)
                .foregroundColor(.secondary)

            if item.isLowStock {
                Image(systemName: "exclamationmark.triangle.fill")
                    .font(.caption)
                    .foregroundColor(.orange)
            }
        }
    }

    private var stockStatusColor: Color {
        if item.isLowStock {
            return .orange
        } else if item.quantity == 0 {
            return .red
        } else {
            return .primary
        }
    }

    // MARK: - Accessibility

    private var accessibilityLabel: String {
        var label = "\(item.name), \(item.quantity) \(item.unit)"

        if let description = item.itemDescription, !description.isEmpty {
            label += ", \(description)"
        }

        label += ", Category: \(item.inventoryCategory.displayName)"

        if item.isLowStock {
            label += ", Low stock"
        }

        return label
    }
}

// MARK: - Category Filter View

struct CategoryFilterView: View {
    @Binding var selectedCategory: InventoryCategory

    var body: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                ForEach(InventoryCategory.allCases, id: \.self) { category in
                    CategoryFilterChip(
                        category: category,
                        isSelected: selectedCategory == category
                    ) {
                        selectedCategory = category
                    }
                }
            }
            .padding(.horizontal)
        }
    }
}

struct CategoryFilterChip: View {
    let category: InventoryCategory
    let isSelected: Bool
    let onTap: () -> Void

    var body: some View {
        Button(action: onTap) {
            HStack(spacing: 6) {
                Image(systemName: category.iconName)
                    .font(.caption)

                Text(category.displayName)
                    .font(.caption)
                    .fontWeight(.medium)
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 6)
            .background(
                Capsule().fill(
                    isSelected ? Color.accentColor : Color(.systemGray5)
                )
            )
            .foregroundColor(
                isSelected ? .white : .primary
            )
        }
        .buttonStyle(PlainButtonStyle())
    }
}

// MARK: - Item Detail View Placeholder

struct ItemDetailView: View {
    let item: InventoryItem

    var body: some View {
        VStack {
            Text("Item Detail")
                .font(.title)
                .padding()

            Text(item.name)
                .font(.headline)

            Text("Quantity: \(item.quantity) \(item.unit)")

            if let description = item.itemDescription {
                Text(description)
                    .padding()
            }

            Spacer()
        }
        .navigationTitle(item.name)
        .navigationBarTitleDisplayMode(.large)
    }
}

// MARK: - Extensions

extension InventoryCategory {
    var iconName: String {
        switch self {
        case .all:
            return "list.bullet"
        case .seeds:
            return "leaf.fill"
        case .fertilizers:
            return "drop.fill"
        case .pesticides:
            return "shield.fill"
        case .equipment:
            return "wrench.fill"
        case .tools:
            return "hammer.fill"
        case .livestock:
            return "pawprint.fill"
        case .feed:
            return "basket.fill"
        case .fuel:
            return "fuelpump.fill"
        case .supplies:
            return "shippingbox.fill"
        }
    }

    var color: Color {
        switch self {
        case .all:
            return .gray
        case .seeds:
            return .green
        case .fertilizers:
            return .brown
        case .pesticides:
            return .red
        case .equipment:
            return .blue
        case .tools:
            return .orange
        case .livestock:
            return .purple
        case .feed:
            return .yellow
        case .fuel:
            return .black
        case .supplies:
            return .cyan
        }
    }
}

// MARK: - Preview

#Preview {
    let context = PersistenceController.preview.container.viewContext

    // Create sample location
    let location = Location(context: context)
    location.id = UUID()
    location.name = "Main Barn"
    location.locationDescription = "Primary storage facility"

    // Create sample items
    let items = (0..<10).map { index in
        let item = InventoryItem(context: context)
        item.id = UUID()
        item.name = "Sample Item \(index + 1)"
        item.itemDescription = "Description for item \(index + 1)"
        item.quantity = Int32.random(in: 1...100)
        item.unit = "kg"
        item.category = InventoryCategory.allCases.randomElement()?.rawValue ?? "supplies"
        item.location = location
        return item
    }

    return NavigationView {
        LocationInventoryListView(location: location, items: items)
    }
}