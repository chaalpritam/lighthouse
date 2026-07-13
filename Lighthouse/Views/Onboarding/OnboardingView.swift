import SwiftUI

struct OnboardingView: View {
    var viewModel: MissionViewModel
    @State private var step = 0
    @State private var micGranted = false
    @State private var customName = ""
    @State private var customType = "Earthquake"
    @State private var customLocation = ""
    @State private var showAdvanced = false
    @State private var appearToken = 0

    private let totalSteps = 5

    private let disasterTypes = [
        "Earthquake", "Flood", "Landslide", "Cyclone", "Building Collapse", "Forest Fire"
    ]

    private let presets: [(icon: String, label: String, name: String, type: String, location: String)] = [
        ("waveform.path.ecg", "Earthquake Chennai", "Chennai Earthquake Response", "Earthquake", "Chennai, Tamil Nadu"),
        ("water.waves", "Flood Kerala", "Kerala Flood Response", "Flood", "Kochi, Kerala"),
        ("building.2.crop.circle", "Collapse Mumbai", "Mumbai Collapse Response", "Building Collapse", "Mumbai, Maharashtra")
    ]

    private let features: [(icon: String, title: String, detail: String)] = [
        ("location.fill", "GPS geotagging", "Every report is pinned to where you are"),
        ("mic.fill", "Voice reports", "Speak naturally — Lighthouse listens"),
        ("icloud.slash", "Works offline", "No signal required in the field"),
        ("map.fill", "Map-first home", "See nearby incidents at a glance")
    ]

    private let helpSteps: [(icon: String, title: String, detail: String)] = [
        ("waveform.badge.mic", "Tell what’s happening", "Speak or type a field report"),
        ("list.bullet.clipboard", "Get clear next actions", "Guidance is spoken aloud"),
        ("dot.radiowaves.left.and.right", "SOS to the right team", "Routes to ambulance, fire, and more")
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
        .background {
            onboardingBackdrop
        }
        .safeAreaInset(edge: .bottom, spacing: 0) {
            bottomChrome
        }
        .onChange(of: step) { _, _ in
            appearToken += 1
        }
    }

    // MARK: - Chrome

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
                    Capsule()
                        .fill(Color(.tertiarySystemFill))
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
            PrimaryButton(title: "Continue", systemImage: "arrow.right") {
                advance(to: 1)
            }
        case 1:
            PrimaryButton(title: "Continue") {
                advance(to: 2)
            }
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
            .disabled(viewModel.isCreatingMission)
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

    // MARK: - Pages

    private var welcomeStep: some View {
        onboardingScroll {
            heroIcon("light.max", tint: .accentColor)
                .symbolEffect(.pulse, options: .repeating)

            pageTitle(
                "Lighthouse",
                subtitle: "Field guidance when every second counts — fully offline."
            )

            LazyVGrid(
                columns: [
                    GridItem(.flexible(), spacing: LHLayout.rowSpacing),
                    GridItem(.flexible(), spacing: LHLayout.rowSpacing)
                ],
                spacing: LHLayout.rowSpacing
            ) {
                ForEach(features, id: \.title) { feature in
                    featureCard(icon: feature.icon, title: feature.title, detail: feature.detail)
                }
            }
        }
    }

    private var howItHelpsStep: some View {
        onboardingScroll {
            heroIcon("arrow.triangle.branch", tint: .accentColor)

            pageTitle(
                "How it helps",
                subtitle: "An agent loop that turns field reports into action."
            )

            HStack(spacing: LHSpacing.xxs) {
                ForEach(["Sense", "Decide", "Act", "Verify", "Recover"], id: \.self) { phase in
                    Text(phase)
                        .font(.caption2.weight(.semibold))
                        .padding(.horizontal, LHSpacing.xs)
                        .padding(.vertical, LHSpacing.xxs)
                        .foregroundStyle(.tint)
                        .background(Color.accentColor.opacity(0.12), in: Capsule())
                        .frame(maxWidth: .infinity)
                }
            }

            VStack(spacing: LHLayout.rowSpacing) {
                ForEach(Array(helpSteps.enumerated()), id: \.offset) { index, item in
                    helpCard(number: index + 1, icon: item.icon, title: item.title, detail: item.detail)
                }
            }
        }
    }

