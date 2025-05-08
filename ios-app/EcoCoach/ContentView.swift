import SwiftUI
import MapKit
import CoreLocation

struct ContentView: View {
    @StateObject private var locationManager = EcoLocationManager()
    
    @State private var mapRegion = MKCoordinateRegion(
        center: CLLocationCoordinate2D(latitude: 35.6762, longitude: 139.6503), // Tokyo
        span: MKCoordinateSpan(latitudeDelta: 0.05, longitudeDelta: 0.05)
    )
    
    @State private var destination: CLLocationCoordinate2D?
    @State private var isCalculating = false
    @State private var routePoints: [CLLocationCoordinate2D] = []
    @State private var alternativeRoutePoints: [CLLocationCoordinate2D] = []
    @State private var routeInfo: RouteInfo?
    @State private var showAlternative = false
    @State private var userLocationString: String = ""
    @State private var pollutionReduction: Int = 15 // Default value
    
    // Map item for directions
    @State private var directionsRoute: MKRoute?
    @State private var alternativeDirectionsRoute: MKRoute?
    
    var body: some View {
        ZStack {
            // Map
            Map(coordinateRegion: $mapRegion, showsUserLocation: true, annotationItems: mapAnnotations()) { annotation in
                MapAnnotation(coordinate: annotation.coordinate) {
                    if annotation.isDestination {
                        MapPinView()
                    }
                }
            }
            .edgesIgnoringSafeArea(.top)
            .onTapGesture { location in
                setDestination(tapLocation: location)
            }
            .onAppear {
                locationManager.startUpdatingLocation()
                locationManager.locationUpdateHandler = { location in
                    // Use callback instead of onChange
                    if destination == nil {
                        mapRegion = MKCoordinateRegion(
                            center: location,
                            span: MKCoordinateSpan(latitudeDelta: 0.05, longitudeDelta: 0.05)
                        )
                    }
                }
            }
            .overlay(
                GeometryReader { geometry in
                    ZStack {
                        // Draw the primary route
                        if !routePoints.isEmpty {
                            Path { path in
                                let startPoint = convertCoordinateToPoint(routePoints[0], in: geometry.size)
                                path.move(to: startPoint)
                                
                                for i in 1..<routePoints.count {
                                    let point = convertCoordinateToPoint(routePoints[i], in: geometry.size)
                                    path.addLine(to: point)
                                }
                            }
                            .stroke(Color.green, lineWidth: 4)
                        }
                        
                        // Draw alternative route when toggled
                        if showAlternative && !alternativeRoutePoints.isEmpty {
                            Path { path in
                                let startPoint = convertCoordinateToPoint(alternativeRoutePoints[0], in: geometry.size)
                                path.move(to: startPoint)
                                
                                for i in 1..<alternativeRoutePoints.count {
                                    let point = convertCoordinateToPoint(alternativeRoutePoints[i], in: geometry.size)
                                    path.addLine(to: point)
                                }
                            }
                            .stroke(Color.blue, lineWidth: 4)
                            .opacity(0.8)
                        }
                    }
                }
            )
            
            // Bottom panel
            VStack {
                Spacer()
                
                // Bottom panel
                VStack(spacing: 20) {
                    if destination == nil {
                        Text("Tap on the map to set a destination")
                            .font(.headline)
                            .padding()
                    } else if routeInfo == nil {
                        Button(action: calculateRoute) {
                            if isCalculating {
                                ProgressView()
                                    .progressViewStyle(CircularProgressViewStyle(tint: .white))
                                    .padding()
                            } else {
                                Text("Calculate Eco-Friendly Route")
                                    .fontWeight(.bold)
                                    .foregroundColor(.white)
                                    .padding()
                                    .frame(maxWidth: .infinity)
                            }
                        }
                        .frame(maxWidth: .infinity)
                        .background(Color.green)
                        .cornerRadius(10)
                        .disabled(isCalculating)
                        .padding(.horizontal)
                    } else {
                        // Route information
                        VStack(alignment: .leading, spacing: 12) {
                            Text("Eco-Friendly Route")
                                .font(.headline)
                                .foregroundColor(.green)
                            
                            Divider()
                            
                            HStack {
                                Image(systemName: "arrow.triangle.swap")
                                Text("Distance:")
                                Spacer()
                                Text("\(String(format: "%.1f", (directionsRoute?.distance ?? 0) / 1000)) km")
                                    .fontWeight(.medium)
                            }
                            
                            HStack {
                                Image(systemName: "clock")
                                Text("Est. Time:")
                                Spacer()
                                Text("\(Int((directionsRoute?.expectedTravelTime ?? 0) / 60)) min")
                                    .fontWeight(.medium)
                            }
                            
                            HStack {
                                Image(systemName: "aqi.low")
                                Text("Pollution Level:")
                                Spacer()
                                Text(routeInfo?.pollutionExposure ?? "Low")
                                    .fontWeight(.medium)
                                    .foregroundColor(getPollutionColor(routeInfo?.pollutionExposure ?? "Low"))
                            }
                            
                            if !alternativeRoutePoints.isEmpty {
                                Toggle("Show Alternative Route", isOn: $showAlternative)
                                    .padding(.top, 4)
                                
                                if showAlternative {
                                    HStack {
                                        Text("Alternative reduces pollution by:")
                                        Spacer()
                                        Text("\(pollutionReduction)%")
                                            .fontWeight(.bold)
                                            .foregroundColor(.blue)
                                    }
                                    .padding(.top, 4)
                                }
                            }
                            
                            HStack {
                                Button(action: resetRoute) {
                                    Text("Reset")
                                        .fontWeight(.bold)
                                        .foregroundColor(.white)
                                        .padding(.vertical, 10)
                                        .frame(maxWidth: .infinity)
                                        .background(Color.red)
                                        .cornerRadius(8)
                                }
                                
                                if directionsRoute != nil {
                                    Button(action: {
                                        // Center map on the route
                                        fitMapToRoute()
                                    }) {
                                        Text("Zoom to Route")
                                            .fontWeight(.bold)
                                            .foregroundColor(.white)
                                            .padding(.vertical, 10)
                                            .frame(maxWidth: .infinity)
                                            .background(Color.blue)
                                            .cornerRadius(8)
                                    }
                                }
                            }
                        }
                        .padding()
                    }
                }
                .background(Color.white)
                .cornerRadius(15)
                .shadow(radius: 5)
                .padding()
            }
        }
    }
    
