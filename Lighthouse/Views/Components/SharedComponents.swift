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
                LighthouseColor.priority(priority).opacity(LHLayout.badgeFillOpacity),
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
            in: RoundedRectangle(cornerRadius: LHLayout.cardCorner, style: .continuous)
        )
    }
}

struct AgentBrainStatusBar: View {
    var brain: AgentBrainStatus

    var body: some View {
        HStack(spacing: LHSpacing.sm) {
            Image(systemName: "brain.head.profile")
                .font(.body.weight(.medium))
                .foregroundStyle(.tint)
                .frame(width: 24, alignment: .center)
            VStack(alignment: .leading, spacing: LHSpacing.xxs) {
                Text(brain.mode.rawValue)
                    .font(.subheadline.weight(.semibold))
                Text(brain.statusMessage)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
            }
            Spacer(minLength: 0)
        }
        .padding(.horizontal, LHLayout.screenPadding)
        .padding(.vertical, LHSpacing.sm)
        .background(.bar)
        .overlay(alignment: .bottom) {
            Divider()
        }
    }
}

struct VoiceMicButton: View {
    let isListening: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Image(systemName: isListening ? "stop.fill" : "mic.fill")
                .font(.title3.weight(.semibold))
                .foregroundStyle(.white)
                .frame(width: 56, height: 56)
                .background(
                    Circle().fill(isListening ? LighthouseColor.critical : Color.accentColor)
                )
        }
        .buttonStyle(.plain)
        .accessibilityLabel(isListening ? "Stop listening" : "Start voice report")
    }
}

/// Soft floating dock for primary actions (Home voice controls).
struct FloatingDock<Content: View>: View {
    @ViewBuilder var content: () -> Content

    var body: some View {
        content()
            .padding(.horizontal, LHSpacing.md)
            .padding(.vertical, LHSpacing.sm)
            .background(.regularMaterial, in: Capsule())
            .padding(.horizontal, LHLayout.screenPadding)
            .padding(.bottom, LHSpacing.xs)
    }
}
