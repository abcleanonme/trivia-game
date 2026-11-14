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
