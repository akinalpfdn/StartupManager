import SwiftUI

struct ContentView: View {
    var body: some View {
        VStack {
            Text("StartupManager")
                .font(.largeTitle)
            Text("Step 1: Basic Project Created")
                .foregroundColor(.secondary)
        }
        .padding()
        .frame(minWidth: 400, minHeight: 300)
    }
}

#Preview {
    ContentView()
}