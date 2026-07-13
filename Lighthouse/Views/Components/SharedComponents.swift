import SwiftUI

struct AgentLoopBar: View {
    let current: AgentLoopPhase
    let traversed: [AgentLoopPhase]

    private let activePhases: [AgentLoopPhase] = [.sense, .decide, .act, .verify, .recover]

    var body: some View {
        HStack(spacing: LHSpacing.xs) {
            ForEach(activePhases) { phase in
                VStack(spacing: LHSpacing.xxs) {
                    Circle()
                        .fill(color(for: phase))
                        .frame(width: 10, height: 10)
                    Text(phase.rawValue)
                        .font(.caption2)
                        .foregroundStyle(phase == current ? Color.primary : Color.secondary)
                        .lineLimit(1)
                        .minimumScaleFactor(0.8)
                }
                .frame(maxWidth: .infinity)
            }
        }
        .padding(.vertical, LHSpacing.xs)
        .accessibilityElement(children: .combine)
        .accessibilityLabel("Agent phase \(current.rawValue)")
    }

    private func color(for phase: AgentLoopPhase) -> Color {
        if phase == current { return .accentColor }
        if traversed.contains(phase) { return LighthouseColor.success }
        return Color(.tertiaryLabel).opacity(0.4)
    }
}

struct PriorityBadge: View {
    let priority: String

    var body: some View {
        Text(priority.capitalized)
            .font(.caption2.weight(.semibold))
            .padding(.horizontal, LHSpacing.xs)
            .padding(.vertical, LHSpacing.xxs)
            .foregroundStyle(LighthouseColor.priority(priority))
            .background(
                LighthouseColor.priority(priority).opacity(0.14),
                in: Capsule()
            )
    }
}

struct StatTile: View {
    let title: String
    let value: String
    var tint: Color = .accentColor

    var body: some View {
        VStack(alignment: .leading, spacing: LHSpacing.xxs) {
            Text(value)
                .font(.title2.weight(.semibold))
                .foregroundStyle(tint)
                .monospacedDigit()
            Text(title)
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(LHSpacing.sm)
        .background(
            Color(.secondarySystemGroupedBackground),
            in: RoundedRectangle(cornerRadius: LHLayout.controlCorner, style: .continuous)
        )
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
