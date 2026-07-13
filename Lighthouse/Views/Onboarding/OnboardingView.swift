import SwiftUI

struct OnboardingView: View {
    var viewModel: MissionViewModel
    @State private var step = 0
    @State private var micGranted = false
    @State private var customName = ""
    @State private var customType = "Earthquake"
    @State private var customLocation = ""
    @State private var showAdvanced = false

    private let totalSteps = 5

    private let disasterTypes = [
        "Earthquake", "Flood", "Landslide", "Cyclone", "Building Collapse", "Forest Fire"
    ]

    private let presets: [(label: String, name: String, type: String, location: String)] = [
        ("Earthquake Chennai", "Chennai Earthquake Response", "Earthquake", "Chennai, Tamil Nadu"),
        ("Flood Kerala", "Kerala Flood Response", "Flood", "Kochi, Kerala"),
        ("Building Collapse Mumbai", "Mumbai Collapse Response", "Building Collapse", "Mumbai, Maharashtra")
    ]

    var body: some View {
        VStack(spacing: 0) {
            topChrome
            TabView(selection: $step) {
                welcomeStep.tag(0)
                howItHelpsStep.tag(1)
                permissionsStep.tag(2)
                aiStep.tag(3)
                readyStep.tag(4)
            }
            .tabViewStyle(.page(indexDisplayMode: .never))
            .animation(.smooth(duration: 0.35), value: step)
        }
        .background { onboardingBackdrop }
        .safeAreaInset(edge: .bottom, spacing: 0) {
            bottomChrome
        }
    }

