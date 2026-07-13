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
    static let blue = Color(red: 0, green: 0.478, blue: 1)
    static let blueDark = Color(red: 0, green: 0.318, blue: 0.835)
    static let blueLight = Color(red: 0.910, green: 0.949, blue: 1)
    static let groupedBackground = Color(red: 0.949, green: 0.949, blue: 0.969)
    static let critical = Color(red: 1, green: 0.231, blue: 0.188)
    static let high = Color(red: 1, green: 0.584, blue: 0)
    static let success = Color(red: 0.204, green: 0.780, blue: 0.349)
    static let beacon = Color(red: 1, green: 0.800, blue: 0)
    static let secondaryLabel = Color(red: 0.557, green: 0.557, blue: 0.576)

    static func priority(_ value: String) -> Color {
        switch value.lowercased() {
        case "critical": return critical
        case "high": return high
        case "medium": return beacon
        default: return success
        }
    }
}

/// Liquid Glass–inspired surfaces. On iOS 26+ SDKs these materials
/// adopt Apple's system glass automatically; custom chrome uses
/// ultra-thin material + specular stroke to match the latest HIG.
struct GlassCard<Content: View>: View {
    var padding: CGFloat = 16
    var cornerRadius: CGFloat = 20
    @ViewBuilder var content: () -> Content

    var body: some View {
        content()
            .padding(padding)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background {
                RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                    .fill(.ultraThinMaterial)
                    .overlay {
                        RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                            .strokeBorder(
                                LinearGradient(
                                    colors: [
                                        .white.opacity(0.55),
                                        .white.opacity(0.12)
                                    ],
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing
                                ),
                                lineWidth: 0.8
                            )
                    }
                    .shadow(color: .black.opacity(0.08), radius: 16, y: 8)
            }
    }
}

struct GlassPrimaryButton: View {
    let title: String
    var systemImage: String? = nil
    var tint: Color = LighthouseColor.blue
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 8) {
                if let systemImage {
                    Image(systemName: systemImage)
                }
                Text(title)
                    .fontWeight(.semibold)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 14)
        }
        .buttonStyle(.borderedProminent)
        .tint(tint)
        .buttonBorderShape(.capsule)
        .controlSize(.large)
    }
}

struct SectionHeaderLabel: View {
    let title: String

    var body: some View {
        Text(title.uppercased())
            .font(.caption.weight(.semibold))
            .foregroundStyle(LighthouseColor.secondaryLabel)
            .tracking(0.6)
    }
}

struct LighthouseBackground: View {
    var body: some View {
        LinearGradient(
            colors: [
                LighthouseColor.blueLight.opacity(0.85),
                LighthouseColor.groupedBackground,
                Color.white
            ],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
        .ignoresSafeArea()
    }
}
