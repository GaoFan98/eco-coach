@preconcurrency import SwiftUI
@preconcurrency import MapKit
import CoreLocation
import Combine

// Import required components
import Foundation
import UIKit

// Ensure other components are imported
@_exported import SwiftUI
@_exported import MapKit
@_exported import UIKit

// Import all the model types directly
// Define AWSServiceClass as our main service
class AWSServiceClass: ObservableObject {
    // Implementation will be in AWSService.swift
    func getRouteInsights(routeData: RouteInfo) -> AnyPublisher<RouteInsightsResponse, Error> {
        // Placeholder implementation
        return Just(RouteInsightsResponse(insights: [
            RouteInsight(title: "Short-term Benefit", description: "Reduced coughing and throat irritation during your trip."),
            RouteInsight(title: "Long-term Benefit", description: "Lower risk of respiratory conditions from consistent low-pollution routes."),
            RouteInsight(title: "Health Tip", description: "Travel during early morning when pollution levels are typically lower.")
        ]))
        .setFailureType(to: Error.self)
        .eraseToAnyPublisher()
    }
    
    func getRouteStory(routeData: RouteInfo) -> AnyPublisher<RouteStoryResponse, Error> {
        // Placeholder implementation
        return Just(RouteStoryResponse(
            title: "Eco-Warrior's Journey",
            story: "Today you chose a path less traveled, reducing your CO2 emissions by 1.4kg and breathing in 15% less pollution. Small choices like these add up to big impacts for both your health and our planet.",
            stats: [
                RouteStatItem(label: "CO2 Saved", value: "\(Int(routeData.distance * 280))g"),
                RouteStatItem(label: "PM2.5 Avoided", value: "\(String(format: "%.2f", routeData.distance * 0.2))g"),
                RouteStatItem(label: "Health Impact", value: "Positive")
            ],
            shareText: "I just saved \(Int(routeData.distance * 280))g of CO2 and reduced my pollution exposure by choosing an eco-friendly route with EcoCoach!"
        ))
        .setFailureType(to: Error.self)
        .eraseToAnyPublisher()
    }
    
    func decodeBase64Image(_ base64String: String) -> UIImage? {
        guard !base64String.isEmpty,
              let data = Data(base64Encoded: base64String) else { 
            return nil 
        }
        return UIImage(data: data)
    }
}

typealias AWSService = AWSServiceClass

// Needed to satisfy compiler - Models explicitly defined to avoid import errors
struct RouteInsight: Codable {
    let title: String
    let description: String
}

struct RouteInsightsResponse: Codable {
    let insights: [RouteInsight]
}

struct PollutionPoint: Codable, Identifiable {
    let id: UUID
    let position: Double
    let level: String
    let lat: Double
    let lon: Double
    
    init(position: Double, level: String, lat: Double, lon: Double) {
        self.id = UUID()
        self.position = position
        self.level = level
        self.lat = lat
        self.lon = lon
    }
    
    // Required for Codable compatibility
    enum CodingKeys: String, CodingKey {
        case position, level, lat, lon
    }
    
    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        position = try container.decode(Double.self, forKey: .position)
        level = try container.decode(String.self, forKey: .level)
        lat = try container.decode(Double.self, forKey: .lat)
        lon = try container.decode(Double.self, forKey: .lon)
        id = UUID() // Generate a unique ID when decoding
    }
    
    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(position, forKey: .position)
        try container.encode(level, forKey: .level)
        try container.encode(lat, forKey: .lat)
        try container.encode(lon, forKey: .lon)
        // id is not encoded as it's generated on the client
    }
}

struct PollutionForecastResponse: Codable {
    let imageBase64: String
    let pollutionData: [PollutionPoint]
    let isRealData: Bool
    
    init(imageBase64: String, pollutionData: [PollutionPoint], isRealData: Bool = false) {
        self.imageBase64 = imageBase64
        self.pollutionData = pollutionData
        self.isRealData = isRealData
    }
}

struct RouteStatItem: Codable {
    let label: String
    let value: String
}

struct RouteStoryResponse: Codable {
    let title: String
    let story: String
    let stats: [RouteStatItem]
    let shareText: String
}

// Model for OpenAQ API response
struct OpenAQResponse: Codable {
    let results: [Location]
    
    struct Location: Codable {
        let id: Int
        let name: String
        let coordinates: Coordinates?
        let parameters: [Parameter]?
        
        struct Coordinates: Codable {
            let latitude: Double
            let longitude: Double
        }
        
        struct Parameter: Codable {
            let id: Int
            let parameter: String
            let lastValue: Double?
            let unit: String
            let displayName: String?
            
            enum CodingKeys: String, CodingKey {
                case id, parameter, unit
                case lastValue = "lastValue"
                case displayName = "displayName"
            }
        }
    }
}

// MARK: - ContentView Definition
struct ContentView: View {
    @StateObject private var locationManager = EcoLocationManager()
    @StateObject private var awsService = AWSService()
    
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
    
    // AWS AI feature states
    @State private var routeInsights: [RouteInsight] = []
    @State private var isLoadingInsights = false
    @State private var showInsights = false
    
    @State private var pollutionForecast: PollutionForecastResponse?
    @State private var isLoadingForecast = false
    @State private var showPollutionOverlayOnMap = false
    
    @State private var routeStory: RouteStoryResponse?
    @State private var isLoadingStory = false
    @State private var showRouteStory = false
    
    // Cancellables for API requests
    @State private var cancellables = Set<AnyCancellable>()
    
    // A variation for handling the opacity of the overlay
    var pollutionOverlayOpacity: Double {
        if pollutionForecast != nil && showPollutionOverlayOnMap {
            return 0.65 // More transparent when showing pollution data
        }
        return 0.0
    }
    
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
                
