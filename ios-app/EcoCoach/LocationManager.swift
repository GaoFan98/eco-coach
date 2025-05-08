import Foundation
import CoreLocation
import MapKit
import SwiftUI
import Combine

// MARK: - Location Manager
class EcoLocationManager: NSObject, ObservableObject {
    private let clLocationManager = CLLocationManager()
    
    @Published var location: CLLocationCoordinate2D?
    var locationUpdateHandler: ((CLLocationCoordinate2D) -> Void)?
    
    override init() {
        super.init()
        self.clLocationManager.delegate = self
        self.clLocationManager.desiredAccuracy = kCLLocationAccuracyBest
        self.clLocationManager.requestWhenInUseAuthorization()
    }
    
    func startUpdatingLocation() {
        self.clLocationManager.startUpdatingLocation()
    }
    
    // Get Tokyo coordinates if user is not in Tokyo
    func getInitialLocation() -> CLLocationCoordinate2D {
        // Tokyo center coordinates
        let tokyoCenter = CLLocationCoordinate2D(latitude: 35.6762, longitude: 139.6503)
        
        // If we have a user location, check if it's near Tokyo
        if let userLocation = location {
            let userCLLocation = CLLocation(latitude: userLocation.latitude, longitude: userLocation.longitude)
            let tokyoCLLocation = CLLocation(latitude: tokyoCenter.latitude, longitude: tokyoCenter.longitude)
            
            // Calculate distance in kilometers
            let distance = userCLLocation.distance(from: tokyoCLLocation) / 1000
            
            // If user is within 100km of Tokyo, use their location, otherwise use Tokyo center
            if distance <= 100 {
                return userLocation
            }
        }
        
        return tokyoCenter
    }
}

extension EcoLocationManager: CLLocationManagerDelegate {
    func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        guard let location = locations.last else { return }
        
        self.location = location.coordinate
        
        // Call the callback if it exists
        if let callback = locationUpdateHandler {
            callback(location.coordinate)
        }
    }
    
    func locationManager(_ manager: CLLocationManager, didFailWithError error: Error) {
        print("Location manager failed with error: \(error.localizedDescription)")
    }
} 