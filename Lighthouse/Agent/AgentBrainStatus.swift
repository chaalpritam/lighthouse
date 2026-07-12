import Foundation
import Combine

enum AgentBrainMode: String {
    case rules = "Rules engine"
    case onDeviceAI = "On-device AI"
}

@MainActor
final class AgentBrainStatus: ObservableObject {
    @Published var mode: AgentBrainMode = .rules
    @Published var statusMessage = "Offline rules engine ready"
    @Published var selectedVariant = "Rules"
    @Published var isDownloading = false
    @Published var downloadProgress: Double = 0

    /// Gemma LiteRT models are Android-specific. On iOS the rules engine
    /// provides full offline parity; this surface keeps UI parity for settings.
    let variants = ["Rules (on-device)", "Gemma 4 E2B (Android)", "Gemma 4 E4B (Android)"]

    var ramSummary: String {
        let total = ProcessInfo.processInfo.physicalMemory
        let gb = Double(total) / 1_073_741_824
        return String(format: "%.1f GB device RAM · rules engine uses minimal memory", gb)
    }

    func selectVariant(_ name: String) {
        selectedVariant = name
        if name.contains("Rules") {
            mode = .rules
            statusMessage = "Offline rules engine ready"
        } else {
            mode = .rules
            statusMessage = "Gemma LiteRT is Android-only — using rules engine on iOS"
        }
    }
}
