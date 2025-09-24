import SwiftUI
import PhotosUI

#if os(iOS)
import UIKit
#elseif os(macOS)
import AppKit
#endif

public struct AddEditItemView: View {
    @StateObject private var viewModel: AddEditItemViewModel
    @Environment(\.dismiss) private var dismiss

    public init(item: InventoryItem? = nil) {
        self._viewModel = StateObject(wrappedValue: AddEditItemViewModel(item: item))
    }

    public var body: some View {
        NavigationView {
            ScrollView {
                LazyVStack(alignment: .leading, spacing: 20) {
                    // Image section
                    ImageSelectionSection(viewModel: viewModel)

                    // Basic information
                    BasicInfoSection(viewModel: viewModel)

                    // Quantity and pricing
                    QuantityPricingSection(viewModel: viewModel)

                    // Dates
                    DatesSection(viewModel: viewModel)

                    // Location
                    LocationSection(viewModel: viewModel)

                    // Notes
                    NotesSection(viewModel: viewModel)

                    // Validation errors
                    if !viewModel.validationErrors.isEmpty {
                        ValidationErrorsSection(errors: viewModel.validationErrors)
                    }
                }
                .padding()
            }
            .navigationTitle(viewModel.formattedTitle)
            #if os(iOS)
            .navigationBarTitleDisplayMode(.inline)
            #endif
            .toolbar {
                #if os(iOS)
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") {
                        dismiss()
                    }
                }

                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Save") {
                        Task {
                            await viewModel.saveItem()
                            if viewModel.errorMessage == nil {
                                dismiss()
                            }
                        }
                    }
                    .disabled(!viewModel.isFormValid || viewModel.isLoading)
                }
                #else
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        dismiss()
                    }
                }

                ToolbarItem(placement: .primaryAction) {
                    Button("Save") {
                        Task {
                            await viewModel.saveItem()
                            if viewModel.errorMessage == nil {
                                dismiss()
                            }
                        }
                    }
                    .disabled(!viewModel.isFormValid || viewModel.isLoading)
                }
                #endif
            }
            .alert("Error", isPresented: .constant(viewModel.errorMessage != nil)) {
                Button("OK") { viewModel.errorMessage = nil }
            } message: {
                Text(viewModel.errorMessage ?? "")
            }
            .photosPicker(
                isPresented: $viewModel.showingImagePicker,
                selection: $viewModel.selectedPhotoItem,
                matching: .images,
                photoLibrary: .shared()
            )
        }
        .overlay {
            if viewModel.isLoading {
                Color.black.opacity(0.3)
                    .ignoresSafeArea()
                    .overlay {
                        ProgressView("Saving...")
                            .padding()
                            .background(Color(red: 1.0, green: 1.0, blue: 1.0))
                            .cornerRadius(8)
                    }
            }
        }
    }
}

// MARK: - Image Selection Section

struct ImageSelectionSection: View {
    @ObservedObject var viewModel: AddEditItemViewModel

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Photo")
                .font(.headline)

            HStack {
                // Image preview
                if let image = viewModel.itemImage {
                        #if os(iOS)
                        Image(uiImage: image)
                            .resizable()
                            .aspectRatio(contentMode: .fill)
                            .frame(width: 100, height: 100)
                            .clipShape(RoundedRectangle(cornerRadius: 8))
                        #elseif os(macOS)
                        Image(nsImage: image)
                            .resizable()
                            .aspectRatio(contentMode: .fill)
                            .frame(width: 100, height: 100)
                            .clipShape(RoundedRectangle(cornerRadius: 8))
                        #endif
                } else {
                    RoundedRectangle(cornerRadius: 8)
                        .fill(Color.gray.opacity(0.2))
                        .frame(width: 100, height: 100)
                        .overlay(
                            Image(systemName: "photo")
                                .foregroundColor(.secondary)
                                .font(.largeTitle)
                        )
                }

                VStack(alignment: .leading, spacing: 8) {
                    Button("Select Photo") {
                        viewModel.showingImagePicker = true
                    }
                    .buttonStyle(.bordered)

                    if viewModel.itemImage != nil {
                        Button("Remove Photo") {
                            viewModel.itemImage = nil
                        }
                        .buttonStyle(.borderedProminent)
                        .controlSize(.small)
                    }
                }

                Spacer()
            }
        }
    }
}

// MARK: - Basic Info Section

struct BasicInfoSection: View {
    @ObservedObject var viewModel: AddEditItemViewModel
    @State private var showingNewCategoryAlert = false
    @State private var newCategoryName = ""

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Basic Information")
                .font(.headline)

            FormField(title: "Name *", text: $viewModel.name)

            FormField(title: "Description", text: $viewModel.itemDescription)

