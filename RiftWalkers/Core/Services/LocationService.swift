import Foundation
import CoreLocation
import Combine

// MARK: - Location Service
// Core geo-tracking engine. Researched: Pokemon GO uses significant location changes
// for background + continuous GPS for foreground. Battery optimization is critical.

final class LocationService: NSObject, ObservableObject {
    static let shared = LocationService()

    @Published var currentLocation: CLLocation?
    @Published var currentHeading: CLHeading?
    @Published var authorizationStatus: CLAuthorizationStatus = .notDetermined
    @Published var isTracking = false
    @Published var totalDistanceWalked: Double = 0
    @Published var currentBiome: BiomeType = .urban
    @Published var nearbyPOIs: [PointOfInterest] = []

    private let locationManager = CLLocationManager()
    private var lastRecordedLocation: CLLocation?
    private var locationUpdateHandler: ((CLLocation) -> Void)?
    private var cancellables = Set<AnyCancellable>()

    // Geo-fence triggers for territories and dungeons
    private var monitoredRegions: [CLCircularRegion] = []

    // Distance tracking for quest objectives ("Walk 5km")
    private let minimumDistanceFilter: CLLocationDistance = 5.0  // meters
    private let significantDistanceFilter: CLLocationDistance = 50.0

    override init() {
        super.init()
        locationManager.delegate = self
        locationManager.desiredAccuracy = kCLLocationAccuracyBest
        locationManager.distanceFilter = minimumDistanceFilter
        locationManager.pausesLocationUpdatesAutomatically = true
    }

    // MARK: - Authorization

    func requestAuthorization() {
        locationManager.requestWhenInUseAuthorization()
    }

    func requestAlwaysAuthorization() {
        locationManager.requestAlwaysAuthorization()
    }

    // MARK: - Tracking

    func startTracking() {
        guard authorizationStatus == .authorizedWhenInUse || authorizationStatus == .authorizedAlways else {
            requestAuthorization()
            return
        }
        locationManager.startUpdatingLocation()
        locationManager.startUpdatingHeading()
        isTracking = true
    }

    func stopTracking() {
        locationManager.stopUpdatingLocation()
        locationManager.stopUpdatingHeading()
        isTracking = false
    }

    // Background: use significant location changes (battery efficient)
    func startBackgroundTracking() {
        locationManager.startMonitoringSignificantLocationChanges()
    }

    func stopBackgroundTracking() {
        locationManager.stopMonitoringSignificantLocationChanges()
    }

    // MARK: - Region Monitoring (Territory geofences)

    func monitorTerritory(_ territory: Territory) {
        let region = CLCircularRegion(
            center: territory.location.coordinate,
            radius: territory.radius,
            identifier: territory.id
        )
        region.notifyOnEntry = true
        region.notifyOnExit = true
        locationManager.startMonitoring(for: region)
        monitoredRegions.append(region)
    }

    func stopMonitoringTerritory(_ territory: Territory) {
        if let region = monitoredRegions.first(where: { $0.identifier == territory.id }) {
            locationManager.stopMonitoring(for: region)
            monitoredRegions.removeAll { $0.identifier == territory.id }
        }
    }

    // MARK: - Biome Detection
    // Uses a combination of Apple Maps POI data and location characteristics

    func detectBiome(for location: CLLocation) -> BiomeType {
        // In production, this would use MapKit's MKLocalSearch to identify nearby POIs
        // and classify the biome based on what's around. For now, use placeholders.
        let geocoder = CLGeocoder()
        geocoder.reverseGeocodeLocation(location) { [weak self] placemarks, _ in
            guard let placemark = placemarks?.first else { return }

            let biome: BiomeType
            if let areasOfInterest = placemark.areasOfInterest, !areasOfInterest.isEmpty {
                biome = .historic
            } else if placemark.inlandWater != nil || placemark.ocean != nil {
                biome = .water
            } else if placemark.subLocality?.lowercased().contains("park") == true {
                biome = .park
            } else if placemark.locality != nil {
                biome = .urban
            } else {
                biome = .suburban
            }

            DispatchQueue.main.async {
                self?.currentBiome = biome
            }
        }
        return currentBiome
    }

    // MARK: - Distance Calculation

    func distance(from: GeoPoint, to: GeoPoint) -> CLLocationDistance {
        let loc1 = CLLocation(latitude: from.latitude, longitude: from.longitude)
        let loc2 = CLLocation(latitude: to.latitude, longitude: to.longitude)
        return loc1.distance(from: loc2)
    }

    func isWithinRange(of point: GeoPoint, radius: Double) -> Bool {
        guard let current = currentLocation else { return false }
        let target = CLLocation(latitude: point.latitude, longitude: point.longitude)
        return current.distance(from: target) <= radius
    }

    // MARK: - Helpers

    func onLocationUpdate(_ handler: @escaping (CLLocation) -> Void) {
        locationUpdateHandler = handler
    }
}

// MARK: - CLLocationManagerDelegate

extension LocationService: CLLocationManagerDelegate {
    func locationManagerDidChangeAuthorization(_ manager: CLLocationManager) {
        DispatchQueue.main.async {
            self.authorizationStatus = manager.authorizationStatus
        }

        if manager.authorizationStatus == .authorizedWhenInUse || manager.authorizationStatus == .authorizedAlways {
            startTracking()
        }
    }

    func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        guard let location = locations.last else { return }

        // Filter out inaccurate readings
        guard location.horizontalAccuracy < 50 else { return }

        DispatchQueue.main.async {
            self.currentLocation = location

            // Track walking distance
            if let lastLocation = self.lastRecordedLocation {
                let distance = location.distance(from: lastLocation)
                if distance > self.minimumDistanceFilter && distance < 100 {
                    // Cap at 100m to prevent GPS drift from inflating distance
                    self.totalDistanceWalked += distance
                }
            }
            self.lastRecordedLocation = location

            // Notify handlers
            self.locationUpdateHandler?(location)

            // Update biome periodically
            if Int(self.totalDistanceWalked) % 200 == 0 {
                _ = self.detectBiome(for: location)
            }
        }
    }

    func locationManager(_ manager: CLLocationManager, didUpdateHeading newHeading: CLHeading) {
        DispatchQueue.main.async {
            self.currentHeading = newHeading
        }
    }

    func locationManager(_ manager: CLLocationManager, didEnterRegion region: CLRegion) {
        NotificationCenter.default.post(
            name: .didEnterTerritoryRegion,
            object: nil,
            userInfo: ["regionID": region.identifier]
        )
    }

    func locationManager(_ manager: CLLocationManager, didExitRegion region: CLRegion) {
        NotificationCenter.default.post(
            name: .didExitTerritoryRegion,
            object: nil,
            userInfo: ["regionID": region.identifier]
        )
    }
}

// MARK: - POI Model

struct PointOfInterest: Identifiable {
    let id: UUID
    let name: String
    let location: GeoPoint
    let type: POIType
    let biome: BiomeType
}

enum POIType: String {
    case landmark
    case park
    case water
    case commercial
    case educational
    case religious
    case transportation
}

// MARK: - Notifications

extension Notification.Name {
    static let didEnterTerritoryRegion = Notification.Name("didEnterTerritoryRegion")
    static let didExitTerritoryRegion = Notification.Name("didExitTerritoryRegion")
}
