import SwiftUI

struct ContentView: View {
    var body: some View {
        NavigationSplitView {
            VStack {
                Text("Startup Items")
                    .font(.headline)
                    .padding()
                List {
                    Text("Login Items")
                    Text("Launch Agents")
                    Text("Launch Daemons")
                }
            }
            .frame(minWidth: 200)
        } detail: {
            VStack {
                Text("StartupManager")
                    .font(.largeTitle)
                    .padding()
                Text("Phase 1: Complete - Models Created")
                    .foregroundColor(.secondary)
                Text("✓ LaunchItem Protocol")
                    .foregroundColor(.green)
                Text("✓ LoginItem, LaunchAgent, LaunchDaemon")
                    .foregroundColor(.green)
                Text("✓ PlistParser")
                    .foregroundColor(.green)

                Spacer()

                Text("Select a category to view startup items")
                    .foregroundColor(.secondary)

                Spacer()
            }
            .frame(minWidth: 600, minHeight: 400)
        }
    }
}

#Preview {
    ContentView()
}