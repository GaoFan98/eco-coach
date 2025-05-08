@_exported import Foundation
@_exported import UIKit

// Route insights models
struct RouteInsight: Codable {
    let title: String
    let description: String
}

struct RouteInsightsResponse: Codable {
    let insights: [RouteInsight]
}

// Pollution forecast models
struct PollutionPoint: Codable {
    let position: Double
    let level: String
    let lat: Double
    let lon: Double
}

struct PollutionForecastResponse: Codable {
    let imageBase64: String
    let pollutionData: [PollutionPoint]
}

// Route story models
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

// Core route data model
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