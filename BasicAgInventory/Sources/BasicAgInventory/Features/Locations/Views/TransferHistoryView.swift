import SwiftUI

/// Transfer history view showing all transfers for a location or item
struct TransferHistoryView: View {

    let transfers: [Transfer]
    let location: Location?
    let item: InventoryItem?

    @State private var selectedStatus: Transfer.Status?
    @State private var searchText = ""

    init(transfers: [Transfer], location: Location? = nil, item: InventoryItem? = nil) {
        self.transfers = transfers
        self.location = location
        self.item = item
    }

    var body: some View {
        NavigationView {
            VStack(spacing: 0) {
                // Search and filter bar
                VStack(spacing: 12) {
                    // Search bar
                    HStack {
                        Image(systemName: "magnifyingglass")
                            .foregroundColor(.secondary)

                        TextField("Search transfers...", text: $searchText)
                            .textFieldStyle(PlainTextFieldStyle())

                        if !searchText.isEmpty {
                            Button("Clear") {
                                searchText = ""
                            }
                            .font(.caption)
                        }
                    }
                    .padding()
                    .background(Color(.systemGray6))
                    .cornerRadius(8)

                    // Status filter
                    StatusFilterView(selectedStatus: $selectedStatus)
                }
                .padding()

                // Transfer list
                if filteredTransfers.isEmpty {
                    emptyStateView
                } else {
                    List {
                        ForEach(groupedTransfers.keys.sorted(by: >), id: \.self) { date in
                            Section {
                                ForEach(groupedTransfers[date] ?? []) { transfer in
                                    TransferHistoryRow(transfer: transfer, location: location)
                                }
                            } header: {
                                Text(formatSectionDate(date))
                                    .font(.headline)
                                    .foregroundColor(.primary)
                            }
                        }
                    }
                    .listStyle(PlainListStyle())
                }
            }
            .navigationTitle(navigationTitle)
            .navigationBarTitleDisplayMode(.inline)
        }
    }

    // MARK: - Computed Properties

    private var navigationTitle: String {
        if let location = location {
            return "\(location.name) Transfers"
        } else if let item = item {
            return "\(item.name) History"
        } else {
            return "Transfer History"
        }
    }

    private var filteredTransfers: [Transfer] {
        transfers.filter { transfer in
            let matchesSearch = searchText.isEmpty ||
                transfer.transferDescription.localizedCaseInsensitiveContains(searchText) ||
                (transfer.notes?.localizedCaseInsensitiveContains(searchText) ?? false)

            let matchesStatus = selectedStatus == nil ||
                transfer.transferStatus == selectedStatus

            return matchesSearch && matchesStatus
        }
        .sorted { $0.transferDate > $1.transferDate }
    }

    private var groupedTransfers: [Date: [Transfer]] {
        Dictionary(grouping: filteredTransfers) { transfer in
            Calendar.current.startOfDay(for: transfer.transferDate)
        }
    }

    private func formatSectionDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .none

