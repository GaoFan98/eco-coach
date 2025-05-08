import Foundation
import UIKit
import Combine
import CryptoKit

struct RouteInsight: Codable {
    let title: String
    let description: String
}

struct RouteInsightsResponse: Codable {
    let insights: [RouteInsight]
}

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

// Bedrock API request and response structures
struct ClaudeMessage: Codable {
    let role: String
    let content: [ClaudeContent]
}

struct ClaudeContent: Codable {
    let type: String
    let text: String
}

struct ClaudeRequest: Codable {
    let anthropic_version: String
    let max_tokens: Int
    let messages: [ClaudeMessage]
}

struct ClaudeResponse: Codable {
    let content: [ClaudeContent]
}

struct StableDiffusionTextPrompt: Codable {
    let text: String
    let weight: Double
}

struct StableDiffusionRequest: Codable {
    let text_prompts: [StableDiffusionTextPrompt]
    let cfg_scale: Double
    let steps: Int
    let width: Int
    let height: Int
}

struct StableDiffusionArtifact: Codable {
    let base64: String
}

struct StableDiffusionResponse: Codable {
    let artifacts: [StableDiffusionArtifact]
}

class AWSServiceClass {
    
    // Bedrock model IDs
    private let claudeModelId: String
    private let stableDiffusionModelId: String
    
    // AWS credentials - to be loaded from secure storage
    private var accessKey: String
    private var secretKey: String
    private var region: String
    
    private var cancellables = Set<AnyCancellable>()
    
    init() {
        // Load credentials from Config
        self.accessKey = Config.AWS.accessKey
        self.secretKey = Config.AWS.secretKey
        self.region = Config.AWS.region
        
        self.claudeModelId = Config.Bedrock.claudeModel
        self.stableDiffusionModelId = Config.Bedrock.stableDiffusionModel
    }
    
    // MARK: - Direct Bedrock API Calls
    
    private func callClaudeAPI(prompt: String) -> AnyPublisher<String, Error> {
        // Create Claude request
        let request = ClaudeRequest(
            anthropic_version: "bedrock-2023-05-31",
            max_tokens: 1000,
            messages: [
                ClaudeMessage(
                    role: "user",
                    content: [ClaudeContent(type: "text", text: prompt)]
                )
            ]
        )
        
        // Convert to JSON
        guard let requestData = try? JSONEncoder().encode(request) else {
            return Fail(error: NSError(domain: "AWSService", code: 1, userInfo: [NSLocalizedDescriptionKey: "Failed to encode request"]))
                .eraseToAnyPublisher()
        }
        
        // Create Bedrock request
        let endpoint = "https://bedrock-runtime.\(region).amazonaws.com/model/\(claudeModelId)/invoke"
        guard let url = URL(string: endpoint) else {
            return Fail(error: URLError(.badURL)).eraseToAnyPublisher()
        }
        
        var urlRequest = URLRequest(url: url)
        urlRequest.httpMethod = "POST"
        urlRequest.httpBody = requestData
        urlRequest.setValue("application/json", forHTTPHeaderField: "Content-Type")
        
        // Sign request with AWS SigV4
        let date = ISO8601DateFormatter().string(from: Date())
        signRequest(&urlRequest, date: date)
        
        // Make the request
        return URLSession.shared.dataTaskPublisher(for: urlRequest)
            .tryMap { data, response in
                guard let httpResponse = response as? HTTPURLResponse, 
                      (200...299).contains(httpResponse.statusCode) else {
                    let responseText = String(data: data, encoding: .utf8) ?? "Unknown error"
                    throw NSError(domain: "BedrockAPI", code: 2, userInfo: [NSLocalizedDescriptionKey: "API Error: \(responseText)"])
                }
                return data
            }
            .decode(type: ClaudeResponse.self, decoder: JSONDecoder())
            .map { $0.content[0].text }
            .eraseToAnyPublisher()
    }
    
