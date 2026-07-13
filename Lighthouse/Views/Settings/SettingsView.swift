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
            List {
                Section {
                    Text(viewModel.brainStatus.ramSummary)
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                    ForEach(viewModel.brainStatus.variants, id: \.self) { variant in
                        Button {
                            viewModel.brainStatus.selectVariant(variant)
                        } label: {
                            HStack {
                                Text(variant)
                                    .foregroundStyle(.primary)
                                Spacer()
                                if viewModel.brainStatus.selectedVariant == variant {
                                    Image(systemName: "checkmark")
                                        .foregroundStyle(.tint)
                                        .fontWeight(.semibold)
                                }
                            }
                        }
                    }
                    LabeledContent("Status", value: viewModel.brainStatus.statusMessage)
                } header: {
                    Text("Agent Brain")
                }

                if let mission = viewModel.mission {
                    Section("Mission") {
                        LabeledContent("Name", value: mission.name)
                        LabeledContent("Type", value: mission.disasterType)
                        LabeledContent("Location", value: mission.location)
                        LabeledContent("Incidents", value: "\(viewModel.stats.incidents)")
                        LabeledContent("Critical", value: "\(viewModel.stats.criticalIncidents)")
                        LabeledContent("Rescued", value: "\(viewModel.stats.rescued)")
                    }
                }

                if !viewModel.planSteps.isEmpty {
                    Section("Current Plan") {
                        ForEach(Array(viewModel.planSteps.enumerated()), id: \.offset) { index, step in
                            Text("\(index + 1). \(step.action)")
                        }
                    }
                }

                Section {
                    Button("Export Mission JSON") {
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
                        )
                        Text(exportText)
                            .font(.caption.monospaced())
                            .foregroundStyle(.secondary)
                            .lineLimit(4)
                    }
                    Button("Import Mission JSON") {
                        showImporter = true
                    }
                } header: {
                    Text("Peer Sync")
                } footer: {
                    Text("Share a JSON snapshot with nearby devices when network is unavailable.")
                }

                if !viewModel.timeline.isEmpty {
                    Section("Timeline") {
                        ForEach(Array(viewModel.timeline.prefix(6)), id: \.id) { event in
                            VStack(alignment: .leading, spacing: 2) {
                                Text(event.title)
                                    .font(.body)
                                Text(event.eventDescription)
                                    .font(.subheadline)
                                    .foregroundStyle(.secondary)
                            }
                            .padding(.vertical, 2)
                        }
                    }
                }

                Section {
                    Button("Reset App", role: .destructive) {
                        showResetConfirm = true
                    }
                } footer: {
                    Text("Clears mission database and field captures. Model preference is kept.")
                }
            }
            .listStyle(.insetGrouped)
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
}
