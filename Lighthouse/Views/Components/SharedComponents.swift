import SwiftUI

struct AgentLoopBar: View {
    let current: AgentLoopPhase
    let traversed: [AgentLoopPhase]

    private let activePhases: [AgentLoopPhase] = [.sense, .decide, .act, .verify, .recover]

    var body: some View {
        HStack(spacing: 6) {
            ForEach(activePhases) { phase in
                VStack(spacing: 4) {
                    Circle()
                        .fill(color(for: phase))
                        .frame(width: 10, height: 10)
                    Text(phase.rawValue)
                        .font(.caption2.weight(.medium))
                        .foregroundStyle(phase == current ? LighthouseColor.blue : LighthouseColor.secondaryLabel)
                }
                .frame(maxWidth: .infinity)
            }
        }
        .padding(.vertical, 8)
    }

    private func color(for phase: AgentLoopPhase) -> Color {
        if phase == current { return LighthouseColor.blue }
        if traversed.contains(phase) { return LighthouseColor.success }
        return Color.secondary.opacity(0.25)
    }
}

struct PriorityBadge: View {
    let priority: String

    var body: some View {
        Text(priority.uppercased())
            .font(.caption2.weight(.bold))
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
            .foregroundStyle(.white)
            .background(LighthouseColor.priority(priority), in: Capsule())
    }
}

struct StatTile: View {
    let title: String
    let value: String
    var tint: Color = LighthouseColor.blue

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(value)
                .font(.title2.bold())
                .foregroundStyle(tint)
            Text(title)
                .font(.caption)
                .foregroundStyle(LighthouseColor.secondaryLabel)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(12)
        .background(.thinMaterial, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
    }
}

struct AgentBrainStatusBar: View {
    var brain: AgentBrainStatus

    var body: some View {
        HStack(spacing: 10) {
            Image(systemName: "brain.head.profile")
                .foregroundStyle(LighthouseColor.blue)
            VStack(alignment: .leading, spacing: 2) {
                Text(brain.mode.rawValue)
                    .font(.caption.weight(.semibold))
                Text(brain.statusMessage)
                    .font(.caption2)
                    .foregroundStyle(LighthouseColor.secondaryLabel)
                    .lineLimit(1)
            }
            Spacer()
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 10)
        .background(.ultraThinMaterial)
    }
}

struct VoiceMicButton: View {
    let isListening: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Image(systemName: isListening ? "stop.fill" : "mic.fill")
                .font(.title2.weight(.semibold))
                .foregroundStyle(.white)
                .frame(width: 68, height: 68)
                .background(
                    Circle()
                        .fill(isListening ? LighthouseColor.critical : LighthouseColor.blue)
                        .shadow(color: (isListening ? LighthouseColor.critical : LighthouseColor.blue).opacity(0.45), radius: 16, y: 6)
                )
                .scaleEffect(isListening ? 1.08 : 1)
                .animation(.easeInOut(duration: 0.8).repeatForever(autoreverses: true), value: isListening)
        }
        .buttonStyle(.plain)
        .accessibilityLabel(isListening ? "Stop listening" : "Start voice report")
    }
}
