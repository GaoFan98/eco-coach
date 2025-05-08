import Foundation
import MapKit
import SwiftUI

// Custom overlay item that represents a pollution point
class PollutionOverlay: NSObject, MKOverlay {
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

// Custom renderer for pollution overlays
class PollutionOverlayRenderer: MKOverlayRenderer {
    let pollutionOverlay: PollutionOverlay
    
    init(overlay: PollutionOverlay) {
        self.pollutionOverlay = overlay
        super.init(overlay: overlay)
    }
    
    override func draw(_ mapRect: MKMapRect, zoomScale: MKZoomScale, in ctx: CGContext) {
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

// Extension to add pollution overlays to MKMapView
extension MKMapView {
    func addPollutionOverlays(from pollutionData: [PollutionPoint]) {
        // Remove existing pollution overlays
        let existingOverlays = overlays.filter { $0 is PollutionOverlay }
        removeOverlays(existingOverlays)
        
        // Add new pollution overlays
        let newOverlays = pollutionData.map { point -> PollutionOverlay in
            // Create an overlay for each point with radius based on significance
            // Higher radius for more significant points, but cap at reasonable size
            var radius: Double
            
            switch point.level.lowercased() {
            case "low":
                radius = 150.0 + (point.position * 100) // 150-250m radius
            case "medium":
                radius = 180.0 + (point.position * 120) // 180-300m radius
            case "high":
                radius = 200.0 + (point.position * 150) // 200-350m radius
            default:
                radius = 150.0 // Default radius
            }
            
            return PollutionOverlay(
                center: CLLocationCoordinate2D(latitude: point.lat, longitude: point.lon),
                radius: radius,
                pollutionLevel: point.level
            )
        }
        
        print("📍 Adding \(newOverlays.count) pollution overlays to map")
        addOverlays(newOverlays)
    }
} 