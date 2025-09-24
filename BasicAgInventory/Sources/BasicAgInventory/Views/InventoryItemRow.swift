import SwiftUI

#if os(iOS)
import UIKit
#elseif os(macOS)
import AppKit
#endif

public struct InventoryItemRow: View {
    let item: InventoryItem
    let onIncrement: () -> Void
    let onDecrement: () -> Void
    let onEdit: () -> Void

    public init(
        item: InventoryItem,
        onIncrement: @escaping () -> Void,
        onDecrement: @escaping () -> Void,
        onEdit: @escaping () -> Void
    ) {
        self.item = item
        self.onIncrement = onIncrement
        self.onDecrement = onDecrement
        self.onEdit = onEdit
    }

    public var body: some View {
        HStack(spacing: 12) {
            // Item image or placeholder
            ItemImageView(imageData: item.imageData)

            // Item details
            VStack(alignment: .leading, spacing: 4) {
                HStack {
                    Text(item.name)
                        .font(.headline)
                        .lineLimit(1)

                    Spacer()

                    // Status indicators
                    HStack(spacing: 4) {
                        if item.isLowStock {
                            StatusBadge(text: "Low", color: .orange)
                        }

                        if item.isExpired {
                            StatusBadge(text: "Expired", color: .red)
                        }
                    }
                }

                // Category and location
                HStack {
                    Text(item.category)
                        .font(.subheadline)
                        .foregroundColor(.secondary)

                    if let location = item.location {
                        Text("•")
                            .foregroundColor(.secondary)
                        Text(location.name)
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                    }

                    Spacer()
                }

                // Description if available
                if let description = item.itemDescription, !description.isEmpty {
                    Text(description)
                        .font(.caption)
                        .foregroundColor(.secondary)
                        .lineLimit(2)
                }

                // Quantity controls
                HStack {
                    QuantityControls(
                        quantity: item.quantity,
                        unit: item.unit,
                        onIncrement: onIncrement,
                        onDecrement: onDecrement
                    )

                    Spacer()

                    // Additional info button
                    Button(action: onEdit) {
                        Image(systemName: "info.circle")
                            .foregroundColor(.blue)
                    }
                    .buttonStyle(PlainButtonStyle())
                }
            }
        }
        .padding(.vertical, 8)
        .contextMenu {
            Button(action: onEdit) {
                Label("Edit", systemImage: "pencil")
            }

            Button(action: onIncrement) {
                Label("Add 1", systemImage: "plus")
            }

            if item.quantity > 0 {
                Button(action: onDecrement) {
                    Label("Remove 1", systemImage: "minus")
                }
            }

            Divider()

            Button(role: .destructive, action: {}) {
                Label("Delete", systemImage: "trash")
            }
        }
    }
}

// MARK: - Item Image View

struct ItemImageView: View {
    let imageData: Data?
    private let imageSize: CGFloat = 60

    var body: some View {
        Group {
            if let imageData = imageData {
                #if os(iOS)
                if let uiImage = UIImage(data: imageData) {
                    Image(uiImage: uiImage)
                        .resizable()
                        .aspectRatio(contentMode: .fill)
                        .frame(width: imageSize, height: imageSize)
                        .clipShape(RoundedRectangle(cornerRadius: 8))
                } else {
                    placeholderImage
                }
                #elseif os(macOS)
                if let nsImage = NSImage(data: imageData) {
                    Image(nsImage: nsImage)
                        .resizable()
                        .aspectRatio(contentMode: .fill)
                        .frame(width: imageSize, height: imageSize)
                        .clipShape(RoundedRectangle(cornerRadius: 8))
                } else {
                    placeholderImage
                }
                #endif
            } else {
                placeholderImage
            }
        }
    }

    private var placeholderImage: some View {
        RoundedRectangle(cornerRadius: 8)
            .fill(Color.gray.opacity(0.2))
            .frame(width: imageSize, height: imageSize)
            .overlay(
                Image(systemName: "photo")
                    .foregroundColor(.secondary)
                    .font(.title2)
            )
    }
}

// MARK: - Status Badge

struct StatusBadge: View {
    let text: String
    let color: Color

    var body: some View {
        Text(text)
            .font(.caption2)
            .fontWeight(.medium)
            .foregroundColor(.white)
            .padding(.horizontal, 6)
            .padding(.vertical, 2)
            .background(color)
            .cornerRadius(4)
    }
}

// MARK: - Quantity Controls

struct QuantityControls: View {
    let quantity: Int32
    let unit: String
    let onIncrement: () -> Void
    let onDecrement: () -> Void

    var body: some View {
        HStack(spacing: 8) {
            // Decrement button
            Button(action: onDecrement) {
                Image(systemName: "minus.circle.fill")
                    .foregroundColor(quantity > 0 ? .blue : .gray)
                    .font(.title3)
            }
            .disabled(quantity <= 0)
            .buttonStyle(PlainButtonStyle())

            // Quantity display
            VStack(spacing: 2) {
                Text("\(quantity)")
                    .font(.headline)
                    .fontWeight(.semibold)
                    .monospacedDigit()

                Text(unit)
                    .font(.caption2)
                    .foregroundColor(.secondary)
            }
            .frame(minWidth: 44)

            // Increment button
            Button(action: onIncrement) {
                Image(systemName: "plus.circle.fill")
                    .foregroundColor(.blue)
                    .font(.title3)
            }
            .buttonStyle(PlainButtonStyle())
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 4)
        .background(Color.gray.opacity(0.1))
        .cornerRadius(8)
    }
}

// MARK: - Preview

#Preview {
    List {
        InventoryItemRow(
            item: {
                // Create a mock item for preview
                let context = PersistenceController.preview.container.viewContext
                let item = InventoryItem(context: context)
                item.id = UUID()
                item.name = "John Deere Tractor"
                item.category = "Equipment"
                item.quantity = 1
                item.unit = "unit"
                item.minimumStock = 1
                item.isActive = true
                item.createdAt = Date()
                item.updatedAt = Date()
                return item
            }(),
            onIncrement: {},
            onDecrement: {},
            onEdit: {}
        )

        InventoryItemRow(
            item: {
                let context = PersistenceController.preview.container.viewContext
                let item = InventoryItem(context: context)
                item.id = UUID()
                item.name = "Fertilizer Bags"
                item.itemDescription = "Organic nitrogen fertilizer for crop growth"
                item.category = "Supplies"
                item.quantity = 5
                item.unit = "bags"
                item.minimumStock = 10
                item.isActive = true
                item.createdAt = Date()
                item.updatedAt = Date()
                return item
            }(),
            onIncrement: {},
            onDecrement: {},
            onEdit: {}
        )
    }
    .listStyle(PlainListStyle())
}