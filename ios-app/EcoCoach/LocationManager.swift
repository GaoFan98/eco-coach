import Foundation
import CoreLocation
import MapKit
import SwiftUI

class LocationManager: NSObject, ObservableObject, CLLocationManagerDelegate {
    private let locationManager = CLLocationManager()
    
    @Published var location: CLLocationCoordinate2D?
    @Published var authorizationStatus: CLAuthorizationStatus
    
    override init() {
        authorizationStatus = locationManager.authorizationStatus
        
        super.init()
        
        locationManager.delegate = self
        locationManager.desiredAccuracy = kCLLocationAccuracyBest
        locationManager.distanceFilter = 10 // Update when user moves 10 meters
        locationManager.requestWhenInUseAuthorization()
        locationManager.startUpdatingLocation()
    }
    
    func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        guard let location = locations.last else { return }
        self.location = location.coordinate
    }
    
    func locationManager(_ manager: CLLocationManager, didChangeAuthorization status: CLAuthorizationStatus) {
        authorizationStatus = status
    }
    
    func startUpdatingLocation() {
        locationManager.startUpdatingLocation()
    }
    
    func stopUpdatingLocation() {
        locationManager.stopUpdatingLocation()
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