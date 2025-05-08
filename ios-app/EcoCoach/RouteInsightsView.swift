import SwiftUI

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

struct RouteInsightsView_Previews: PreviewProvider {
    static var previews: some View {
        RouteInsightsView(insights: [
            RouteInsight(title: "Short-term Benefit", description: "Reduced coughing and throat irritation during your trip."),
            RouteInsight(title: "Long-term Benefit", description: "Lower risk of respiratory conditions from consistent low-pollution routes."),
            RouteInsight(title: "Health Tip", description: "Travel during early morning when pollution levels are typically lower.")
        ])
        .padding()
        .previewLayout(.sizeThatFits)
    }
} 