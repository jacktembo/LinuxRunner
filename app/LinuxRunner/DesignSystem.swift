import SwiftUI
import UIKit

// MARK: - LinuxRunner design system
//
// One visual language for every screen: graphite surfaces with hairline
// borders (no decorative shadows or gradients), the brand's signal orange for
// primary actions and active states only, SF Pro for interface text and SF
// Mono for technical data (versions, sizes, paths). Every token has a dark and
// a light value; the app follows the Appearance setting.
//
// Use these tokens and components instead of literal colours, radii or
// paddings in views.

enum DS {
    // MARK: Colour
    enum Palette {
        /// Screen background.
        static let background = dynamic(dark: 0x0B0B0D, light: 0xF4F4F6)
        /// Cards, list rows, grouped content. Dark value matches the system grouped-list rows.
        static let surface = dynamic(dark: 0x1C1C1E, light: 0xFFFFFF)
        /// Elements placed on a surface: icon tiles, inputs, nested panels.
        static let surfaceRaised = dynamic(dark: 0x2A2A2F, light: 0xEFEFF3)
        /// Hairline borders and dividers.
        static let border = dynamic(dark: 0x2C2C31, light: 0xE2E2E8)
        static let textPrimary = dynamic(dark: 0xF4F4F5, light: 0x111114)
        /// Secondary text; at least 4.5:1 on surface in both modes.
        static let textSecondary = dynamic(dark: 0xA1A1AA, light: 0x5C5C66)
        /// Tertiary text for non-essential captions.
        static let textTertiary = dynamic(dark: 0x8A8A93, light: 0x75757F)
        /// Brand signal orange (from the app icon). Primary actions and active states only.
        static let accent = dynamic(dark: 0xFF7A1A, light: 0xC2410C)
        /// Text and symbols placed on an accent fill.
        static let onAccent = dynamic(dark: 0x170A02, light: 0xFFFFFF)
        static let success = dynamic(dark: 0x34C759, light: 0x1A8F3C)
        static let warning = dynamic(dark: 0xFFB020, light: 0xB45309)
        static let danger = dynamic(dark: 0xFF5A52, light: 0xC8251B)
        static let info = dynamic(dark: 0x5AA9FF, light: 0x1F6FD1)

        static func dynamic(dark: UInt32, light: UInt32) -> Color {
            Color(UIColor { $0.userInterfaceStyle == .light ? UIColor(hex: light) : UIColor(hex: dark) })
        }
    }

    /// Semantic tone for icon tiles, badges and notices.
    enum Tone {
        case neutral, accent, success, warning, danger, info
        var color: Color {
            switch self {
            case .neutral: return Palette.textSecondary
            case .accent: return Palette.accent
            case .success: return Palette.success
            case .warning: return Palette.warning
            case .danger: return Palette.danger
            case .info: return Palette.info
            }
        }
        /// Tinted fill behind a tone-coloured symbol or label.
        var fill: Color { self == .neutral ? Palette.surfaceRaised : color.opacity(0.14) }
    }

    // MARK: Spacing (4-point scale)
    enum Space {
        static let xxs: CGFloat = 4
        static let xs: CGFloat = 8
        static let sm: CGFloat = 12
        static let md: CGFloat = 16
        static let lg: CGFloat = 20
        static let xl: CGFloat = 24
        static let xxl: CGFloat = 32
        /// Horizontal margin of scrolling screens.
        static let screen: CGFloat = 20
    }

    // MARK: Corner radius (continuous)
    enum Radius {
        /// Badges, small tiles.
        static let sm: CGFloat = 8
        /// Buttons, icon tiles, inputs.
        static let md: CGFloat = 12
        /// Cards and panels.
        static let lg: CGFloat = 16
        /// The hero desktop preview.
        static let xl: CGFloat = 22
    }

