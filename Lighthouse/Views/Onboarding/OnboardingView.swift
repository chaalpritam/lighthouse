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
        .background(LighthouseBackground())
    }

    private var progressHeader: some View {
        HStack(spacing: LHSpacing.xs) {
            ForEach(0..<5, id: \.self) { index in
                Capsule()
                    .fill(index <= step ? Color.accentColor : Color(.tertiarySystemFill))
                    .frame(height: 4)
            }
        }
        .padding(.horizontal, LHLayout.screenPadding)
        .padding(.top, LHSpacing.md)
        .padding(.bottom, LHSpacing.sm)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("Step \(step + 1) of 5")
    }

    private var welcomeStep: some View {
        onboardingPage {
            Image(systemName: "light.max")
                .font(.system(size: 48, weight: .medium))
                .foregroundStyle(.tint)
                .symbolEffect(.pulse, options: .repeating)
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.bottom, LHSpacing.xs)

            Text("Lighthouse")
                .font(.largeTitle.bold())
            Text("Help when you need it. Works offline.")
                .font(.title3)
                .foregroundStyle(.secondary)
                .padding(.bottom, LHSpacing.sm)

            VStack(spacing: LHSpacing.sm) {
                featureRow("location.fill", "GPS geotagging")
                featureRow("mic.fill", "Voice reports")
                featureRow("icloud.slash", "Fully offline agent")
                featureRow("map.fill", "Map-first home")
            }

            Spacer(minLength: LHSpacing.xl)
            PrimaryButton(title: "Continue", systemImage: "arrow.right") { step = 1 }
        }
    }

    private var howItHelpsStep: some View {
        onboardingPage {
            Text("How It Helps")
                .font(.largeTitle.bold())
            Text("Sense → Decide → Act → Verify → Recover")
                .font(.headline)
                .foregroundStyle(.tint)
                .padding(.bottom, LHSpacing.xs)

            SurfaceCard {
                VStack(alignment: .leading, spacing: LHSpacing.sm) {
                    numberedRow(1, "Tell Lighthouse what's happening")
                    numberedRow(2, "Get clear next actions spoken aloud")
                    numberedRow(3, "SOS routes to the right emergency team")
                }
            }

            Spacer(minLength: LHSpacing.xl)
            navigationFooter(back: 0) {
                PrimaryButton(title: "Continue") { step = 2 }
            }
        }
    }

    private var permissionsStep: some View {
        onboardingPage {
            Text("Permissions")
                .font(.largeTitle.bold())
            Text("Lighthouse needs a few permissions to help in the field.")
                .font(.body)
                .foregroundStyle(.secondary)
                .padding(.bottom, LHSpacing.xs)

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
            .controlSize(.regular)

            Spacer(minLength: LHSpacing.xl)
            navigationFooter(back: 1) {
                PrimaryButton(title: "Continue") { step = 3 }
                    .disabled(!micGranted)
                    .opacity(micGranted ? 1 : 0.5)
            }
        }
    }

    private var aiStep: some View {
        onboardingPage {
            Text("Optional AI")
                .font(.largeTitle.bold())
            Text(viewModel.brainStatus.ramSummary)
                .font(.body)
                .foregroundStyle(.secondary)
                .padding(.bottom, LHSpacing.xs)

            SurfaceCard {
                VStack(alignment: .leading, spacing: LHSpacing.sm) {
                    Text("On iOS, Lighthouse uses the full offline rules engine. Android Gemma LiteRT models are noted in Settings.")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)

                    ForEach(viewModel.brainStatus.variants, id: \.self) { variant in
                        Button {
                            viewModel.brainStatus.selectVariant(variant)
                        } label: {
                            HStack(spacing: LHSpacing.sm) {
                                Image(systemName: viewModel.brainStatus.selectedVariant == variant
                                      ? "checkmark.circle.fill" : "circle")
                                    .foregroundStyle(.tint)
                                Text(variant)
                                    .foregroundStyle(.primary)
                                Spacer()
                            }
                            .padding(.vertical, LHSpacing.xxs)
                        }
                        .buttonStyle(.plain)
                    }
                }
            }

            Spacer(minLength: LHSpacing.xl)
            HStack(spacing: LHSpacing.sm) {
                Button("Back") { step = 2 }
                Spacer()
                Button("Skip") { step = 4 }
                PrimaryButton(title: "Continue") { step = 4 }
                    .frame(width: 140)
            }
        }
    }

    private var readyStep: some View {
        onboardingPage {
            Text("You're Ready")
                .font(.largeTitle.bold())
            Text("Start with your GPS location — no mission setup required.")
                .font(.body)
                .foregroundStyle(.secondary)
                .padding(.bottom, LHSpacing.xs)

            PrimaryButton(title: "Get Started", systemImage: "bolt.fill") {
                Task { await viewModel.quickStart() }
            }
            .disabled(viewModel.isCreatingMission)

            Button(showAdvanced ? "Hide Advanced Options" : "Custom Mission & Presets") {
                withAnimation(.snappy) { showAdvanced.toggle() }
            }
            .font(.subheadline.weight(.semibold))

            if showAdvanced {
                SurfaceCard {
                    VStack(alignment: .leading, spacing: LHSpacing.sm) {
                        TextField("Mission name", text: $customName)
                            .textFieldStyle(.roundedBorder)
                        Picker("Disaster", selection: $customType) {
                            ForEach(disasterTypes, id: \.self) { Text($0).tag($0) }
                        }
                        .pickerStyle(.menu)
                        TextField("Location", text: $customLocation)
                            .textFieldStyle(.roundedBorder)
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

                VStack(spacing: LHLayout.rowSpacing) {
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
                            SurfaceCard(padding: LHSpacing.sm) {
                                VStack(alignment: .leading, spacing: 2) {
                                    Text(preset.label)
                                        .font(.body.weight(.semibold))
                                        .foregroundStyle(.primary)
                                    Text("\(preset.type) · \(preset.location)")
                                        .font(.subheadline)
                                        .foregroundStyle(.secondary)
                                }
                            }
                        }
                        .buttonStyle(.plain)
                    }
                }
            }

            Button("Back") { step = 3 }
                .padding(.top, LHSpacing.xs)
        }
    }

    private func onboardingPage<Content: View>(@ViewBuilder content: () -> Content) -> some View {
        ScrollView {
            VStack(alignment: .leading, spacing: LHSpacing.md) {
                content()
            }
            .padding(.horizontal, LHLayout.screenPadding)
            .padding(.top, LHSpacing.sm)
            .padding(.bottom, LHSpacing.xl)
            .frame(maxWidth: .infinity, alignment: .leading)
        }
    }

    private func navigationFooter(back: Int, @ViewBuilder trailing: () -> some View) -> some View {
        HStack(spacing: LHSpacing.sm) {
            Button("Back") { step = back }
            Spacer()
            trailing()
                .frame(maxWidth: 180)
        }
    }

    private func featureRow(_ icon: String, _ title: String) -> some View {
        HStack(spacing: LHSpacing.sm) {
            Image(systemName: icon)
                .font(.body.weight(.semibold))
                .foregroundStyle(.tint)
                .frame(width: 28, height: 28)
                .background(Color.accentColor.opacity(0.12), in: RoundedRectangle(cornerRadius: 8, style: .continuous))
            Text(title)
                .font(.body)
            Spacer(minLength: 0)
        }
    }

    private func numberedRow(_ number: Int, _ text: String) -> some View {
        HStack(alignment: .top, spacing: LHSpacing.sm) {
            Text("\(number)")
                .font(.subheadline.weight(.bold))
                .foregroundStyle(.tint)
                .frame(width: 22, height: 22)
                .background(Color.accentColor.opacity(0.12), in: Circle())
            Text(text)
                .font(.body)
                .fixedSize(horizontal: false, vertical: true)
        }
    }

    private func permissionRow(title: String, subtitle: String, granted: Bool, action: @escaping () -> Void) -> some View {
        SurfaceCard(padding: LHSpacing.sm) {
            HStack(spacing: LHSpacing.sm) {
                VStack(alignment: .leading, spacing: 2) {
                    Text(title)
                        .font(.body.weight(.semibold))
                    Text(subtitle)
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
                Spacer(minLength: LHSpacing.xs)
                if granted {
                    Image(systemName: "checkmark.circle.fill")
                        .font(.title3)
                        .foregroundStyle(LighthouseColor.success)
                        .accessibilityLabel("Granted")
                } else {
                    Button("Allow", action: action)
                        .buttonStyle(.borderedProminent)
                        .controlSize(.small)
                }
            }
        }
    }
}
