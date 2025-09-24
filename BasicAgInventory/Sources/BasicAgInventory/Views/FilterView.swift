import SwiftUI

public struct FilterView: View {
    @ObservedObject var viewModel: InventoryListViewModel

    public init(viewModel: InventoryListViewModel) {
        self.viewModel = viewModel
    }

    public var body: some View {
        NavigationView {
            Form {
                // Category filter
                Section("Category") {
                    Picker("Category", selection: $viewModel.selectedCategory) {
                        ForEach(viewModel.categories, id: \.self) { category in
                            Text(category).tag(category)
                        }
                    }
                    .pickerStyle(MenuPickerStyle())
                }

                // Location filter
                Section("Location") {
                    Picker("Location", selection: $viewModel.selectedLocation) {
                        Text("All Locations").tag(nil as Location?)
                        ForEach(viewModel.locations, id: \.id) { location in
                            Text(location.name).tag(location as Location?)
                        }
                    }
                    .pickerStyle(MenuPickerStyle())
                }

                // Status filters
                Section("Status") {
                    Toggle("Show Low Stock Only", isOn: $viewModel.showLowStockOnly)
                    Toggle("Show Expired Items Only", isOn: $viewModel.showExpiredOnly)
                }

                // Reset section
                Section {
                    Button("Clear All Filters") {
                        viewModel.clearFilters()
                    }
                    .foregroundColor(.red)
                } footer: {
                    if viewModel.hasFiltersApplied {
                        Text("Active filters are applied")
                            .foregroundColor(.blue)
                    }
                }
            }
            .navigationTitle("Filters")
            #if os(iOS)
            .navigationBarTitleDisplayMode(.inline)
            #endif
        }
    }
}

#Preview {
    FilterView(viewModel: InventoryListViewModel())
}