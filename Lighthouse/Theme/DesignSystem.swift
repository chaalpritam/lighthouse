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

typealias GlassCard = SurfaceCard

struct PrimaryButton: View {
    let title: String
    var systemImage: String? = nil
    var role: ButtonRole? = nil
    var tint: Color = .accentColor
    let action: () -> Void

    var body: some View {
        Button(role: role, action: action) {
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
        .buttonStyle(.borderedProminent)
        .tint(tint)
        .controlSize(.large)
    }
}

typealias GlassPrimaryButton = PrimaryButton

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

struct LighthouseBackground: View {
    var body: some View {
        Color(.systemGroupedBackground)
            .ignoresSafeArea()
    }
}

struct ScreenContainer<Content: View>: View {
    @ViewBuilder var content: () -> Content

    var body: some View {
        content()
            .padding(.horizontal, LHLayout.screenPadding)
            .padding(.vertical, LHSpacing.md)
            .frame(maxWidth: .infinity, alignment: .leading)
    }
}