    private var permissionsStep: some View {
        onboardingScroll {
            heroIcon("lock.shield.fill", tint: .accentColor)

            pageTitle(
                "Permissions",
                subtitle: "Grant access so Lighthouse can listen and geotag reports."
            )

            VStack(spacing: LHLayout.rowSpacing) {
                permissionCard(
                    icon: "mic.fill",
                    title: "Microphone",
                    subtitle: "Required for voice reports",
                    granted: micGranted,
                    actionTitle: "Allow"
                ) {
                    Task {
                        micGranted = await viewModel.voiceService.requestPermissions()
                    }
                }

                permissionCard(
                    icon: "location.fill",
                    title: "Location",
                    subtitle: "Recommended for geotagging",
                    granted: viewModel.locationService.location != nil,
                    actionTitle: "Allow"
                ) {
                    viewModel.locationService.requestPermission()
                    viewModel.locationService.startUpdates()
                }
            }

            Button {
                viewModel.testVoice()
            } label: {
                Label("Play voice test", systemImage: "speaker.wave.2.fill")
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(.bordered)
            .controlSize(.large)
        }
    }

    private var aiStep: some View {
        onboardingScroll {
            heroIcon("brain.head.profile", tint: .accentColor)

            pageTitle(
                "On-device brain",
                subtitle: viewModel.brainStatus.ramSummary
            )

            SurfaceCard {
                VStack(alignment: .leading, spacing: LHSpacing.md) {
                    Label {
                        Text("Rules engine is ready on iOS")
                            .font(.subheadline.weight(.semibold))
                    } icon: {
                        Image(systemName: "checkmark.seal.fill")
                            .foregroundStyle(LighthouseColor.success)
                    }

                    Text("Gemma LiteRT variants are Android-only. You can note a preference here; iOS keeps using the offline rules engine.")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }

            VStack(spacing: LHSpacing.xs) {
                ForEach(viewModel.brainStatus.variants, id: \.self) { variant in
                    brainOption(variant)
                }
            }
        }
    }

    private var readyStep: some View {
        onboardingScroll {
            heroIcon("checkmark.circle.fill", tint: LighthouseColor.success)

            pageTitle(
                "You're ready",
                subtitle: "Start from your GPS location — no mission setup required."
            )

            SurfaceCard {
                HStack(spacing: LHSpacing.sm) {
                    Image(systemName: "location.fill")
                        .font(.title3)
                        .foregroundStyle(.tint)
                        .frame(width: 36, height: 36)
                        .background(Color.accentColor.opacity(0.12), in: RoundedRectangle(cornerRadius: 10, style: .continuous))

                    VStack(alignment: .leading, spacing: 2) {
                        Text(viewModel.locationService.location?.shortLabel() ?? "Finding your location…")
                            .font(.body.weight(.semibold))
                        Text(viewModel.locationService.location?.countryLabel() ?? "Location updates when permitted")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                    }
                    Spacer(minLength: 0)
                }
            }

            DisclosureGroup(isExpanded: $showAdvanced) {
                VStack(alignment: .leading, spacing: LHLayout.rowSpacing) {
                    SurfaceCard(padding: LHSpacing.sm) {
                        VStack(alignment: .leading, spacing: LHSpacing.sm) {
                            TextField("Mission name", text: $customName)
                                .textFieldStyle(.roundedBorder)
                            Picker("Disaster", selection: $customType) {
                                ForEach(disasterTypes, id: \.self) { Text($0).tag($0) }
                            }
                            .pickerStyle(.menu)
                            TextField("Location", text: $customLocation)
                                .textFieldStyle(.roundedBorder)
                            Button {
                                Task {
                                    await viewModel.createMission(
                                        name: customName.isEmpty ? "Custom Mission" : customName,
                                        disasterType: customType,
                                        location: customLocation.isEmpty ? "Unknown" : customLocation
                                    )
                                }
                            } label: {
                                Text("Create custom mission")
                                    .frame(maxWidth: .infinity)
                            }
                            .buttonStyle(.borderedProminent)
                            .controlSize(.large)
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
                            SurfaceCard(padding: LHSpacing.sm) {
                                HStack(spacing: LHSpacing.sm) {
                                    Image(systemName: preset.icon)
                                        .foregroundStyle(.tint)
                                        .frame(width: 28)
                                    VStack(alignment: .leading, spacing: 2) {
                                        Text(preset.label)
                                            .font(.body.weight(.semibold))
                                            .foregroundStyle(.primary)
                                        Text("\(preset.type) · \(preset.location)")
                                            .font(.caption)
                                            .foregroundStyle(.secondary)
                                    }
                                    Spacer(minLength: 0)
                                    Image(systemName: "chevron.right")
                                        .font(.caption.weight(.semibold))
                                        .foregroundStyle(.tertiary)
                                }
                            }
                        }
                        .buttonStyle(.plain)
                    }
                }
                .padding(.top, LHSpacing.sm)
            } label: {
                Text("Custom mission & presets")
                    .font(.subheadline.weight(.semibold))
            }
            .tint(.primary)
        }
    }

    // MARK: - Building blocks

    private func onboardingScroll<Content: View>(@ViewBuilder content: () -> Content) -> some View {
        ScrollView {
            VStack(alignment: .leading, spacing: LHSpacing.lg) {
                content()
            }
            .padding(.horizontal, LHLayout.screenPadding)
            .padding(.top, LHSpacing.md)
            .padding(.bottom, LHSpacing.xxl)
            .frame(maxWidth: .infinity, alignment: .leading)
            .id(appearToken)
            .transition(.opacity.combined(with: .move(edge: .trailing)))
        }
        .scrollIndicators(.hidden)
    }

    private func pageTitle(_ title: String, subtitle: String) -> some View {
        VStack(alignment: .leading, spacing: LHSpacing.xs) {
            Text(title)
                .font(.largeTitle.weight(.bold))
                .foregroundStyle(.primary)
            Text(subtitle)
                .font(.body)
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)
        }
    }

    private func heroIcon(_ systemName: String, tint: Color) -> some View {
        Image(systemName: systemName)
            .font(.system(size: 36, weight: .semibold))
            .foregroundStyle(tint)
            .frame(width: 84, height: 84)
            .background {
                Circle()
                    .fill(
                        LinearGradient(
                            colors: [tint.opacity(0.22), tint.opacity(0.08)],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
            }
            .overlay {
                Circle()
                    .strokeBorder(tint.opacity(0.18), lineWidth: 1)
            }
            .accessibilityHidden(true)
    }

    private func featureCard(icon: String, title: String, detail: String) -> some View {
        VStack(alignment: .leading, spacing: LHSpacing.sm) {
            Image(systemName: icon)
                .font(.title3.weight(.semibold))
                .foregroundStyle(.tint)
                .frame(width: 36, height: 36)
                .background(Color.accentColor.opacity(0.12), in: RoundedRectangle(cornerRadius: 10, style: .continuous))
            Text(title)
                .font(.subheadline.weight(.semibold))
            Text(detail)
                .font(.caption)
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)
            Spacer(minLength: 0)
        }
        .padding(LHSpacing.sm)
        .frame(maxWidth: .infinity, minHeight: 132, alignment: .topLeading)
        .background(
            Color(.secondarySystemGroupedBackground),
            in: RoundedRectangle(cornerRadius: LHLayout.cardCorner, style: .continuous)
        )
    }

    private func helpCard(number: Int, icon: String, title: String, detail: String) -> some View {
        SurfaceCard(padding: LHSpacing.sm) {
            HStack(alignment: .top, spacing: LHSpacing.sm) {
                ZStack {
                    Circle()
                        .fill(Color.accentColor.opacity(0.12))
                        .frame(width: 40, height: 40)
                    Image(systemName: icon)
                        .font(.body.weight(.semibold))
                        .foregroundStyle(.tint)
                }

                VStack(alignment: .leading, spacing: 4) {
                    Text("Step \(number)")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(.secondary)
                    Text(title)
                        .font(.body.weight(.semibold))
                    Text(detail)
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                }
                Spacer(minLength: 0)
            }
        }
    }

    private func permissionCard(
        icon: String,
        title: String,
        subtitle: String,
        granted: Bool,
        actionTitle: String,
        action: @escaping () -> Void
    ) -> some View {
        SurfaceCard(padding: LHSpacing.sm) {
            HStack(spacing: LHSpacing.sm) {
                Image(systemName: icon)
                    .font(.body.weight(.semibold))
                    .foregroundStyle(granted ? LighthouseColor.success : Color.accentColor)
                    .frame(width: 40, height: 40)
                    .background(
                        (granted ? LighthouseColor.success : Color.accentColor).opacity(0.12),
                        in: RoundedRectangle(cornerRadius: 10, style: .continuous)
                    )

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
                        .font(.title2)
                        .foregroundStyle(LighthouseColor.success)
                        .accessibilityLabel("Granted")
                } else {
                    Button(actionTitle, action: action)
                        .buttonStyle(.borderedProminent)
                        .controlSize(.small)
                }
            }
        }
    }

    private func brainOption(_ variant: String) -> some View {
        let selected = viewModel.brainStatus.selectedVariant == variant
        return Button {
            viewModel.brainStatus.selectVariant(variant)
        } label: {
            HStack(spacing: LHSpacing.sm) {
                Image(systemName: selected ? "checkmark.circle.fill" : "circle")
                    .font(.title3)
                    .foregroundStyle(selected ? Color.accentColor : Color.secondary)
                VStack(alignment: .leading, spacing: 2) {
                    Text(variant)
                        .font(.body.weight(.medium))
                        .foregroundStyle(.primary)
                    if !variant.contains("Rules") {
                        Text("Shown for parity · Android only")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }
                Spacer(minLength: 0)
            }
            .padding(LHSpacing.sm)
            .background(
                Color(.secondarySystemGroupedBackground),
                in: RoundedRectangle(cornerRadius: LHLayout.cardCorner, style: .continuous)
            )
            .overlay {
                RoundedRectangle(cornerRadius: LHLayout.cardCorner, style: .continuous)
                    .strokeBorder(selected ? Color.accentColor : .clear, lineWidth: 2)
            }
        }
        .buttonStyle(.plain)
    }

    private func advance(to next: Int) {
        withAnimation(.smooth(duration: 0.35)) {
            step = next
        }
    }
}
