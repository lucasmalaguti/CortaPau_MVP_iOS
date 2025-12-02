import SwiftUI
import Combine
import CoreLocation

@main
struct CortaPauApp: App {
    @StateObject private var appState = AppState()
    @StateObject private var locationManager = LocationManager()

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environmentObject(appState)
                .environmentObject(locationManager)
                .onReceive(locationManager.$authorizationStatus) { status in
                    appState.locationPermissionState = LocationPermissionState(from: status)
                }
                .onReceive(locationManager.$lastKnownLocation) { newLocation in
                    if let coord = newLocation {
                        appState.realUserLocation = GeoPoint(latitude: coord.latitude, longitude: coord.longitude)
                    } else {
                        appState.realUserLocation = nil
                    }
                }
        }
    }
}
