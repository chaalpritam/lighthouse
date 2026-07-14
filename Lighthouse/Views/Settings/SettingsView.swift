import SwiftUI
import UniformTypeIdentifiers

struct SettingsView: View {
    var viewModel: MissionViewModel
    @State private var exportText: String?
    @State private var showImporter = false
    @State private var showResetConfirm = false
    @State private var importError: String?

    var body: some View {
        NavigationStack {
            ScrollView {
                ScreenScrollContent {
                    brainSection
                    if viewModel.mission != nil {
                        missionSection
                    }
                    if !viewModel.planSteps.isEmpty {
                        planSection
                    }
                    peerSyncSection
                    if !viewModel.timeline.isEmpty {
                        timelineSection
                    }
                    resetSection
                }
            }
            .background(LighthouseBackground())
            .navigationTitle("Settings")
            .toolbarTitleDisplayMode(.large)
            .fileImporter(isPresented: $showImporter, allowedContentTypes: [.json, .plainText]) { result in
                switch result {
                case .success(let url):
                    do {
                        let accessed = url.startAccessingSecurityScopedResource()
                        defer { if accessed { url.stopAccessingSecurityScopedResource() } }
                        let json = try String(contentsOf: url, encoding: .utf8)
                        try viewModel.importMission(json: json)
                    } catch {
                        importError = error.localizedDescription
                    }
                case .failure(let error):
                    importError = error.localizedDescription
                }
            }
            .confirmationDialog("Reset Lighthouse?", isPresented: $showResetConfirm, titleVisibility: .visible) {
                Button("Reset", role: .destructive) {
                    try? viewModel.resetApp()
                }
            }
            .alert("Sync Error", isPresented: Binding(
                get: { importError != nil },
                set: { if !$0 { importError = nil } }
            )) {
                Button("OK", role: .cancel) { importError = nil }
            } message: {
                Text(importError ?? "")
            }
        }
    }

    private var brainSection: some View {
        SectionBlock(title: "Agent Brain") {
            VStack(spacing: LHLayout.rowSpacing) {
                SurfaceCard(padding: LHSpacing.sm) {
                    VStack(alignment: .leading, spacing: LHSpacing.sm) {
                        Text(viewModel.brainStatus.ramSummary)
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                            .fixedSize(horizontal: false, vertical: true)
                        InfoRow(label: "Status", value: viewModel.brainStatus.statusMessage)
                    }
                }

                VStack(spacing: LHSpacing.xs) {
                    ForEach(viewModel.brainStatus.variants, id: \.self) { variant in
                        SelectableRow(
                            title: variant,
                            subtitle: variant.contains("Rules") ? nil : "Shown for parity · Android only",
                            isSelected: viewModel.brainStatus.selectedVariant == variant
                        ) {
                            viewModel.brainStatus.selectVariant(variant)
                        }
                    }
                }
            }
        }
    }

    private var missionSection: some View {
        SectionBlock(title: "Mission") {
            SurfaceCard {
                VStack(spacing: LHSpacing.sm) {
                    InfoRow(label: "Name", value: viewModel.mission?.name ?? "—")
                    Divider()
                    InfoRow(label: "Type", value: viewModel.mission?.disasterType ?? "—")
                    Divider()
                    InfoRow(label: "Location", value: viewModel.mission?.location ?? "—")
                    Divider()
                    InfoRow(label: "Incidents", value: "\(viewModel.stats.incidents)")
                    Divider()
                    InfoRow(label: "Critical", value: "\(viewModel.stats.criticalIncidents)")
                    Divider()
                    InfoRow(label: "Rescued", value: "\(viewModel.stats.rescued)")
                }
            }
        }
    }

    private var planSection: some View {
        SectionBlock(title: "Current Plan") {
            SurfaceCard {
                PlanStepsList(steps: viewModel.planSteps)
            }
        }
    }

    private var peerSyncSection: some View {
        SectionBlock(title: "Peer Sync") {
            SurfaceCard {
                VStack(alignment: .leading, spacing: LHSpacing.sm) {
                    Text("Share a JSON snapshot with nearby devices when network is unavailable.")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                        .fixedSize(horizontal: false, vertical: true)

                    SecondaryButton(title: "Export Mission JSON", systemImage: "square.and.arrow.up") {
                        do {
                            exportText = try viewModel.exportMission()
                        } catch {
                            importError = error.localizedDescription
                        }
                    }

                    if let exportText {
                        ShareLink(
                            item: exportText,
                            subject: Text("Lighthouse Mission"),
                            message: Text("Offline mission snapshot")
                        ) {
                            Label("Share Snapshot", systemImage: "square.and.arrow.up.on.square")
                                .fontWeight(.semibold)
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 4)
                        }
                        .buttonStyle(.bordered)
                        .controlSize(.large)

                        Text(exportText)
                            .font(.caption.monospaced())
                            .foregroundStyle(.secondary)
                            .lineLimit(4)
                    }

                    SecondaryButton(title: "Import Mission JSON", systemImage: "square.and.arrow.down") {
                        showImporter = true
                    }
                }
            }
        }
    }

    private var timelineSection: some View {
        SectionBlock(title: "Timeline") {
            SurfaceCard {
                VStack(alignment: .leading, spacing: LHSpacing.sm) {
                    ForEach(Array(viewModel.timeline.prefix(6)), id: \.id) { event in
                        TimelineEventRow(event: event, showsTimestamp: false)
                        if event.id != viewModel.timeline.prefix(6).last?.id {
                            Divider()
                        }
                    }
                }
            }
        }
    }

    private var resetSection: some View {
        SectionBlock(title: "Danger Zone") {
            SurfaceCard {
                VStack(alignment: .leading, spacing: LHSpacing.sm) {
                    Text("Clears mission database and field captures. Model preference is kept.")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                        .fixedSize(horizontal: false, vertical: true)

                    PrimaryButton(title: "Reset App", tint: LighthouseColor.critical) {
                        showResetConfirm = true
                    }
                }
            }
        }
    }
}
