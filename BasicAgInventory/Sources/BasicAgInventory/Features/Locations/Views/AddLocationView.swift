import SwiftUI
import CoreLocation

/// Form-based location creation view with GPS coordinate capture
/// Enables location creation under 45 seconds with accessible form fields and GPS status indication
public struct AddLocationView: View {

    // MARK: - Properties
    @Environment(\.dismiss) private var dismiss
    @StateObject private var locationService = LocationService()
    @StateObject private var viewModel = AddLocationViewModel()

    let onLocationCreated: (Location) -> Void

    // MARK: - Form State
    @State private var name = ""
    @State private var description = ""
    @State private var address = ""
    @State private var latitude = ""
    @State private var longitude = ""
    @State private var useCurrentLocation = true
    @State private var showingManualCoordinates = false

    // MARK: - UI State
    @State private var showingPermissionAlert = false
    @State private var showingGPSError = false
    @State private var gpsErrorMessage = ""

    // MARK: - Body
    public var body: some View {
        NavigationView {
            Form {
                // Basic Information Section
                Section("Location Details") {
                    TextField("Location Name", text: $name)
                        .accessibilityLabel("Location name")
                        .accessibilityHint("Enter a name for this farm location")

                    TextField("Description (Optional)", text: $description, axis: .vertical)
                        .lineLimit(3...6)
                        .accessibilityLabel("Location description")
                        .accessibilityHint("Enter an optional description")

                    TextField("Address (Optional)", text: $address, axis: .vertical)
                        .lineLimit(2...4)
                        .accessibilityLabel("Location address")
                        .accessibilityHint("Enter an optional address")
                }

                // GPS Section
                Section("GPS Coordinates") {
                    GPSCoordinateSection()
                }

                // Current Location Status
                if useCurrentLocation {
                    Section("Location Status") {
                        LocationStatusView()
                    }
                }

                // Manual Coordinates (if GPS not used)
                if !useCurrentLocation {
                    Section("Manual Coordinates") {
                        ManualCoordinatesSection()
                    }
                }
            }
            .navigationTitle("Add Location")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") {
                        dismiss()
                    }
                }

                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Save") {
                        saveLocation()
                    }
                    .disabled(!isFormValid || viewModel.isSaving)
                }
            }
            .alert("Location Permission", isPresented: $showingPermissionAlert) {
                Button("Settings") {
                    openLocationSettings()
                }
                Button("Manual Entry", role: .cancel) {
                    useCurrentLocation = false
                }
            } message: {
                Text("Location access is required to capture GPS coordinates. You can grant permission in Settings or enter coordinates manually.")
            }
            .alert("GPS Error", isPresented: $showingGPSError) {
                Button("Try Again") {
                    captureCurrentLocation()
                }
                Button("Manual Entry", role: .cancel) {
                    useCurrentLocation = false
                }
            } message: {
                Text(gpsErrorMessage)
            }
            .onAppear {
                setupInitialState()
            }
            .overlay {
                if viewModel.isSaving {
                    SavingOverlay()
                }
            }
        }
    }

    // MARK: - Subviews

    @ViewBuilder
    private func GPSCoordinateSection() -> some View {
        Toggle("Use Current Location", isOn: $useCurrentLocation)
            .accessibilityLabel("Use current GPS location")
            .accessibilityHint("Toggle to use device GPS or enter coordinates manually")
            .onChange(of: useCurrentLocation) { newValue in
                if newValue {
                    captureCurrentLocation()
                } else {
                    clearGPSData()
                }
            }

        if useCurrentLocation && locationService.isCapturingLocation {
            HStack {
                ProgressView()
                    .scaleEffect(0.8)
                Text("Capturing GPS coordinates...")
                    .foregroundColor(.secondary)
            }
        }

        if useCurrentLocation && !locationService.isLocationAvailable {
            Button("Request Location Permission") {
                requestLocationPermission()
            }
            .foregroundColor(.blue)
        }
    }

    @ViewBuilder
    private func LocationStatusView() -> some View {
        if let location = locationService.currentLocation {
            VStack(alignment: .leading, spacing: 8) {
                HStack {
                    Image(systemName: "location.circle.fill")
                        .foregroundColor(.green)
                    Text("GPS Coordinates Captured")
                        .font(.subheadline)
                        .fontWeight(.medium)
                }

                VStack(alignment: .leading, spacing: 4) {
                    Text("Latitude: \(location.coordinate.latitude, specifier: "%.6f")")
                        .font(.caption)
                        .foregroundColor(.secondary)

                    Text("Longitude: \(location.coordinate.longitude, specifier: "%.6f")")
                        .font(.caption)
                        .foregroundColor(.secondary)

                    Text(locationService.accuracyDescription(for: location))
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                .padding(.leading, 20)
            }
        } else if let errorMessage = locationService.locationError?.localizedDescription {
            HStack {
                Image(systemName: "location.slash")
                    .foregroundColor(.red)
                VStack(alignment: .leading) {
                    Text("GPS Unavailable")
                        .font(.subheadline)
                        .fontWeight(.medium)
                    Text(errorMessage)
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }
        }
    }

    @ViewBuilder
    private func ManualCoordinatesSection() -> some View {
        TextField("Latitude", text: $latitude)
            .keyboardType(.decimalPad)
            .accessibilityLabel("Latitude coordinate")
            .accessibilityHint("Enter latitude in decimal degrees")

        TextField("Longitude", text: $longitude)
            .keyboardType(.decimalPad)
            .accessibilityLabel("Longitude coordinate")
            .accessibilityHint("Enter longitude in decimal degrees")

        Text("Enter coordinates in decimal degrees (e.g., 40.7128, -74.0060)")
            .font(.caption)
            .foregroundColor(.secondary)
    }

    @ViewBuilder
    private func SavingOverlay() -> some View {
        Color.black.opacity(0.3)
            .ignoresSafeArea()
            .overlay {
                VStack(spacing: 16) {
                    ProgressView()
                        .scaleEffect(1.2)
                        .progressViewStyle(CircularProgressViewStyle(tint: .white))

                    Text("Creating Location...")
                        .font(.headline)
                        .foregroundColor(.white)
                }
                .padding(32)
                .background(Color.black.opacity(0.7))
                .cornerRadius(12)
            }
    }

    // MARK: - Computed Properties

    private var isFormValid: Bool {
        let hasName = !name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
        let hasValidCoordinates: Bool

        if useCurrentLocation {
            hasValidCoordinates = locationService.currentLocation != nil
        } else {
            hasValidCoordinates = isManualCoordinatesValid
        }

        return hasName && hasValidCoordinates
    }

    private var isManualCoordinatesValid: Bool {
        guard let lat = Double(latitude), let lon = Double(longitude) else {
            return false
        }

        let coordinate = CLLocationCoordinate2D(latitude: lat, longitude: lon)
        return CLLocationCoordinate2DIsValid(coordinate) &&
               lat >= -90 && lat <= 90 &&
               lon >= -180 && lon <= 180
    }

    // MARK: - Methods

    private func setupInitialState() {
        if locationService.isLocationAvailable {
            captureCurrentLocation()
        } else {
            requestLocationPermission()
        }
    }

    private func requestLocationPermission() {
        locationService.requestLocationPermission()

        // Check permission status after a brief delay
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
            if !locationService.isLocationAvailable {
                showingPermissionAlert = true
            }
        }
    }

    private func captureCurrentLocation() {
        guard locationService.isLocationAvailable else {
            showingPermissionAlert = true
            return
        }

        Task {
            do {
                let location = try await locationService.captureCurrentLocation()
                await MainActor.run {
                    // GPS coordinates are automatically stored in locationService.currentLocation
                }
            } catch {
                await MainActor.run {
                    gpsErrorMessage = error.localizedDescription
                    showingGPSError = true
                }
            }
        }
    }

    private func clearGPSData() {
        locationService.currentLocation = nil
    }

    private func saveLocation() {
        let coordinate: CLLocationCoordinate2D

        if useCurrentLocation {
            guard let currentLocation = locationService.currentLocation else { return }
            coordinate = currentLocation.coordinate
        } else {
            guard let lat = Double(latitude), let lon = Double(longitude) else { return }
            coordinate = CLLocationCoordinate2D(latitude: lat, longitude: lon)
        }

        let locationData = LocationData(
            name: name.trimmingCharacters(in: .whitespacesAndNewlines),
            description: description.isEmpty ? nil : description.trimmingCharacters(in: .whitespacesAndNewlines),
            address: address.isEmpty ? nil : address.trimmingCharacters(in: .whitespacesAndNewlines),
            coordinate: coordinate
        )

        viewModel.createLocation(locationData) { result in
            switch result {
            case .success(let location):
                onLocationCreated(location)
                dismiss()
            case .failure(let error):
                gpsErrorMessage = error.localizedDescription
                showingGPSError = true
            }
        }
    }

    private func openLocationSettings() {
        if let settingsUrl = URL(string: UIApplication.openSettingsURLString) {
            UIApplication.shared.open(settingsUrl)
        }
    }

    // MARK: - Initialization

    public init(onLocationCreated: @escaping (Location) -> Void) {
        self.onLocationCreated = onLocationCreated
    }
}

// MARK: - ViewModel

@MainActor
private class AddLocationViewModel: ObservableObject {
    @Published var isSaving = false
    @Published var errorMessage: String?

    private let locationRepository: LocationRepositoryProtocol

    init(locationRepository: LocationRepositoryProtocol = LocationRepository()) {
        self.locationRepository = locationRepository
    }

    func createLocation(
        _ locationData: LocationData,
        completion: @escaping (Result<Location, Error>) -> Void
    ) {
        isSaving = true
        errorMessage = nil

        locationRepository.createLocation(locationData)
            .receive(on: DispatchQueue.main)
            .sink(
                receiveCompletion: { [weak self] result in
                    self?.isSaving = false
                    if case .failure(let error) = result {
                        self?.errorMessage = error.localizedDescription
                        completion(.failure(error))
                    }
                },
                receiveValue: { location in
                    completion(.success(location))
                }
            )
            .store(in: &cancellables)
    }

    private var cancellables = Set<AnyCancellable>()
}

// MARK: - Extensions

import Combine

// MARK: - Preview

struct AddLocationView_Previews: PreviewProvider {
    static var previews: some View {
        AddLocationView { _ in
            // Preview completion handler
        }
    }
}