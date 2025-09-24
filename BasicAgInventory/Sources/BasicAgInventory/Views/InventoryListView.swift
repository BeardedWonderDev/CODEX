import SwiftUI

public struct InventoryListView: View {
    @StateObject private var viewModel = InventoryListViewModel()
    @State private var showingAddItem = false

    public init() {}

    public var body: some View {
        NavigationView {
            VStack(spacing: 0) {
                // Search bar
                SearchBar(text: $viewModel.searchText)
                    .padding(.horizontal)
                    .padding(.top, 8)

                // Filter summary
                if viewModel.hasFiltersApplied {
                    FilterSummaryView(viewModel: viewModel)
                        .padding(.horizontal)
                        .padding(.top, 8)
                }

                // Stats bar
                StatsBarView(viewModel: viewModel)
                    .padding(.horizontal)
                    .padding(.vertical, 8)

                // Item list
                if viewModel.isLoading {
                    ProgressView("Loading inventory...")
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                } else if viewModel.filteredItems.isEmpty {
                    EmptyStateView(
                        title: "No Items Found",
                        subtitle: viewModel.hasFiltersApplied ? "Try adjusting your filters" : "Add your first inventory item to get started",
                        systemImage: "archivebox",
                        primaryAction: EmptyStateView.Action(
                            title: "Add Item",
                            action: { showingAddItem = true }
                        ),
                        secondaryAction: viewModel.hasFiltersApplied ? EmptyStateView.Action(
                            title: "Clear Filters",
                            action: viewModel.clearFilters
                        ) : nil
                    )
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                } else {
                    List {
                        ForEach(viewModel.filteredItems, id: \.id) { item in
                            InventoryItemRow(
                                item: item,
                                onIncrement: { viewModel.incrementQuantity(for: item) },
                                onDecrement: { viewModel.decrementQuantity(for: item) },
                                onEdit: {
                                    // Navigate to edit view
                                }
                            )
                        }
                        .onDelete(perform: deleteItems)
                    }
                    .listStyle(PlainListStyle())
                    .refreshable {
                        viewModel.refreshData()
                    }
                }
            }
            .navigationTitle("Inventory")
            #if os(iOS)
            .navigationBarTitleDisplayMode(.large)
            #endif
            .toolbar {
                #if os(iOS)
                ToolbarItem(placement: .navigationBarLeading) {
                    Button(action: { viewModel.showingFilters = true }) {
                        Image(systemName: "line.3.horizontal.decrease.circle")
                            .foregroundColor(viewModel.hasFiltersApplied ? .blue : .primary)
                    }
                }

                ToolbarItem(placement: .navigationBarTrailing) {
                    Button(action: { showingAddItem = true }) {
                        Image(systemName: "plus")
                    }
                }
                #else
                ToolbarItem(placement: .primaryAction) {
                    HStack {
                        Button(action: { viewModel.showingFilters = true }) {
                            Image(systemName: "line.3.horizontal.decrease.circle")
                                .foregroundColor(viewModel.hasFiltersApplied ? .blue : .primary)
                        }
                        Button(action: { showingAddItem = true }) {
                            Image(systemName: "plus")
                        }
                    }
                }
                #endif
            }
            .alert("Error", isPresented: .constant(viewModel.errorMessage != nil)) {
                Button("OK") { viewModel.errorMessage = nil }
            } message: {
                Text(viewModel.errorMessage ?? "")
            }
            .sheet(isPresented: $showingAddItem) {
                AddEditItemView()
            }
            .sheet(isPresented: $viewModel.showingFilters) {
                NavigationView {
                    FilterView(viewModel: viewModel)
                        #if os(iOS)
                        .navigationBarTitleDisplayMode(.inline)
                        .toolbar {
                            ToolbarItem(placement: .navigationBarLeading) {
                                Button("Cancel") { viewModel.showingFilters = false }
                            }
                            ToolbarItem(placement: .navigationBarTrailing) {
                                Button("Apply") { viewModel.showingFilters = false }
                            }
                        }
                        #else
                        .toolbar {
                            ToolbarItem(placement: .cancellationAction) {
                                Button("Cancel") { viewModel.showingFilters = false }
                            }
                            ToolbarItem(placement: .primaryAction) {
                                Button("Apply") { viewModel.showingFilters = false }
                            }
                        }
                        #endif
                }
            }
        }
        .onAppear {
            viewModel.loadData()
        }
    }

    private func deleteItems(offsets: IndexSet) {
        for index in offsets {
            let item = viewModel.filteredItems[index]
            viewModel.deleteItem(item)
        }
    }
}

// MARK: - Search Bar

struct SearchBar: View {
    @Binding var text: String
    @State private var isEditing = false