                // Initialize MapKit if needed for pollution overlays
                _ = MKMapView()
            }
            // Pollution overlay with reduced opacity
            .overlay(
                PollutionMapViewWrapper(
                    isVisible: $showPollutionOverlayOnMap,
                    region: $mapRegion,
                    pollutionData: pollutionForecast?.pollutionData ?? [],
                    routePoints: routePoints
                )
                .allowsHitTesting(false)
                .opacity(pollutionOverlayOpacity)
            )
            // Route overlay with improved visibility
            .overlay(
                GeometryReader { geometry in
                    ZStack {
                        // Draw the primary route with improved visibility
                        if !routePoints.isEmpty {
                            // Add white outline/shadow for contrast
                            Path { path in
                                let startPoint = convertCoordinateToPoint(routePoints[0], in: geometry.size)
                                path.move(to: startPoint)
                                
                                for i in 1..<routePoints.count {
                                    let point = convertCoordinateToPoint(routePoints[i], in: geometry.size)
                                    path.addLine(to: point)
                                }
                            }
                            .stroke(Color.white, lineWidth: 7) // Thicker white outline
                            .shadow(color: .black, radius: 2, x: 0, y: 0)
                            
                            // Main route line
                            Path { path in
                                let startPoint = convertCoordinateToPoint(routePoints[0], in: geometry.size)
                                path.move(to: startPoint)
                                
                                for i in 1..<routePoints.count {
                                    let point = convertCoordinateToPoint(routePoints[i], in: geometry.size)
                                    path.addLine(to: point)
                                }
                            }
                            .stroke(Color.green.opacity(0.9), lineWidth: 5) // Brighter green, thicker line
                        }
                        
                        // Draw alternative route when toggled with improved visibility
                        if showAlternative && !alternativeRoutePoints.isEmpty {
                            // Add white outline/shadow for contrast
                            Path { path in
                                let startPoint = convertCoordinateToPoint(alternativeRoutePoints[0], in: geometry.size)
                                path.move(to: startPoint)
                                
                                for i in 1..<alternativeRoutePoints.count {
                                    let point = convertCoordinateToPoint(alternativeRoutePoints[i], in: geometry.size)
                                    path.addLine(to: point)
                                }
                            }
                            .stroke(Color.white, lineWidth: 7) // Thicker white outline
                            .shadow(color: .black, radius: 2, x: 0, y: 0)
                            
                            // Alternative route line
                            Path { path in
                                let startPoint = convertCoordinateToPoint(alternativeRoutePoints[0], in: geometry.size)
                                path.move(to: startPoint)
                                
                                for i in 1..<alternativeRoutePoints.count {
                                    let point = convertCoordinateToPoint(alternativeRoutePoints[i], in: geometry.size)
                                    path.addLine(to: point)
                                }
                            }
                            .stroke(Color.blue.opacity(0.9), lineWidth: 5) // Brighter blue, thicker line
                        }
                        
                        // Add markers for start and end points with high visibility
                        if !routePoints.isEmpty {
                            // Start point marker
                            Circle()
                                .fill(Color.white)
                                .frame(width: 14, height: 14)
                                .position(convertCoordinateToPoint(routePoints.first!, in: geometry.size))
                                .overlay(
                                    Circle()
                                        .fill(Color.green)
                                        .frame(width: 10, height: 10)
                                        .position(convertCoordinateToPoint(routePoints.first!, in: geometry.size))
                                )
                            
                            // End point marker
                            Circle()
                                .fill(Color.white)
                                .frame(width: 14, height: 14)
                                .position(convertCoordinateToPoint(routePoints.last!, in: geometry.size))
                                .overlay(
                                    Circle()
                                        .fill(Color.red)
                                        .frame(width: 10, height: 10)
                                        .position(convertCoordinateToPoint(routePoints.last!, in: geometry.size))
                                )
                        }
                    }
                }
            )
            
            // AI Feature buttons overlay (when route is active)
            if routeInfo != nil {
                VStack {
                    HStack(spacing: 10) {
                        Spacer()
                        
                        // Health insights button
                        Button(action: {
                            if routeInsights.isEmpty {
                                fetchRouteInsights()
                            } else {
                                showInsights = true
                            }
                        }) {
                            VStack {
                                Image(systemName: "heart.fill")
                                    .font(.system(size: 20))
                                    .foregroundColor(.white)
                                    .padding(10)
                                    .background(Circle().fill(Color.green))
                                
                                if isLoadingInsights {
                                    ProgressView()
                                        .scaleEffect(0.8)
                                }
                            }
                        }
                        
                        // Pollution toggle button
                        Button(action: {
                            if pollutionForecast == nil {
                                fetchPollutionForecast()
                            } else {
                                // Toggle the pollution overlay visibility
                                showPollutionOverlayOnMap.toggle()
                            }
                        }) {
                            VStack {
                                Image(systemName: "aqi.high")
                                    .font(.system(size: 20))
                                    .foregroundColor(.white)
                                    .padding(10)
                                    .background(Circle().fill(pollutionForecast != nil && showPollutionOverlayOnMap ? Color.purple : Color.orange))
                                
                                if isLoadingForecast {
                                    ProgressView()
                                        .scaleEffect(0.8)
                                }
                            }
                        }
                        .overlay(
                            // Add a small badge to show pollution level
                            Group {
                                if let level = getPollutionSummaryLevel(), showPollutionOverlayOnMap {
                                    Text(level)
                                        .font(.system(size: 10))
                                        .fontWeight(.bold)
                                        .foregroundColor(.white)
                                        .padding(4)
                                        .background(getPollutionColor(level))
                                        .clipShape(Circle())
                                        .offset(x: 20, y: -15)
                                }
                            }
                        )
                        
                        // Route story button
                        Button(action: {
                            if routeStory == nil {
                                fetchRouteStory()
                            } else {
                                showRouteStory = true
                            }
                        }) {
                            VStack {
                                Image(systemName: "book.fill")
                                    .font(.system(size: 20))
                                    .foregroundColor(.white)
                                    .padding(10)
                                    .background(Circle().fill(Color.blue))
                                
                                if isLoadingStory {
                                    ProgressView()
                                        .scaleEffect(0.8)
                                }
                            }
                        }
                    }
                    .padding()
                    
                    Spacer()
                }
            }
            
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
                            
                            // Add data source indicator
                            if pollutionForecast != nil && showPollutionOverlayOnMap {
                                HStack {
                                    Image(systemName: "info.circle")
                                        .foregroundColor(.blue)
                                    Text("Data Source:")
                                    Spacer()
                                    Text(pollutionForecast?.isRealData == true ? "OpenAQ Live Data" : "Simulated Data")
                                        .font(.caption)
                                        .foregroundColor(pollutionForecast?.isRealData == true ? .green : .orange)
                                }
                                .padding(.top, 4)
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
                                
                                if !routePoints.isEmpty {
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
            
            // Route insights sheet
            if showInsights {
                Color.black.opacity(0.4)
                    .edgesIgnoringSafeArea(.all)
                    .onTapGesture {
                        showInsights = false
                    }
                
                RouteInsightsView(insights: routeInsights)
                    .padding(.horizontal)
                    .transition(AnyTransition.move(edge: .bottom))
            }
            
            // Route story sheet
            if showRouteStory, let storyData = routeStory {
                Color.black.opacity(0.4)
                    .edgesIgnoringSafeArea(.all)
                    .onTapGesture {
                        showRouteStory = false
                    }
                
                RouteStoryView(
                    storyData: storyData,
                    isPresented: $showRouteStory
                )
                .transition(AnyTransition.move(edge: .bottom))
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
        
        // Reset AWS AI feature data
        self.routeInsights = []
        self.pollutionForecast = nil
        self.routeStory = nil
        
        // Automatically calculate route when destination is set
        calculateRoute()
        
    }
    
    // Fetch route insights from AWS Bedrock
    private func fetchRouteInsights() {
        guard let routeInfo = routeInfo else { return }
        
        isLoadingInsights = true
        
        let cancellable = awsService.getRouteInsights(routeData: routeInfo)
            .receive(on: DispatchQueue.main)
            .sink(
                receiveCompletion: { completion in
                    if case .failure(let error) = completion {
                        print("Error fetching route insights: \(error)")
                        
                        // Fallback to mock insights if API call fails
                        self.routeInsights = [
                            RouteInsight(title: "Short-term Benefit", description: "Reduced coughing and throat irritation during your trip."),
                            RouteInsight(title: "Long-term Benefit", description: "Lower risk of respiratory conditions from consistent low-pollution routes."),
                            RouteInsight(title: "Health Tip", description: "Travel during early morning when pollution levels are typically lower.")
                        ]
                        self.showInsights = true
                    }
                    self.isLoadingInsights = false
                },
                receiveValue: { response in
                    self.routeInsights = response.insights
                    self.showInsights = true
                }
            )
            
        self.cancellables.insert(cancellable)
    }
    
    // Fetch pollution forecast using OpenAQ data or fallback to simulation
    private func fetchPollutionForecast() {
        guard let routeInfo = routeInfo, let start = routePoints.first, let end = routePoints.last else { return }
        
        isLoadingForecast = true
        print("🔍 Fetching air pollution data")
        
        // Use URLSession directly instead of OpenAQService reference
        fetchPollutionData(for: routePoints)
            .receive(on: DispatchQueue.main)
            .sink(
                receiveCompletion: { completion in
                    if case .failure(let error) = completion {
                        print("❌ Error fetching pollution data: \(error)")
                        print("❌ Error details: \(String(describing: error))")
                        
                        // Fallback to mock data if API call fails
                        self.generateMockPollutionData(start: start, end: end)
                    } else {
                        print("✅ Successfully fetched pollution data")
                    }
                    self.isLoadingForecast = false
                },
                receiveValue: { pollutionPoints in
                    print("📥 Received \(pollutionPoints.count) pollution data points")
                    
                    if pollutionPoints.isEmpty {
                        // No data from API, generate mock data
                        print("⚠️ No pollution data received, using fallback data")
                        self.generateMockPollutionData(start: start, end: end)
                        return
                    }
                    
                    // Enhance the data with additional points to create a smoother visualization
                    let enhancedData = self.enhanceWithInterpolatedPoints(pollutionPoints)
                    
                    // Create the response with the real data
                    self.pollutionForecast = PollutionForecastResponse(
                        imageBase64: "",
                        pollutionData: enhancedData,
                        isRealData: true
                    )
                    
                    // Calculate route pollution exposure based on real data
                    let exposureLevel = self.calculateRoutePollutionExposure(pollutionPoints)
                    self.routeInfo = RouteInfo(
                        distance: routeInfo.distance,
                        estimatedTime: routeInfo.estimatedTime,
                        pollutionExposure: exposureLevel
                    )
                    
                    // Auto-enable overlay on main map
                    self.showPollutionOverlayOnMap = true
                    
                    // If we have alternative route, calculate real pollution reduction
                    if !self.alternativeRoutePoints.isEmpty {
                        self.calculateAlternativeRoutePollution()
                    }
                }
            )
            .store(in: &cancellables)
    }
    
    // Direct implementation of pollution data fetching
    private func fetchPollutionData(for coordinates: [CLLocationCoordinate2D]) -> AnyPublisher<[PollutionPoint], Error> {
        // Return empty if no coordinates
        if coordinates.isEmpty {
            return Just([])
                .setFailureType(to: Error.self)
                .eraseToAnyPublisher()
        }
        
        // Sample points along the route to reduce API calls
        let samplePoints = sampleRouteCoordinates(coordinates, count: min(5, coordinates.count))
        
        // Create a publisher for each sample point
        let publishers = samplePoints.enumerated().map { (index, coordinate) -> AnyPublisher<PollutionPoint, Error> in
            return fetchNearbyPollution(latitude: coordinate.latitude, longitude: coordinate.longitude)
                .map { response -> PollutionPoint in
                    // Calculate position along route (0.0 to 1.0)
                    let position = Double(index) / Double(samplePoints.count - 1)
                    
                    // Extract pollution level from response
                    let pollutionLevel = self.determinePollutionLevel(from: response)
                    
                    return PollutionPoint(
                        position: position,
                        level: pollutionLevel,
                        lat: coordinate.latitude,
                        lon: coordinate.longitude
                    )
                }
                .eraseToAnyPublisher()
        }
        
        // Combine all publishers into a single result
        return Publishers.MergeMany(publishers)
            .collect()
            .map { points in
                // Sort by position to ensure correct order
                return points.sorted { $0.position < $1.position }
            }
            .eraseToAnyPublisher()
    }
    
    // Generate sample points along the route
    private func sampleRouteCoordinates(_ coordinates: [CLLocationCoordinate2D], count: Int) -> [CLLocationCoordinate2D] {
        guard coordinates.count > 1, count > 1 else {
            return coordinates
        }
        
        var result: [CLLocationCoordinate2D] = []
        
        // Always include start and end points
        result.append(coordinates.first!)
        
        if count > 2 {
            let step = Double(coordinates.count - 1) / Double(count - 1)
            for i in 1..<(count - 1) {
                let index = Int(Double(i) * step)
                if index < coordinates.count {
                    result.append(coordinates[index])
                }
            }
        }
        
        result.append(coordinates.last!)
        return result
    }
    
    // Fetch pollution data for a specific location
    private func fetchNearbyPollution(latitude: Double, longitude: Double, radius: Int = 5000) -> AnyPublisher<OpenAQResponse, Error> {
        let baseURL = "https://api.openaq.org/v3"
        let urlString = "\(baseURL)/locations?coordinates=\(latitude),\(longitude)&radius=\(radius)&limit=5&sort=distance&order=asc"
        
        guard let url = URL(string: urlString) else {
            return Fail(error: URLError(.badURL)).eraseToAnyPublisher()
        }
        
        var request = URLRequest(url: url)
        
        // Get API key from Info.plist
        if let apiKey = Bundle.main.object(forInfoDictionaryKey: "OpenAQAPIKey") as? String {
            request.addValue(apiKey, forHTTPHeaderField: "X-API-Key")
        }
        
        print("🔍 Fetching data for: \(latitude), \(longitude)")
        
        return URLSession.shared.dataTaskPublisher(for: request)
            .map(\.data)
            .decode(type: OpenAQResponse.self, decoder: JSONDecoder())
            .eraseToAnyPublisher()
    }
    
    // Determine pollution level from API response
    private func determinePollutionLevel(from response: OpenAQResponse) -> String {
        // Default to medium if no data
        if response.results.isEmpty {
            return "Medium"
        }
        
        // Find the location with the most recent measurements
        guard let location = response.results.first,
              let parameters = location.parameters else {
            return "Medium"
        }
        
        // Check for common pollutants
        var pollutionScore = 0
        var parameterCount = 0
        
        for parameter in parameters {
            if let value = parameter.lastValue {
                parameterCount += 1
                
                switch parameter.parameter {
                case "pm25":
                    // PM2.5 thresholds (μg/m³): Good < 12, Moderate < 35.4, Poor > 35.4
                    if value < 12 {
                        pollutionScore += 1 // Low
                    } else if value < 35.4 {
                        pollutionScore += 2 // Medium
                    } else {
                        pollutionScore += 3 // High
                    }
                    
                case "pm10":
                    // PM10 thresholds (μg/m³): Good < 54, Moderate < 154, Poor > 154
                    if value < 54 {
                        pollutionScore += 1 // Low
                    } else if value < 154 {
                        pollutionScore += 2 // Medium
                    } else {
                        pollutionScore += 3 // High
                    }
                    
                case "o3": // Ozone
                    // Ozone thresholds (ppb): Good < 54, Moderate < 70, Poor > 70
                    if value < 54 {
                        pollutionScore += 1 // Low
                    } else if value < 70 {
                        pollutionScore += 2 // Medium
                    } else {
                        pollutionScore += 3 // High
                    }
                    
                case "no2": // Nitrogen Dioxide
                    // NO2 thresholds (ppb): Good < 53, Moderate < 100, Poor > 100
                    if value < 53 {
                        pollutionScore += 1 // Low
                    } else if value < 100 {
                        pollutionScore += 2 // Medium
                    } else {
                        pollutionScore += 3 // High
                    }
                    
                case "co": // Carbon Monoxide
                    // CO thresholds (ppm): Good < 4.4, Moderate < 9.4, Poor > 9.4
                    if value < 4.4 {
                        pollutionScore += 1 // Low
                    } else if value < 9.4 {
                        pollutionScore += 2 // Medium
                    } else {
                        pollutionScore += 3 // High
                    }
                    
                default:
                    pollutionScore += 2 // Default to medium
                    parameterCount += 1
                }
            }
        }
        
        // Calculate average
        if parameterCount > 0 {
            let avgScore = Double(pollutionScore) / Double(parameterCount)
            
            if avgScore < 1.5 {
                return "Low"
            } else if avgScore < 2.5 {
                return "Medium"
            } else {
                return "High"
            }
        }
        
        return "Medium" // Default if no data
    }
    
    // Calculate pollution reduction for alternative route
    private func calculateAlternativeRoutePollution() {
        guard !alternativeRoutePoints.isEmpty else { return }
        
        fetchPollutionData(for: alternativeRoutePoints)
            .receive(on: DispatchQueue.main)
            .sink(
                receiveCompletion: { completion in
                    if case .failure(let error) = completion {
                        print("❌ Error fetching alternative route pollution data: \(error)")
                        
                        // Fallback to random reduction if API call fails
                        self.pollutionReduction = Int.random(in: 10...30)
                    }
                },
                receiveValue: { alternativePoints in
                    if alternativePoints.isEmpty {
                        // Fallback to random
                        self.pollutionReduction = Int.random(in: 10...30)
                        return
                    }
                    
                    // Calculate real reduction percentage based on PM2.5 exposure
                    if let mainRouteData = self.pollutionForecast?.pollutionData {
                        let mainExposure = self.calculateAveragePollutionScore(mainRouteData)
                        let altExposure = self.calculateAveragePollutionScore(alternativePoints)
                        
                        if mainExposure > 0 && altExposure < mainExposure {
                            let reduction = (mainExposure - altExposure) / mainExposure * 100
                            self.pollutionReduction = min(50, max(5, Int(reduction))) // Cap between 5-50%
                            print("📊 Calculated real pollution reduction: \(self.pollutionReduction)%")
                        } else {
                            // Default if alternative is not better
                            self.pollutionReduction = Int.random(in: 5...15)
                        }
                    } else {
                        // Fallback to random
                        self.pollutionReduction = Int.random(in: 10...30)
                    }
                }
            )
            .store(in: &cancellables)
    }
    
    // Calculate average pollution score from points (higher score = more pollution)
    private func calculateAveragePollutionScore(_ points: [PollutionPoint]) -> Double {
        if points.isEmpty {
            return 0
        }
        
        var totalScore = 0.0
        for point in points {
            switch point.level.lowercased() {
            case "low":
                totalScore += 1.0
            case "medium":
                totalScore += 2.0
            case "high":
                totalScore += 3.0
            default:
                totalScore += 1.5
            }
        }
        
        return totalScore / Double(points.count)
    }
    
    // Enhance data points with interpolated values for smoother visualization
    private func enhanceWithInterpolatedPoints(_ basePoints: [PollutionPoint]) -> [PollutionPoint] {
        guard basePoints.count >= 2 else {
            return basePoints
        }
        
        var enhancedPoints: [PollutionPoint] = []
        let pointsToGenerate = min(15, basePoints.count * 3) // Generate up to 3x more points, max 15
        
        // Always include actual data points
        enhancedPoints.append(contentsOf: basePoints)
        
        // Add interpolated points between actual measurements
        for i in 0..<(basePoints.count - 1) {
            let current = basePoints[i]
            let next = basePoints[i + 1]
            
            // Add 1-2 points between each pair of actual measurements
            let interpolationsNeeded = min(2, max(1, Int((next.position - current.position) * Double(pointsToGenerate))))
            
            for j in 1...interpolationsNeeded {
                let fraction = Double(j) / Double(interpolationsNeeded + 1)
                let position = current.position + (next.position - current.position) * fraction
                let lat = current.lat + (next.lat - current.lat) * fraction
                let lon = current.lon + (next.lon - current.lon) * fraction
                
                // Determine level by weighted average or nearest
                let level: String
                let rand = Double.random(in: 0...1)
                if rand < fraction {
                    level = next.level
                } else {
                    level = current.level
                }
                
                enhancedPoints.append(PollutionPoint(
                    position: position,
                    level: level,
                    lat: lat,
                    lon: lon
                ))
            }
        }
        
        // Add perpendicular offset points for visualizing pollution spread
        let baseEnhancedPoints = enhancedPoints
        for point in baseEnhancedPoints where Int.random(in: 0...2) == 0 { // Only add offsets to some points
            // Add 1-2 offset points perpendicular to route
            let offsetDistance = 0.0005 // ~50m
            let angle = Double.random(in: 0...(2 * Double.pi))
            
            // Calculate offset
            let offsetLat = point.lat + offsetDistance * sin(angle)
            let offsetLon = point.lon + offsetDistance * cos(angle)
            
            // Slightly vary the pollution level
            let level = randomizedPollutionLevel(baseLevel: point.level)
            
            enhancedPoints.append(PollutionPoint(
                position: point.position,
                level: level,
                lat: offsetLat,
                lon: offsetLon
            ))
        }
        
        return enhancedPoints.sorted { $0.position < $1.position }
    }
    
    // Helper method to generate realistic pollution data
    private func generateMockPollutionData(start: CLLocationCoordinate2D, end: CLLocationCoordinate2D) {
        // Create a more complex pollution pattern along the route
        let pointCount = 15 // More points for better visualization
        var mockPoints: [PollutionPoint] = []
        
        // Create main route points
        for i in 0..<pointCount {
            let fraction = Double(i) / Double(pointCount - 1)
            
            // Create main route point
            let lat = start.latitude + (end.latitude - start.latitude) * fraction
            let lon = start.longitude + (end.longitude - start.longitude) * fraction
            
            // Vary the pollution levels along the route with more variation
            var level = "Low"
            if fraction < 0.2 {
                level = "Medium"
            } else if fraction > 0.7 && fraction < 0.9 {
                level = "High"
            } else if fraction > 0.4 && fraction < 0.6 {
                level = "Medium"
            }
            
            mockPoints.append(PollutionPoint(position: fraction, level: level, lat: lat, lon: lon))
            
            // Add some offset points for more realistic distribution
            if i % 3 == 0 {
                // Add some offset points perpendicular to route
                let perpOffset = 0.0005 // ~50m perpendicular to route
                
                // Calculate perpendicular offset (90 degrees to route direction)
                let routeAngle = atan2(end.latitude - start.latitude, end.longitude - start.longitude)
                let perpAngle = routeAngle + .pi/2
                
                // Add a point on one side
                let perpLat1 = lat + perpOffset * sin(perpAngle)
                let perpLon1 = lon + perpOffset * cos(perpAngle)
                
                // Add a point on the other side
                let perpLat2 = lat - perpOffset * sin(perpAngle)
                let perpLon2 = lon - perpOffset * cos(perpAngle)
                
                // Random levels for these points based on main route point but with some variation
                let sideLevel1 = randomizedPollutionLevel(baseLevel: level)
                let sideLevel2 = randomizedPollutionLevel(baseLevel: level)
                
                mockPoints.append(PollutionPoint(position: fraction, level: sideLevel1, lat: perpLat1, lon: perpLon1))
                mockPoints.append(PollutionPoint(position: fraction, level: sideLevel2, lat: perpLat2, lon: perpLon2))
            }
        }
        
        self.pollutionForecast = PollutionForecastResponse(
            imageBase64: "",
            pollutionData: mockPoints,
            isRealData: false
        )
        
        // Auto-enable overlay on main map
        self.showPollutionOverlayOnMap = true
    }
    
    // Helper to add some randomness to pollution levels
    private func randomizedPollutionLevel(baseLevel: String) -> String {
        let random = Int.random(in: 1...10)
        
        switch baseLevel {
        case "Low":
            return random <= 7 ? "Low" : "Medium"
        case "Medium":
            return random <= 5 ? "Medium" : (random <= 8 ? "Low" : "High")
        case "High":
            return random <= 7 ? "High" : "Medium"
        default:
            return baseLevel
        }
    }
    
    // Fetch route story from AWS Bedrock
    private func fetchRouteStory() {
        guard let routeInfo = routeInfo else { return }
        
        isLoadingStory = true
        
        let cancellable = awsService.getRouteStory(routeData: routeInfo)
            .receive(on: DispatchQueue.main)
            .sink(
                receiveCompletion: { completion in
                    if case .failure(let error) = completion {
                        print("Error fetching route story: \(error)")
                        
                        // Fallback to mock data if API call fails
                        self.routeStory = RouteStoryResponse(
                            title: "Eco-Warrior's Journey",
                            story: "Today you chose a path less traveled, reducing your CO2 emissions by 1.4kg and breathing in 15% less pollution. Small choices like these add up to big impacts for both your health and our planet.",
                            stats: [
                                RouteStatItem(label: "CO2 Saved", value: "\(Int(routeInfo.distance * 280))g"),
                                RouteStatItem(label: "PM2.5 Avoided", value: "\(String(format: "%.2f", routeInfo.distance * 0.2))g"),
                                RouteStatItem(label: "Health Impact", value: "Positive")
                            ],
                            shareText: "I just saved \(Int(routeInfo.distance * 280))g of CO2 and reduced my pollution exposure by choosing an eco-friendly route with EcoCoach!"
                        )
                        self.showRouteStory = true
                    }
                    self.isLoadingStory = false
                },
                receiveValue: { response in
                    self.routeStory = response
                    self.showRouteStory = true
                }
            )
            
        self.cancellables.insert(cancellable)
    }
    
    // MARK: - Original Map and Route Functions
    
    @State private var directionsRoute: MKRoute?
    @State private var alternativeDirectionsRoute: MKRoute?
    
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
        request.transportType = .walking // Use walking instead of cycling which isn't available
        
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
        
        // Reset AWS AI feature data
        routeInsights = []
        pollutionForecast = nil
        routeStory = nil
        
        // Reset UI states
        showInsights = false
        showRouteStory = false
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
    
    // Add helper function to determine the overall pollution level for badge
    private func getPollutionSummaryLevel() -> String? {
        guard let pollutionData = pollutionForecast?.pollutionData, !pollutionData.isEmpty else {
            return nil
        }
        
        // Count the occurrences of each level
        var levelCounts: [String: Int] = [:]
        
        for point in pollutionData {
            levelCounts[point.level, default: 0] += 1
        }
        
        // Find the most common level
        if let mostCommon = levelCounts.max(by: { $0.value < $1.value }) {
            return mostCommon.key
        }
        
        return nil
    }
    
    // Function to calculate pollution exposure along a route based on data points
    private func calculateRoutePollutionExposure(_ points: [PollutionPoint]) -> String {
        // Default to medium if no data
        if points.isEmpty {
            return "Medium"
        }
        
        // Count occurrences of each level
        var levelCounts: [String: Int] = [:]
        for point in points {
            levelCounts[point.level, default: 0] += 1
        }
        
        // Find the most common level
        return levelCounts.max(by: { $0.value < $1.value })?.key ?? "Medium"
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
        PolylineShape(polyline: route.polyline)
            .stroke(color, lineWidth: 4)
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

// RouteInsightsView
struct RouteInsightsView: View {
    let insights: [RouteInsight]
    
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Health Insights")
                .font(.headline)
                .foregroundColor(.green)
            
            Divider()
            
            ForEach(insights, id: \.title) { insight in
                InsightRow(insight: insight)
            }
        }
        .padding()
        .background(Color.white)
        .cornerRadius(15)
        .shadow(radius: 5)
    }
}

struct InsightRow: View {
    let insight: RouteInsight
    
    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(insight.title)
                .font(.subheadline)
                .fontWeight(.semibold)
                .foregroundColor(.primary)
            
            Text(insight.description)
                .font(.body)
                .foregroundColor(.secondary)
                .fixedSize(horizontal: false, vertical: true)
        }
    }
}