    // MARK: Typography (Dynamic Type text styles)
    enum Font {
        static let screenTitle = SwiftUI.Font.largeTitle.weight(.bold)
        static let sectionTitle = SwiftUI.Font.title3.weight(.semibold)
        static let cardTitle = SwiftUI.Font.headline
        static let body = SwiftUI.Font.body
        static let label = SwiftUI.Font.subheadline.weight(.medium)
        static let detail = SwiftUI.Font.subheadline
        static let caption = SwiftUI.Font.footnote
        static let overline = SwiftUI.Font.caption.weight(.semibold)
        /// Quiet uppercase label above a group of cards.
        static let sectionLabel = SwiftUI.Font.footnote.weight(.semibold)
        /// Numbers inside interface text (versions, sizes, counts): tabular digits, interface face.
        static let data = SwiftUI.Font.footnote.monospacedDigit()
        static let dataSmall = SwiftUI.Font.caption.monospacedDigit()
        /// Code-like data only: package names, paths, durations, key/value values.
        static let mono = SwiftUI.Font.system(.footnote, design: .monospaced)
        static let monoSmall = SwiftUI.Font.system(.caption, design: .monospaced)
    }

    static let maxContentWidth: CGFloat = 980
}

extension UIColor {
    convenience init(hex: UInt32) {
        self.init(red: CGFloat((hex >> 16) & 0xFF) / 255, green: CGFloat((hex >> 8) & 0xFF) / 255, blue: CGFloat(hex & 0xFF) / 255, alpha: 1)
    }
}

// MARK: - Shapes and surfaces

extension Shape where Self == RoundedRectangle {
    static func ds(_ radius: CGFloat) -> RoundedRectangle { RoundedRectangle(cornerRadius: radius, style: .continuous) }
}

extension View {
    /// Card surface: graphite fill and a hairline border.
    func dsCard(padding: CGFloat = DS.Space.md, radius: CGFloat = DS.Radius.lg) -> some View {
        self.padding(padding)
            .background(RoundedRectangle.ds(radius).fill(DS.Palette.surface))
            .overlay(RoundedRectangle.ds(radius).stroke(DS.Palette.border, lineWidth: 1))
    }

    /// Screen background behind scrolling content.
    func dsScreenBackground() -> some View {
        background(DS.Palette.background.ignoresSafeArea())
    }

    /// Lists and forms on the app background with surface rows (iOS 16+;
    /// earlier systems keep the standard grouped look).
    @ViewBuilder func dsListStyle() -> some View {
        if #available(iOS 16.0, *) {
            self.scrollContentBackground(.hidden).background(DS.Palette.background.ignoresSafeArea())
        } else {
            self
        }
    }

    /// Centres content and limits its width on iPad.
    func dsReadableWidth() -> some View {
        frame(maxWidth: DS.maxContentWidth).frame(maxWidth: .infinity)
    }
}

// MARK: - Components

/// Symbol on a tinted rounded square.
struct DSIconTile: View {
    let symbol: String
    var tone: DS.Tone = .neutral
    var size: CGFloat = 36
    var body: some View {
        RoundedRectangle.ds(size * 0.3)
            .fill(tone.fill)
            .frame(width: size, height: size)
            .overlay(Image(systemName: symbol).font(.system(size: size * 0.44, weight: .semibold)).foregroundColor(tone == .neutral ? DS.Palette.textPrimary : tone.color))
            .accessibilityHidden(true)
    }
}

/// Small status label with a leading dot.
struct DSBadge: View {
    let text: String
    var tone: DS.Tone = .neutral
    var body: some View {
        HStack(spacing: 5) {
            Circle().fill(tone.color).frame(width: 6, height: 6)
            Text(text).font(DS.Font.overline).foregroundColor(tone == .neutral ? DS.Palette.textSecondary : tone.color)
        }
        .padding(.horizontal, 8).padding(.vertical, 4)
        .background(Capsule().fill(tone.fill))
        .accessibilityElement(children: .combine)
    }
}

/// Section heading with an optional trailing action.
struct DSSectionHeader<Trailing: View>: View {
    let title: String
    let trailing: Trailing
    init(_ title: String, @ViewBuilder trailing: () -> Trailing) { self.title = title; self.trailing = trailing() }
    var body: some View {
        HStack(alignment: .firstTextBaseline) {
            Text(title.uppercased()).font(DS.Font.sectionLabel).tracking(0.6).foregroundColor(DS.Palette.textSecondary)
                .accessibilityLabel(title).accessibilityAddTraits(.isHeader)
            Spacer()
            trailing
        }
        .padding(.horizontal, DS.Space.xxs)
    }
}
extension DSSectionHeader where Trailing == EmptyView {
    init(_ title: String) { self.init(title) { EmptyView() } }
}

