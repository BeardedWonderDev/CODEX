import SwiftUI

/// Multi-step transfer workflow interface for moving items between farm locations
struct ItemTransferView: View {

    @StateObject private var viewModel: ItemTransferViewModel
    @Environment(\.dismiss) private var dismiss

    init(transferService: TransferService,
         locationRepository: LocationRepository,
         inventoryRepository: InventoryRepository) {
        self._viewModel = StateObject(wrappedValue:
            ItemTransferViewModel(
                transferService: transferService,
                locationRepository: locationRepository,
                inventoryRepository: inventoryRepository
            )
        )
    }

    var body: some View {
        NavigationView {
            VStack(spacing: 0) {
                // Progress indicator
                TransferStepProgressView(
                    currentStep: viewModel.currentStep,
                    progress: viewModel.stepProgress
                )

                // Content area
                ScrollView {
                    VStack(alignment: .leading, spacing: 24) {
                        // Step header
                        VStack(alignment: .leading, spacing: 8) {
                            Text(viewModel.stepTitle)
                                .font(.title2)
                                .fontWeight(.bold)

                            Text(viewModel.stepDescription)
                                .font(.subheadline)
                                .foregroundColor(.secondary)
                        }

                        // Step content
                        switch viewModel.currentStep {
                        case .selectItem:
                            itemSelectionStep
                        case .chooseDestination:
                            destinationSelectionStep
                        case .confirmTransfer:
                            confirmationStep
                        case .completed:
                            completionStep
                        }
                    }
                    .padding()
                }

                // Navigation buttons
                transferNavigationButtons
            }
            .navigationTitle("Transfer Item")
            .navigationBarTitleDisplayMode(.large)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") {
                        dismiss()
                    }
                }