    // Convert map coordinate to screen point
    private func convertCoordinateToPoint(_ coordinate: CLLocationCoordinate2D, in size: CGSize) -> CGPoint {
        let mapCenterLatitude = mapRegion.center.latitude
        let mapCenterLongitude = mapRegion.center.longitude
        let latitudeSpan = mapRegion.span.latitudeDelta
        let longitudeSpan = mapRegion.span.longitudeDelta
        
        let latitudeDelta = coordinate.latitude - mapCenterLatitude
        let longitudeDelta = coordinate.longitude - mapCenterLongitude
        
        let percentLatitude = latitudeDelta / (latitudeSpan / 2)
        let percentLongitude = longitudeDelta / (longitudeSpan / 2)
        
        let x = size.width / 2 + (size.width / 2) * CGFloat(percentLongitude)
        let y = size.height / 2 - (size.height / 2) * CGFloat(percentLatitude)
        
        return CGPoint(x: x, y: y)
    }
    
    // Map annotations
    private func mapAnnotations() -> [MapAnnotationItem] {
        var annotations: [MapAnnotationItem] = []
        
        if let destination = destination {
            // Destination pin
            annotations.append(MapAnnotationItem(coordinate: destination, isDestination: true))
        }
        
        return annotations
    }
    
    private func setDestination(tapLocation: CGPoint) {
        // Get the tap location relative to the screen center
        let size = UIScreen.main.bounds.size
        let centerX = size.width / 2
        let centerY = size.height / 2
        
        // Calculate the deltas as percentage of the center to the tap
        let latPercent = (centerY - tapLocation.y) / (size.height / 2)
        let lonPercent = (tapLocation.x - centerX) / (size.width / 2)
        
        // Scale these percentages to the coordinate span
        let latDelta = mapRegion.span.latitudeDelta / 2 * Double(latPercent)
        let lonDelta = mapRegion.span.longitudeDelta / 2 * Double(lonPercent)
        
        // Get the actual coordinate
        let tappedLatitude = mapRegion.center.latitude + latDelta
        let tappedLongitude = mapRegion.center.longitude + lonDelta
        
        self.destination = CLLocationCoordinate2D(
            latitude: tappedLatitude,
            longitude: tappedLongitude
        )
        
        // Reset route information when a new destination is set
        self.routePoints = []
        self.alternativeRoutePoints = []
        self.routeInfo = nil
        self.showAlternative = false
        self.directionsRoute = nil
        self.alternativeDirectionsRoute = nil
        
        // Automatically calculate route when destination is set
        calculateRoute()
    }
    