            VStack(alignment: .leading, spacing: 8) {
                Text("Category *")
                    .font(.subheadline)
                    .fontWeight(.medium)

                HStack {
                    Picker("Category", selection: $viewModel.category) {
                        ForEach(viewModel.categories, id: \.self) { category in
                            Text(category).tag(category)
                        }
                    }
                    .pickerStyle(MenuPickerStyle())

                    Button("Add New") {
                        showingNewCategoryAlert = true
                    }
                    .font(.caption)
                    .buttonStyle(.bordered)
                    .controlSize(.small)
                }
            }
        }
        .alert("New Category", isPresented: $showingNewCategoryAlert) {
            TextField("Category name", text: $newCategoryName)
            Button("Add") {
                viewModel.addCategory(newCategoryName)
                newCategoryName = ""
            }
            Button("Cancel", role: .cancel) {
                newCategoryName = ""
            }
        } message: {
            Text("Enter a name for the new category")
        }
    }
}

// MARK: - Quantity and Pricing Section

struct QuantityPricingSection: View {
    @ObservedObject var viewModel: AddEditItemViewModel

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Quantity & Pricing")
                .font(.headline)

            HStack(spacing: 16) {
                #if os(iOS)
                FormField(title: "Quantity *", text: $viewModel.quantity, keyboardType: .numberPad)
                #else
                FormField(title: "Quantity *", text: $viewModel.quantity)
                #endif

                VStack(alignment: .leading, spacing: 8) {
                    Text("Unit")
                        .font(.subheadline)
                        .fontWeight(.medium)

                    Picker("Unit", selection: $viewModel.unit) {
                        ForEach(viewModel.commonUnits, id: \.self) { unit in
                            Text(unit).tag(unit)
                        }
                    }
                    .pickerStyle(MenuPickerStyle())
                }
            }

            HStack(spacing: 16) {
                #if os(iOS)
                FormField(title: "Minimum Stock", text: $viewModel.minimumStock, keyboardType: .numberPad)
                #else
                FormField(title: "Minimum Stock", text: $viewModel.minimumStock)
                #endif

                #if os(iOS)
                FormField(title: "Purchase Price", text: $viewModel.purchasePrice, keyboardType: .decimalPad)
                #else
                FormField(title: "Purchase Price", text: $viewModel.purchasePrice)
                #endif
            }
        }
    }
}

// MARK: - Dates Section

struct DatesSection: View {
    @ObservedObject var viewModel: AddEditItemViewModel

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Dates")
                .font(.headline)

            VStack(alignment: .leading, spacing: 8) {
                Toggle("Has Purchase Date", isOn: $viewModel.hasPurchaseDate)

                if viewModel.hasPurchaseDate {
                    DatePicker("Purchase Date", selection: $viewModel.purchaseDate, displayedComponents: .date)
                        .datePickerStyle(CompactDatePickerStyle())
                }
            }

            VStack(alignment: .leading, spacing: 8) {
                Toggle("Has Expiration Date", isOn: $viewModel.hasExpirationDate)

                if viewModel.hasExpirationDate {
                    DatePicker("Expiration Date", selection: $viewModel.expirationDate, displayedComponents: .date)
                        .datePickerStyle(CompactDatePickerStyle())
                }
            }
        }
    }
}

// MARK: - Location Section

struct LocationSection: View {
    @ObservedObject var viewModel: AddEditItemViewModel

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Location")
                .font(.headline)

            Picker("Location", selection: $viewModel.selectedLocation) {
                Text("No Location").tag(nil as Location?)
                ForEach(viewModel.locations, id: \.id) { location in
                    Text(location.name).tag(location as Location?)
                }
            }
            .pickerStyle(MenuPickerStyle())
        }
    }
}

// MARK: - Notes Section

struct NotesSection: View {
    @ObservedObject var viewModel: AddEditItemViewModel

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Notes")
                .font(.headline)

            TextField("Additional notes...", text: $viewModel.notes, axis: .vertical)
                .lineLimit(3...6)
                .textFieldStyle(RoundedBorderTextFieldStyle())
        }
    }
}

// MARK: - Validation Errors Section

struct ValidationErrorsSection: View {
    let errors: [ValidationError]

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Please fix the following errors:")
                .font(.headline)
                .foregroundColor(.red)

            ForEach(errors) { error in
                Label(error.message, systemImage: "exclamationmark.triangle")
                    .font(.subheadline)
                    .foregroundColor(.red)
            }
        }
        .padding()
        .background(Color.red.opacity(0.1))
        .cornerRadius(8)
    }
}

// MARK: - Form Field

struct FormField: View {
    let title: String
    @Binding var text: String
    #if os(iOS)
    var keyboardType: UIKeyboardType = .default
    #endif

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(title)
                .font(.subheadline)
                .fontWeight(.medium)

            TextField(title, text: $text)
                .textFieldStyle(RoundedBorderTextFieldStyle())
                #if os(iOS)
                .keyboardType(keyboardType)
                #endif
        }
    }
}

// MARK: - Preview

#Preview {
    AddEditItemView()
}