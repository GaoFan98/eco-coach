import SwiftUI
import MapKit

// RouteInsightsView
struct RouteInsightsView: View {
    let insights: [RouteInsight]
    
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Health Insights")
                .font(.headline)
                .foregroundColor(.green)
            
            Divider()
            
            ForEach(insights, id: \.title) { insight in
                InsightRow(insight: insight)
            }
        }
        .padding()
        .background(Color.white)
        .cornerRadius(15)
        .shadow(radius: 5)
    }
}

struct InsightRow: View {
    let insight: RouteInsight
    
    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(insight.title)
                .font(.subheadline)
                .fontWeight(.semibold)
                .foregroundColor(.primary)
            
            Text(insight.description)
                .font(.body)
                .foregroundColor(.secondary)
                .fixedSize(horizontal: false, vertical: true)
        }
    }
}

// PollutionForecastView
struct PollutionForecastView: View {
    let pollutionOverlayImage: UIImage?
    let pollutionData: [PollutionPoint]
    @Binding var isPresented: Bool
    
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
            
            if let image = pollutionOverlayImage {
                Image(uiImage: image)
                    .resizable()
                    .aspectRatio(contentMode: .fit)
                    .frame(height: 200)
                    .cornerRadius(12)
                    .overlay(
                        RoundedRectangle(cornerRadius: 12)
                            .stroke(Color.gray.opacity(0.3), lineWidth: 1)
                    )
            } else {
                Rectangle()
                    .fill(Color.gray.opacity(0.2))
                    .frame(height: 200)
                    .cornerRadius(12)
                    .overlay(
                        Text("Pollution overlay not available")
                            .foregroundColor(.gray)
                    )
            }
            
            VStack(alignment: .leading, spacing: 8) {
                Text("Pollution Levels")
                    .font(.subheadline)
                    .fontWeight(.semibold)
                
                ForEach(pollutionData, id: \.position) { point in
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

// RouteStoryView
struct RouteStoryView: View {
    let storyData: RouteStoryResponse
    @Binding var isPresented: Bool
    
    @State private var isShareSheetPresented = false
    
    var body: some View {
        VStack(spacing: 20) {
            HStack {
                Text("Your Eco Journey")
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
            
            Text(storyData.title)
                .font(.title2)
                .fontWeight(.bold)
                .foregroundColor(.green)
                .multilineTextAlignment(.center)
            
            Text(storyData.story)
                .font(.body)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
                .fixedSize(horizontal: false, vertical: true)
                .padding(.horizontal)
            
            HStack(spacing: 12) {
                ForEach(storyData.stats, id: \.label) { stat in
                    StatBox(stat: stat)
                }
            }
            .padding(.vertical)
            
            Button(action: {
                isShareSheetPresented = true
            }) {
                Label("Share Your Impact", systemImage: "square.and.arrow.up")
                    .font(.headline)
                    .foregroundColor(.white)
                    .padding()
                    .frame(maxWidth: .infinity)
                    .background(Color.blue)
                    .cornerRadius(10)
            }
            .sheet(isPresented: $isShareSheetPresented) {
                ShareSheet(activityItems: [prepareShareText()])
            }
        }
        .padding()
        .background(Color.white)
        .cornerRadius(20)
        .shadow(radius: 10)
        .padding()
    }
    
    private func prepareShareText() -> String {
        let text = """
        \(storyData.title)
        
        \(storyData.shareText)
        
        #EcoCoach #SustainableTravel #CleanAir
        """
        return text
    }
}

struct StatBox: View {
    let stat: RouteStatItem
    
    var body: some View {
        VStack {
            Text(stat.value)
                .font(.headline)
                .fontWeight(.bold)
                .foregroundColor(.primary)
            
            Text(stat.label)
                .font(.caption)
                .foregroundColor(.secondary)
        }
        .frame(maxWidth: .infinity)
        .padding()
        .background(Color(UIColor.systemGray6))
        .cornerRadius(10)
    }
}

struct ShareSheet: UIViewControllerRepresentable {
    let activityItems: [Any]
    
    func makeUIViewController(context: Context) -> UIActivityViewController {
        let controller = UIActivityViewController(
            activityItems: activityItems,
            applicationActivities: nil
        )
        return controller
    }
    
    func updateUIViewController(_ uiViewController: UIActivityViewController, context: Context) {}
}

// Map pin
struct MapPinView: View {
    var body: some View {
        VStack(spacing: 0) {
            Image(systemName: "mappin.circle.fill")
                .font(.title)
                .foregroundColor(.red)
                .background(Circle().fill(.white))
            
            Image(systemName: "arrowtriangle.down.fill")
                .font(.caption)
                .foregroundColor(.red)
                .offset(x: 0, y: -5)
        }
        .offset(y: -10) // Adjust for pin point
    }
} 