import SwiftUI

struct ChartsView: View {
    var body: some View {
        VStack(spacing: 20) {
            Spacer()

            Image(systemName: "chart.line.uptrend.xyaxis")
                .font(.system(size: 60))
                .foregroundStyle(.secondary)

            Text("Performance Charts")
                .font(.title2)
                .fontWeight(.semibold)

            Text("Track your progress with detailed charts and analytics")
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal)

            Spacer()
        }
        .navigationTitle("Charts")
    }
}

#Preview {
    NavigationStack {
        ChartsView()
    }
}