    private func callStableDiffusionAPI(prompt: String) -> AnyPublisher<String, Error> {
        // Create Stable Diffusion request
        let request = StableDiffusionRequest(
            text_prompts: [
                StableDiffusionTextPrompt(text: prompt, weight: 1.0)
            ],
            cfg_scale: 8.0,
            steps: 50,
            width: 1024,
            height: 1024
        )
        
        // Convert to JSON
        guard let requestData = try? JSONEncoder().encode(request) else {
            return Fail(error: NSError(domain: "AWSService", code: 1, userInfo: [NSLocalizedDescriptionKey: "Failed to encode request"]))
                .eraseToAnyPublisher()
        }
        
        // Create Bedrock request
        let endpoint = "https://bedrock-runtime.\(region).amazonaws.com/model/\(stableDiffusionModelId)/invoke"
        guard let url = URL(string: endpoint) else {
            return Fail(error: URLError(.badURL)).eraseToAnyPublisher()
        }
        
        var urlRequest = URLRequest(url: url)
        urlRequest.httpMethod = "POST"
        urlRequest.httpBody = requestData
        urlRequest.setValue("application/json", forHTTPHeaderField: "Content-Type")
        
        // Sign request with AWS SigV4
        let date = ISO8601DateFormatter().string(from: Date())
        signRequest(&urlRequest, date: date)
        
        // Make the request
        return URLSession.shared.dataTaskPublisher(for: urlRequest)
            .tryMap { data, response in
                guard let httpResponse = response as? HTTPURLResponse, 
                      (200...299).contains(httpResponse.statusCode) else {
                    let responseText = String(data: data, encoding: .utf8) ?? "Unknown error"
                    throw NSError(domain: "BedrockAPI", code: 2, userInfo: [NSLocalizedDescriptionKey: "API Error: \(responseText)"])
                }
                return data
            }
            .decode(type: StableDiffusionResponse.self, decoder: JSONDecoder())
            .map { $0.artifacts[0].base64 }
            .eraseToAnyPublisher()
    }
    
    // AWS SigV4 signing helper using CryptoKit
    private func signRequest(_ request: inout URLRequest, date: String) {
        let amzDate = date.replacingOccurrences(of: "-", with: "").replacingOccurrences(of: ":", with: "")
        let dateStamp = String(amzDate.prefix(8))
        
        request.setValue(amzDate, forHTTPHeaderField: "X-Amz-Date")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        
        // Service and region
        let service = "bedrock"
        
        // Calculate the canonical request and signature
        let canonicalURI = request.url?.path ?? "/"
        let canonicalQueryString = request.url?.query ?? ""
        
        let canonicalHeaders = "content-type:application/json\nhost:\(request.url?.host ?? "")\nx-amz-date:\(amzDate)\n"
        let signedHeaders = "content-type;host;x-amz-date"
        
        // Calculate the payload hash
        let payloadHash = request.httpBody.map { 
            SHA256.hash(data: $0).compactMap { String(format: "%02x", $0) }.joined() 
        } ?? "e3b0c44298fc1c149afbf4c8996fb92427ae41e4649b934ca495991b7852b855" // Empty string hash
        
        let canonicalRequest = [
            request.httpMethod ?? "GET",
            canonicalURI,
            canonicalQueryString,
            canonicalHeaders,
            signedHeaders,
            payloadHash
        ].joined(separator: "\n")
        
        let canonicalRequestHash = SHA256.hash(data: canonicalRequest.data(using: .utf8)!)
            .compactMap { String(format: "%02x", $0) }.joined()
        
        // Create string to sign
        let algorithm = "AWS4-HMAC-SHA256"
        let credentialScope = "\(dateStamp)/\(region)/\(service)/aws4_request"
        let stringToSign = [
            algorithm,
            amzDate,
            credentialScope,
            canonicalRequestHash
        ].joined(separator: "\n")
        
        // Calculate the signature
        func hmac(data: Data, key: Data) -> Data {
            let symmetricKey = SymmetricKey(data: key)
            let signature = HMAC<SHA256>.authenticationCode(for: data, using: symmetricKey)
            return Data(signature)
        }
        
        // Generate the signing key
        let kDate = hmac(data: dateStamp.data(using: .utf8)!, key: "AWS4\(secretKey)".data(using: .utf8)!)
        let kRegion = hmac(data: region.data(using: .utf8)!, key: kDate)
        let kService = hmac(data: service.data(using: .utf8)!, key: kRegion)
        let kSigning = hmac(data: "aws4_request".data(using: .utf8)!, key: kService)
        
        let signature = hmac(data: stringToSign.data(using: .utf8)!, key: kSigning)
            .compactMap { String(format: "%02x", $0) }.joined()
        
        // Add the Auth header
        let authHeader = "\(algorithm) Credential=\(accessKey)/\(credentialScope), SignedHeaders=\(signedHeaders), Signature=\(signature)"
        request.setValue(authHeader, forHTTPHeaderField: "Authorization")
    }
    
