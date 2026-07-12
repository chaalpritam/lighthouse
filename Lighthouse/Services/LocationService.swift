import Foundation
import CoreLocation

@Observable
@MainActor
final class LocationService: NSObject {
    var location: GeoLocation?
    var authorizationStatus: CLAuthorizationStatus = .notDetermined
    var errorMessage: String?

    private let manager = CLLocationManager()
    private let geocoder = CLGeocoder()

    override init() {
        super.init()
        manager.delegate = self
        manager.desiredAccuracy = kCLLocationAccuracyBest
        authorizationStatus = manager.authorizationStatus
    }

    func requestPermission() {
        manager.requestWhenInUseAuthorization()
    }

    func startUpdates() {
        if authorizationStatus == .notDetermined {
            requestPermission()
        }
        manager.startUpdatingLocation()
    }

    func stopUpdates() {
        manager.stopUpdatingLocation()
    }

    @discardableResult
    func refreshOnce() async -> GeoLocation? {
        startUpdates()
        if location == nil {
            try? await Task.sleep(for: .milliseconds(800))
        }
        return location
    }

    private func update(from clLocation: CLLocation) {
        Task {
            var address: String?
            var countryCode: String?
            var countryName: String?
            if let placemark = try? await geocoder.reverseGeocodeLocation(clLocation).first {
                address = [placemark.name, placemark.locality, placemark.administrativeArea]
                    .compactMap { $0 }
                    .joined(separator: ", ")
                countryCode = placemark.isoCountryCode
                countryName = placemark.country
            }
            location = GeoLocation(
                latitude: clLocation.coordinate.latitude,
                longitude: clLocation.coordinate.longitude,
                address: address,
                countryCode: countryCode,
                countryName: countryName,
                accuracyMeters: clLocation.horizontalAccuracy >= 0 ? clLocation.horizontalAccuracy : nil
            )
        }
    }
}

extension LocationService: CLLocationManagerDelegate {
    nonisolated func locationManagerDidChangeAuthorization(_ manager: CLLocationManager) {
        Task { @MainActor in
            authorizationStatus = manager.authorizationStatus
            if authorizationStatus == .authorizedWhenInUse || authorizationStatus == .authorizedAlways {
                manager.startUpdatingLocation()
            }
        }
    }

    nonisolated func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        guard let latest = locations.last else { return }
        Task { @MainActor in
            update(from: latest)
        }
    }

    nonisolated func locationManager(_ manager: CLLocationManager, didFailWithError error: Error) {
        Task { @MainActor in
            errorMessage = error.localizedDescription
        }
    }
}
