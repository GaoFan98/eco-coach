import Foundation

// This class ensures that Config.swift is included in the build
class ConfigImporter {
    // Place your AWS credentials directly here
    struct AwsConfig {
        static let accessKey = "AKIARYEUCVA4XQ6O4XT6"
        static let secretKey = "fMAz3hyA5wWMZ3CeMKwMlaCYKXgrGg8lAj02" 
        static let region = "us-east-1"
    }
    
    struct BedrockConfig {
        static let claudeModel = "anthropic.claude-3-sonnet-20240229-v1:0"
        static let stableDiffusionModel = "stability.stable-diffusion-xl-v1"
    }
}