    // MARK: - Feature implementations with real API calls
    
    func getRouteInsights(routeData: RouteInfo) -> AnyPublisher<RouteInsightsResponse, Error> {
        // Create Claude prompt for route insights
        let prompt = """
        You are EcoCoach, an AI health assistant specialized in air pollution and its health effects.
        
        Analyze this eco-friendly route data and provide personalized health insights about pollution exposure:
        - Route distance: \(routeData.distance) km
        - Estimated time: \(routeData.estimatedTime) minutes
        - Pollution exposure level: \(routeData.pollutionExposure)
        
        Generate 3 short, specific health insights about:
        1. Immediate health benefits from taking this less-polluted route
        2. Long-term health benefits from consistently choosing eco-friendly routes
        3. One actionable tip for further reducing pollution exposure while traveling
        
        Format the response as JSON with the following structure:
        {
            "insights": [
                { "title": "Short-term Benefit", "description": "..." },
                { "title": "Long-term Benefit", "description": "..." },
                { "title": "Health Tip", "description": "..." }
            ]
        }
        
        Keep each insight under 30 words, practical and informative.
        """
        
        return callClaudeAPI(prompt: prompt)
            .tryMap { responseText -> RouteInsightsResponse in
                // Try to parse the JSON response
                if let jsonData = responseText.data(using: .utf8),
                   let response = try? JSONDecoder().decode(RouteInsightsResponse.self, from: jsonData) {
                    return response
                }
                
                // If parsing fails, extract JSON from the text using regex or other methods
                if let jsonStart = responseText.range(of: "{"),
                   let jsonEnd = responseText.range(of: "}", options: .backwards),
                   jsonStart.upperBound <= jsonEnd.lowerBound {
                    let jsonString = responseText[jsonStart.lowerBound...jsonEnd.upperBound]
                    if let jsonData = String(jsonString).data(using: .utf8),
                       let response = try? JSONDecoder().decode(RouteInsightsResponse.self, from: jsonData) {
                        return response
                    }
                }
                
                // If all parsing fails, use mock data
                throw NSError(domain: "JSONParsing", code: 3, userInfo: [NSLocalizedDescriptionKey: "Failed to parse Claude response"])
            }
            .catch { error -> AnyPublisher<RouteInsightsResponse, Error> in
                // Fallback to mock insights if API call or parsing fails
                print("Error in route insights: \(error)")
                let mockInsights = [
                    RouteInsight(title: "Short-term Benefit", description: "Reduced coughing and throat irritation during your trip."),
                    RouteInsight(title: "Long-term Benefit", description: "Lower risk of respiratory conditions from consistent low-pollution routes."),
                    RouteInsight(title: "Health Tip", description: "Travel during early morning when pollution levels are typically lower.")
                ]
                
                let mockResponse = RouteInsightsResponse(insights: mockInsights)
                return Just(mockResponse)
                    .setFailureType(to: Error.self)
                    .eraseToAnyPublisher()
            }
            .eraseToAnyPublisher()
    }
    
