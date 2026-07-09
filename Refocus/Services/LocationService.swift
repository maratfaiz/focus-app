import Foundation
import CoreLocation

/// Геофенсинг для правил «по местоположению»: вход в зону включает щит,
/// выход — снимает. Работает и в фоне (region monitoring будит приложение).
final class LocationService: NSObject, ObservableObject, CLLocationManagerDelegate {
    private let manager = CLLocationManager()

    @Published var lastKnownLocation: CLLocation?
    @Published var authorizationStatus: CLAuthorizationStatus = .notDetermined

    /// Источник актуальных правил (читаем из App Group, а не из памяти).
    var rulesProvider: () -> [BlockRule] = { [] }

    override init() {
        super.init()
        manager.delegate = self
    }

    func requestAuthorization() {
        manager.requestAlwaysAuthorization()
    }

    func requestCurrentLocation() {
        manager.requestWhenInUseAuthorization()
        manager.requestLocation()
    }

    /// Пересоздаёт мониторинг регионов под текущий список правил.
    func refresh(rules: [BlockRule]) {
        for region in manager.monitoredRegions where region.identifier.hasPrefix("rule_") {
            manager.stopMonitoring(for: region)
        }
        for rule in rules where rule.isEnabled {
            guard case .location(let lat, let lon, let radius, _) = rule.kind else { continue }
            let region = CLCircularRegion(
                center: CLLocationCoordinate2D(latitude: lat, longitude: lon),
                radius: min(radius, manager.maximumRegionMonitoringDistance),
                identifier: "rule_\(rule.id.uuidString)"
            )
            region.notifyOnEntry = true
            region.notifyOnExit = true
            manager.startMonitoring(for: region)
            manager.requestState(for: region)
        }
    }

    private func ruleID(from region: CLRegion) -> UUID? {
        guard region.identifier.hasPrefix("rule_") else { return nil }
        return UUID(uuidString: String(region.identifier.dropFirst("rule_".count)))
    }

    private func handle(region: CLRegion, inside: Bool) {
        guard let id = ruleID(from: region),
              let rule = rulesProvider().first(where: { $0.id == id }),
              rule.isEnabled else { return }
        if inside {
            BlockingService.applyShield(for: rule)
        } else {
            BlockingService.clearShield(for: rule.id)
        }
    }

    // MARK: - CLLocationManagerDelegate

    func locationManagerDidChangeAuthorization(_ manager: CLLocationManager) {
        authorizationStatus = manager.authorizationStatus
    }

    func locationManager(_ manager: CLLocationManager, didEnterRegion region: CLRegion) {
        handle(region: region, inside: true)
    }

    func locationManager(_ manager: CLLocationManager, didExitRegion region: CLRegion) {
        handle(region: region, inside: false)
    }

    func locationManager(_ manager: CLLocationManager, didDetermineState state: CLRegionState, for region: CLRegion) {
        if state == .inside { handle(region: region, inside: true) }
        if state == .outside { handle(region: region, inside: false) }
    }

    func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        lastKnownLocation = locations.last
    }

    func locationManager(_ manager: CLLocationManager, didFailWithError error: Error) {
        // Игнорируем разовые сбои определения местоположения.
    }
}
