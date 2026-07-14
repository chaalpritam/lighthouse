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

struct LocationCard: View {
    let title: String?
    let primary: String
    let secondary: String
    var systemImage: String = "location.fill"
    var onRefresh: (() -> Void)? = nil

    init(
        title: String? = nil,
        primary: String,
        secondary: String,
        systemImage: String = "location.fill",
        onRefresh: (() -> Void)? = nil
    ) {
        self.title = title
        self.primary = primary
        self.secondary = secondary
        self.systemImage = systemImage
        self.onRefresh = onRefresh
    }

    var body: some View {
        Group {
            if let title {
                SectionBlock(title: title) {
                    card
                }
            } else {
                card
            }
        }
    }

    private var card: some View {
        SurfaceCard(padding: LHSpacing.sm) {
            HStack(alignment: .center, spacing: LHSpacing.sm) {
                IconWell(
                    systemName: systemImage,
                    size: LHLayout.iconWellMd,
                    font: .body.weight(.semibold)
                )
                VStack(alignment: .leading, spacing: LHSpacing.xxs) {
                    Text(primary)
                        .font(.body.weight(.semibold))
                    Text(secondary)
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
                Spacer(minLength: LHSpacing.xs)
                if let onRefresh {
                    Button(action: onRefresh) {
                        Image(systemName: "arrow.clockwise")
                    }
                    .buttonStyle(.bordered)
                    .controlSize(.small)
                    .accessibilityLabel("Refresh location")
                }
            }
        }
    }
}

struct PlanStepsList: View {
    let steps: [MissionPlanStep]

    var body: some View {
        VStack(alignment: .leading, spacing: LHSpacing.xs) {
            ForEach(Array(steps.enumerated()), id: \.offset) { index, step in
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
}

struct IncidentRow: View {
    let incident: Incident
    var subtitle: String? = nil
    var detail: String? = nil
    var meta: String? = nil
    var distanceLabel: String? = nil

    var body: some View {
        SurfaceCard(padding: LHSpacing.sm) {
            HStack(alignment: .top, spacing: LHSpacing.sm) {
                VStack(alignment: .leading, spacing: LHSpacing.xxs) {
                    Text(subtitle ?? "Incident #\(incident.number)")
                        .font(.body.weight(.semibold))
                    if let detail {
                        Text(detail)
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                            .lineLimit(2)
                            .fixedSize(horizontal: false, vertical: true)
                    } else {
                        Text(incident.location)
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                    }
                    if let meta {
                        Text(meta)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                    if let distanceLabel {
                        Text(distanceLabel)
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

struct TimelineEventRow: View {
    let event: TimelineEvent
    var showsTimestamp: Bool = true

    var body: some View {
        HStack(alignment: .top, spacing: LHSpacing.sm) {
            if showsTimestamp {
                Text(event.createdAt, style: .time)
                    .font(.caption.monospacedDigit())
                    .foregroundStyle(.secondary)
                    .frame(width: 52, alignment: .leading)
            }
            VStack(alignment: .leading, spacing: LHSpacing.xxs) {
                Text(event.title)
                    .font(.subheadline.weight(.semibold))
                Text(event.eventDescription)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
            Spacer(minLength: 0)
        }
    }
}
