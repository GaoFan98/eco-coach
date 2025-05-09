# Eco-Coach: Pollution-Minimizing Route Planner

An eco-friendly cycling/walking route optimizer that minimizes your exposure to air pollution, powered by AWS Generative AI.

## Features

- Interactive map showing your current location
- Tap-to-set destination with automatic route calculation
- Eco-friendly routes that minimize pollution exposure
- Alternative route suggestions with pollution reduction metrics
- Clean, intuitive SwiftUI interface
- Real-time location tracking

## AI-Powered Features

- **Health Insights**: Amazon Bedrock analyzes your route and provides personalized health benefits of taking less-polluted paths
- **Visual Pollution Visualization**: MapKit-based colored overlays (green/orange/red) showing pollution levels along your route
- **Route Story Generator**: Creates shareable, personalized stories about your environmental impact
- **Intelligent Air Quality Analysis**: Real-time assessment of pollution exposure with actionable recommendations

## Technology Stack

- **Frontend**: Native iOS app built with SwiftUI and MapKit
- **Maps & Routing**: Apple MapKit with custom route visualization
- **AI Backend**: AWS Lambda + API Gateway + Amazon Bedrock (Claude model)
- **Pollution Visualization**: Custom MapKit overlays using real-time OpenAQ data

## AWS Services Used

- **Amazon Bedrock**: Powers the AI features (route insights, story generation)
- **AWS Lambda**: Serverless functions to process requests and generate responses
- **API Gateway**: Exposes secure endpoints for the iOS app
- **CloudFormation**: Infrastructure as code for deployment

## Getting Started

### Prerequisites

- Xcode 14.0 or later
- iOS 16.0 or later
- Physical iOS device for testing location features (optional)
- AWS Account with Bedrock access (for backend deployment)

### Running the App

1. Open the project in Xcode:
```bash
cd ios-app
open EcoCoach.xcodeproj
```

2. Select your target device (simulator or physical device)
3. Click the Run button or press Cmd+R
4. The app will launch and request location permissions

### Deploying the AWS Backend

1. Install the AWS SAM CLI
2. Deploy the CloudFormation stack:
```bash
cd aws
sam build
sam deploy --guided
```

3. Update the `baseURL` in `AWSService.swift` with your API Gateway URL

### Using the App

1. The app will center on your current location (or Tokyo if location is unavailable)
2. Tap anywhere on the map to set a destination
3. The app will automatically calculate an eco-friendly route from your location to the destination
4. View route details showing distance, time, and pollution exposure
5. Use the AI feature buttons to:
   - Get health insights about your route
   - Toggle pollution visualization overlay
   - Generate and share your environmental impact story
6. Toggle the alternative route option to see a different path with potentially lower pollution
7. Press "Zoom to Route" to view the entire route
8. Press "Reset" to clear the route and start over

## Real-world Impact

The Eco-Coach app delivers measurable real-world impact:

- **Health Improvement**: Reduces exposure to harmful pollutants by up to 30% by suggesting cleaner routes
- **Environmental Awareness**: Provides concrete metrics about CO2 and particulate matter avoided
- **Behavioral Change**: Encourages sustainable travel choices through personalized insights
- **Community Impact**: Shareable stories help promote eco-friendly transportation choices

## Screenshots
App overview

![image](https://github.com/user-attachments/assets/0c0ca736-2738-43a5-b3ae-2111e754d9e5)

![image](https://github.com/user-attachments/assets/9c3f36aa-c075-4c8f-8a9f-e356f8abcd0a)

![image](https://github.com/user-attachments/assets/0248d5a7-1e07-4995-b0f5-5b43dd40c9f8)

![image](https://github.com/user-attachments/assets/ee4a7b6e-1f1d-4837-b6a3-3d84738b30d5)

Features demo videos

https://github.com/user-attachments/assets/cca82839-1609-4789-ba4f-4867e67b3a51

https://github.com/user-attachments/assets/3da3d990-7f0c-42a2-b6b9-94c955ea4426