/// Inline message with a tone: warnings, errors, hints.
struct DSNotice: View {
    let text: String
    var symbol = "info.circle.fill"
    var tone: DS.Tone = .info
    var body: some View {
        HStack(alignment: .top, spacing: DS.Space.sm) {
            Image(systemName: symbol).foregroundColor(tone.color).font(.subheadline.weight(.semibold)).accessibilityHidden(true)
            Text(text).font(DS.Font.caption).foregroundColor(DS.Palette.textPrimary).fixedSize(horizontal: false, vertical: true)
            Spacer(minLength: 0)
        }
        .padding(DS.Space.sm)
        .background(RoundedRectangle.ds(DS.Radius.md).fill(tone.color.opacity(0.10)))
        .overlay(RoundedRectangle.ds(DS.Radius.md).stroke(tone.color.opacity(0.25), lineWidth: 1))
        .accessibilityElement(children: .combine)
    }
}

/// Empty state: symbol, title, message and an optional action.
struct DSEmptyState: View {
    let symbol: String
    let title: String
    let message: String
    var actionTitle: String?
    var action: (() -> Void)?
    var body: some View {
        VStack(spacing: DS.Space.sm) {
            DSIconTile(symbol: symbol, size: 44)
            Text(title).font(DS.Font.cardTitle).foregroundColor(DS.Palette.textPrimary)
            Text(message).font(DS.Font.caption).foregroundColor(DS.Palette.textSecondary).multilineTextAlignment(.center)
            if let actionTitle, let action {
                Button(actionTitle, action: action).buttonStyle(DSButtonStyle(.secondary, size: .small)).padding(.top, DS.Space.xxs)
            }
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, DS.Space.xl)
        .dsCard()
    }
}

/// Label/value row; values use the monospaced face.
struct DSKeyValueRow: View {
    let key: String
    let value: String
    var body: some View {
        HStack(alignment: .firstTextBaseline) {
            Text(key).font(DS.Font.detail).foregroundColor(DS.Palette.textSecondary)
            Spacer(minLength: DS.Space.sm)
            Text(value).font(DS.Font.mono).foregroundColor(DS.Palette.textPrimary).multilineTextAlignment(.trailing).textSelection(.enabled)
        }
        .accessibilityElement(children: .combine)
    }
}

/// Settings and list row label: neutral icon tile and title.
struct DSRowLabel: View {
    let title: String
    let symbol: String
    var tone: DS.Tone = .neutral
    init(_ title: String, _ symbol: String, tone: DS.Tone = .neutral) { self.title = title; self.symbol = symbol; self.tone = tone }
    var body: some View {
        Label { Text(title).foregroundColor(DS.Palette.textPrimary) } icon: { DSIconTile(symbol: symbol, tone: tone, size: 30) }
    }
}

// MARK: - Inputs and selection

/// Labelled text or password field with a visible focus state.
struct DSTextField: View {
    let title: String
    @Binding var text: String
    /// Example or hint shown inside the empty field; the title stays above it.
    var prompt: String?
    var secure = false
    var contentType: UITextContentType?
    @FocusState private var focused: Bool
    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(title).font(DS.Font.overline).foregroundColor(DS.Palette.textSecondary).accessibilityHidden(true)
            Group {
                if secure { SecureField(prompt ?? "", text: $text) } else { TextField(prompt ?? "", text: $text) }
            }
            .accessibilityLabel(title)
            .textContentType(contentType)
            .focused($focused)
            .font(DS.Font.body)
            .foregroundColor(DS.Palette.textPrimary)
            .padding(.horizontal, DS.Space.sm)
            .frame(minHeight: 46)
            .background(RoundedRectangle.ds(DS.Radius.md).fill(DS.Palette.surfaceRaised))
            .overlay(RoundedRectangle.ds(DS.Radius.md).stroke(focused ? DS.Palette.accent : DS.Palette.border, lineWidth: focused ? 1.5 : 1))
            .animation(.easeOut(duration: 0.12), value: focused)
        }
    }
}

