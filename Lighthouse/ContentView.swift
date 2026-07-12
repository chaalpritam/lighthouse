import SwiftUI

struct ContentView: View {
    var body: some View {
        VStack(spacing: 16) {
            Image(systemName: "light.max")
                .font(.system(size: 64))
                .foregroundStyle(.tint)

            Text("Lighthouse")
                .font(.largeTitle.bold())

            Text("Your iOS app is ready.")
                .font(.body)
                .foregroundStyle(.secondary)
        }
        .padding()
    }
}

#Preview {
    ContentView()
}