                if viewModel.currentStep == .completed {
                    ToolbarItem(placement: .navigationBarTrailing) {
                        Button("New Transfer") {
                            viewModel.startNewTransfer()
                        }
                    }
                }
            }
        }
        .task {
            await viewModel.loadInitialData()
        }
        .alert("Transfer Successful", isPresented: $viewModel.showingSuccessAlert) {
            Button("OK") {
                // Alert will dismiss automatically
            }
        } message: {
            Text("Item transfer completed successfully.")
        }
        .alert("Transfer Error", isPresented: .constant(viewModel.errorMessage != nil)) {
            Button("OK") {
                viewModel.errorMessage = nil
            }
        } message: {
            Text(viewModel.errorMessage ?? "")
        }
    }

    // MARK: - Step 1: Item Selection

    @ViewBuilder
    private var itemSelectionStep: some View {
        VStack(alignment: .leading, spacing: 16) {
            // Source location picker
            VStack(alignment: .leading, spacing: 8) {
                Text("Transfer From")
                    .font(.headline)

                Picker("Source Location", selection: $viewModel.sourceLocation) {
                    Text("New Stock Assignment")
                        .tag(nil as Location?)

                    ForEach(viewModel.availableLocations) { location in
                        Text(location.name)
                            .tag(location as Location?)
                    }
                }
                .pickerStyle(.menu)
                .accessibilityLabel("Source location")
            }

            // Available items
            VStack(alignment: .leading, spacing: 8) {
                Text("Select Item")
                    .font(.headline)

                if viewModel.isLoading {
                    ProgressView("Loading items...")
                        .frame(maxWidth: .infinity)
                        .padding()
                } else if viewModel.availableItems.isEmpty {
                    Text("No items available")
                        .foregroundColor(.secondary)
                        .frame(maxWidth: .infinity)
                        .padding()
                } else {
                    LazyVStack(spacing: 8) {
                        ForEach(viewModel.availableItems) { item in
                            ItemSelectionRow(
                                item: item,
                                isSelected: viewModel.selectedItem?.id == item.id
                            ) {
                                viewModel.selectedItem = item
                            }
                        }
                    }
                }
            }
        }
    }

    // MARK: - Step 2: Destination Selection

    @ViewBuilder
    private var destinationSelectionStep: some View {
        VStack(alignment: .leading, spacing: 16) {
            // Selected item summary
            if let item = viewModel.selectedItem {
                SelectedItemSummary(item: item)
            }

            // Destination location picker
            VStack(alignment: .leading, spacing: 8) {
                Text("Destination Location")
                    .font(.headline)

                LazyVStack(spacing: 8) {
                    ForEach(availableDestinations) { location in
                        LocationSelectionRow(
                            location: location,
                            isSelected: viewModel.destinationLocation?.id == location.id,
                            isDisabled: location.id == viewModel.sourceLocation?.id
                        ) {
                            viewModel.destinationLocation = location
                        }
                    }
                }

                if availableDestinations.isEmpty {
                    Text("No available destinations")
                        .foregroundColor(.secondary)
                        .frame(maxWidth: .infinity)
                        .padding()
                }
            }
        }
    }

    private var availableDestinations: [Location] {
        viewModel.availableLocations.filter { location in
            location.id != viewModel.sourceLocation?.id
        }
    }

    // MARK: - Step 3: Transfer Confirmation

    @ViewBuilder
    private var confirmationStep: some View {
        VStack(alignment: .leading, spacing: 20) {
            // Transfer summary
            TransferSummaryCard(
                item: viewModel.selectedItem,
                sourceLocation: viewModel.sourceLocation,
                destinationLocation: viewModel.destinationLocation,
                quantity: viewModel.transferQuantityInt
            )

            // Quantity input
            VStack(alignment: .leading, spacing: 8) {
                Text("Quantity to Transfer")
                    .font(.headline)

                HStack {
                    TextField("Quantity", text: $viewModel.transferQuantity)
                        .textFieldStyle(.roundedBorder)
                        .keyboardType(.numberPad)
                        .accessibilityLabel("Transfer quantity")

                    if let unit = viewModel.selectedItem?.unit {
                        Text(unit)
                            .foregroundColor(.secondary)
                    }
                }

                if let validationMessage = viewModel.transferValidationMessage {
                    Text(validationMessage)
                        .font(.caption)
                        .foregroundColor(.red)
                }
            }

            // Notes input
            VStack(alignment: .leading, spacing: 8) {
                Text("Notes (Optional)")
                    .font(.headline)

                TextField("Add notes about this transfer...", text: $viewModel.notes, axis: .vertical)
                    .textFieldStyle(.roundedBorder)
                    .lineLimit(3...6)
                    .accessibilityLabel("Transfer notes")
            }
        }
    }

    // MARK: - Step 4: Completion

    @ViewBuilder
    private var completionStep: some View {
        VStack(spacing: 24) {
            // Success icon
            Image(systemName: "checkmark.circle.fill")
                .font(.system(size: 60))
                .foregroundColor(.green)

            // Success message
            Text("Transfer Complete!")
                .font(.title2)
                .fontWeight(.bold)

            // Transfer details
            if let transfer = viewModel.completedTransfer {
                TransferCompletionCard(transfer: transfer)
            }

            // Action buttons
            VStack(spacing: 12) {
                Button("Start New Transfer") {
                    viewModel.startNewTransfer()
                }
                .buttonStyle(.borderedProminent)

                Button("View Transfer History") {
                    Task {
                        await viewModel.loadTransferHistory()
                    }
                }
                .buttonStyle(.bordered)
            }
        }
        .multilineTextAlignment(.center)
    }

    // MARK: - Navigation Buttons

    @ViewBuilder
    private var transferNavigationButtons: some View {
        HStack {
            if viewModel.currentStep != .selectItem && viewModel.currentStep != .completed {
                Button("Back") {
                    viewModel.goBackToPreviousStep()
                }
                .buttonStyle(.bordered)
            }

            Spacer()

            if viewModel.currentStep != .completed {
                Button(buttonTitle) {
                    viewModel.proceedToNextStep()
                }
                .buttonStyle(.borderedProminent)
                .disabled(!viewModel.canProceedToNextStep || viewModel.isTransferring)
                .overlay {
                    if viewModel.isTransferring {
                        ProgressView()
                            .scaleEffect(0.8)
                            .progressViewStyle(CircularProgressViewStyle(tint: .white))
                    }
                }
            }
        }
        .padding()
        .background(Color(.systemBackground))
    }

    private var buttonTitle: String {
        switch viewModel.currentStep {
        case .selectItem:
            return "Next"
        case .chooseDestination:
            return "Next"
        case .confirmTransfer:
            return viewModel.isTransferring ? "Transferring..." : "Transfer Item"
        case .completed:
            return "Done"
        }
    }
}

// MARK: - Supporting Views

struct TransferStepProgressView: View {
    let currentStep: TransferStep
    let progress: Double

    var body: some View {
        VStack(spacing: 16) {
            // Progress bar
            ProgressView(value: progress)
                .progressViewStyle(LinearProgressViewStyle(tint: .accentColor))

            // Step indicators
            HStack {
                ForEach(TransferStep.allCases, id: \.rawValue) { step in
                    HStack {
                        Circle()
                            .fill(step.rawValue <= currentStep.rawValue ? Color.accentColor : Color.gray.opacity(0.3))
                            .frame(width: 12, height: 12)

                        Text(step.title)
                            .font(.caption)
                            .foregroundColor(step.rawValue <= currentStep.rawValue ? .primary : .secondary)

                        if step != TransferStep.allCases.last {
                            Spacer()
                        }
                    }
                }
            }
        }
        .padding()
        .background(Color(uiColor: .systemGroupedBackground))
    }
}

