import Foundation
import CoreLocation
import Combine
import MapKit

final class LocationManager: NSObject, ObservableObject {
    @Published var lastKnownLocation: CLLocationCoordinate2D?
    @Published var lastResolvedAddress: String?
    @Published var authorizationStatus: CLAuthorizationStatus

    private let manager = CLLocationManager()

    override init() {
        self.authorizationStatus = manager.authorizationStatus
        super.init()
        manager.delegate = self
        manager.desiredAccuracy = kCLLocationAccuracyHundredMeters
    }

    func requestWhenInUseAuthorization() {
        manager.requestWhenInUseAuthorization()
    }

    func startUpdatingLocationIfNeeded() {
        switch authorizationStatus {
        case .authorizedWhenInUse, .authorizedAlways:
            manager.startUpdatingLocation()
        case .notDetermined:
            manager.requestWhenInUseAuthorization()
        default:
            break
        }
    }
}

extension LocationManager: CLLocationManagerDelegate {
    func locationManagerDidChangeAuthorization(_ manager: CLLocationManager) {
        DispatchQueue.main.async {
            self.authorizationStatus = manager.authorizationStatus
        }
    }

    func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        guard let location = locations.last else { return }

        let coord = location.coordinate

        DispatchQueue.main.async {
            // Coordenada crua para quem precisar trabalhar com mapa (MapKit) em outros pontos do app
            self.lastKnownLocation = coord

            // Fallback de "endereço" baseado em lat/lon, suficiente para o MVP
            let addressString = String(
                format: "Lat %.5f, Lon %.5f (aprox.)",
                coord.latitude,
                coord.longitude
            )
            self.lastResolvedAddress = addressString
        }

        // Para evitar consumo desnecessário, paramos as atualizações
        manager.stopUpdatingLocation()
    }

    func locationManager(_ manager: CLLocationManager, didFailWithError error: Error) {
        print("Location error:", error)
    }
}