// RouteStoryView
struct RouteStoryView: View {
    let storyData: RouteStoryResponse
    @Binding var isPresented: Bool
    
    @State private var isShareSheetPresented = false
    
    var body: some View {
        VStack(spacing: 20) {
            HStack {
                Text("Your Eco Journey")
                    .font(.headline)
                    .foregroundColor(.primary)
                
                Spacer()
                
                Button(action: {
                    isPresented = false
                }) {
                    Image(systemName: "xmark.circle.fill")
                        .foregroundColor(.gray)
                }
            }
            
            Text(storyData.title)
                .font(.title2)
                .fontWeight(.bold)
                .foregroundColor(.green)
                .multilineTextAlignment(.center)
            
            Text(storyData.story)
                .font(.body)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
                .fixedSize(horizontal: false, vertical: true)
                .padding(.horizontal)
            
            HStack(spacing: 12) {
                ForEach(storyData.stats, id: \.label) { stat in
                    StatBox(stat: stat)
                }
            }
            .padding(.vertical)
            
            Button(action: {
                isShareSheetPresented = true
            }) {
                Label("Share Your Impact", systemImage: "square.and.arrow.up")
                    .font(.headline)
                    .foregroundColor(.white)
                    .padding()
                    .frame(maxWidth: .infinity)
                    .background(Color.blue)
                    .cornerRadius(10)
            }
            .sheet(isPresented: $isShareSheetPresented) {
                ShareSheet(activityItems: [prepareShareText()])
            }
        }
        .padding()
        .background(Color.white)
        .cornerRadius(20)
        .shadow(radius: 10)
        .padding()
    }
    
