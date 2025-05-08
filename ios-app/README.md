# Eco-Coach iOS App

A native iOS application for the Eco-Coach project, providing eco-friendly cycling routes in Tokyo that minimize air pollution exposure.

## Features

- Interactive MapKit map centered on Tokyo
- Real-time user location tracking
- Tap to set destinations
- Calculate eco-friendly routes that minimize pollution exposure
- Display route information (distance, time, pollution level)
- Clean, intuitive SwiftUI interface

## Requirements

- Xcode 14+ (recommended Xcode 15+)
- iOS 16.0+
- macOS Ventura or later
- Active Apple Developer account (for device testing)

## Getting Started

### Running in the iOS Simulator

1. Start the backend services:
   ```bash
   cd ..  # Go to the project root
   docker compose up -d postgres route-generator route-serve tile-edge tile-server
   ```

2. Open the Xcode project:
   ```bash
   open ios-app/EcoCoach.xcodeproj
   ```

3. In Xcode:
   - Select your target device (iPhone simulator)
   - Press the Run button (⌘+R)

### Running on a Physical Device

1. Start the backend services with your local IP address:
   ```bash
   cd ..  # Go to the project root
   docker compose up -d postgres route-generator route-serve tile-edge tile-server
   ```

2. Open the Xcode project:
   ```bash
   open ios-app/EcoCoach.xcodeproj
   ```

3. In Xcode:
   - Update the API URL in ContentView.swift to use your local network IP address
   - Select your physical device from the device dropdown
   - Sign the app with your development team
   - Press the Run button (⌘+R)

## Using the App

1. When the app launches, it will request permission to access your location
2. The map will center on your location (or on Tokyo if you're not in Tokyo)
3. Tap anywhere on the map to set a destination
4. Tap the "Calculate Eco-Friendly Route" button
5. The app will display the optimized route and information about:
   - Distance
   - Estimated time
   - Pollution exposure level
6. Tap "Reset" to choose a new destination

## Troubleshooting

- If the app can't connect to the backend services, it will use mock data for demonstration
- Ensure your firewall allows connections to the backend ports (3000, 5001, 8080)
- For physical devices, make sure your phone and computer are on the same network 