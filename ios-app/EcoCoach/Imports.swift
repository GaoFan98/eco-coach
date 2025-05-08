// This file centralizes all imports to avoid circular dependencies
import SwiftUI
import Foundation
import Combine
import MapKit
import CoreLocation
import CryptoKit
import UIKit

// Re-export all views to make them available throughout the app
@_exported import SwiftUI
@_exported import MapKit
@_exported import CoreLocation
@_exported import Combine
@_exported import UIKit

// This ensures views are accessible everywhere in the app

// Import order matters - define types before using them
@_exported import SwiftUI
@_exported import Foundation
@_exported import UIKit 