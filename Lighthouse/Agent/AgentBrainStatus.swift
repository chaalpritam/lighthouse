import Foundation

enum AgentBrainMode: String {
    case rules = "Rules engine"
    case onDeviceAI = "On-device AI"
}

@Observable
@MainActor
final class AgentBrainStatus {
    var mode: AgentBrainMode = .rules
    var statusMessage = "Offline rules engine ready"
    var selectedVariant = "Rules"
    var isDownloading = false
    var downloadProgress: Double = 0

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