    private func calculateRoute() {
        guard let destination = destination else { return }
        
        let userLocation: CLLocationCoordinate2D
        
        if let location = locationManager.location {
            userLocation = location
        } else {
            // If we don't have user location, use Tokyo center as starting point
            userLocation = CLLocationCoordinate2D(latitude: 35.6762, longitude: 139.6503)
        }
        
        isCalculating = true
        
        // Create request for MapKit directions
        let request = MKDirections.Request()
        request.source = MKMapItem(placemark: MKPlacemark(coordinate: userLocation))
        request.destination = MKMapItem(placemark: MKPlacemark(coordinate: destination))
        request.transportType = .walking // Use walking as cycling isn't available in MKDirectionsTransportType
        
        let directions = MKDirections(request: request)
        directions.calculate { [self] response, error in
            DispatchQueue.main.async {
                self.isCalculating = false
                
                if let route = response?.routes.first {
                    self.directionsRoute = route
                    
                    // Get points from the route polyline
                    let routeCoordinates = route.polyline.coordinates
                    self.routePoints = routeCoordinates
                    
                    // Create route info
                    self.routeInfo = RouteInfo(
                        distance: route.distance / 1000, // Convert to km
                        estimatedTime: route.expectedTravelTime / 60, // Convert to minutes
                        pollutionExposure: calculatePollutionLevel()
                    )
                    
                    // Generate alternative route
                    self.generateAlternativeRoute(from: userLocation, to: destination)
                    
                    // Zoom to fit the route
                    self.fitMapToRoute()
                } else {
                    print("Failed to get directions: \(error?.localizedDescription ?? "Unknown error")")
                    // Fallback to mock routes if MapKit directions fail
                    self.generateMockRoute(from: userLocation, to: destination)
                }
            }
        }
    }
    
    private func calculatePollutionLevel() -> String {
        // In a real app, this would calculate based on actual pollution data
        // For now, return a random value for demonstration
        let levels = ["Low", "Medium", "High"]
        return levels.randomElement() ?? "Low"
    }
    
    private func generateAlternativeRoute(from start: CLLocationCoordinate2D, to end: CLLocationCoordinate2D) {
        // Create a slightly different request for the alternative route
        let request = MKDirections.Request()
        request.source = MKMapItem(placemark: MKPlacemark(coordinate: start))
        request.destination = MKMapItem(placemark: MKPlacemark(coordinate: end))
        request.transportType = .walking
        
        // Request alternatives
        request.requestsAlternateRoutes = true
        
        let directions = MKDirections(request: request)
        directions.calculate { [self] response, error in
            if let routes = response?.routes, routes.count > 1 {
                // Get a different route than the primary
                self.alternativeDirectionsRoute = routes[1]
                self.alternativeRoutePoints = routes[1].polyline.coordinates
                
                // Calculate a varying pollution reduction percentage (10-30%)
                self.pollutionReduction = Int.random(in: 10...30)
            } else {
                // If no alternative from MapKit, create a modified version of main route
                self.generateMockAlternativeRoute()
            }
        }
    }
    