    private func prepareShareText() -> String {
        let text = """
        \(storyData.title)
        
        \(storyData.shareText)
        
        #EcoCoach #SustainableTravel #CleanAir
        """
        return text
    }
}

struct StatBox: View {
    let stat: RouteStatItem
    
    var body: some View {
        VStack {
            Text(stat.value)
                .font(.headline)
                .fontWeight(.bold)
                .foregroundColor(.primary)
            
            Text(stat.label)
                .font(.caption)
                .foregroundColor(.secondary)
        }
        .frame(maxWidth: .infinity)
        .padding()
        .background(Color(UIColor.systemGray6))
        .cornerRadius(10)
    }
}

struct ShareSheet: UIViewControllerRepresentable {
    let activityItems: [Any]
    
    func makeUIViewController(context: Context) -> UIActivityViewController {
        let controller = UIActivityViewController(
            activityItems: activityItems,
            applicationActivities: nil
        )
        return controller
    }
    
    func updateUIViewController(_ uiViewController: UIActivityViewController, context: Context) {}
}

// Replace CustomMapViewRepresentable with this fixed version
struct PollutionMapViewWrapper: UIViewRepresentable {
    @Binding var isVisible: Bool
    @Binding var region: MKCoordinateRegion
    let pollutionData: [PollutionPoint]
    let routePoints: [CLLocationCoordinate2D]
    
