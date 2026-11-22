import SwiftUI
import Observation
import TriviaKit

/// The colors and animated background for one app theme (bought with Sparks
/// in the Style shop). Themes change paper, cards and the accent only: ink,
/// muted text and the correct/wrong colors stay put so everything stays
/// readable and nobody is confused about right and wrong answers.
struct ThemePalette: Identifiable, Equatable {
    let id: String
    let paper: Color
    let card: Color
    let accent: Color
    /// Dark themes force dark mode so ink, muted text and lines flip to
    /// their light-on-dark pairs. nil follows the system setting.
    let scheme: ColorScheme?
    let motion: Cosmetic.Motion
    /// Colors used by the animated background, drawn at low opacity.
    let motionColors: [Color]
    /// How strong the background layer is (0...1). Kept low so text on
    /// paper stays easy to read.
    var intensity: Double = 1

    static let classic = ThemePalette(
        id: "theme.classic",
        paper: Color(light: 0xF7F6F2, dark: 0x14141E),
        card: Color(light: 0xFFFFFF, dark: 0x22222F),
        accent: Color(light: 0x3B5BFD, dark: 0x5B76FF),
        scheme: nil, motion: .drift,
        motionColors: [Color(hex: 0x3B5BFD), Color(hex: 0xFFC93C), Color(hex: 0x2BC48A)],
        intensity: 0.8)