    private func generateMockRoute(from start: CLLocationCoordinate2D, to end: CLLocationCoordinate2D) {
        // Generate a direct route with some randomness
        var points: [CLLocationCoordinate2D] = []
        let numPoints = 12
        
        // Ensure we include start and end points exactly
        points.append(start)
        
        for i in 1..<numPoints {
            let fraction = Double(i) / Double(numPoints)
            let lat = start.latitude + (end.latitude - start.latitude) * fraction
            let lon = start.longitude + (end.longitude - start.longitude) * fraction
            
            // Add some randomness to make it look like a real route
            let jitter = 0.0005
            let randomLat = (Double.random(in: 0...1) - 0.5) * jitter
            let randomLon = (Double.random(in: 0...1) - 0.5) * jitter
            
            points.append(CLLocationCoordinate2D(latitude: lat + randomLat, longitude: lon + randomLon))
        }
        
        // Add end point
        points.append(end)
        
        self.routePoints = points
        
        // Calculate approximate distance between two points
        let distance = calculateDistance(from: start, to: end)
        
        // Set route info
        self.routeInfo = RouteInfo(
            distance: distance,
            estimatedTime: distance * 4, // Cycling pace: ~4 minutes per km
            pollutionExposure: calculatePollutionLevel()
        )
        
        // Generate an alternative route
        generateMockAlternativeRoute()
        
        // Adjust map to show the route
        fitMapToRoute()
    }
    
    private func generateMockAlternativeRoute() {
        // Create an alternative route with a different path
        guard !routePoints.isEmpty else { return }
        
        var altPoints: [CLLocationCoordinate2D] = []
        let numPoints = routePoints.count
        
        // Use the same start and end points
        altPoints.append(routePoints.first!)
        
        // Create a different path in the middle
        for i in 1..<numPoints-1 {
            let basePoint = routePoints[i]
            
            // Add a larger deviation to make the route visibly different
            let deviation = 0.001
            let adjustedLat = basePoint.latitude + (Double.random(in: 0...1) - 0.5) * deviation
            let adjustedLon = basePoint.longitude + (Double.random(in: 0...1) - 0.5) * deviation
            
            altPoints.append(CLLocationCoordinate2D(latitude: adjustedLat, longitude: adjustedLon))
        }
        
        altPoints.append(routePoints.last!)
        self.alternativeRoutePoints = altPoints
        
        // Calculate a dynamic pollution reduction (10-30%)
        self.pollutionReduction = Int.random(in: 10...30)
    }
    
    private func calculateDistance(from start: CLLocationCoordinate2D, to end: CLLocationCoordinate2D) -> Double {
        let startLocation = CLLocation(latitude: start.latitude, longitude: start.longitude)
        let endLocation = CLLocation(latitude: end.latitude, longitude: end.longitude)
        
        // Distance in meters, convert to kilometers
        return startLocation.distance(from: endLocation) / 1000
    }
    
