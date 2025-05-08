import SwiftUI

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

struct RouteStoryView_Previews: PreviewProvider {
    static var previews: some View {
        RouteStoryView(
            storyData: RouteStoryResponse(
                title: "Eco-Warrior's Journey",
                story: "Today you chose a path less traveled, reducing your CO2 emissions by 1.4kg and breathing in 15% less pollution. Small choices like these add up to big impacts for both your health and our planet.",
                stats: [
                    RouteStatItem(label: "CO2 Saved", value: "1.4kg"),
                    RouteStatItem(label: "PM2.5 Avoided", value: "0.32g"),
                    RouteStatItem(label: "Health Impact", value: "Positive")
                ],
                shareText: "I just saved 1.4kg of CO2 and reduced my pollution exposure by choosing an eco-friendly route with EcoCoach!"
            ),
            isPresented: .constant(true)
        )
    }
} 