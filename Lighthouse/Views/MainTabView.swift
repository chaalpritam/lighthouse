import SwiftUI

struct MainTabView: View {
    var viewModel: MissionViewModel

    var body: some View {
        TabView {
            Tab("Home", systemImage: "map.fill") {
                HomeMapView(viewModel: viewModel)
            }
            Tab("Agents", systemImage: "cross.case.fill") {
                AgentsView(viewModel: viewModel)
            }
            Tab("Guide", systemImage: "list.bullet.rectangle") {
                GuideConsoleView(viewModel: viewModel)
            }
            Tab("Activity", systemImage: "bubble.left.and.bubble.right.fill") {
                ActivityLogView(viewModel: viewModel)
            }
            Tab("Settings", systemImage: "gearshape.fill") {
                SettingsView(viewModel: viewModel)
            }
        }
        .tint(LighthouseColor.blue)
        .safeAreaInset(edge: .bottom, spacing: 0) {
            if viewModel.mission != nil {
                AgentBrainStatusBar(brain: viewModel.brainStatus)
            }
        }
    }
}
