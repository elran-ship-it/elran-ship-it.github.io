import CoreLocation
import Foundation
import Observation

/// Wraps CLLocationManager: one circular "home" geofence plus one-shot location requests.
///
/// Region monitoring is the only thing that reliably wakes a terminated app on iOS,
/// so the whole "alarm me when I leave" feature hangs on this class.
@Observable
final class LocationService: NSObject, CLLocationManagerDelegate {
    enum HomeState: String {
        case unknown, inside, outside
    }

    static let homeRegionIdentifier = "home"

    private let manager = CLLocationManager()
    private var locationContinuation: CheckedContinuation<CLLocation?, Never>?

    private(set) var authorization: CLAuthorizationStatus = .notDetermined
    private(set) var homeState: HomeState = .unknown
    private(set) var lastLocation: CLLocation?
    private(set) var lastError: String?

    var onExitHome: (() -> Void)?
    var onEnterHome: (() -> Void)?

    override init() {
        super.init()
        manager.delegate = self
        manager.desiredAccuracy = kCLLocationAccuracyHundredMeters
        authorization = manager.authorizationStatus
    }

    var isAtHome: Bool? {
        switch homeState {
        case .inside: return true
        case .outside: return false
        case .unknown: return nil
        }
    }

    var hasAlwaysAuthorization: Bool { authorization == .authorizedAlways }

    var isMonitoringHome: Bool {
        manager.monitoredRegions.contains { $0.identifier == Self.homeRegionIdentifier }
    }

    var maximumRadius: CLLocationDistance { manager.maximumRegionMonitoringDistance }

    // MARK: - Permissions

    func requestWhenInUseAuthorization() {
        manager.requestWhenInUseAuthorization()
    }

    func requestAlwaysAuthorization() {
        manager.requestAlwaysAuthorization()
    }

    // MARK: - One-shot location

    /// Returns a recent fix, asking the system for a new one if the cached fix is stale.
    func requestCurrentLocation() async -> CLLocation? {
        if let cached = manager.location, cached.timestamp.timeIntervalSinceNow > -30 {
            return cached
        }
        return await withCheckedContinuation { continuation in
            locationContinuation?.resume(returning: nil)
            locationContinuation = continuation
            manager.requestLocation()
        }
    }

    // MARK: - Home geofence

    func monitorHome(center: CLLocationCoordinate2D, radius: CLLocationDistance) {
        stopMonitoringHome()
        guard CLLocationManager.isMonitoringAvailable(for: CLCircularRegion.self) else {
            lastError = "Geofencing is not available on this device."
            return
        }
        let clamped = min(max(radius, 100), manager.maximumRegionMonitoringDistance)
        let region = CLCircularRegion(center: center, radius: clamped, identifier: Self.homeRegionIdentifier)
        region.notifyOnEntry = true
        region.notifyOnExit = true
        manager.startMonitoring(for: region)
        manager.requestState(for: region)
    }

    func stopMonitoringHome() {
        for region in manager.monitoredRegions where region.identifier == Self.homeRegionIdentifier {
            manager.stopMonitoring(for: region)
        }
        homeState = .unknown
    }

    /// Asks CoreLocation whether we are currently inside the home region.
    func refreshHomeState() {
        for region in manager.monitoredRegions where region.identifier == Self.homeRegionIdentifier {
            manager.requestState(for: region)
        }
    }

    // MARK: - CLLocationManagerDelegate

    func locationManagerDidChangeAuthorization(_ manager: CLLocationManager) {
        authorization = manager.authorizationStatus
    }

    func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        lastLocation = locations.last
        locationContinuation?.resume(returning: locations.last)
        locationContinuation = nil
    }

    func locationManager(_ manager: CLLocationManager, didFailWithError error: Error) {
        lastError = error.localizedDescription
        locationContinuation?.resume(returning: manager.location)
        locationContinuation = nil
    }

    func locationManager(_ manager: CLLocationManager, didExitRegion region: CLRegion) {
        guard region.identifier == Self.homeRegionIdentifier else { return }
        homeState = .outside
        onExitHome?()
    }

    func locationManager(_ manager: CLLocationManager, didEnterRegion region: CLRegion) {
        guard region.identifier == Self.homeRegionIdentifier else { return }
        homeState = .inside
        onEnterHome?()
    }

    func locationManager(_ manager: CLLocationManager, didDetermineState state: CLRegionState, for region: CLRegion) {
        guard region.identifier == Self.homeRegionIdentifier else { return }
        switch state {
        case .inside: homeState = .inside
        case .outside: homeState = .outside
        case .unknown: homeState = .unknown
        @unknown default: homeState = .unknown
        }
    }

    func locationManager(_ manager: CLLocationManager, monitoringDidFailFor region: CLRegion?, withError error: Error) {
        lastError = "Could not monitor home: \(error.localizedDescription)"
    }
}