    static let all: [ThemePalette] = [
        classic,
        ThemePalette(
            id: "theme.mint",
            paper: Color(light: 0xE6F7EF, dark: 0x0F1C18),
            card: Color(light: 0xFFFFFF, dark: 0x1B2A25),
            accent: Color(light: 0x0E7A54, dark: 0x13865D),
            scheme: nil, motion: .bubbles,
            motionColors: [Color(hex: 0x2BC48A), Color(hex: 0x3BA8C9)]),
        ThemePalette(
            id: "theme.sunset",
            paper: Color(light: 0xFFF0E4, dark: 0x1E1412),
            card: Color(light: 0xFFFFFF, dark: 0x2C1E1A),
            accent: Color(light: 0xB83280, dark: 0xB83280),
            scheme: nil, motion: .waves,
            motionColors: [Color(hex: 0xFF8A5B), Color(hex: 0xFFC93C), Color(hex: 0xE0559A)]),
        ThemePalette(
            id: "theme.confetti",
            paper: Color(light: 0xFFF8EC, dark: 0x17141F),
            card: Color(light: 0xFFFFFF, dark: 0x26222F),
            accent: Color(light: 0x7C3AED, dark: 0x7C3AED),
            scheme: nil, motion: .confetti,
            motionColors: [Color(hex: 0x3B5BFD), Color(hex: 0xFFC93C), Color(hex: 0xE0559A), Color(hex: 0x2BC48A)]),
        ThemePalette(
            id: "theme.midnight",
            paper: Color(hex: 0x0E1030),
            card: Color(hex: 0x1B1E4A),
            accent: Color(hex: 0x4F5BE8),
            scheme: .dark, motion: .stars,
            motionColors: [Color(hex: 0xFFFFFF), Color(hex: 0xFFC93C), Color(hex: 0x9DB4FF)]),
        ThemePalette(
            id: "theme.rain",
            paper: Color(light: 0xEAF0F6, dark: 0x111820),
            card: Color(light: 0xFFFFFF, dark: 0x1C2631),
            accent: Color(light: 0x2F5D8A, dark: 0x356A9E),
            scheme: nil, motion: .rain,
            motionColors: [Color(hex: 0x5B8DB8), Color(hex: 0x9DB4CF)]),
        ThemePalette(
            id: "theme.candy",
            paper: Color(light: 0xFFF0F7, dark: 0x1E1219),
            card: Color(light: 0xFFFFFF, dark: 0x2D1C26),
            accent: Color(light: 0xC0267D, dark: 0xC0267D),
            scheme: nil, motion: .confetti,
            motionColors: [Color(hex: 0xFF9ECF), Color(hex: 0x9FE3D0), Color(hex: 0xFFD66B), Color(hex: 0xB9A4FF)]),
        ThemePalette(
            id: "theme.snow",
            paper: Color(light: 0xEEF5FB, dark: 0x101722),
            card: Color(light: 0xFFFFFF, dark: 0x1B2433),
            accent: Color(light: 0x2563A8, dark: 0x2D6FBA),
            scheme: nil, motion: .snow,
            motionColors: [Color(light: 0x8FB3D9, dark: 0xFFFFFF), Color(light: 0xB8CFE6, dark: 0xC9DAEE)]),
        ThemePalette(
            id: "theme.lagoon",
            paper: Color(light: 0xE3F6F7, dark: 0x0D1B1E),
            card: Color(light: 0xFFFFFF, dark: 0x182A2E),
            accent: Color(light: 0x0F7383, dark: 0x128091),
            scheme: nil, motion: .waves,
            motionColors: [Color(hex: 0x2BB3C0), Color(hex: 0xFFE08A), Color(hex: 0x3B82F6)]),
        ThemePalette(
            id: "theme.blossom",
            paper: Color(light: 0xFFF1F4, dark: 0x1E1418),
            card: Color(light: 0xFFFFFF, dark: 0x2C1F25),
            accent: Color(light: 0xB0306A, dark: 0xB0306A),
            scheme: nil, motion: .petals,
            motionColors: [Color(hex: 0xF7A1C4), Color(hex: 0xFFC9DA), Color(hex: 0xE87AA6)]),
        ThemePalette(
            id: "theme.chalk",
            paper: Color(hex: 0x1E3A2F),
            card: Color(hex: 0x27493B),
            accent: Color(hex: 0x2E7D5B),
            scheme: .dark, motion: .snow,
            motionColors: [Color(hex: 0xF2F1EC), Color(hex: 0xFFE9A8)],
            intensity: 0.7),
        ThemePalette(
            id: "theme.lava",
            paper: Color(hex: 0x1F0F1A),
            card: Color(hex: 0x2E1826),
            accent: Color(hex: 0xA8341A),
            scheme: .dark, motion: .drift,
            motionColors: [Color(hex: 0xFF6A3D), Color(hex: 0xFFB02E), Color(hex: 0xE0379A)],
            intensity: 1.6),
        ThemePalette(
            id: "theme.fireflies",
            paper: Color(hex: 0x0F1F17),
            card: Color(hex: 0x1A2F24),
            accent: Color(hex: 0x2F7D4F),
            scheme: .dark, motion: .fireflies,
            motionColors: [Color(hex: 0xE8F77A), Color(hex: 0xFFD45C), Color(hex: 0x2BC48A)]),
        ThemePalette(
            id: "theme.aurora",
            paper: Color(hex: 0x0B1A26),
            card: Color(hex: 0x152838),
            accent: Color(hex: 0x0F8A7A),
            scheme: .dark, motion: .aurora,
            motionColors: [Color(hex: 0x3BE8B0), Color(hex: 0x6C7CFF), Color(hex: 0xC86BFA)]),
        ThemePalette(
            id: "theme.orbit",
            paper: Color(hex: 0x07081A),
            card: Color(hex: 0x15173A),
            accent: Color(hex: 0x6D3FD6),
            scheme: .dark, motion: .orbits,
            motionColors: [Color(hex: 0xFFC93C), Color(hex: 0x39D5FF), Color(hex: 0xFF8A5B), Color(hex: 0xFFFFFF)]),
        ThemePalette(
            id: "theme.neon",
            paper: Color(hex: 0x120A1F),
            card: Color(hex: 0x221437),
            accent: Color(hex: 0xC2247A),
            scheme: .dark, motion: .grid,
            motionColors: [Color(hex: 0xFF4FD8), Color(hex: 0x39D5FF), Color(hex: 0xFFC93C)]),
        ThemePalette(
            id: "theme.lemonade",
            paper: Color(light: 0xFFF9DB, dark: 0x1C1A10),
            card: Color(light: 0xFFFFFF, dark: 0x2A271A),
            accent: Color(light: 0x8A6100, dark: 0x9A6C00),
            scheme: nil, motion: .bubbles,
            motionColors: [Color(hex: 0xF4C430), Color(hex: 0x9FD356)]),
        ThemePalette(
            id: "theme.desert",
            paper: Color(light: 0xF8EEDC, dark: 0x1D1712),
            card: Color(light: 0xFFFFFF, dark: 0x2B231C),
            accent: Color(light: 0x9C4A1E, dark: 0xA85224),
            scheme: nil, motion: .waves,
            motionColors: [Color(hex: 0xE0A15E), Color(hex: 0xFFD08A), Color(hex: 0xC97B4A)]),
        ThemePalette(
            id: "theme.matcha",
            paper: Color(light: 0xEEF3E2, dark: 0x141A10),
            card: Color(light: 0xFFFFFF, dark: 0x20281A),
            accent: Color(light: 0x4A7324, dark: 0x527F28),
            scheme: nil, motion: .leaves,
            motionColors: [Color(hex: 0x8DB255), Color(hex: 0xB5CF7A), Color(hex: 0x5E8C31)]),
        ThemePalette(
            id: "theme.autumn",
            paper: Color(light: 0xFFF3E6, dark: 0x1E1510),
            card: Color(light: 0xFFFFFF, dark: 0x2D211A),
            accent: Color(light: 0xB0471A, dark: 0xB84D1C),
            scheme: nil, motion: .leaves,
            motionColors: [Color(hex: 0xE0702A), Color(hex: 0xC9A227), Color(hex: 0xB83A26), Color(hex: 0x9C6B30)]),
        ThemePalette(
            id: "theme.sweetheart",
            paper: Color(light: 0xFFF0F2, dark: 0x1E1215),
            card: Color(light: 0xFFFFFF, dark: 0x2D1C21),
            accent: Color(light: 0xC2264B, dark: 0xC2264B),
            scheme: nil, motion: .hearts,
            motionColors: [Color(hex: 0xF25C7A), Color(hex: 0xFF9EB5), Color(hex: 0xE0554B)]),
        ThemePalette(
            id: "theme.birthday",
            paper: Color(light: 0xFFF6EE, dark: 0x1D1517),
            card: Color(light: 0xFFFFFF, dark: 0x2C2124),
            accent: Color(light: 0xB8327A, dark: 0xB8327A),
            scheme: nil, motion: .confetti,
            motionColors: [Color(hex: 0xFF9ECF), Color(hex: 0x7FD1FF), Color(hex: 0xFFD66B), Color(hex: 0xA0E7A0)]),
        ThemePalette(
            id: "theme.bubblegum",
            paper: Color(light: 0xFFEAF6, dark: 0x1E1119),
            card: Color(light: 0xFFFFFF, dark: 0x2D1B27),
            accent: Color(light: 0xA8236F, dark: 0xB0287A),
            scheme: nil, motion: .hearts,
            motionColors: [Color(hex: 0xFF8AC9), Color(hex: 0xB9A4FF), Color(hex: 0x8FE3FF)]),
        ThemePalette(
            id: "theme.deepsea",
            paper: Color(hex: 0x06182A),
            card: Color(hex: 0x10283F),
            accent: Color(hex: 0x1C7FB0),
            scheme: .dark, motion: .bubbles,
            motionColors: [Color(hex: 0x5FD4F4), Color(hex: 0x2BC4A8)],
            intensity: 1.2),
        ThemePalette(
            id: "theme.storm",
            paper: Color(hex: 0x101521),
            card: Color(hex: 0x1C2333),
            accent: Color(hex: 0x4B6CB7),
            scheme: .dark, motion: .rain,
            motionColors: [Color(hex: 0x9DB4CF), Color(hex: 0x6C7CFF)],
            intensity: 1.2),
        ThemePalette(
            id: "theme.lantern",
            paper: Color(hex: 0x1B1020),
            card: Color(hex: 0x2A1A30),
            accent: Color(hex: 0xC2410C),
            scheme: .dark, motion: .fireflies,
            motionColors: [Color(hex: 0xFFB02E), Color(hex: 0xFF6A3D), Color(hex: 0xFFD45C)]),
        ThemePalette(
            id: "theme.galaxy",
            paper: Color(hex: 0x120B2A),
            card: Color(hex: 0x1F1640),
            accent: Color(hex: 0x8B5CF6),
            scheme: .dark, motion: .stars,
            motionColors: [Color(hex: 0xFFFFFF), Color(hex: 0xFF8AC9), Color(hex: 0x9D8CFF)]),
    ]

    private static let byID = Dictionary(uniqueKeysWithValues: all.map { ($0.id, $0) })

    /// The palette for a theme cosmetic, falling back to Classic.
    static func palette(for id: String) -> ThemePalette { byID[id] ?? classic }
}

/// The theme currently in use. `Theme.paper`, `Theme.card` and
/// `Theme.accent` read from here, so any view that uses them redraws when
/// the player switches themes (Observation tracks the read).
///
/// Only written on the main actor (by `PlayerStore`); reads are plain
/// value loads, so it's safe to read from anywhere.
@Observable
final class ThemeManager: @unchecked Sendable {
    static let shared = ThemeManager()

    private(set) var palette: ThemePalette = .classic

    @MainActor
    func apply(_ themeID: String) {
        let next = ThemePalette.palette(for: themeID)
        if next != palette { palette = next }
    }
}