    func makeUIView(context: Context) -> UIView {
        // Create a transparent container view
        let containerView = UIView()
        containerView.backgroundColor = .clear
        
        // Create and add MapView only if visible
        if isVisible {
            let mapView = MKMapView()
            mapView.delegate = context.coordinator
            mapView.isUserInteractionEnabled = false // Prevent interactions with this overlay map
            mapView.alpha = 0.7 // Make slightly transparent to see base map
            
            // Make the map background transparent
            mapView.backgroundColor = .clear
            
            // Add the map view to the container
            containerView.addSubview(mapView)
            mapView.translatesAutoresizingMaskIntoConstraints = false
            NSLayoutConstraint.activate([
                mapView.topAnchor.constraint(equalTo: containerView.topAnchor),
                mapView.bottomAnchor.constraint(equalTo: containerView.bottomAnchor),
                mapView.leadingAnchor.constraint(equalTo: containerView.leadingAnchor),
                mapView.trailingAnchor.constraint(equalTo: containerView.trailingAnchor)
            ])
            
            // Store the map view for later updates
            context.coordinator.mapView = mapView
        }
        
        return containerView
    }
    
    func updateUIView(_ uiView: UIView, context: Context) {
        // Find the map view if it exists
        let mapView = context.coordinator.mapView
        
        // Handle visibility changes
        if isVisible && mapView == nil {
            // Create and add MapView if it should be visible but doesn't exist
            let newMapView = MKMapView()
            newMapView.delegate = context.coordinator
            newMapView.isUserInteractionEnabled = false
            newMapView.alpha = 0.7
            newMapView.backgroundColor = .clear
            
            uiView.addSubview(newMapView)
            newMapView.translatesAutoresizingMaskIntoConstraints = false
            NSLayoutConstraint.activate([
                newMapView.topAnchor.constraint(equalTo: uiView.topAnchor),
                newMapView.bottomAnchor.constraint(equalTo: uiView.bottomAnchor),
                newMapView.leadingAnchor.constraint(equalTo: uiView.leadingAnchor),
                newMapView.trailingAnchor.constraint(equalTo: uiView.trailingAnchor)
            ])
            
            context.coordinator.mapView = newMapView
        } else if !isVisible && mapView != nil {
            // Remove MapView if it should not be visible but exists
            mapView?.removeFromSuperview()
            context.coordinator.mapView = nil
            return
        } else if !isVisible {
            // Nothing to update if not visible
            return
        }
        
        // Update the map view
        if let mapView = context.coordinator.mapView {
            // Set region to match main map
            mapView.setRegion(region, animated: false)
            
            // Clear existing overlays
            mapView.removeOverlays(mapView.overlays)
            
            // Add pollution overlays
            if !pollutionData.isEmpty {
                for point in pollutionData {
                    let level = point.level
                    let coordinate = CLLocationCoordinate2D(latitude: point.lat, longitude: point.lon)
                    
                    // Adjust radius based on pollution level
                    var radius: Double
                    switch level.lowercased() {
                    case "low":
                        radius = 150.0 + (point.position * 100) // 150-250m radius
                    case "medium":
                        radius = 180.0 + (point.position * 120) // 180-300m radius
                    case "high":
                        radius = 200.0 + (point.position * 150) // 200-350m radius
                    default:
                        radius = 150.0 // Default radius
                    }
                    
                    let overlay = CustomPollutionOverlay(
                        center: coordinate,
                        radius: radius,
                        pollutionLevel: level
                    )
                    mapView.addOverlay(overlay)
                }
                print("🔄 Updated pollution overlay with \(pollutionData.count) points")
            }
        }
    }
    
