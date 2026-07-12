import SwiftUI

struct OnboardingView: View {
    var viewModel: MissionViewModel
    @State private var step = 0
    @State private var micGranted = false
    @State private var customName = ""
    @State private var customType = "Earthquake"
    @State private var customLocation = ""
    @State private var showAdvanced = false

    private let disasterTypes = [
        "Earthquake", "Flood", "Landslide", "Cyclone", "Building Collapse", "Forest Fire"
    ]

    private let presets: [(label: String, name: String, type: String, location: String)] = [
        ("Earthquake Chennai", "Chennai Earthquake Response", "Earthquake", "Chennai, Tamil Nadu"),
        ("Flood Kerala", "Kerala Flood Response", "Flood", "Kochi, Kerala"),
        ("Building Collapse Mumbai", "Mumbai Collapse Response", "Building Collapse", "Mumbai, Maharashtra")
    ]

    var body: some View {
        ZStack {
            LighthouseBackground()
            VStack(spacing: 0) {
                progressHeader
                TabView(selection: $step) {
                    welcomeStep.tag(0)
                    howItHelpsStep.tag(1)
                    permissionsStep.tag(2)
                    aiStep.tag(3)
                    readyStep.tag(4)
                }
                .tabViewStyle(.page(indexDisplayMode: .never))
                .animation(.snappy, value: step)

                AgentBrainStatusBar(brain: viewModel.brainStatus)
            }
        }
    }

    private var progressHeader: some View {
        HStack {
            ForEach(0..<5, id: \.self) { index in
                Capsule()
                    .fill(index <= step ? LighthouseColor.blue : Color.secondary.opacity(0.2))
                    .frame(height: 4)
            }
        }
        .padding(.horizontal, 24)
        .padding(.top, 16)
        .padding(.bottom, 8)
    }

