# Eco-Coach: Pollution-Minimizing Route Planner

An eco-friendly cycling/walking route optimizer that minimizes your exposure to air pollution.

## Features

- Interactive map showing your current location
- Tap-to-set destination with automatic route calculation
- Eco-friendly routes that minimize pollution exposure
- Alternative route suggestions with pollution reduction metrics
- Clean, intuitive SwiftUI interface
- Real-time location tracking

## Technology Stack

- **Frontend**: Native iOS app built with SwiftUI and MapKit
- **Maps & Routing**: Apple MapKit with custom route visualization
- **Navigation**: Real-time cycling/walking directions with pollution awareness

## Getting Started

### Prerequisites

- Xcode 14.0 or later
- iOS 16.0 or later
- Physical iOS device for testing location features (optional)

### Running the App

1. Open the project in Xcode:
```bash
cd ios-app
open EcoCoach.xcodeproj
```

2. Select your target device (simulator or physical device)
3. Click the Run button or press Cmd+R
4. The app will launch and request location permissions

### Using the App

1. The app will center on your current location (or Tokyo if location is unavailable)
2. Tap anywhere on the map to set a destination
3. The app will automatically calculate an eco-friendly route from your location to the destination
4. View route details showing distance, time, and pollution exposure
5. Toggle the alternative route option to see a different path with potentially lower pollution
6. Press "Zoom to Route" to view the entire route
7. Press "Reset" to clear the route and start over

## App Architecture

The app is structured with a clean architecture:

- **Location Management**: Custom location manager for real-time position updates
- **Map Interaction**: Interactive map with custom overlays for routes
- **Route Generation**: Integration with MapKit's route planning with custom eco-awareness
- **UI Components**: Clean SwiftUI interface with dynamic information panels

## Future Enhancements

Potential future enhancements include:

- Integration with real pollution data sources via APIs
- Machine learning models to predict pollution patterns
- User accounts to save favorite routes
- Historical tracking of pollution exposure
- Integration with health apps to monitor respiratory impact

## Screenshots

*Screenshots of the app in action would be included here* 