    func makeCoordinator() -> Coordinator {
        Coordinator()
    }
    
    class Coordinator: NSObject, MKMapViewDelegate {
        // Store the mapView to allow updating/removing in updateUIView
        var mapView: MKMapView?
        
        func mapView(_ mapView: MKMapView, rendererFor overlay: MKOverlay) -> MKOverlayRenderer {
            if let pollutionOverlay = overlay as? CustomPollutionOverlay {
                return CustomPollutionOverlayRenderer(overlay: pollutionOverlay)
            } else if let polyline = overlay as? MKPolyline {
                let renderer = MKPolylineRenderer(overlay: polyline)
                renderer.strokeColor = UIColor.systemBlue
                renderer.lineWidth = 3
                return renderer
            }
            
            return MKOverlayRenderer(overlay: overlay)
        }
    }
}

// Duplicated overlay classes for ContentView
class CustomPollutionOverlay: NSObject, MKOverlay {
    let coordinate: CLLocationCoordinate2D
    let boundingMapRect: MKMapRect
    let radius: CLLocationDistance
    let pollutionLevel: String
    
    init(center: CLLocationCoordinate2D, radius: CLLocationDistance, pollutionLevel: String) {
        self.coordinate = center
        self.radius = radius
        self.pollutionLevel = pollutionLevel
        
        // Create bounding rect for the overlay
        let regionRadius = radius * 1.5
        let radiusInMapPoints = regionRadius / MKMapPointsPerMeterAtLatitude(center.latitude)
        let topLeft = MKMapPoint(x: MKMapPoint(coordinate).x - radiusInMapPoints, 
                                y: MKMapPoint(coordinate).y - radiusInMapPoints)
        let size = MKMapSize(width: radiusInMapPoints * 2, height: radiusInMapPoints * 2)
        self.boundingMapRect = MKMapRect(origin: topLeft, size: size)
        
        super.init()
    }
}

