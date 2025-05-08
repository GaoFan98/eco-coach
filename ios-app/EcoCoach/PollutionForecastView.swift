import SwiftUI
import MapKit

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

struct PollutionForecastView_Previews: PreviewProvider {
    static var previews: some View {
        PollutionForecastView(
            pollutionOverlayImage: nil,
            pollutionData: [
                PollutionPoint(position: 0, level: "Medium", lat: 35.6895, lon: 139.6917),
                PollutionPoint(position: 0.25, level: "Low", lat: 35.6890, lon: 139.6920),
                PollutionPoint(position: 0.5, level: "Low", lat: 35.6885, lon: 139.6925),
                PollutionPoint(position: 0.75, level: "Medium", lat: 35.6880, lon: 139.6930),
                PollutionPoint(position: 1, level: "High", lat: 35.6875, lon: 139.6935)
            ],
            isPresented: .constant(true)
        )
    }
} 