        let calendar = Calendar.current
        if calendar.isDateInToday(date) {
            return "Today"
        } else if calendar.isDateInYesterday(date) {
            return "Yesterday"
        } else if calendar.isDate(date, equalTo: Date(), toGranularity: .weekOfYear) {
            formatter.dateFormat = "EEEE"
            return formatter.string(from: date)
        } else {
            return formatter.string(from: date)
        }
    }

    // MARK: - Empty State

    @ViewBuilder
    private var emptyStateView: some View {
        VStack(spacing: 20) {
            Spacer()

            Image(systemName: searchText.isEmpty ? "arrow.right.arrow.left" : "magnifyingglass")
                .font(.system(size: 60))
                .foregroundColor(.gray)

            VStack(spacing: 8) {
                Text(searchText.isEmpty ? "No Transfer History" : "No Results")
                    .font(.title2)
                    .fontWeight(.bold)
                    .foregroundColor(.primary)

                Text(searchText.isEmpty ?
                     "Transfer history will appear here when items are moved." :
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

// MARK: - Transfer History Row

struct TransferHistoryRow: View {
    let transfer: Transfer
    let location: Location?

    var body: some View {
        HStack(spacing: 12) {
            // Transfer direction indicator
            transferDirectionIcon
                .font(.title2)
                .foregroundColor(transferDirectionColor)
                .frame(width: 30, height: 30)

            // Transfer details
            VStack(alignment: .leading, spacing: 4) {
                Text(transfer.transferDescription)
                    .font(.headline)
                    .lineLimit(2)

                Text(transfer.formattedTransferDate)
                    .font(.subheadline)
                    .foregroundColor(.secondary)

                if let notes = transfer.notes, !notes.isEmpty {
                    Text(notes)
                        .font(.caption)
                        .foregroundColor(.secondary)
                        .lineLimit(2)
                        .padding(.top, 2)
                }
            }

            Spacer()

            // Status and quantity
            VStack(alignment: .trailing, spacing: 4) {
                TransferStatusBadge(status: transfer.transferStatus)

                Text("\(transfer.quantity)")
                    .font(.headline)
                    .fontWeight(.bold)

                if let item = transfer.inventoryItem {
                    Text(item.unit.uppercased())
                        .font(.caption2)
                        .foregroundColor(.secondary)
                }
            }
        }
        .padding(.vertical, 4)
        .accessibilityElement(children: .combine)
        .accessibilityLabel(accessibilityLabel)
    }

    // MARK: - Transfer Direction

    @ViewBuilder
    private var transferDirectionIcon: some View {
        if let location = location {
            if transfer.toLocation == location {
                Image(systemName: "arrow.down.circle.fill")
            } else if transfer.fromLocation == location {
                Image(systemName: "arrow.up.circle.fill")
            } else {
                Image(systemName: "arrow.right.arrow.left.circle.fill")
            }
        } else {
            Image(systemName: "arrow.right.arrow.left.circle.fill")
        }
    }

    private var transferDirectionColor: Color {
        if let location = location {
            if transfer.toLocation == location {
                return .green // Incoming
            } else if transfer.fromLocation == location {
                return .orange // Outgoing
            } else {
                return .blue // Internal
            }
        } else {
            return .blue
        }
    }

    // MARK: - Accessibility

    private var accessibilityLabel: String {
        var label = transfer.transferDescription
        label += ", \(transfer.transferStatus.displayName)"
        label += ", \(transfer.formattedTransferDate)"

        if let notes = transfer.notes, !notes.isEmpty {
            label += ", Notes: \(notes)"
        }

        return label
    }
}

// MARK: - Status Filter View

struct StatusFilterView: View {
    @Binding var selectedStatus: Transfer.Status?

    var body: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                StatusFilterChip(
                    title: "All",
                    isSelected: selectedStatus == nil
                ) {
                    selectedStatus = nil
                }

                ForEach(Transfer.Status.allCases, id: \.self) { status in
                    StatusFilterChip(
                        title: status.displayName,
                        isSelected: selectedStatus == status
                    ) {
                        selectedStatus = status
                    }
                }
            }
            .padding(.horizontal)
        }
    }
}

struct StatusFilterChip: View {
    let title: String
    let isSelected: Bool
    let onTap: () -> Void

    var body: some View {
        Button(action: onTap) {
            Text(title)
                .font(.caption)
                .fontWeight(.medium)
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

// MARK: - Transfer Detail View

struct TransferDetailView: View {
    let transfer: Transfer

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                // Transfer overview
                VStack(alignment: .leading, spacing: 12) {
                    Text("Transfer Details")
                        .font(.title2)
                        .fontWeight(.bold)

                    TransferOverviewCard(transfer: transfer)
                }

                // Transfer timeline
                VStack(alignment: .leading, spacing: 12) {
                    Text("Timeline")
                        .font(.title2)
                        .fontWeight(.bold)

                    TransferTimelineCard(transfer: transfer)
                }

                // Notes section
                if let notes = transfer.notes, !notes.isEmpty {
                    VStack(alignment: .leading, spacing: 12) {
                        Text("Notes")
                            .font(.title2)
                            .fontWeight(.bold)

                        Text(notes)
                            .font(.body)
                            .padding()
                            .background(Color(.systemGray6))
                            .cornerRadius(8)
                    }
                }

                Spacer()
            }
            .padding()
        }
        .navigationTitle("Transfer #\(String(transfer.id.uuidString.prefix(8)))")
        .navigationBarTitleDisplayMode(.inline)
    }
}

struct TransferOverviewCard: View {
    let transfer: Transfer

    var body: some View {
        VStack(spacing: 12) {
            HStack {
                Text("Status")
                Spacer()
                TransferStatusBadge(status: transfer.transferStatus)
            }

            HStack {
                Text("Item")
                Spacer()
                Text(transfer.inventoryItem?.name ?? "Unknown")
                    .fontWeight(.medium)
            }

            HStack {
                Text("Quantity")
                Spacer()
                Text("\(transfer.quantity) \(transfer.inventoryItem?.unit ?? "")")
                    .fontWeight(.medium)
            }

            HStack {
                Text("From")
                Spacer()
                Text(transfer.fromLocation?.name ?? "New Stock")
                    .fontWeight(.medium)
            }

            HStack {
                Text("To")
                Spacer()
                Text(transfer.toLocation?.name ?? "Unknown")
                    .fontWeight(.medium)
            }
        }
        .padding()
        .background(Color(.systemGroupedBackground))
        .cornerRadius(8)
    }
}

struct TransferTimelineCard: View {
    let transfer: Transfer

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            TimelineEntry(
                title: "Transfer Initiated",
                time: transfer.formattedTransferDate,
                isCompleted: true
            )

            if transfer.transferStatus == .completed {
                TimelineEntry(
                    title: "Transfer Completed",
                    time: transfer.formattedTransferDate,
                    isCompleted: true
                )
            } else if transfer.transferStatus == .cancelled {
                TimelineEntry(
                    title: "Transfer Cancelled",
                    time: transfer.formattedTransferDate,
                    isCompleted: true
                )
            }
        }
        .padding()
        .background(Color(.systemGroupedBackground))
        .cornerRadius(8)
    }
}

struct TimelineEntry: View {
    let title: String
    let time: String
    let isCompleted: Bool

    var body: some View {
        HStack(spacing: 12) {
            Circle()
                .fill(isCompleted ? Color.green : Color.gray)
                .frame(width: 12, height: 12)

            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.subheadline)
                    .fontWeight(.medium)

                Text(time)
                    .font(.caption)
                    .foregroundColor(.secondary)
            }

            Spacer()
        }
    }
}

// MARK: - Preview

#Preview("Transfer History") {
    let context = PersistenceController.preview.container.viewContext

    // Create sample location
    let location = Location(context: context)
    location.id = UUID()
    location.name = "Main Barn"

    // Create sample transfers
    let transfers = (0..<10).map { index in
        let transfer = Transfer(context: context)
        transfer.id = UUID()
        transfer.quantity = Int32.random(in: 1...50)
        transfer.transferDate = Date().addingTimeInterval(-Double(index * 86400)) // Past days
        transfer.status = Transfer.Status.allCases.randomElement()?.rawValue ?? "completed"
        transfer.notes = index % 3 == 0 ? "Sample transfer notes" : nil
        return transfer
    }

    return TransferHistoryView(transfers: transfers, location: location)
}