class CustomPollutionOverlayRenderer: MKOverlayRenderer {
    let pollutionOverlay: CustomPollutionOverlay
    
    init(overlay: CustomPollutionOverlay) {
        self.pollutionOverlay = overlay
        super.init(overlay: overlay)
    }
    
    override func draw(_ mapRect: MKMapRect, zoomScale: MKZoomScale, in ctx: CGContext) {
        // Get the circle's center point and radius in points
        let mapPoint = MKMapPoint(pollutionOverlay.coordinate)
        let circleCenter = point(for: mapPoint)
        let circleRadius = pollutionOverlay.radius * Double(MKMapPointsPerMeterAtLatitude(pollutionOverlay.coordinate.latitude)) / zoomScale
        
        // Draw only if in visible rect (optimization)
        if !mapRect.contains(mapPoint) && distance(from: mapPoint, to: mapRect) > circleRadius {
            return
        }
        
        // Draw a circle with gradient
        ctx.saveGState()
        
        // Define circle path
        let circlePath = CGMutablePath()
        circlePath.addArc(center: circleCenter, radius: CGFloat(circleRadius), 
                         startAngle: 0, endAngle: CGFloat(2 * Double.pi), clockwise: false)
        ctx.addPath(circlePath)
        
        // Set colors based on pollution level with more distinct colors
        var fillColor: CGColor
        let alpha: CGFloat = 0.7 // Slightly more opaque
        
        switch pollutionOverlay.pollutionLevel.lowercased() {
        case "low":
            fillColor = UIColor.systemGreen.withAlphaComponent(alpha).cgColor
        case "medium":
            fillColor = UIColor.systemOrange.withAlphaComponent(alpha).cgColor
        case "high":
            fillColor = UIColor.systemRed.withAlphaComponent(alpha).cgColor
        default:
            fillColor = UIColor.systemBlue.withAlphaComponent(alpha).cgColor
        }
        
        // Create gradient
        let colorSpace = CGColorSpaceCreateDeviceRGB()
        let colors = [fillColor, UIColor.clear.cgColor] as CFArray
        let locations: [CGFloat] = [0.0, 1.0]
        
        if let gradient = CGGradient(colorsSpace: colorSpace, colors: colors, locations: locations) {
            ctx.drawRadialGradient(gradient, 
                                 startCenter: circleCenter, 
                                 startRadius: 0, 
                                 endCenter: circleCenter, 
                                 endRadius: CGFloat(circleRadius), 
                                 options: .drawsBeforeStartLocation)
        }
        
        ctx.restoreGState()
    }
    
    // Helper method to calculate distance from a point to a rect
    private func distance(from point: MKMapPoint, to rect: MKMapRect) -> Double {
        if rect.contains(point) { return 0 }
        
        let closestX = max(rect.minX, min(point.x, rect.maxX))
        let closestY = max(rect.minY, min(point.y, rect.maxY))
        let closestPoint = MKMapPoint(x: closestX, y: closestY)
        
        return point.distance(to: closestPoint)
    }
} 
 
 