    private var welcomeStep: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                Image(systemName: "light.max")
                    .font(.system(size: 56))
                    .foregroundStyle(LighthouseColor.blue)
                    .symbolEffect(.pulse, options: .repeating)
                Text("Lighthouse")
                    .font(.largeTitle.bold())
                Text("Help when you need it. Works offline.")
                    .font(.title3)
                    .foregroundStyle(.secondary)
                featureRow("location.fill", "GPS geotagging")
                featureRow("mic.fill", "Voice reports")
                featureRow("icloud.slash", "Fully offline agent")
                featureRow("map.fill", "Map-first home")
                GlassPrimaryButton(title: "Continue", systemImage: "arrow.right") { step = 1 }
            }
            .padding(24)
        }
    }

    private var howItHelpsStep: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                Text("How it helps")
                    .font(.largeTitle.bold())
                Text("Sense → Decide → Act → Verify → Recover")
                    .font(.headline)
                    .foregroundStyle(LighthouseColor.blue)
                GlassCard {
                    VStack(alignment: .leading, spacing: 12) {
                        Text("1. Tell Lighthouse what's happening")
                        Text("2. Get clear next actions spoken aloud")
                        Text("3. SOS routes to the right emergency team")
                    }
                }
                HStack {
                    Button("Back") { step = 0 }
                    Spacer()
                    GlassPrimaryButton(title: "Continue") { step = 2 }
                        .frame(width: 160)
                }
            }
            .padding(24)
        }
    }

    private var permissionsStep: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                Text("Permissions")
                    .font(.largeTitle.bold())
                permissionRow(
                    title: "Microphone",
                    subtitle: "Required for voice reports",
                    granted: micGranted
                ) {
                    Task {
                        micGranted = await viewModel.voiceService.requestPermissions()
                    }
                }
                permissionRow(
                    title: "Location",
                    subtitle: "Recommended for geotagging",
                    granted: viewModel.locationService.location != nil
                ) {
                    viewModel.locationService.requestPermission()
                    viewModel.locationService.startUpdates()
                }
                Button("Voice test: “Building A collapsed”") {
                    viewModel.testVoice()
                }
                .buttonStyle(.bordered)
                HStack {
                    Button("Back") { step = 1 }
                    Spacer()
                    GlassPrimaryButton(title: "Continue") { step = 3 }
                        .frame(width: 160)
                        .disabled(!micGranted)
                        .opacity(micGranted ? 1 : 0.5)
                }
            }
            .padding(24)
        }
    }

    private var aiStep: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                Text("Optional AI")
                    .font(.largeTitle.bold())
                Text(viewModel.brainStatus.ramSummary)
                    .foregroundStyle(.secondary)
                GlassCard {
                    VStack(alignment: .leading, spacing: 10) {
                        Text("On iOS, Lighthouse uses the full offline rules engine (Android Gemma LiteRT models are noted in Settings).")
                        ForEach(viewModel.brainStatus.variants, id: \.self) { variant in
                            Button {
                                viewModel.brainStatus.selectVariant(variant)
                            } label: {
                                HStack {
                                    Image(systemName: viewModel.brainStatus.selectedVariant == variant
                                          ? "checkmark.circle.fill" : "circle")
                                        .foregroundStyle(LighthouseColor.blue)
                                    Text(variant)
                                    Spacer()
                                }
                            }
                            .buttonStyle(.plain)
                        }
                    }
                }
                HStack {
                    Button("Back") { step = 2 }
                    Spacer()
                    Button("Skip") { step = 4 }
                    GlassPrimaryButton(title: "Continue") { step = 4 }
                        .frame(width: 160)
                }
            }
            .padding(24)
        }
    }

    private var readyStep: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                Text("You're ready")
                    .font(.largeTitle.bold())
                Text("Start with your GPS location — no mission setup required.")
                    .foregroundStyle(.secondary)
                GlassPrimaryButton(title: "Get started", systemImage: "bolt.fill") {
                    Task { await viewModel.quickStart() }
                }
                .disabled(viewModel.isCreatingMission)

                Button(showAdvanced ? "Hide advanced" : "Custom mission & presets") {
                    withAnimation { showAdvanced.toggle() }
                }
                .font(.subheadline.weight(.semibold))

                if showAdvanced {
                    GlassCard {
                        VStack(alignment: .leading, spacing: 12) {
                            TextField("Mission name", text: $customName)
                            Picker("Disaster", selection: $customType) {
                                ForEach(disasterTypes, id: \.self) { Text($0).tag($0) }
                            }
                            TextField("Location", text: $customLocation)
                            Button("Create mission") {
                                Task {
                                    await viewModel.createMission(
                                        name: customName.isEmpty ? "Custom Mission" : customName,
                                        disasterType: customType,
                                        location: customLocation.isEmpty ? "Unknown" : customLocation
                                    )
                                }
                            }
                            .buttonStyle(.borderedProminent)
                        }
                    }
                    ForEach(presets, id: \.label) { preset in
                        Button {
                            Task {
                                await viewModel.createMission(
                                    name: preset.name,
                                    disasterType: preset.type,
                                    location: preset.location
                                )
                            }
                        } label: {
                            GlassCard {
                                VStack(alignment: .leading, spacing: 4) {
                                    Text(preset.label).fontWeight(.semibold)
                                    Text("\(preset.type) · \(preset.location)")
                                        .font(.caption)
                                        .foregroundStyle(.secondary)
                                }
                            }
                        }
                        .buttonStyle(.plain)
                    }
                }
                Button("Back") { step = 3 }
            }
            .padding(24)
        }
    }

    private func featureRow(_ icon: String, _ title: String) -> some View {
        HStack(spacing: 12) {
            Image(systemName: icon)
                .foregroundStyle(LighthouseColor.blue)
                .frame(width: 28)
            Text(title)
            Spacer()
        }
        .padding(.vertical, 4)
    }

    private func permissionRow(title: String, subtitle: String, granted: Bool, action: @escaping () -> Void) -> some View {
        GlassCard {
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text(title).fontWeight(.semibold)
                    Text(subtitle).font(.caption).foregroundStyle(.secondary)
                }
                Spacer()
                if granted {
                    Image(systemName: "checkmark.circle.fill").foregroundStyle(LighthouseColor.success)
                } else {
                    Button("Allow", action: action).buttonStyle(.borderedProminent)
                }
            }
        }
    }
}
