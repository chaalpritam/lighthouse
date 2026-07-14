import SwiftUI
import MapKit
import PhotosUI

struct HomeMapView: View {
    var viewModel: MissionViewModel
    @State private var cameraPosition: MapCameraPosition = .userLocation(fallback: .automatic)
    @State private var selectedPhoto: PhotosPickerItem?

    private let quickReports = [
        "There's a fire near me — what should I do?",
        "People are trapped — help me",
        "Someone is injured and needs help",
        "Where am I? What's the safest action?"
    ]

    var body: some View {
        NavigationStack {
            ZStack(alignment: .bottom) {
                ScrollView {
                    ScreenScrollContent(bottomClearance: 96) {
                        locationSection
                        guidanceSection
                        mapSection
                        quickReportSection
                        nearbyIncidentsSection
                    }
                }
                voiceDock
            }
            .background(LighthouseBackground())
            .navigationTitle("Home")
            .toolbarTitleDisplayMode(.large)
        }
        .onChange(of: selectedPhoto) { _, item in
            guard let item else { return }
            Task {
                if let data = try? await item.loadTransferable(type: Data.self),
                   let image = UIImage(data: data) {
                    await viewModel.ingestPhoto(image)
                }
                selectedPhoto = nil
            }
        }
    }

    private var locationSection: some View {
        LocationCard(
            title: "Your Location",
            primary: viewModel.locationService.location?.shortLabel() ?? "Locating…",
            secondary: viewModel.locationService.location?.countryLabel() ?? "Waiting for GPS",
            systemImage: "location.fill"
        ) {
            Task { await viewModel.refreshLocation() }
        }
    }

    private var guidanceSection: some View {
        SectionBlock(title: "What To Do") {
            SurfaceCard {
                VStack(alignment: .leading, spacing: LHSpacing.sm) {
                    Text(viewModel.messages.last(where: { $0.role == "agent" })?.content
                          ?? "Tap a quick report or the mic to get guidance.")
                        .font(.body)
                        .fixedSize(horizontal: false, vertical: true)

                    if !viewModel.planSteps.isEmpty {
                        Divider()
                        PlanStepsList(steps: viewModel.planSteps)
                    }

                    HStack(spacing: LHSpacing.xs) {
                        Label(viewModel.agentPhase.rawValue, systemImage: "circle.fill")
                            .font(.caption.weight(.semibold))
                            .foregroundStyle(.tint)
                            .labelStyle(.titleAndIcon)
                            .symbolRenderingMode(.hierarchical)
                        Spacer()
                        Text(viewModel.brainStatus.mode.rawValue)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }
            }
        }
    }

    private var mapSection: some View {
        SectionBlock(title: "Map") {
            Map(position: $cameraPosition) {
                UserAnnotation()
                ForEach(viewModel.incidents, id: \.id) { incident in
                    if let lat = incident.latitude, let lon = incident.longitude {
                        Annotation("#\(incident.number)", coordinate: .init(latitude: lat, longitude: lon)) {
                            Circle()
                                .fill(LighthouseColor.priority(incident.priority))
                                .frame(width: 22, height: 22)
                                .overlay {
                                    Text("\(incident.number)")
                                        .font(.caption2.bold())
                                        .foregroundStyle(.white)
                                }
                        }
                    }
                }
            }
            .frame(height: 260)
            .clipShape(RoundedRectangle(cornerRadius: LHLayout.cardCorner, style: .continuous))
            .mapControls {
                MapUserLocationButton()
                MapCompass()
            }

            HStack(spacing: LHSpacing.md) {
                ForEach(["critical", "high", "medium", "low"], id: \.self) { level in
                    HStack(spacing: LHSpacing.xxs) {
                        Circle()
                            .fill(LighthouseColor.priority(level))
                            .frame(width: 8, height: 8)
                        Text(level.capitalized)
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                    }
                }
                Spacer(minLength: 0)
            }
            .padding(.top, LHSpacing.xxs)
        }
    }

    private var quickReportSection: some View {
        SectionBlock(title: "Quick Report") {
            FlowLayout(spacing: LHSpacing.xs) {
                ForEach(quickReports, id: \.self) { report in
                    Button(report) {
                        Task { await viewModel.sendMessage(report) }
                    }
                    .buttonStyle(.bordered)
                    .controlSize(.small)
                }
            }
        }
    }

    private var nearbyIncidentsSection: some View {
        SectionBlock(title: "Nearby Incidents") {
            if viewModel.incidents.isEmpty {
                EmptyStateCard(
                    title: "No Incidents Yet",
                    systemImage: "mappin.slash",
                    description: "Reports you send will appear here."
                )
            } else {
                VStack(spacing: LHLayout.rowSpacing) {
                    ForEach(Array(viewModel.incidents.prefix(5)), id: \.id) { incident in
                        IncidentRow(
                            incident: incident,
                            distanceLabel: distanceLabel(for: incident)
                        )
                    }
                }
            }
        }
    }

    private func distanceLabel(for incident: Incident) -> String? {
        guard let user = viewModel.locationService.location,
              let lat = incident.latitude,
              let lon = incident.longitude else { return nil }
        let km = LocationResolver.distanceKm(from: user, toLat: lat, toLon: lon)
        return String(format: "%.1f km away", km)
    }

    private var voiceDock: some View {
        FloatingDock {
            HStack(spacing: LHSpacing.md) {
                Button {
                    viewModel.toggleContinuousVoice()
                } label: {
                    Image(systemName: viewModel.continuousVoiceMode ? "ear.fill" : "ear")
                        .font(.body.weight(.semibold))
                        .frame(width: LHLayout.dockButton, height: LHLayout.dockButton)
                }
                .buttonStyle(.bordered)
                .tint(viewModel.continuousVoiceMode ? .accentColor : .secondary)
                .accessibilityLabel("Hands-free mode")

                PhotosPicker(selection: $selectedPhoto, matching: .images) {
                    Image(systemName: "camera.fill")
                        .font(.body.weight(.semibold))
                        .frame(width: LHLayout.dockButton, height: LHLayout.dockButton)
                }
                .buttonStyle(.bordered)
                .accessibilityLabel("Attach photo")

                VoiceMicButton(isListening: viewModel.voiceService.state == .listening) {
                    if viewModel.voiceService.state == .listening {
                        viewModel.stopListening()
                    } else {
                        viewModel.startListening()
                    }
                }

                Group {
                    if viewModel.voiceService.transcript.isEmpty {
                        Text(viewModel.voiceService.state == .listening ? "Listening…" : "Hold mic to report")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                            .frame(maxWidth: .infinity, alignment: .leading)
                    } else {
                        Text(viewModel.voiceService.transcript)
                            .font(.caption)
                            .foregroundStyle(.primary)
                            .lineLimit(2)
                            .frame(maxWidth: .infinity, alignment: .leading)
                    }
                }
            }
        }
    }
}
