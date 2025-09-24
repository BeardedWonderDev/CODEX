import SwiftUI
import MapKit
import CoreLocation

/// MapKit integration view for visual farm location representation
/// Uses UIViewRepresentable wrapper for MKMapView with location annotations and map region calculation
public struct LocationMapView: View {

    // MARK: - Properties
    let locations: [Location]
    @Binding var selectedLocation: Location?

    @State private var region = MKCoordinateRegion(
        center: CLLocationCoordinate2D(latitude: 0, longitude: 0),
        span: MKCoordinateSpan(latitudeDelta: 0.01, longitudeDelta: 0.01)
    )
    @State private var annotations: [LocationAnnotation] = []
    @State private var showingLocationDetails = false

    // MARK: - Body
    public var body: some View {
        NavigationView {
            ZStack(alignment: .bottom) {
                // Map View
                MapViewRepresentable(
                    region: $region,
                    annotations: $annotations,
                    selectedLocation: $selectedLocation
                )
                .ignoresSafeArea()
                .onAppear {
                    setupMapData()
                }
                .onChange(of: locations) { _ in
                    updateAnnotations()
                }

                // Location Details Sheet Trigger
                if selectedLocation != nil {
                    Color.clear
                        .onAppear {
                            showingLocationDetails = true
                        }
                }
            }
            .navigationTitle("Farm Locations")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") {
                        selectedLocation = nil
                    }
                }
            }
            .sheet(isPresented: $showingLocationDetails) {
                if let location = selectedLocation {
                    LocationDetailSheet(location: location) {
                        selectedLocation = nil
                        showingLocationDetails = false
                    }
                }
            }
        }
    }

    // MARK: - Private Methods

    private func setupMapData() {
        updateAnnotations()
        calculateMapRegion()
    }

    private func updateAnnotations() {
        annotations = locations.map { LocationAnnotation(location: $0) }
    }

    private func calculateMapRegion() {
        guard !locations.isEmpty else { return }

        let coordinates = locations.map { $0.coordinate }
        let minLat = coordinates.map { $0.latitude }.min() ?? 0
        let maxLat = coordinates.map { $0.latitude }.max() ?? 0
        let minLon = coordinates.map { $0.longitude }.min() ?? 0
        let maxLon = coordinates.map { $0.longitude }.max() ?? 0

        let center = CLLocationCoordinate2D(
            latitude: (minLat + maxLat) / 2,
            longitude: (minLon + maxLon) / 2
        )

        let span = MKCoordinateSpan(
            latitudeDelta: max((maxLat - minLat) * 1.3, 0.01),
            longitudeDelta: max((maxLon - minLon) * 1.3, 0.01)
        )

        region = MKCoordinateRegion(center: center, span: span)
    }

    // MARK: - Initialization

    public init(locations: [Location], selectedLocation: Binding<Location?>) {
        self.locations = locations
        self._selectedLocation = selectedLocation
    }
}

// MARK: - MapView UIViewRepresentable

private struct MapViewRepresentable: UIViewRepresentable {
    @Binding var region: MKCoordinateRegion
    @Binding var annotations: [LocationAnnotation]
    @Binding var selectedLocation: Location?

    func makeUIView(context: Context) -> MKMapView {
        let mapView = MKMapView()
        mapView.delegate = context.coordinator
        mapView.showsUserLocation = true
        mapView.userTrackingMode = .none
        mapView.mapType = .hybrid // Good for rural farm environments
        mapView.showsCompass = true
        mapView.showsScale = true

        // Enable clustering for multiple locations
        mapView.register(
            LocationAnnotationView.self,
            forAnnotationViewWithReuseIdentifier: LocationAnnotationView.identifier
        )

        return mapView
    }

    func updateUIView(_ mapView: MKMapView, context: Context) {
        // Update region
        if mapView.region.center.latitude != region.center.latitude ||
           mapView.region.center.longitude != region.center.longitude {
            mapView.setRegion(region, animated: true)
        }

        // Update annotations
        let currentAnnotations = mapView.annotations.compactMap { $0 as? LocationAnnotation }
        let currentLocationIds = Set(currentAnnotations.map { $0.location.id })
        let newLocationIds = Set(annotations.map { $0.location.id })

        // Remove annotations that are no longer needed
        let annotationsToRemove = currentAnnotations.filter { !newLocationIds.contains($0.location.id) }
        mapView.removeAnnotations(annotationsToRemove)

        // Add new annotations
        let annotationsToAdd = annotations.filter { !currentLocationIds.contains($0.location.id) }
        mapView.addAnnotations(annotationsToAdd)
    }

    func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }

    // MARK: - Coordinator

    class Coordinator: NSObject, MKMapViewDelegate {
        var parent: MapViewRepresentable

        init(_ parent: MapViewRepresentable) {
            self.parent = parent
        }

        func mapView(_ mapView: MKMapView, viewFor annotation: MKAnnotation) -> MKAnnotationView? {
            guard let locationAnnotation = annotation as? LocationAnnotation else {
                return nil
            }

            let annotationView = mapView.dequeueReusableAnnotationView(
                withIdentifier: LocationAnnotationView.identifier,
                for: annotation
            ) as! LocationAnnotationView

            annotationView.configure(with: locationAnnotation)
            return annotationView
        }

        func mapView(_ mapView: MKMapView, didSelect view: MKAnnotationView) {
            if let locationAnnotation = view.annotation as? LocationAnnotation {
                parent.selectedLocation = locationAnnotation.location
            }
        }

        func mapView(_ mapView: MKMapView, didDeselect view: MKAnnotationView) {
            // Keep selection for sheet presentation
        }

        func mapView(_ mapView: MKMapView, regionDidChangeAnimated animated: Bool) {
            parent.region = mapView.region
        }
    }
}

