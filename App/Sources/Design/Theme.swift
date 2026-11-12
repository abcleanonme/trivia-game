import SwiftUI
import UIKit

/// Colors and type from the Design mockups (cream paper, ink outlines,
/// electric-blue accent, Spark yellow). Each color has a dark-mode pair.
enum Theme {
    static let paper = Color(light: 0xF7F6F2, dark: 0x14141E)
    static let card = Color(light: 0xFFFFFF, dark: 0x22222F)
    static let ink = Color(light: 0x17172B, dark: 0xF2F1EC)
    /// The solid "drop" under chunky cards and buttons.
    static let shadow = Color(light: 0x17172B, dark: 0x000000)
    static let muted = Color(light: 0x55556A, dark: 0xA9A9BA)
    static let line = Color(light: 0xE2E0D8, dark: 0x34344A)
    static let disabled = Color(light: 0xEEEDE7, dark: 0x1B1B26)
    static let accent = Color(light: 0x3B5BFD, dark: 0x5B76FF)
    static let spark = Color(light: 0xFFC93C, dark: 0xFFC93C)
    /// Text and icons on Spark yellow stay dark in both modes.
    static let onSpark = Color(light: 0x17172B, dark: 0x17172B)
    /// Correct and wrong stay the same everywhere (design guardrail) and are
    /// always paired with an icon and text, never color alone.
    static let correct = Color(light: 0x15803D, dark: 0x15803D)
    static let wrong = Color(light: 0xC2410C, dark: 0xC2410C)

    static let corner: CGFloat = 18
    /// Looks like a capsule on one line, but stays a rounded rectangle (not
    /// an oval) when large text wraps onto several lines.
    static let pill = RoundedRectangle(cornerRadius: 26, style: .continuous)
    static let border: CGFloat = 2

    /// Display face. The mockups use Space Grotesk; until we bundle it we use
    /// SF Rounded, which keeps the friendly game-show feel and Dynamic Type.
    static func display(_ style: Font.TextStyle) -> Font {
        .system(style, design: .rounded, weight: .bold)
    }
}

extension Color {
    init(light: UInt32, dark: UInt32) {
        self.init(uiColor: UIColor { traits in
            UIColor(hex: traits.userInterfaceStyle == .dark ? dark : light)
        })
    }
}

private extension UIColor {
    convenience init(hex: UInt32) {
        self.init(red: CGFloat((hex >> 16) & 0xFF) / 255,
                  green: CGFloat((hex >> 8) & 0xFF) / 255,
                  blue: CGFloat(hex & 0xFF) / 255,
                  alpha: 1)
    }
}

/// The mockups' signature look: a filled shape with an ink outline sitting on
/// a solid drop shadow that "presses in" when tapped.
struct ChunkyButtonStyle: ButtonStyle {
    var fill: Color = Theme.card
    var foreground: Color = Theme.ink
    var shape: AnyShape = AnyShape(RoundedRectangle(cornerRadius: Theme.corner, style: .continuous))
    var depth: CGFloat = 4
    /// Keep the ink outline when disabled (e.g. a revealed answer), instead
    /// of fading to the light disabled line.
    var outlined = false

    @Environment(\.isEnabled) private var isEnabled

    func makeBody(configuration: Configuration) -> some View {
        let pressed = configuration.isPressed && isEnabled
        let drop = isEnabled ? depth : 0
        configuration.label
            .foregroundStyle(foreground)
            .background(shape.fill(fill))
            .overlay(shape.stroke(isEnabled || outlined ? Theme.ink : Theme.line, lineWidth: Theme.border))
            .offset(y: pressed ? drop : 0)
            .background(shape.fill(Theme.shadow).offset(y: drop))
            // Reserve the full depth even when the drop is hidden, so a
            // button that becomes disabled doesn't shift everything below it.
            .padding(.bottom, depth)
            .animation(.easeOut(duration: 0.08), value: pressed)
    }
}

extension ButtonStyle where Self == ChunkyButtonStyle {
    static var chunky: ChunkyButtonStyle { ChunkyButtonStyle() }

    static func chunky(fill: Color, foreground: Color = Theme.ink, capsule: Bool = false) -> ChunkyButtonStyle {
        ChunkyButtonStyle(fill: fill, foreground: foreground,
                          shape: capsule ? AnyShape(Theme.pill) : AnyShape(RoundedRectangle(cornerRadius: Theme.corner, style: .continuous)))
    }
}

/// An outlined card container.
struct CardBackground: ViewModifier {
    var fill: Color = Theme.card
    var radius: CGFloat = 24
    var drop: CGFloat = 0

    func body(content: Content) -> some View {
        let shape = RoundedRectangle(cornerRadius: radius, style: .continuous)
        content
            .background(shape.fill(fill))
            .overlay(shape.stroke(Theme.ink, lineWidth: Theme.border))
            .background(shape.fill(Theme.shadow).offset(y: drop))
            .padding(.bottom, drop)
    }
}

extension View {
    func card(fill: Color = Theme.card, radius: CGFloat = 24, drop: CGFloat = 0) -> some View {
        modifier(CardBackground(fill: fill, radius: radius, drop: drop))
    }
}

/// The yellow bolt used for Sparks everywhere.
struct SparkIcon: View {
    var size: CGFloat = 16

    var body: some View {
        Image(systemName: "bolt.fill")
            .font(.system(size: size, weight: .bold))
            .foregroundStyle(Theme.spark)
            .shadow(color: Theme.shadow, radius: 0, x: 0.8, y: 0.8)
            .accessibilityHidden(true)
    }
}