    func getPollutionForecast(routeData: RouteInfo, startLat: Double, startLon: Double, endLat: Double, endLon: Double) -> AnyPublisher<PollutionForecastResponse, Error> {
        // Create Stable Diffusion prompt for pollution heatmap
        let timeOfDay = getCurrentTimeOfDay()
        
        let imagePrompt = """
        Create a realistic air pollution heatmap overlay for a map showing predicted pollution levels. 
        The image should show a gradient of color representing air pollution concentration 
        (green for low, yellow for medium, red for high).
        
        Location details:
        - Urban area: urban area
        - Time of day: \(timeOfDay)
        - Weather: clear
        - Route coordinates: from (\(startLat), \(startLon)) to (\(endLat), \(endLon))
        
        Create a top-down view showing pollution concentration as a smooth heatmap overlay.
        Main roads should have higher pollution (orange/red), while parks and open areas should be greener.
        The background should be very subtle/transparent - focus on creating a clean overlay that could go on a map.
        """
        
        let pollutionDataPrompt = """
        Based on the following route and environmental factors, generate pollution level data for different points along the route:
        
        - Urban area: urban area
        - Time of day: \(timeOfDay)
        - Weather: clear
        - Route coordinates: from (\(startLat), \(startLon)) to (\(endLat), \(endLon))
        
        Provide pollution levels (Low, Medium, High) for 5 points along the route as JSON:
        
        Return ONLY the JSON array in this format without any other text:
        [
          {"position": 0, "level": "Medium", "lat": \(startLat), "lon": \(startLon)},
          {"position": 0.25, "level": "Low", "lat": \(startLat + (endLat - startLat) * 0.25), "lon": \(startLon + (endLon - startLon) * 0.25)},
          ...etc for 5 points total
        ]
        """
        
        // First get the image
        let imagePublisher = callStableDiffusionAPI(prompt: imagePrompt)
            .catch { error -> AnyPublisher<String, Error> in
                print("Error generating pollution heatmap image: \(error)")
                return Just("").setFailureType(to: Error.self).eraseToAnyPublisher()
            }
        
        // Then get the pollution data
        let dataPublisher = callClaudeAPI(prompt: pollutionDataPrompt)
            .tryMap { responseText -> [PollutionPoint] in
                // Try to parse the JSON response
                if let jsonData = responseText.data(using: .utf8),
                   let response = try? JSONDecoder().decode([PollutionPoint].self, from: jsonData) {
                    return response
                }
                
                // If parsing fails, extract JSON from the text
                if let jsonStart = responseText.range(of: "["),
                   let jsonEnd = responseText.range(of: "]", options: .backwards),
                   jsonStart.upperBound <= jsonEnd.lowerBound {
                    let jsonString = responseText[jsonStart.lowerBound...jsonEnd.upperBound]
                    if let jsonData = String(jsonString).data(using: .utf8),
                       let response = try? JSONDecoder().decode([PollutionPoint].self, from: jsonData) {
                        return response
                    }
                }
                
                // If all parsing fails, throw an error
                throw NSError(domain: "JSONParsing", code: 3, userInfo: [NSLocalizedDescriptionKey: "Failed to parse Claude pollution data response"])
            }
            .catch { error -> AnyPublisher<[PollutionPoint], Error> in
                // Fallback to mock data if API call or parsing fails
                print("Error in pollution data: \(error)")
                let mockData = [
                    PollutionPoint(position: 0, level: "Medium", lat: startLat, lon: startLon),
                    PollutionPoint(position: 0.25, level: "Low", lat: startLat + (endLat - startLat) * 0.25, lon: startLon + (endLon - startLon) * 0.25),
                    PollutionPoint(position: 0.5, level: "Low", lat: startLat + (endLat - startLat) * 0.5, lon: startLon + (endLon - startLon) * 0.5),
                    PollutionPoint(position: 0.75, level: "Medium", lat: startLat + (endLat - startLat) * 0.75, lon: startLon + (endLon - startLon) * 0.75),
                    PollutionPoint(position: 1, level: "High", lat: endLat, lon: endLon)
                ]
                return Just(mockData)
                    .setFailureType(to: Error.self)
                    .eraseToAnyPublisher()
            }
        
        // Combine both results
        return Publishers.Zip(imagePublisher, dataPublisher)
            .map { imageBase64, pollutionData -> PollutionForecastResponse in
                return PollutionForecastResponse(
                    imageBase64: imageBase64,
                    pollutionData: pollutionData
                )
            }
            .eraseToAnyPublisher()
    }
    
