import SwiftUI
import MapKit

struct PollutionForecastView: View {
    @State private var mapRegion: MKCoordinateRegion
    let pollutionData: [PollutionPoint]
    @Binding var isPresented: Bool
    
    // Filter pollution data to only show main route points
    private var filteredPollutionData: [PollutionPoint] {
        // Create a dictionary to store unique positions
        var uniquePositions: [Double: PollutionPoint] = [:]
        
        // For each point, only keep the first one found for each position value
        for point in pollutionData {
            if uniquePositions[point.position] == nil {
                uniquePositions[point.position] = point
            }
        }
        
        // Sort by position (0% to 100% along route)
        return uniquePositions.values.sorted { $0.position < $1.position }
    }
    
    init(pollutionData: [PollutionPoint], isPresented: Binding<Bool>) {
        self._isPresented = isPresented
        self.pollutionData = pollutionData
        
        // Calculate the center and span for the region
        if let firstPoint = pollutionData.first, let lastPoint = pollutionData.last {
            let centerLat = (firstPoint.lat + lastPoint.lat) / 2
            let centerLon = (firstPoint.lon + lastPoint.lon) / 2
            
            let latDelta = abs(firstPoint.lat - lastPoint.lat) * 1.5 // Add 50% padding
            let lonDelta = abs(firstPoint.lon - lastPoint.lon) * 1.5
            
            // Ensure minimum span
            let finalLatDelta = max(latDelta, 0.02)
            let finalLonDelta = max(lonDelta, 0.02)
            
            self._mapRegion = State(initialValue: MKCoordinateRegion(
                center: CLLocationCoordinate2D(latitude: centerLat, longitude: centerLon),
                span: MKCoordinateSpan(latitudeDelta: finalLatDelta, longitudeDelta: finalLonDelta)
            ))
        } else {
            // Default region if no points
            self._mapRegion = State(initialValue: MKCoordinateRegion(
                center: CLLocationCoordinate2D(latitude: 37.7749, longitude: -122.4194), // San Francisco
                span: MKCoordinateSpan(latitudeDelta: 0.05, longitudeDelta: 0.05)
            ))
        }
    }
    
    var body: some View {
        VStack(spacing: 16) {
            HStack {
                Text("Pollution Forecast")
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
            
            // Map view with pollution overlays
            MapViewWithOverlays(region: $mapRegion, pollutionData: pollutionData)
                .frame(height: 300)
                .cornerRadius(12)
                .overlay(
                    RoundedRectangle(cornerRadius: 12)
                        .stroke(Color.gray.opacity(0.3), lineWidth: 1)
                )
                .padding(.horizontal, 4) // Give it some space
            
            VStack(alignment: .leading, spacing: 8) {
                Text("Pollution Levels")
                    .font(.subheadline)
                    .fontWeight(.semibold)
                
                ForEach(filteredPollutionData) { point in
                    HStack {
                        Circle()
                            .fill(getPollutionColor(point.level))
                            .frame(width: 12, height: 12)
                        
                        Text("Point \(Int(point.position * 100))%")
                            .font(.caption)
                        
                        Spacer()
                        
                        Text(point.level)
                            .font(.caption)
                            .foregroundColor(getPollutionColor(point.level))
                            .fontWeight(.semibold)
                    }
                    .padding(.vertical, 4)
                }
            }
            .padding()
            .background(Color(UIColor.systemGray6))
            .cornerRadius(12)
            
            Text("Best times to travel: Early morning or late evening")
                .font(.caption)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
                .padding(.top, 8)
        }
        .padding()
        .background(Color.white)
        .cornerRadius(20)
        .shadow(radius: 10)
        .padding()
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
            return .gray
        }
    }
}

// Map view with overlays
struct MapViewWithOverlays: UIViewRepresentable {
    @Binding var region: MKCoordinateRegion
    let pollutionData: [PollutionPoint]
    
    func makeUIView(context: Context) -> MKMapView {
        let mapView = MKMapView()
        mapView.delegate = context.coordinator
        mapView.mapType = .standard
        print("🗺️ Creating map view with \(pollutionData.count) pollution points")
        return mapView
    }
    
    func updateUIView(_ mapView: MKMapView, context: Context) {
        mapView.setRegion(region, animated: true)
        
        // Clear existing overlays first
        mapView.removeOverlays(mapView.overlays)
        
        // Filter out points that are too close to each other to avoid clutter on the map
        let filteredPoints = filterDuplicateCoordinates(pollutionData)
        
        // Add pollution overlays
        mapView.addPollutionOverlays(from: filteredPoints)
        print("🔴 Added \(filteredPoints.count) filtered pollution overlays to map")
        
        // Add route points as a polyline
        if filteredPoints.count > 1 {
            // Get the main points (unique positions)
            let uniquePositions = Dictionary(grouping: filteredPoints, by: { $0.position })
                .compactMap { $0.value.first }
                .sorted { $0.position < $1.position }
            
            var coordinates = uniquePositions.map { 
                CLLocationCoordinate2D(latitude: $0.lat, longitude: $0.lon) 
            }
            
            if coordinates.count > 1 {
                let polyline = MKPolyline(coordinates: &coordinates, count: coordinates.count)
                mapView.addOverlay(polyline)
                print("📍 Added route polyline to map with \(coordinates.count) points")
            }
        }
    }
    
    // Filter out points that are too close to each other
    private func filterDuplicateCoordinates(_ points: [PollutionPoint]) -> [PollutionPoint] {
        // If we have very few points, don't filter
        if points.count < 10 {
            return points
        }
        
        // For larger datasets, keep the main route points (one per position)
        // and a subset of the offset points
        var result: [PollutionPoint] = []
        let uniquePositions = Dictionary(grouping: points, by: { $0.position })
        
        for (_, pointsWithSamePosition) in uniquePositions {
            // Always keep the first point (main route point)
            if let mainPoint = pointsWithSamePosition.first {
                result.append(mainPoint)
                
                // For offset points, only keep a subset to reduce visual clutter
                if pointsWithSamePosition.count > 1 {
                    // Add up to 2 more offset points if available
                    let additionalPoints = Array(pointsWithSamePosition.dropFirst().prefix(2))
                    result.append(contentsOf: additionalPoints)
                }
            }
        }
        
        return result
    }
    
    func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }
    
    class Coordinator: NSObject, MKMapViewDelegate {
        var parent: MapViewWithOverlays
        
        init(_ parent: MapViewWithOverlays) {
            self.parent = parent
        }
        
        func mapView(_ mapView: MKMapView, rendererFor overlay: MKOverlay) -> MKOverlayRenderer {
            if let pollutionOverlay = overlay as? PollutionOverlay {
                print("🎨 Rendering PollutionOverlay with level: \(pollutionOverlay.pollutionLevel)")
                return PollutionOverlayRenderer(overlay: pollutionOverlay)
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

struct PollutionForecastView_Previews: PreviewProvider {
    static var previews: some View {
        PollutionForecastView(
            pollutionData: [
                PollutionPoint(position: 0, level: "Medium", lat: 35.6895, lon: 139.6917),
                PollutionPoint(position: 0.25, level: "Low", lat: 35.6890, lon: 139.6920),
                PollutionPoint(position: 0.5, level: "Low", lat: 35.6885, lon: 139.6925),
                PollutionPoint(position: 0.75, level: "Medium", lat: 35.6880, lon: 139.6930),
                PollutionPoint(position: 1, level: "High", lat: 35.6875, lon: 139.6935)
            ],
            isPresented: .constant(true)
        )
    }
} 