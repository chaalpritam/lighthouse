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
                    VStack(alignment: .leading, spacing: 16) {
                        locationCard
                        guidanceCard
                        mapCard
                        legend
                        quickReportChips
                        nearbyIncidents
                        Color.clear.frame(height: 120)
                    }
                    .padding(16)
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

    private var locationCard: some View {
        GlassCard {
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    SectionHeaderLabel(title: "Your location")
                    Text(viewModel.locationService.location?.shortLabel() ?? "Locating…")
                        .font(.headline)
                    if let geo = viewModel.locationService.location {
                        Text(geo.countryLabel())
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }
                Spacer()
                Button {
                    Task { await viewModel.refreshLocation() }
                } label: {
                    Image(systemName: "location.fill")
                }
                .buttonStyle(.bordered)
            }
        }
    }

    private var guidanceCard: some View {
        GlassCard {
            VStack(alignment: .leading, spacing: 10) {
                SectionHeaderLabel(title: "What to do")
                Text(viewModel.messages.last(where: { $0.role == "agent" })?.content
                      ?? "Tap a quick report or the mic to get guidance.")
                    .font(.body)
                if !viewModel.planSteps.isEmpty {
                    Divider()
                    ForEach(Array(viewModel.planSteps.enumerated()), id: \.offset) { index, step in
                        Text("\(index + 1). \(step.action)")
                            .font(.subheadline)
                    }
                }
                HStack {
                    Text(viewModel.agentPhase.rawValue)
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(LighthouseColor.blue)
                    Spacer()
                    Text(viewModel.brainStatus.mode.rawValue)
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                }
            }
        }
    }

    private var mapCard: some View {
        Map(position: $cameraPosition) {
            UserAnnotation()
            ForEach(viewModel.incidents, id: \.id) { incident in
                if let lat = incident.latitude, let lon = incident.longitude {
                    Annotation("#\(incident.number)", coordinate: .init(latitude: lat, longitude: lon)) {
                        Circle()
                            .fill(LighthouseColor.priority(incident.priority))
                            .frame(width: 18, height: 18)
                            .overlay {
                                Text("\(incident.number)")
                                    .font(.caption2.bold())
                                    .foregroundStyle(.white)
                            }
                    }
                }
            }
        }
        .frame(height: 280)
        .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 20, style: .continuous)
                .strokeBorder(.white.opacity(0.35), lineWidth: 0.8)
        }
        .mapControls {
            MapUserLocationButton()
            MapCompass()
        }
    }

    private var legend: some View {
        HStack(spacing: 12) {
            ForEach(["critical", "high", "medium", "low"], id: \.self) { level in
                HStack(spacing: 4) {
                    Circle().fill(LighthouseColor.priority(level)).frame(width: 8, height: 8)
                    Text(level.capitalized).font(.caption2)
                }
            }
        }
    }

    private var quickReportChips: some View {
        VStack(alignment: .leading, spacing: 8) {
            SectionHeaderLabel(title: "Quick report")
            FlowLayout(spacing: 8) {
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

    private var nearbyIncidents: some View {
        VStack(alignment: .leading, spacing: 8) {
            SectionHeaderLabel(title: "Nearby incidents")
            if viewModel.incidents.isEmpty {
                Text("No incidents yet.")
                    .foregroundStyle(.secondary)
            } else {
                ForEach(Array(viewModel.incidents.prefix(5)), id: \.id) { incident in
                    GlassCard(padding: 12, cornerRadius: 14) {
                        HStack {
                            VStack(alignment: .leading, spacing: 4) {
                                Text("Incident #\(incident.number)").fontWeight(.semibold)
                                Text(incident.location).font(.caption).foregroundStyle(.secondary)
                                if let user = viewModel.locationService.location,
                                   let lat = incident.latitude, let lon = incident.longitude {
                                    let km = LocationResolver.distanceKm(from: user, toLat: lat, toLon: lon)
                                    Text(String(format: "%.1f km away", km))
                                        .font(.caption2)
                                        .foregroundStyle(LighthouseColor.blue)
                                }
                            }
                            Spacer()
                            PriorityBadge(priority: incident.priority)
                        }
                    }
                }
            }
        }
    }

    private var voiceDock: some View {
        GlassEffectContainerCompat {
            HStack(spacing: 14) {
                Button("Hands-free") { viewModel.toggleContinuousVoice() }
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(viewModel.continuousVoiceMode ? LighthouseColor.blue : .primary)
                PhotosPicker(selection: $selectedPhoto, matching: .images) {
                    Label("Photo", systemImage: "camera.fill")
                        .labelStyle(.iconOnly)
                }
                VoiceMicButton(isListening: viewModel.voiceService.state == .listening) {
                    if viewModel.voiceService.state == .listening {
                        viewModel.stopListening()
                    } else {
                        viewModel.startListening()
                    }
                }
                if !viewModel.voiceService.transcript.isEmpty {
                    Text(viewModel.voiceService.transcript)
                        .font(.caption2)
                        .lineLimit(2)
                        .frame(maxWidth: 100)
                }
            }
            .padding(.horizontal, 20)
            .padding(.vertical, 12)
        }
        .padding(.bottom, 8)
    }
}

/// Layout helper for wrapping chips.
struct FlowLayout: Layout {
    var spacing: CGFloat = 8

    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        let result = arrange(proposal: proposal, subviews: subviews)
        return result.size
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

/// Glass dock wrapper that uses ultra-thin material (Liquid Glass–ready).
struct GlassEffectContainerCompat<Content: View>: View {
    @ViewBuilder var content: () -> Content
    var body: some View {
        content()
            .background(.ultraThinMaterial, in: Capsule())
            .overlay {
                Capsule().strokeBorder(.white.opacity(0.35), lineWidth: 0.8)
            }
            .shadow(color: .black.opacity(0.12), radius: 18, y: 8)
            .padding(.horizontal, 16)
    }
}