extension View {
    /// Card that can be chosen: accent border and check mark when selected.
    func dsSelectable(_ selected: Bool, enabled: Bool = true) -> some View {
        self
            .padding(DS.Space.md)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(RoundedRectangle.ds(DS.Radius.lg).fill(selected ? DS.Palette.accent.opacity(0.08) : DS.Palette.surface))
            .overlay(RoundedRectangle.ds(DS.Radius.lg).stroke(selected ? DS.Palette.accent : DS.Palette.border, lineWidth: selected ? 1.5 : 1))
            .overlay(alignment: .topTrailing) {
                Image(systemName: selected ? "checkmark.circle.fill" : "circle")
                    .font(.title3).foregroundColor(selected ? DS.Palette.accent : DS.Palette.textTertiary)
                    .padding(DS.Space.sm).opacity(enabled ? 1 : 0.4)
                    .accessibilityHidden(true)
            }
            .opacity(enabled ? 1 : 0.55)
            .accessibilityAddTraits(selected ? .isSelected : [])
    }
}

/// "Step 2 of 5" with a segmented bar.
struct DSStepIndicator: View {
    let current: Int
    let total: Int
    var body: some View {
        VStack(alignment: .leading, spacing: DS.Space.xs) {
            Text("Step \(current) of \(total)").font(DS.Font.overline).foregroundColor(DS.Palette.textSecondary)
            HStack(spacing: 4) {
                ForEach(1...total, id: \.self) { index in
                    Capsule().fill(index <= current ? DS.Palette.accent : DS.Palette.border).frame(height: 4)
                }
            }
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("Step \(current) of \(total)")
    }
}

/// Heading at the top of a full-screen step: title and a short explanation.
struct DSScreenHeading: View {
    let title: String
    var message: String?
    var body: some View {
        VStack(alignment: .leading, spacing: DS.Space.xs) {
            Text(title).font(.title2.weight(.bold)).foregroundColor(DS.Palette.textPrimary).accessibilityAddTraits(.isHeader)
            if let message { Text(message).font(DS.Font.detail).foregroundColor(DS.Palette.textSecondary).fixedSize(horizontal: false, vertical: true) }
        }
    }
}

// MARK: - Buttons

struct DSButtonStyle: ButtonStyle {
    enum Kind { case primary, secondary, tertiary, destructive }
    enum Size { case large, regular, small }
    let kind: Kind
    var size: Size = .regular
    var fullWidth = false
    init(_ kind: Kind, size: Size = .regular, fullWidth: Bool = false) { self.kind = kind; self.size = size; self.fullWidth = fullWidth }

    func makeBody(configuration: Configuration) -> some View {
        DSButtonBody(configuration: configuration, kind: kind, size: size, fullWidth: fullWidth)
    }

    private struct DSButtonBody: View {
        let configuration: ButtonStyleConfiguration
        let kind: Kind, size: Size, fullWidth: Bool
        @Environment(\.isEnabled) private var enabled
        private var height: CGFloat { size == .large ? 52 : size == .regular ? 44 : 34 }
        private var font: Font { size == .small ? .subheadline.weight(.semibold) : .body.weight(.semibold) }
        private var foreground: Color {
            if !enabled && kind == .primary { return DS.Palette.textTertiary }
            switch kind {
            case .primary: return DS.Palette.onAccent
            case .secondary: return DS.Palette.textPrimary
            case .tertiary: return DS.Palette.accent
            case .destructive: return DS.Palette.danger
            }
        }
        private var fill: Color {
            if !enabled && kind == .primary { return DS.Palette.surfaceRaised }
            switch kind {
            case .primary: return DS.Palette.accent
            case .secondary: return DS.Palette.surfaceRaised
            case .tertiary: return .clear
            case .destructive: return DS.Palette.danger.opacity(0.12)
            }
        }
        var body: some View {
            configuration.label
                .font(font)
                .foregroundColor(foreground)
                .padding(.horizontal, size == .small ? DS.Space.sm : DS.Space.md)
                .frame(minHeight: height)
                .frame(maxWidth: fullWidth ? .infinity : nil)
                .background(RoundedRectangle.ds(DS.Radius.md).fill(fill))
                .overlay(RoundedRectangle.ds(DS.Radius.md).stroke(kind == .secondary ? DS.Palette.border : .clear, lineWidth: 1))
                .opacity(enabled ? (configuration.isPressed ? 0.82 : 1) : (kind == .primary ? 1 : 0.4))
                .scaleEffect(configuration.isPressed ? 0.98 : 1)
                .animation(.easeOut(duration: 0.12), value: configuration.isPressed)
                .contentShape(RoundedRectangle.ds(DS.Radius.md))
        }
    }
}

/// Press feedback for cards and tiles that act as buttons.
struct DSPressableStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed ? 0.98 : 1)
            .opacity(configuration.isPressed ? 0.85 : 1)
            .animation(.easeOut(duration: 0.12), value: configuration.isPressed)
    }
}

