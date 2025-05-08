import Foundation

// Re-export Config to make it accessible throughout the app
@_exported import Foundation

// Config struct - direct implementation to avoid reference issues
public struct Config {
    public struct AWS {
        // Replace these with your actual AWS credentials 
        public static let accessKey = "YOUR_AWS_ACCESS_KEY"
        public static let secretKey = "YOUR_AWS_SECRET_KEY"
        public static let region = "us-east-1"
    }
    
    public struct Bedrock {
        public static let claudeModel = "anthropic.claude-3-sonnet-20240229-v1:0"
        public static let stableDiffusionModel = "stability.stable-diffusion-xl-v1"
    }
} 