    func getRouteStory(routeData: RouteInfo) -> AnyPublisher<RouteStoryResponse, Error> {
        // Calculate avoided pollutants based on distance and pollution level
        let co2Grams = routeData.distance * 280  // approx. CO2 saved vs. car
        
        // A coefficient to adjust particulate matter avoided based on pollution level
        var pmCoefficient = 1.0
        if routeData.pollutionExposure == "Low" {
            pmCoefficient = 0.3
        } else if routeData.pollutionExposure == "Medium" {
            pmCoefficient = 0.6
        }
        
        let pmAvoided = routeData.distance * 0.2 * pmCoefficient  // PM2.5 in grams
        
        // Create Claude prompt for route story
        let prompt = """
        Create an inspiring, shareable route story for a cyclist/walker who just completed an eco-friendly route.
        
        Route details:
        - Distance: \(routeData.distance) km
        - Duration: \(routeData.estimatedTime) minutes
        - Pollution exposure: \(routeData.pollutionExposure)
        - Estimated CO2 emissions avoided: \(co2Grams) grams
        - Estimated particulate matter avoided: \(String(format: "%.2f", pmAvoided)) grams
        
        Create a brief, compelling story (max 100 words) about their journey that highlights:
        1. Environmental impact (CO2 saved)
        2. Health benefits (reduced pollution exposure)
        3. A motivational element to encourage more eco-friendly travel
        
        Format the response as JSON with the following structure:
        {
            "title": "A catchy, positive title",
            "story": "The main story text...",
            "stats": [
                { "label": "CO2 Saved", "value": "\(Int(co2Grams))g" },
                { "label": "PM2.5 Avoided", "value": "\(String(format: "%.2f", pmAvoided))g" },
                { "label": "Health Impact", "value": "Positive phrase" }
            ],
            "shareText": "A short, engaging text perfect for social media sharing"
        }
        
        Make it inspiring, positive and personal.
        """
        
        return callClaudeAPI(prompt: prompt)
            .tryMap { responseText -> RouteStoryResponse in
                // Try to parse the JSON response
                if let jsonData = responseText.data(using: .utf8),
                   let response = try? JSONDecoder().decode(RouteStoryResponse.self, from: jsonData) {
                    return response
                }
                
                // If parsing fails, extract JSON from the text
                if let jsonStart = responseText.range(of: "{"),
                   let jsonEnd = responseText.range(of: "}", options: .backwards),
                   jsonStart.upperBound <= jsonEnd.lowerBound {
                    let jsonString = responseText[jsonStart.lowerBound...jsonEnd.upperBound]
                    if let jsonData = String(jsonString).data(using: .utf8),
                       let response = try? JSONDecoder().decode(RouteStoryResponse.self, from: jsonData) {
                        return response
                    }
                }
                
                // If all parsing fails, throw an error
                throw NSError(domain: "JSONParsing", code: 3, userInfo: [NSLocalizedDescriptionKey: "Failed to parse Claude route story response"])
            }
            .catch { error -> AnyPublisher<RouteStoryResponse, Error> in
                // Fallback to mock response if API call or parsing fails
                print("Error in route story: \(error)")
                let mockResponse = RouteStoryResponse(
                    title: "Eco-Warrior's Journey",
                    story: "Today you chose a path less traveled, reducing your CO2 emissions by \(Int(co2Grams))g and breathing in 15% less pollution. Small choices like these add up to big impacts for both your health and our planet.",
                    stats: [
                        RouteStatItem(label: "CO2 Saved", value: "\(Int(co2Grams))g"),
                        RouteStatItem(label: "PM2.5 Avoided", value: "\(String(format: "%.2f", pmAvoided))g"),
                        RouteStatItem(label: "Health Impact", value: "Positive")
                    ],
                    shareText: "I just saved \(Int(co2Grams))g of CO2 and reduced my pollution exposure by choosing an eco-friendly route with EcoCoach!"
                )
                return Just(mockResponse)
                    .setFailureType(to: Error.self)
                    .eraseToAnyPublisher()
            }
            .eraseToAnyPublisher()
    }
    
    private func getCurrentTimeOfDay() -> String {
        let hour = Calendar.current.component(.hour, from: Date())
        
        switch hour {
        case 5..<11:
            return "morning"
        case 11..<17:
            return "afternoon"
        case 17..<21:
            return "evening"
        default:
            return "night"
        }
    }
    
    func decodeBase64Image(_ base64String: String) -> UIImage? {
        guard let data = Data(base64Encoded: base64String) else { return nil }
        return UIImage(data: data)
    }
} 