    private func fitMapToRoute() {
        guard routePoints.count >= 2 else { return }
        
        var minLat = Double.greatestFiniteMagnitude
        var maxLat = -Double.greatestFiniteMagnitude
        var minLon = Double.greatestFiniteMagnitude
        var maxLon = -Double.greatestFiniteMagnitude
        
        // Find the bounding box for all route points
        for point in routePoints {
            minLat = min(minLat, point.latitude)
            maxLat = max(maxLat, point.latitude)
            minLon = min(minLon, point.longitude)
            maxLon = max(maxLon, point.longitude)
        }
        
        // Also consider alternative route points if they exist
        if !alternativeRoutePoints.isEmpty {
            for point in alternativeRoutePoints {
                minLat = min(minLat, point.latitude)
                maxLat = max(maxLat, point.latitude)
                minLon = min(minLon, point.longitude)
                maxLon = max(maxLon, point.longitude)
            }
        }
        
        // Add a small padding (20%)
        let latDelta = (maxLat - minLat) * 1.4
        let lonDelta = (maxLon - minLon) * 1.4
        
        // Make sure the span isn't too small
        let finalLatDelta = max(latDelta, 0.005)
        let finalLonDelta = max(lonDelta, 0.005)
        
        // Calculate the center point
        let centerLat = (minLat + maxLat) / 2
        let centerLon = (minLon + maxLon) / 2
        
        // Create the new region
        let newRegion = MKCoordinateRegion(
            center: CLLocationCoordinate2D(latitude: centerLat, longitude: centerLon),
            span: MKCoordinateSpan(latitudeDelta: finalLatDelta, longitudeDelta: finalLonDelta)
        )
        
        // Update the map region
        withAnimation {
            self.mapRegion = newRegion
        }
    }
    
    private func resetRoute() {
        destination = nil
        routePoints = []
        alternativeRoutePoints = []
        routeInfo = nil
        showAlternative = false
        directionsRoute = nil
        alternativeDirectionsRoute = nil
    }
    
    private func getPollutionColor(_ level: String) -> Color {
        switch level.lowercased() {
        case "low":
            return .green
        case "medium":
            return .orange
        case "high":
            return .red
        default:
            return .green
        }
    }
}

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

// Map annotation item
struct MapAnnotationItem: Identifiable {
    let id = UUID()
    let coordinate: CLLocationCoordinate2D
    let isDestination: Bool
}

// Custom MapPin View
struct MapPinView: View {
    var body: some View {
        VStack(spacing: 0) {
            Image(systemName: "mappin.circle.fill")
                .font(.title)
                .foregroundColor(.red)
                .background(Circle().fill(.white))
            
            Image(systemName: "arrowtriangle.down.fill")
                .font(.caption)
                .foregroundColor(.red)
                .offset(x: 0, y: -5)
        }
        .offset(y: -10) // Adjust for pin point
    }
}

// MapKit Polyline renderer for routes
struct RoutePolyline: View {
    let route: MKRoute
    let color: Color
    
    var body: some View {
        if let polyline = route.polyline as? MKPolyline {
            PolylineShape(polyline: polyline)
                .stroke(color, lineWidth: 4)
        }
    }
}

struct PolylineShape: Shape {
    let polyline: MKPolyline
    
    func path(in rect: CGRect) -> Path {
        let points = polyline.coordinates
        
        return Path { path in
            guard points.count > 0 else { return }
            
            let origin = points[0]
            let point = MKMapPoint(origin)
            
            path.move(to: CGPoint(x: point.x, y: point.y))
            
            for i in 1..<points.count {
                let point = MKMapPoint(points[i])
                path.addLine(to: CGPoint(x: point.x, y: point.y))
            }
        }
    }
}

// Extension to get coordinates from an MKPolyline
extension MKPolyline {
    var coordinates: [CLLocationCoordinate2D] {
        var coords = [CLLocationCoordinate2D](repeating: CLLocationCoordinate2D(), count: pointCount)
        getCoordinates(&coords, range: NSRange(location: 0, length: pointCount))
        return coords
    }
}

// MARK: - Supporting Types

struct RouteInfo {
    let distance: Double
    let estimatedTime: Double
    let pollutionExposure: String
}

struct RouteResponse: Codable {
    let route: Route
    
    struct Route: Codable {
        let distance: Double
        let estimated_time: Double
        let pollution_exposure: String?
        let points: [Point]
        
        struct Point: Codable {
            let lat: Double
            let lon: Double
        }
    }
} 
 