// MARK: - Brand mark

/// The LinuxRunner app icon drawn natively (same geometry as
/// app/LinuxRunner/Branding/LinuxRunnerIcon.svg), for headers and About.
struct DSBrandMark: View {
    var size: CGFloat = 56
    var body: some View {
        Canvas { context, canvas in
            let s = canvas.width / 1024
            let rect = CGRect(origin: .zero, size: canvas)
            context.fill(Path(roundedRect: rect, cornerRadius: 228 * s, style: .continuous),
                         with: .linearGradient(Gradient(colors: [Color(UIColor(hex: 0xFF8A1F)), Color(UIColor(hex: 0xE0323C))]),
                                               startPoint: .zero, endPoint: CGPoint(x: canvas.width, y: canvas.height)))
            func stroke(_ points: [CGPoint], _ width: CGFloat, _ opacity: Double) {
                var p = Path(); p.addLines(points.map { CGPoint(x: $0.x * s, y: $0.y * s) })
                context.stroke(p, with: .color(.white.opacity(opacity)), style: StrokeStyle(lineWidth: width * s, lineCap: .round, lineJoin: .round))
            }
            stroke([CGPoint(x: 178, y: 404), CGPoint(x: 292, y: 404)], 40, 0.55)
            stroke([CGPoint(x: 128, y: 512), CGPoint(x: 292, y: 512)], 40, 0.8)
            stroke([CGPoint(x: 178, y: 620), CGPoint(x: 292, y: 620)], 40, 0.55)
            stroke([CGPoint(x: 392, y: 300), CGPoint(x: 604, y: 512), CGPoint(x: 392, y: 724)], 100, 1)
            context.fill(Path(roundedRect: CGRect(x: 642 * s, y: 650 * s, width: 222 * s, height: 80 * s), cornerRadius: 22 * s, style: .continuous), with: .color(.white))
        }
        .frame(width: size, height: size)
        .accessibilityHidden(true)
    }
}

// MARK: - App chrome

enum DSAppearance {
    /// Tab and navigation bars on the app background with hairline separators.
    /// iOS 26 and later keep the system's Liquid Glass bars, which already
    /// follow these colours; overriding them there hides large titles.
    static func applyBarAppearance() {
        if #available(iOS 26.0, *) { return }
        let border = UIColor { $0.userInterfaceStyle == .light ? UIColor(hex: 0xE2E2E8) : UIColor(hex: 0x2C2C31) }
        let background = UIColor { $0.userInterfaceStyle == .light ? UIColor(hex: 0xF4F4F6) : UIColor(hex: 0x0B0B0D) }
        let title = UIColor { $0.userInterfaceStyle == .light ? UIColor(hex: 0x111114) : UIColor(hex: 0xF4F4F5) }

        let tab = UITabBarAppearance()
        tab.configureWithOpaqueBackground()
        tab.backgroundColor = background
        tab.shadowColor = border
        UITabBar.appearance().standardAppearance = tab
        UITabBar.appearance().scrollEdgeAppearance = tab

        let nav = UINavigationBarAppearance()
        nav.configureWithOpaqueBackground()
        nav.backgroundColor = background
        nav.shadowColor = .clear
        nav.titleTextAttributes = [.foregroundColor: title]
        nav.largeTitleTextAttributes = [.foregroundColor: title]
        let scrolled = nav.copy()
        scrolled.shadowColor = border
        UINavigationBar.appearance().standardAppearance = scrolled
        UINavigationBar.appearance().compactAppearance = scrolled
        UINavigationBar.appearance().scrollEdgeAppearance = nav
    }
}
