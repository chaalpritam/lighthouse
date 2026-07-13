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
                    VStack(alignment: .leading, spacing: LHLayout.sectionSpacing) {
                        locationSection
                        guidanceSection
                        mapSection
                        quickReportSection
                        nearbyIncidentsSection
                        Color.clear.frame(height: 96)
                    }
                    .padding(.horizontal, LHLayout.screenPadding)
                    .padding(.top, LHSpacing.md)
                    .padding(.bottom, LHSpacing.lg)
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
        VStack(alignment: .leading, spacing: LHSpacing.xs) {
            SectionHeaderLabel(title: "Your Location")
            SurfaceCard {
                HStack(alignment: .center, spacing: LHSpacing.sm) {
                    Image(systemName: "location.fill")
                        .foregroundStyle(.tint)
                        .frame(width: 28)
                    VStack(alignment: .leading, spacing: 2) {
                        Text(viewModel.locationService.location?.shortLabel() ?? "Locating…")
                            .font(.body.weight(.semibold))
                        if let geo = viewModel.locationService.location {
                            Text(geo.countryLabel())
                                .font(.subheadline)
                                .foregroundStyle(.secondary)
                        }
                    }
                    Spacer(minLength: LHSpacing.xs)
                    Button {
                        Task { await viewModel.refreshLocation() }
                    } label: {
                        Image(systemName: "arrow.clockwise")
                    }
                    .buttonStyle(.bordered)
                    .controlSize(.small)
                    .accessibilityLabel("Refresh location")
                }
            }
        }
    }

    private var guidanceSection: some View {
        VStack(alignment: .leading, spacing: LHSpacing.xs) {
            SectionHeaderLabel(title: "What To Do")
            SurfaceCard {
                VStack(alignment: .leading, spacing: LHSpacing.sm) {
                    Text(viewModel.messages.last(where: { $0.role == "agent" })?.content
                          ?? "Tap a quick report or the mic to get guidance.")
                        .font(.body)
                        .fixedSize(horizontal: false, vertical: true)

                    if !viewModel.planSteps.isEmpty {
                        Divider()
                        VStack(alignment: .leading, spacing: LHSpacing.xs) {
                            ForEach(Array(viewModel.planSteps.enumerated()), id: \.offset) { index, step in
                                HStack(alignment: .top, spacing: LHSpacing.xs) {
                                    Text("\(index + 1).")
                                        .font(.subheadline.weight(.semibold))
                                        .foregroundStyle(.secondary)
                                        .frame(width: 20, alignment: .trailing)
                                    Text(step.action)
                                        .font(.subheadline)
                                        .fixedSize(horizontal: false, vertical: true)
                                }
                            }
                        }
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
        VStack(alignment: .leading, spacing: LHSpacing.xs) {
            SectionHeaderLabel(title: "Map")
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
        VStack(alignment: .leading, spacing: LHSpacing.xs) {
            SectionHeaderLabel(title: "Quick Report")
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
        VStack(alignment: .leading, spacing: LHSpacing.xs) {
            SectionHeaderLabel(title: "Nearby Incidents")
            if viewModel.incidents.isEmpty {
                SurfaceCard {
                    ContentUnavailableView(
                        "No Incidents Yet",
                        systemImage: "mappin.slash",
                        description: Text("Reports you send will appear here.")
                    )
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, LHSpacing.sm)
                }
            } else {
                VStack(spacing: LHLayout.rowSpacing) {
                    ForEach(Array(viewModel.incidents.prefix(5)), id: \.id) { incident in
                        SurfaceCard(padding: LHSpacing.sm) {
                            HStack(alignment: .top, spacing: LHSpacing.sm) {
                                VStack(alignment: .leading, spacing: LHSpacing.xxs) {
                                    Text("Incident #\(incident.number)")
                                        .font(.body.weight(.semibold))
                                    Text(incident.location)
                                        .font(.subheadline)
                                        .foregroundStyle(.secondary)
                                    if let user = viewModel.locationService.location,
                                       let lat = incident.latitude, let lon = incident.longitude {
                                        let km = LocationResolver.distanceKm(from: user, toLat: lat, toLon: lon)
                                        Text(String(format: "%.1f km away", km))
                                            .font(.caption)
                                            .foregroundStyle(.tint)
                                    }
                                }
                                Spacer(minLength: LHSpacing.xs)
                                PriorityBadge(priority: incident.priority)
                            }
                        }
                    }
                }
            }
        }
    }

    private var voiceDock: some View {
        FloatingDock {
            HStack(spacing: LHSpacing.md) {
                Button {
                    viewModel.toggleContinuousVoice()
                } label: {
                    Image(systemName: viewModel.continuousVoiceMode ? "ear.fill" : "ear")
                        .font(.body.weight(.semibold))
                        .frame(width: 36, height: 36)
                }
                .buttonStyle(.bordered)
                .tint(viewModel.continuousVoiceMode ? .accentColor : .secondary)
                .accessibilityLabel("Hands-free mode")

                PhotosPicker(selection: $selectedPhoto, matching: .images) {
                    Image(systemName: "camera.fill")
                        .font(.body.weight(.semibold))
                        .frame(width: 36, height: 36)
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

/// Layout helper for wrapping chips.
struct FlowLayout: Layout {
    var spacing: CGFloat = 8

    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        arrange(proposal: proposal, subviews: subviews).size
    }

    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
        let result = arrange(proposal: proposal, subviews: subviews)
        for (index, origin) in result.origins.enumerated() {
            subviews[index].place(
                at: CGPoint(x: bounds.minX + origin.x, y: bounds.minY + origin.y),
                proposal: .unspecified
            )
        }
    }

    private func arrange(proposal: ProposedViewSize, subviews: Subviews) -> (size: CGSize, origins: [CGPoint]) {
        let maxWidth = proposal.width ?? .infinity
        var origins: [CGPoint] = []
        var x: CGFloat = 0
        var y: CGFloat = 0
        var rowHeight: CGFloat = 0
        for subview in subviews {
            let size = subview.sizeThatFits(.unspecified)
            if x + size.width > maxWidth, x > 0 {
                x = 0
                y += rowHeight + spacing
                rowHeight = 0
            }
            origins.append(CGPoint(x: x, y: y))
            rowHeight = max(rowHeight, size.height)
            x += size.width + spacing
        }
        return (CGSize(width: maxWidth, height: y + rowHeight), origins)
    }
}