// MARK: - Custom Annotation View

private class LocationAnnotationView: MKAnnotationView {
    static let identifier = "LocationAnnotationView"

    private let containerView = UIView()
    private let imageView = UIImageView()
    private let countLabel = UILabel()

    override init(annotation: MKAnnotation?, reuseIdentifier: String?) {
        super.init(annotation: annotation, reuseIdentifier: reuseIdentifier)
        setupView()
    }

    required init?(coder aDecoder: NSCoder) {
        super.init(coder: aDecoder)
        setupView()
    }

    private func setupView() {
        // Enable callout
        canShowCallout = true

        // Container setup
        containerView.backgroundColor = UIColor.systemBlue
        containerView.layer.cornerRadius = 15
        containerView.layer.borderWidth = 2
        containerView.layer.borderColor = UIColor.white.cgColor

        // Image setup
        imageView.image = UIImage(systemName: "location.fill")
        imageView.tintColor = .white
        imageView.contentMode = .scaleAspectFit

        // Label setup
        countLabel.textColor = .white
        countLabel.font = UIFont.systemFont(ofSize: 10, weight: .bold)
        countLabel.textAlignment = .center

        // Layout
        addSubview(containerView)
        containerView.addSubview(imageView)
        containerView.addSubview(countLabel)

        containerView.translatesAutoresizingMaskIntoConstraints = false
        imageView.translatesAutoresizingMaskIntoConstraints = false
        countLabel.translatesAutoresizingMaskIntoConstraints = false

        NSLayoutConstraint.activate([
            containerView.widthAnchor.constraint(equalToConstant: 30),
            containerView.heightAnchor.constraint(equalToConstant: 30),
            containerView.centerXAnchor.constraint(equalTo: centerXAnchor),
            containerView.centerYAnchor.constraint(equalTo: centerYAnchor),

            imageView.centerXAnchor.constraint(equalTo: containerView.centerXAnchor),
            imageView.topAnchor.constraint(equalTo: containerView.topAnchor, constant: 4),
            imageView.widthAnchor.constraint(equalToConstant: 12),
            imageView.heightAnchor.constraint(equalToConstant: 12),

            countLabel.centerXAnchor.constraint(equalTo: containerView.centerXAnchor),
            countLabel.bottomAnchor.constraint(equalTo: containerView.bottomAnchor, constant: -2),
            countLabel.leadingAnchor.constraint(greaterThanOrEqualTo: containerView.leadingAnchor, constant: 2),
            countLabel.trailingAnchor.constraint(lessThanOrEqualTo: containerView.trailingAnchor, constant: -2)
        ])

        frame = CGRect(x: 0, y: 0, width: 30, height: 30)
        centerOffset = CGPoint(x: 0, y: -15) // Offset to point to location
    }

    func configure(with annotation: LocationAnnotation) {
        let itemCount = annotation.location.itemCount
        countLabel.text = itemCount > 0 ? "\(itemCount)" : ""

        // Color based on activity
        if annotation.location.hasItems {
            containerView.backgroundColor = UIColor.systemGreen
        } else {
            containerView.backgroundColor = UIColor.systemGray
        }
    }
}

// MARK: - Location Detail Sheet

private struct LocationDetailSheet: View {
    let location: Location
    let onDismiss: () -> Void

    var body: some View {
        NavigationView {
            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    // Header
                    VStack(alignment: .leading, spacing: 8) {
                        Text(location.name)
                            .font(.title)
                            .fontWeight(.bold)

                        if let description = location.locationDescription, !description.isEmpty {
                            Text(description)
                                .font(.body)
                                .foregroundColor(.secondary)
                        }

                        if let address = location.address, !address.isEmpty {
                            Text(address)
                                .font(.body)
                                .foregroundColor(.secondary)
                        }
                    }

                    Divider()

                    // Coordinates
                    VStack(alignment: .leading, spacing: 8) {
                        Text("GPS Coordinates")
                            .font(.headline)

                        HStack {
                            VStack(alignment: .leading) {
                                Text("Latitude")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                                Text(String(format: "%.6f", location.latitude))
                                    .font(.body)
                                    .fontFamily(.monospaced)
                            }

                            Spacer()

                            VStack(alignment: .leading) {
                                Text("Longitude")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                                Text(String(format: "%.6f", location.longitude))
                                    .font(.body)
                                    .fontFamily(.monospaced)
                            }
                        }
                    }

                    Divider()

                    // Inventory Summary
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Inventory Summary")
                            .font(.headline)

                        HStack {
                            Image(systemName: "cube.box")
                                .foregroundColor(.blue)
                            Text("\(location.itemCount) items stored")
                                .font(.body)
                        }

                        if location.totalTransferCount > 0 {
                            HStack {
                                Image(systemName: "arrow.left.arrow.right")
                                    .foregroundColor(.orange)
                                Text("\(location.totalTransferCount) transfers recorded")
                                    .font(.body)
                            }
                        }
                    }

                    Spacer()
                }
                .padding()
            }
            .navigationTitle("Location Details")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") {
                        onDismiss()
                    }
                }
            }
        }
    }
}

// MARK: - Preview

struct LocationMapView_Previews: PreviewProvider {
    static var previews: some View {
        LocationMapView(locations: [], selectedLocation: .constant(nil))
    }
}