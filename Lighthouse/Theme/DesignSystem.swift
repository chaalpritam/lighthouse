import SwiftUI

/// Spacing scale aligned with Apple HIG (8pt grid).
enum LHSpacing {
    static let xxs: CGFloat = 4
    static let xs: CGFloat = 8
    static let sm: CGFloat = 12
    static let md: CGFloat = 16
    static let lg: CGFloat = 20
    static let xl: CGFloat = 24
    static let xxl: CGFloat = 32
}

enum LHLayout {
    static let screenPadding: CGFloat = 16
    static let sectionSpacing: CGFloat = 24
    static let rowSpacing: CGFloat = 12
    static let cardCorner: CGFloat = 12
    static let controlCorner: CGFloat = 10
    static let bubbleCorner: CGFloat = 16
    static let composerCorner: CGFloat = 16
    static let iconWellSm: CGFloat = 28
    static let iconWellMd: CGFloat = 36
    static let iconWellLg: CGFloat = 40
    static let dockButton: CGFloat = 36
    static let tintFillOpacity: Double = 0.12
    static let badgeFillOpacity: Double = 0.14
}

enum LighthouseColor {
    static let blue = Color.accentColor
    static let critical = Color(.systemRed)
    static let high = Color(.systemOrange)
    static let medium = Color(.systemYellow)
    static let success = Color(.systemGreen)

    static func priority(_ value: String) -> Color {
        switch value.lowercased() {
        case "critical": return critical
        case "high": return high
        case "medium": return medium
        default: return success
        }
    }

    static func softFill(_ color: Color = .accentColor) -> Color {
        color.opacity(LHLayout.tintFillOpacity)
    }
}

/// Standard inset surface matching iOS grouped list cells.
struct SurfaceCard<Content: View>: View {
    var padding: CGFloat = LHSpacing.md
    @ViewBuilder var content: () -> Content

    var body: some View {
        content()
            .padding(padding)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(
                Color(.secondarySystemGroupedBackground),
                in: RoundedRectangle(cornerRadius: LHLayout.cardCorner, style: .continuous)
            )
    }
}

struct PrimaryButton: View {
    let title: String
    var systemImage: String? = nil
    var role: ButtonRole? = nil
    var tint: Color = .accentColor
    let action: () -> Void

    var body: some View {
        Button(role: role, action: action) {
            label
        }
        .buttonStyle(.borderedProminent)
        .tint(tint)
        .controlSize(.large)
    }

    private var label: some View {
        HStack(spacing: LHSpacing.xs) {
            if let systemImage {
                Image(systemName: systemImage)
            }
            Text(title)
                .fontWeight(.semibold)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 4)
    }
}

struct SecondaryButton: View {
    let title: String
    var systemImage: String? = nil
    var tint: Color = .accentColor
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: LHSpacing.xs) {
                if let systemImage {
                    Image(systemName: systemImage)
                }
                Text(title)
                    .fontWeight(.semibold)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 4)
        }
        .buttonStyle(.bordered)
        .tint(tint)
        .controlSize(.large)
    }
}

struct SectionHeaderLabel: View {
    let title: String

    var body: some View {
        Text(title)
            .font(.footnote.weight(.semibold))
            .foregroundStyle(.secondary)
            .textCase(nil)
            .frame(maxWidth: .infinity, alignment: .leading)
    }
}

/// Soft tinted well for SF Symbols used across cards.
struct IconWell: View {
    let systemName: String
    var size: CGFloat = LHLayout.iconWellMd
    var tint: Color = .accentColor
    var font: Font = .body.weight(.semibold)

    var body: some View {
        Image(systemName: systemName)
            .font(font)
            .foregroundStyle(tint)
            .frame(width: size, height: size)
            .background(
                LighthouseColor.softFill(tint),
                in: RoundedRectangle(cornerRadius: LHLayout.controlCorner, style: .continuous)
            )
            .accessibilityHidden(true)
    }
}

/// Shared text field chrome used in composers and forms.
struct LighthouseFieldBackground: ViewModifier {
    var cornerRadius: CGFloat = LHLayout.controlCorner

    func body(content: Content) -> some View {
        content
            .padding(LHSpacing.sm)
            .background(
                Color(.tertiarySystemFill),
                in: RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
            )
    }
}

extension View {
    func lighthouseField(cornerRadius: CGFloat = LHLayout.controlCorner) -> some View {
        modifier(LighthouseFieldBackground(cornerRadius: cornerRadius))
    }
}

struct EmptyStateCard: View {
    let title: String
    var systemImage: String? = nil
    var description: String? = nil
    var compact: Bool = false

    var body: some View {
        SurfaceCard {
            if compact {
                Text(description ?? title)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity, alignment: .leading)
            } else if let systemImage, let description {
                ContentUnavailableView(title, systemImage: systemImage, description: Text(description))
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, LHSpacing.sm)
            } else if let systemImage {
                ContentUnavailableView(title, systemImage: systemImage)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, LHSpacing.sm)
            } else {
                Text(title)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }
        }
    }
}

/// Consistent outer padding for scroll-based tab screens.
struct ScreenScrollContent<Content: View>: View {
    var bottomClearance: CGFloat = 0
    @ViewBuilder var content: () -> Content

    var body: some View {
        VStack(alignment: .leading, spacing: LHLayout.sectionSpacing) {
            content()
            if bottomClearance > 0 {
                Color.clear.frame(height: bottomClearance)
            }
        }
        .padding(.horizontal, LHLayout.screenPadding)
        .padding(.vertical, LHSpacing.md)
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

struct SectionBlock<Content: View>: View {
    let title: String
    @ViewBuilder var content: () -> Content

    var body: some View {
        VStack(alignment: .leading, spacing: LHSpacing.xs) {
            SectionHeaderLabel(title: title)
            content()
        }
    }
}

struct LighthouseBackground: View {
    var body: some View {
        Color(.systemGroupedBackground)
            .ignoresSafeArea()
    }
}

struct InfoRow: View {
    let label: String
    let value: String

    var body: some View {
        HStack(alignment: .firstTextBaseline) {
            Text(label)
                .font(.subheadline)
                .foregroundStyle(.secondary)
            Spacer(minLength: LHSpacing.sm)
            Text(value)
                .font(.subheadline.weight(.medium))
                .multilineTextAlignment(.trailing)
        }
    }
}

struct SelectableRow: View {
    let title: String
    var subtitle: String? = nil
    let isSelected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: LHSpacing.sm) {
                Image(systemName: isSelected ? "checkmark.circle.fill" : "circle")
                    .font(.title3)
                    .foregroundStyle(isSelected ? Color.accentColor : Color.secondary)
                VStack(alignment: .leading, spacing: LHSpacing.xxs) {
                    Text(title)
                        .font(.body.weight(.medium))
                        .foregroundStyle(.primary)
                    if let subtitle {
                        Text(subtitle)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }
                Spacer(minLength: 0)
            }
            .padding(LHSpacing.sm)
            .background(
                Color(.secondarySystemGroupedBackground),
                in: RoundedRectangle(cornerRadius: LHLayout.cardCorner, style: .continuous)
            )
            .overlay {
                RoundedRectangle(cornerRadius: LHLayout.cardCorner, style: .continuous)
                    .strokeBorder(isSelected ? Color.accentColor : .clear, lineWidth: 2)
            }
        }
        .buttonStyle(.plain)
    }
}