    private var topChrome: some View {
        VStack(spacing: LHSpacing.sm) {
            HStack {
                if step > 0 {
                    Button {
                        withAnimation(.smooth) { step -= 1 }
                    } label: {
                        Image(systemName: "chevron.left")
                            .font(.body.weight(.semibold))
                            .frame(width: 36, height: 36)
                            .background(Color(.tertiarySystemFill), in: Circle())
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel("Back")
                } else {
                    Color.clear.frame(width: 36, height: 36)
                }

                Spacer()

                Text("\(step + 1) of \(totalSteps)")
                    .font(.subheadline.weight(.medium))
                    .foregroundStyle(.secondary)
                    .monospacedDigit()

                Spacer()

                if step < totalSteps - 1 && step != 0 {
                    Button("Skip") {
                        withAnimation(.smooth) { step = totalSteps - 1 }
                    }
                    .font(.subheadline.weight(.semibold))
                    .frame(minWidth: 36, alignment: .trailing)
                } else {
                    Color.clear.frame(width: 36, height: 36)
                }
            }

            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    Capsule().fill(Color(.tertiarySystemFill))
                    Capsule()
                        .fill(Color.accentColor)
                        .frame(width: max(geo.size.width * CGFloat(step + 1) / CGFloat(totalSteps), 8))
                        .animation(.smooth(duration: 0.35), value: step)
                }
            }
            .frame(height: 4)
        }
        .padding(.horizontal, LHLayout.screenPadding)
        .padding(.top, LHSpacing.sm)
        .padding(.bottom, LHSpacing.xs)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("Step \(step + 1) of \(totalSteps)")
    }

    private var bottomChrome: some View {
        VStack(spacing: LHSpacing.sm) {
            primaryAction
        }
        .padding(.horizontal, LHLayout.screenPadding)
        .padding(.top, LHSpacing.sm)
        .padding(.bottom, LHSpacing.sm)
        .background(.bar)
    }

    @ViewBuilder
    private var primaryAction: some View {
        switch step {
        case 0:
            PrimaryButton(title: "Continue", systemImage: "arrow.right") { advance(to: 1) }
        case 1:
            PrimaryButton(title: "Continue") { advance(to: 2) }
        case 2:
            PrimaryButton(title: micGranted ? "Continue" : "Allow Microphone to Continue") {
                if micGranted {
                    advance(to: 3)
                } else {
                    Task {
                        micGranted = await viewModel.voiceService.requestPermissions()
                        if micGranted { advance(to: 3) }
                    }
                }
            }
        case 3:
            HStack(spacing: LHSpacing.sm) {
                Button("Not Now") { advance(to: 4) }
                    .buttonStyle(.bordered)
                    .controlSize(.large)
                    .frame(maxWidth: .infinity)
                PrimaryButton(title: "Continue") { advance(to: 4) }
            }
        default:
            PrimaryButton(
                title: viewModel.isCreatingMission ? "Starting…" : "Get Started",
                systemImage: "bolt.fill"
            ) {
                Task { await viewModel.quickStart() }
            }
            .disabled(viewModel.isCreatingMission)
        }
    }

    private var onboardingBackdrop: some View {
        ZStack {
            Color(.systemGroupedBackground)
            RadialGradient(
                colors: [
                    Color.accentColor.opacity(0.16),
                    Color.accentColor.opacity(0.04),
                    .clear
                ],
                center: .topTrailing,
                startRadius: 20,
                endRadius: 420
            )
        }
        .ignoresSafeArea()
    }

    private var welcomeStep: some View {
        page {
            Text("Lighthouse").font(.largeTitle.bold())
            Text("Help when you need it. Works offline.")
                .font(.title3).foregroundStyle(.secondary)
            featureRow("location.fill", "GPS geotagging")
            featureRow("mic.fill", "Voice reports")
            featureRow("icloud.slash", "Fully offline agent")
            featureRow("map.fill", "Map-first home")
        }
    }

    private var howItHelpsStep: some View {
        page {
            Text("How It Helps").font(.largeTitle.bold())
            Text("Sense → Decide → Act → Verify → Recover")
                .font(.headline).foregroundStyle(.tint)
            SurfaceCard {
                VStack(alignment: .leading, spacing: LHSpacing.sm) {
                    Text("1. Tell Lighthouse what's happening")
                    Text("2. Get clear next actions spoken aloud")
                    Text("3. SOS routes to the right emergency team")
                }
            }
        }
    }

    private var permissionsStep: some View {
        page {
            Text("Permissions").font(.largeTitle.bold())
            Text("Lighthouse needs a few permissions to help in the field.")
                .foregroundStyle(.secondary)
            permissionRow(title: "Microphone", subtitle: "Required for voice reports", granted: micGranted) {
                Task { micGranted = await viewModel.voiceService.requestPermissions() }
            }
            permissionRow(
                title: "Location",
                subtitle: "Recommended for geotagging",
                granted: viewModel.locationService.location != nil
            ) {
                viewModel.locationService.requestPermission()
                viewModel.locationService.startUpdates()
            }
            Button("Voice test: “Building A collapsed”") { viewModel.testVoice() }
                .buttonStyle(.bordered)
        }
    }

    private var aiStep: some View {
        page {
            Text("Optional AI").font(.largeTitle.bold())
            Text(viewModel.brainStatus.ramSummary).foregroundStyle(.secondary)
            SurfaceCard {
                VStack(alignment: .leading, spacing: LHSpacing.sm) {
                    Text("On iOS, Lighthouse uses the full offline rules engine.")
                        .font(.subheadline).foregroundStyle(.secondary)
                    ForEach(viewModel.brainStatus.variants, id: \.self) { variant in
                        Button {
                            viewModel.brainStatus.selectVariant(variant)
                        } label: {
                            HStack {
                                Image(systemName: viewModel.brainStatus.selectedVariant == variant ? "checkmark.circle.fill" : "circle")
                                    .foregroundStyle(.tint)
                                Text(variant).foregroundStyle(.primary)
                                Spacer()
                            }
                        }
                        .buttonStyle(.plain)
                    }
                }
            }
        }
    }

    private var readyStep: some View {
        page {
            Text("You're Ready").font(.largeTitle.bold())
            Text("Start with your GPS location — no mission setup required.")
                .foregroundStyle(.secondary)
            Button(showAdvanced ? "Hide Advanced Options" : "Custom Mission & Presets") {
                withAnimation(.snappy) { showAdvanced.toggle() }
            }
            .font(.subheadline.weight(.semibold))
            if showAdvanced {
                SurfaceCard {
                    VStack(alignment: .leading, spacing: LHSpacing.sm) {
                        TextField("Mission name", text: $customName).textFieldStyle(.roundedBorder)
                        Picker("Disaster", selection: $customType) {
                            ForEach(disasterTypes, id: \.self) { Text($0).tag($0) }
                        }
                        .pickerStyle(.menu)
                        TextField("Location", text: $customLocation).textFieldStyle(.roundedBorder)
                        Button("Create Mission") {
                            Task {
                                await viewModel.createMission(
                                    name: customName.isEmpty ? "Custom Mission" : customName,
                                    disasterType: customType,
                                    location: customLocation.isEmpty ? "Unknown" : customLocation
                                )
                            }
                        }
                        .buttonStyle(.borderedProminent)
                        .controlSize(.large)
                    }
                }
                ForEach(presets, id: \.label) { preset in
                    Button {
                        Task {
                            await viewModel.createMission(name: preset.name, disasterType: preset.type, location: preset.location)
                        }
                    } label: {
                        SurfaceCard(padding: LHSpacing.sm) {
                            VStack(alignment: .leading, spacing: 2) {
                                Text(preset.label).font(.body.weight(.semibold)).foregroundStyle(.primary)
                                Text("\(preset.type) · \(preset.location)").font(.subheadline).foregroundStyle(.secondary)
                            }
                        }
                    }
                    .buttonStyle(.plain)
                }
            }
        }
    }

    private func page<Content: View>(@ViewBuilder content: () -> Content) -> some View {
        ScrollView {
            VStack(alignment: .leading, spacing: LHSpacing.md) {
                content()
            }
            .padding(.horizontal, LHLayout.screenPadding)
            .padding(.top, LHSpacing.md)
            .padding(.bottom, LHSpacing.xxl)
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .scrollIndicators(.hidden)
    }

    private func featureRow(_ icon: String, _ title: String) -> some View {
        HStack(spacing: LHSpacing.sm) {
            Image(systemName: icon)
                .font(.body.weight(.semibold))
                .foregroundStyle(.tint)
                .frame(width: 28, height: 28)
                .background(Color.accentColor.opacity(0.12), in: RoundedRectangle(cornerRadius: 8, style: .continuous))
            Text(title)
            Spacer(minLength: 0)
        }
    }

    private func permissionRow(title: String, subtitle: String, granted: Bool, action: @escaping () -> Void) -> some View {
        SurfaceCard(padding: LHSpacing.sm) {
            HStack(spacing: LHSpacing.sm) {
                VStack(alignment: .leading, spacing: 2) {
                    Text(title).font(.body.weight(.semibold))
                    Text(subtitle).font(.subheadline).foregroundStyle(.secondary)
                }
                Spacer(minLength: LHSpacing.xs)
                if granted {
                    Image(systemName: "checkmark.circle.fill").font(.title3).foregroundStyle(LighthouseColor.success)
                } else {
                    Button("Allow", action: action).buttonStyle(.borderedProminent).controlSize(.small)
                }
            }
        }
    }

    private func advance(to next: Int) {
        withAnimation(.smooth(duration: 0.35)) { step = next }
    }
}
