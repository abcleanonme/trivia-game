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
