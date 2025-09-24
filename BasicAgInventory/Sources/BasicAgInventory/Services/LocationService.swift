import Foundation
import CoreLocation
import Combine

/// Service for managing GPS location capture and Core Location integration
/// Handles permission requests, coordinate capture with timeout, and rural environment challenges
@MainActor
public class LocationService: NSObject, ObservableObject, CLLocationManagerDelegate {

    // MARK: - Published Properties
    @Published public var currentLocation: CLLocation?
    @Published public var authorizationStatus: CLAuthorizationStatus = .notDetermined
    @Published public var locationError: LocationError?
    @Published public var isCapturingLocation: Bool = false

    // MARK: - Private Properties
    private let locationManager = CLLocationManager()
    private var locationCompletionHandler: ((Result<CLLocation, Error>) -> Void)?
    private var locationTimeout: Timer?

    // MARK: - Constants
    private let captureTimeoutSeconds: TimeInterval = 30.0 // 30 seconds for rural GPS challenges
    private let desiredAccuracy: CLLocationAccuracy = kCLLocationAccuracyBest
    private let distanceFilter: CLLocationDistance = 10.0 // 10 meters

    // MARK: - Initialization
    public override init() {
        super.init()
        setupLocationManager()
    }

    deinit {
        locationTimeout?.invalidate()
    }

    // MARK: - Setup
    private func setupLocationManager() {
        locationManager.delegate = self
        locationManager.desiredAccuracy = desiredAccuracy
        locationManager.distanceFilter = distanceFilter
        authorizationStatus = locationManager.authorizationStatus
    }

    // MARK: - Public Methods

    /// Request location permission from the user
    public func requestLocationPermission() {
        guard authorizationStatus == .notDetermined else {
            return
        }
        locationManager.requestWhenInUseAuthorization()
    }

    /// Capture current GPS coordinates for new farm location
    /// Returns coordinates or throws error if GPS unavailable/times out
    public func captureCurrentLocation() async throws -> CLLocation {
        // Clear any previous errors
        locationError = nil

        return try await withCheckedThrowingContinuation { continuation in
            // Store completion handler
            locationCompletionHandler = continuation.resume

            // Check authorization status
            guard authorizationStatus == .authorizedWhenInUse || authorizationStatus == .authorizedAlways else {
                locationError = .gpsUnavailable
                continuation.resume(throwing: LocationError.gpsUnavailable)
                return
            }

            // Start location capture
            isCapturingLocation = true
            locationManager.requestLocation()

            // Set timeout for rural GPS challenges
            locationTimeout = Timer.scheduledTimer(withTimeInterval: captureTimeoutSeconds, repeats: false) { _ in
                self.handleLocationTimeout()
            }
        }
    }

    /// Get location permission status description for UI
    public var permissionStatusDescription: String {
        switch authorizationStatus {
        case .notDetermined:
            return "Location permission not requested"
        case .denied, .restricted:
            return "Location permission denied"
        case .authorizedWhenInUse, .authorizedAlways:
            return "Location permission granted"
        @unknown default:
            return "Unknown permission status"
        }
    }

    /// Check if location services are available
    public var isLocationAvailable: Bool {
        return CLLocationManager.locationServicesEnabled() &&
               (authorizationStatus == .authorizedWhenInUse || authorizationStatus == .authorizedAlways)
    }

    /// Get accuracy description for current location
    public func accuracyDescription(for location: CLLocation) -> String {
        let accuracy = location.horizontalAccuracy

        if accuracy < 0 {
            return "GPS signal unavailable"
        } else if accuracy <= 5 {
            return "Excellent GPS accuracy (±\(Int(accuracy))m)"
        } else if accuracy <= 10 {
            return "Good GPS accuracy (±\(Int(accuracy))m)"
        } else if accuracy <= 50 {
            return "Fair GPS accuracy (±\(Int(accuracy))m)"
        } else {
            return "Poor GPS accuracy (±\(Int(accuracy))m)"
        }
    }

    // MARK: - Private Methods

    private func handleLocationTimeout() {
        locationTimeout?.invalidate()
        locationTimeout = nil
        isCapturingLocation = false

        let error = LocationError.gpsUnavailable
        locationError = error
        locationCompletionHandler?(.failure(error))
        locationCompletionHandler = nil
    }

    private func completeLocationCapture(with result: Result<CLLocation, Error>) {
        locationTimeout?.invalidate()
        locationTimeout = nil
        isCapturingLocation = false

        switch result {
        case .success(let location):
            currentLocation = location
            locationError = nil
        case .failure(let error):
            locationError = error as? LocationError ?? .gpsUnavailable
        }

        locationCompletionHandler?(result)
        locationCompletionHandler = nil
    }

    // MARK: - CLLocationManagerDelegate

    public func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        guard let location = locations.last else {
            completeLocationCapture(with: .failure(LocationError.gpsUnavailable))
            return
        }

        // Validate location accuracy for farm environment
        if location.horizontalAccuracy < 0 {
            // Invalid location, continue waiting
            return
        }

        completeLocationCapture(with: .success(location))
    }

    public func locationManager(_ manager: CLLocationManager, didFailWithError error: Error) {
        let locationError: LocationError

        if let clError = error as? CLError {
            switch clError.code {
            case .denied:
                locationError = .permissionDenied
            case .locationUnknown:
                locationError = .gpsUnavailable
            case .network:
                locationError = .networkUnavailable
            default:
                locationError = .gpsUnavailable
            }
        } else {
            locationError = .gpsUnavailable
        }

        completeLocationCapture(with: .failure(locationError))
    }

    public func locationManager(_ manager: CLLocationManager, didChangeAuthorization status: CLAuthorizationStatus) {
        authorizationStatus = status

        // If permission was denied during an active capture, fail it
        if isCapturingLocation && (status == .denied || status == .restricted) {
            completeLocationCapture(with: .failure(LocationError.permissionDenied))
        }
    }
}

// MARK: - LocationError Extension
extension LocationError {
    static let permissionDenied = LocationError.gpsUnavailable
    static let networkUnavailable = LocationError.gpsUnavailable
}