struct ItemSelectionRow: View {
    let item: InventoryItem
    let isSelected: Bool
    let onTap: () -> Void

    var body: some View {
        Button {
            onTap()
        } label: {
            HStack {
                VStack(alignment: .leading) {
                    Text(item.name)
                        .font(.headline)
                        .foregroundColor(.primary)

                    Text("\(item.quantity) \(item.unit)")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                }

                Spacer()

                if isSelected {
                    Image(systemName: "checkmark.circle.fill")
                        .foregroundColor(.accentColor)
                }
            }
            .padding()
            .background(
                RoundedRectangle(cornerRadius: 8)
                    .fill(isSelected ? Color.accentColor.opacity(0.1) : Color(.systemGray6))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 8)
                    .stroke(isSelected ? Color.accentColor : Color.clear, lineWidth: 2)
            )
        }
        .buttonStyle(PlainButtonStyle())
    }
}

struct LocationSelectionRow: View {
    let location: Location
    let isSelected: Bool
    let isDisabled: Bool
    let onTap: () -> Void

    var body: some View {
        Button {
            onTap()
        } label: {
            HStack {
                VStack(alignment: .leading) {
                    Text(location.name)
                        .font(.headline)
                        .foregroundColor(isDisabled ? .secondary : .primary)

                    Text(location.locationDescription)
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                        .lineLimit(2)
                }

                Spacer()

                if isSelected && !isDisabled {
                    Image(systemName: "checkmark.circle.fill")
                        .foregroundColor(.accentColor)
                }
            }
            .padding()
            .background(
                RoundedRectangle(cornerRadius: 8)
                    .fill(
                        isDisabled ? Color(.systemGray5) :
                        isSelected ? Color.accentColor.opacity(0.1) : Color(.systemGray6)
                    )
            )
            .overlay(
                RoundedRectangle(cornerRadius: 8)
                    .stroke(
                        isDisabled ? Color.clear :
                        isSelected ? Color.accentColor : Color.clear,
                        lineWidth: 2
                    )
            )
        }
        .buttonStyle(PlainButtonStyle())
        .disabled(isDisabled)
    }
}

struct SelectedItemSummary: View {
    let item: InventoryItem

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Selected Item")
                .font(.headline)

            HStack {
                VStack(alignment: .leading) {
                    Text(item.name)
                        .font(.subheadline)
                        .fontWeight(.medium)

                    Text("Available: \(item.quantity) \(item.unit)")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }

                Spacer()

                Image(systemName: "checkmark.circle.fill")
                    .foregroundColor(.green)
            }
            .padding()
            .background(Color.green.opacity(0.1))
            .cornerRadius(8)
        }
    }
}

struct TransferSummaryCard: View {
    let item: InventoryItem?
    let sourceLocation: Location?
    let destinationLocation: Location?
    let quantity: Int32

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Transfer Summary")
                .font(.headline)

            VStack(spacing: 8) {
                HStack {
                    Text("Item:")
                    Spacer()
                    Text(item?.name ?? "Unknown")
                        .fontWeight(.medium)
                }

                HStack {
                    Text("From:")
                    Spacer()
                    Text(sourceLocation?.name ?? "New Stock")
                        .fontWeight(.medium)
                }

                HStack {
                    Text("To:")
                    Spacer()
                    Text(destinationLocation?.name ?? "Unknown")
                        .fontWeight(.medium)
                }

                HStack {
                    Text("Quantity:")
                    Spacer()
                    Text("\(quantity) \(item?.unit ?? "")")
                        .fontWeight(.medium)
                }
            }
        }
        .padding()
        .background(Color(uiColor: .systemGroupedBackground))
        .cornerRadius(8)
    }
}

struct TransferCompletionCard: View {
    let transfer: Transfer

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(transfer.transferDescription)
                .font(.headline)
                .multilineTextAlignment(.center)

            Text("Completed at \(transfer.formattedTransferDate)")
                .font(.subheadline)
                .foregroundColor(.secondary)

            if let notes = transfer.notes, !notes.isEmpty {
                Text("Notes: \(notes)")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
        }
        .padding()
        .background(Color(uiColor: .systemGroupedBackground))
        .cornerRadius(8)
    }
}

// MARK: - Preview

#Preview {
    ItemTransferView(
        transferService: TransferService(
            context: PersistenceController.preview.container.viewContext,
            inventoryRepository: InventoryRepository(persistenceController: PersistenceController.preview),
            locationRepository: LocationRepository(persistenceController: PersistenceController.preview)
        ),
        locationRepository: LocationRepository(persistenceController: PersistenceController.preview),
        inventoryRepository: InventoryRepository(persistenceController: PersistenceController.preview)
    )
}