    var body: some View {
        HStack {
            TextField("Search inventory...", text: $text)
                .padding(7)
                .padding(.horizontal, 25)
                .background(Color.gray.opacity(0.1))
                .cornerRadius(8)
                .overlay(
                    HStack {
                        Image(systemName: "magnifyingglass")
                            .foregroundColor(.gray)
                            .frame(minWidth: 0, maxWidth: .infinity, alignment: .leading)
                            .padding(.leading, 8)

                        if isEditing && !text.isEmpty {
                            Button(action: {
                                text = ""
                            }) {
                                Image(systemName: "multiply.circle.fill")
                                    .foregroundColor(.gray)
                                    .padding(.trailing, 8)
                            }
                        }
                    }
                )
                .onTapGesture {
                    isEditing = true
                }

            if isEditing {
                Button("Cancel") {
                    isEditing = false
                    text = ""
                    #if os(iOS)
                    UIApplication.shared.sendAction(#selector(UIResponder.resignFirstResponder), to: nil, from: nil, for: nil)
                    #endif
                }
                .foregroundColor(.blue)
                .transition(.move(edge: .trailing))
            }
        }
        .animation(.default, value: isEditing)
    }
}

// MARK: - Filter Summary View

struct FilterSummaryView: View {
    @ObservedObject var viewModel: InventoryListViewModel

    var body: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                if viewModel.selectedCategory != "All" {
                    FilterChip(title: viewModel.selectedCategory) {
                        viewModel.selectedCategory = "All"
                    }
                }

                if let location = viewModel.selectedLocation {
                    FilterChip(title: location.name) {
                        viewModel.selectedLocation = nil
                    }
                }

                if viewModel.showLowStockOnly {
                    FilterChip(title: "Low Stock") {
                        viewModel.showLowStockOnly = false
                    }
                }

                if viewModel.showExpiredOnly {
                    FilterChip(title: "Expired") {
                        viewModel.showExpiredOnly = false
                    }
                }

                Button("Clear All") {
                    viewModel.clearFilters()
                }
                .font(.caption)
                .foregroundColor(.blue)
                .padding(.leading, 8)
            }
            .padding(.horizontal)
        }
    }
}

struct FilterChip: View {
    let title: String
    let onRemove: () -> Void

    var body: some View {
        HStack(spacing: 4) {
            Text(title)
                .font(.caption)
                .foregroundColor(.blue)

            Button(action: onRemove) {
                Image(systemName: "xmark.circle.fill")
                    .foregroundColor(.blue)
                    .font(.caption)
            }
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 4)
        .background(Color.blue.opacity(0.1))
        .cornerRadius(16)
    }
}

// MARK: - Stats Bar View

struct StatsBarView: View {
    @ObservedObject var viewModel: InventoryListViewModel

    var body: some View {
        HStack {
            StatItem(
                title: "Total Items",
                value: "\(viewModel.totalItemsCount)",
                color: .primary
            )

            Spacer()

            if viewModel.lowStockCount > 0 {
                StatItem(
                    title: "Low Stock",
                    value: "\(viewModel.lowStockCount)",
                    color: .orange
                )

                Spacer()
            }

            if viewModel.expiredItemsCount > 0 {
                StatItem(
                    title: "Expired",
                    value: "\(viewModel.expiredItemsCount)",
                    color: .red
                )

                Spacer()
            }

            StatItem(
                title: "Showing",
                value: "\(viewModel.filteredItems.count)",
                color: .secondary
            )
        }
        .padding(.horizontal)
        .padding(.vertical, 8)
        .background(Color.gray.opacity(0.1))
        .cornerRadius(8)
    }
}

struct StatItem: View {
    let title: String
    let value: String
    let color: Color

    var body: some View {
        VStack(spacing: 2) {
            Text(value)
                .font(.headline)
                .foregroundColor(color)
            Text(title)
                .font(.caption)
                .foregroundColor(.secondary)
        }
    }
}

// MARK: - Empty State View

struct EmptyStateView: View {
    let title: String
    let subtitle: String
    let systemImage: String
    let primaryAction: Action?
    let secondaryAction: Action?

    struct Action {
        let title: String
        let action: () -> Void
    }

    var body: some View {
        VStack(spacing: 20) {
            Image(systemName: systemImage)
                .font(.system(size: 64))
                .foregroundColor(.secondary)

            VStack(spacing: 8) {
                Text(title)
                    .font(.title2)
                    .fontWeight(.semibold)

                Text(subtitle)
                    .font(.body)
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
            }

            VStack(spacing: 12) {
                if let primaryAction = primaryAction {
                    Button(action: primaryAction.action) {
                        Text(primaryAction.title)
                            .font(.headline)
                            .foregroundColor(.white)
                            .frame(maxWidth: .infinity)
                            .padding()
                            .background(Color.blue)
                            .cornerRadius(12)
                    }
                }

                if let secondaryAction = secondaryAction {
                    Button(action: secondaryAction.action) {
                        Text(secondaryAction.title)
                            .font(.subheadline)
                            .foregroundColor(.blue)
                    }
                }
            }
            .padding(.horizontal, 40)
        }
        .padding()
    }
}

#Preview {
    InventoryListView()
}