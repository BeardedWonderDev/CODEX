import SwiftUI

/// Reusable transfer progress indicator showing current transfer status
struct TransferProgressView: View {
    let transfer: Transfer
    let showDetails: Bool

    init(transfer: Transfer, showDetails: Bool = true) {
        self.transfer = transfer
        self.showDetails = showDetails
    }

    var body: some View {
        HStack(spacing: 12) {
            // Status icon
            statusIcon
                .font(.title3)
                .foregroundColor(statusColor)

            if showDetails {
                VStack(alignment: .leading, spacing: 2) {
                    Text(transfer.transferDescription)
                        .font(.subheadline)
                        .fontWeight(.medium)
                        .lineLimit(2)

                    Text(statusText)
                        .font(.caption)
                        .foregroundColor(statusColor)
                }

                Spacer()

                if transfer.transferStatus == .pending {
                    ProgressView()
                        .scaleEffect(0.8)
                }
            }
        }
        .padding(showDetails ? 12 : 8)
        .background(backgroundColor)
        .cornerRadius(8)
        .accessibilityElement(children: .combine)
        .accessibilityLabel(accessibilityDescription)
    }

    // MARK: - Status Styling

    private var statusIcon: Image {
        switch transfer.transferStatus {
        case .pending:
            return Image(systemName: "clock.fill")
        case .completed:
            return Image(systemName: "checkmark.circle.fill")
        case .cancelled:
            return Image(systemName: "xmark.circle.fill")
        }
    }

    private var statusColor: Color {
        switch transfer.transferStatus {
        case .pending:
            return .orange
        case .completed:
            return .green
        case .cancelled:
            return .red
        }
    }

    private var backgroundColor: Color {
        switch transfer.transferStatus {
        case .pending:
            return Color.orange.opacity(0.1)
        case .completed:
            return Color.green.opacity(0.1)
        case .cancelled:
            return Color.red.opacity(0.1)
        }
    }

    private var statusText: String {
        switch transfer.transferStatus {
        case .pending:
            return "Transfer in progress..."
        case .completed:
            return "Completed \(transfer.formattedTransferDate)"
        case .cancelled:
            return "Transfer cancelled"
        }
    }

    // MARK: - Accessibility

    private var accessibilityDescription: String {
        let status = transfer.transferStatus.displayName.lowercased()
        return "Transfer \(status): \(transfer.transferDescription)"
    }
}

// MARK: - Minimal Progress Indicator

struct MinimalTransferProgress: View {
    let transfer: Transfer

    var body: some View {
        TransferProgressView(transfer: transfer, showDetails: false)
    }
}

// MARK: - Transfer Status Badge

struct TransferStatusBadge: View {
    let status: Transfer.Status

    var body: some View {
        Text(status.displayName.uppercased())
            .font(.caption2)
            .fontWeight(.bold)
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
            .background(backgroundColor)
            .foregroundColor(foregroundColor)
            .cornerRadius(4)
    }

    private var backgroundColor: Color {
        switch status {
        case .pending:
            return .orange
        case .completed:
            return .green
        case .cancelled:
            return .red
        }
    }

    private var foregroundColor: Color {
        .white
    }
}

// MARK: - Preview

#Preview("Transfer Progress") {
    VStack(spacing: 16) {
        // Create sample transfers for preview
        let context = PersistenceController.preview.container.viewContext

        // Sample completed transfer
        let completedTransfer = Transfer(context: context)
        completedTransfer.id = UUID()
        completedTransfer.quantity = 5
        completedTransfer.transferDate = Date()
        completedTransfer.status = Transfer.Status.completed.rawValue
        completedTransfer.notes = "Moved to barn for winter storage"

        // Sample pending transfer
        let pendingTransfer = Transfer(context: context)
        pendingTransfer.id = UUID()
        pendingTransfer.quantity = 10
        pendingTransfer.transferDate = Date()
        pendingTransfer.status = Transfer.Status.pending.rawValue

        TransferProgressView(transfer: completedTransfer)
        TransferProgressView(transfer: pendingTransfer)
        MinimalTransferProgress(transfer: completedTransfer)

        HStack {
            TransferStatusBadge(status: .completed)
            TransferStatusBadge(status: .pending)
            TransferStatusBadge(status: .cancelled)
        }
    }
    .padding()
}