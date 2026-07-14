import SwiftUI
import SwiftData

struct RootView: View {
    @Environment(\.modelContext) private var modelContext
    @State private var locationService = LocationService()
    @State private var voiceService = VoiceService()
    @State private var brainStatus = AgentBrainStatus()
    @State private var viewModel: MissionViewModel?

    var body: some View {
        Group {
            if let viewModel {
                content(viewModel)
            } else {
                ProgressView("Loading mission…")
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .background(LighthouseBackground())
                    .task {
                        let vm = MissionViewModel(
                            context: modelContext,
                            locationService: locationService,
                            voiceService: voiceService,
                            brainStatus: brainStatus
                        )
                        vm.loadMission()
                        viewModel = vm
                    }
            }
        }
    }

    @ViewBuilder
    private func content(_ viewModel: MissionViewModel) -> some View {
        if viewModel.isLoading {
            ProgressView("Loading mission…")
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .background(LighthouseBackground())
        } else if viewModel.mission == nil {
            OnboardingView(viewModel: viewModel)
        } else {
            MainTabView(viewModel: viewModel)
        }
    }
}
