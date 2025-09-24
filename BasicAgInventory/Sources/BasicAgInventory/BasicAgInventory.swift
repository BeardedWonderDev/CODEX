import SwiftUI
import CoreData

@main
public struct BasicAgInventoryApp: App {
    let persistenceController = PersistenceController.shared

    public init() {}

    public var body: some Scene {
        WindowGroup {
            ContentView()
                .environment(\.managedObjectContext, persistenceController.viewContext)
        }
    }
}

public struct ContentView: View {
    @Environment(\.managedObjectContext) private var viewContext

    public init() {}

    public var body: some View {
        TabView {
            InventoryListView()
                .tabItem {
                    Image(systemName: "archivebox")
                    Text("Inventory")
                }

            // Placeholder for locations view (future feature)
            LocationsPlaceholderView()
                .tabItem {
                    Image(systemName: "map")
                    Text("Locations")
                }

            // Placeholder for reports view (future feature)
            ReportsPlaceholderView()
                .tabItem {
                    Image(systemName: "chart.bar")
                    Text("Reports")
                }

            // Placeholder for settings view (future feature)
            SettingsPlaceholderView()
                .tabItem {
                    Image(systemName: "gear")
                    Text("Settings")
                }
        }
        .accentColor(.blue)
    }
}

// MARK: - Placeholder Views for Future Features

struct LocationsPlaceholderView: View {
    var body: some View {
        NavigationView {
            VStack(spacing: 20) {
                Image(systemName: "map")
                    .font(.system(size: 64))
                    .foregroundColor(.secondary)

                Text("Locations")
                    .font(.largeTitle)
                    .fontWeight(.bold)

                Text("Manage your farm locations and track inventory across different areas")
                    .font(.body)
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal)

                Text("Coming Soon")
                    .font(.headline)
                    .foregroundColor(.blue)
                    .padding()
                    .background(Color.blue.opacity(0.1))
                    .cornerRadius(8)
            }
            .navigationTitle("Locations")
        }
    }
}

struct ReportsPlaceholderView: View {
    var body: some View {
        NavigationView {
            VStack(spacing: 20) {
                Image(systemName: "chart.bar")
                    .font(.system(size: 64))
                    .foregroundColor(.secondary)

                Text("Reports")
                    .font(.largeTitle)
                    .fontWeight(.bold)

                Text("View inventory analytics, usage trends, and generate reports for your agricultural operations")
                    .font(.body)
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal)

                Text("Coming Soon")
                    .font(.headline)
                    .foregroundColor(.blue)
                    .padding()
                    .background(Color.blue.opacity(0.1))
                    .cornerRadius(8)
            }
            .navigationTitle("Reports")
        }
    }
}

struct SettingsPlaceholderView: View {
    var body: some View {
        NavigationView {
            VStack(spacing: 20) {
                Image(systemName: "gear")
                    .font(.system(size: 64))
                    .foregroundColor(.secondary)

                Text("Settings")
                    .font(.largeTitle)
                    .fontWeight(.bold)

                Text("Configure app preferences, backup options, and account settings")
                    .font(.body)
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal)

                Text("Coming Soon")
                    .font(.headline)
                    .foregroundColor(.blue)
                    .padding()
                    .background(Color.blue.opacity(0.1))
                    .cornerRadius(8)
            }
            .navigationTitle("Settings")
        }
    }
}

#Preview {
    ContentView()
        .environment(\.managedObjectContext, PersistenceController.preview.viewContext)
}