import Foundation

/// Cosmetics change how things look, never how the game plays. They're
/// earned with Sparks or by playing, never with money.
public enum CosmeticSlot: String, CaseIterable, Codable, Sendable, CodingKeyRepresentable {
    /// The whole app's look: paper, cards, accent and animated background.
    case theme
    /// Sound-effect pack, voiced by `SoundCatalog`.
    case sounds
    case avatar, border, cardShape, cardBackground, emblem
    /// Player Card extras: avatar color, name lettering, a sticker and a finish.
    case avatarColor, nameStyle, sticker, finish

    public var title: String {
        switch self {
        case .theme: "App theme"
        case .sounds: "Sounds"
        case .avatar: "Avatar"
        case .border: "Border"
        case .cardShape: "Card shape"
        case .cardBackground: "Background"
        case .emblem: "Emblem"
        case .avatarColor: "Avatar color"
        case .nameStyle: "Lettering"
        case .sticker: "Sticker"
        case .finish: "Finish"
        }
    }
}

public struct Cosmetic: Identifiable, Equatable, Sendable {
    public enum Unlock: Equatable, Sendable {
        /// Free and owned from the start.
        case starter
        case sparks(Int)
        case stamp(Stamp)
        /// Finish this weekly event's track.
        case event(String)
    }

    public enum Pattern: String, Sendable { case solid, stripes, dots, grid, gradient, checker, zigzag }
    public enum Shape: String, Sendable { case rounded, ticket, hexagon, ribbon, pill, tag }
    /// How the name is lettered on the card.
    public enum Lettering: String, Sendable { case classic, rounded, serif, typewriter, wide, tall }
    /// A surface effect laid over the whole card.
    public enum Finish: String, Sendable { case none, gloss, shine, holo, sparkle }
    /// The ambient animation behind screens for an app theme.
    public enum Motion: String, CaseIterable, Sendable { case drift, bubbles, waves, stars, confetti, grid, snow, rain, aurora, fireflies, petals, orbits }

    public let id: String
    public let slot: CosmeticSlot
    public let name: String
    public let unlock: Unlock
    /// SF Symbol for avatars and emblems.
    public var symbol: String? = nil
    /// Hex colors: avatar/border/background fill, then pattern color.
    public var colors: [UInt32] = []
    public var pattern: Pattern = .solid
    public var shape: Shape? = nil
    /// Border drawn dashed.
    public var dashed = false
    /// Name lettering (`nameStyle` slot).
    public var lettering: Lettering? = nil
    /// Card finish (`finish` slot).
    public var finish: Finish? = nil
    /// App themes only: the animated background.
    public var motion: Motion? = nil
    /// Sound packs only: a one-line description.
    public var blurb: String? = nil

    public var price: Int? {
        if case .sparks(let n) = unlock { n } else { nil }
    }
}

public enum CosmeticCatalog {
    public static let all: [Cosmetic] = themes + sounds + avatars + borders + shapes + backgrounds + emblems
        + avatarColors + letterings + stickers + finishes

    public static func item(_ id: String) -> Cosmetic? { byID[id] }
    public static func items(in slot: CosmeticSlot) -> [Cosmetic] { all.filter { $0.slot == slot } }

    /// Equipped when nothing else is.
    public static let defaults: [CosmeticSlot: String] = [
        .theme: "theme.classic", .sounds: SoundCatalog.defaultID, .avatar: "avatar.monogram", .border: "border.ink", .cardShape: "shape.rounded",
        .cardBackground: "bg.paper", .emblem: "emblem.none",
        .avatarColor: "color.auto", .nameStyle: "letter.classic", .sticker: "sticker.none", .finish: "finish.none",
    ]

    private static let byID = Dictionary(uniqueKeysWithValues: all.map { ($0.id, $0) })

    /// App themes. Colors are a swatch (paper, accent); the full palette
    /// lives with the app's design code. Prices follow the design spec
    /// (300–600 Sparks). Correct/wrong colors never change with a theme.
    static let themes: [Cosmetic] = [
        Cosmetic(id: "theme.classic", slot: .theme, name: "Classic", unlock: .starter,
                 colors: [0xF7F6F2, 0x3B5BFD], motion: .drift),
        Cosmetic(id: "theme.mint", slot: .theme, name: "Mint Fizz", unlock: .sparks(300),
                 colors: [0xE6F7EF, 0x0E7A54], motion: .bubbles),
        Cosmetic(id: "theme.rain", slot: .theme, name: "Rainy Day", unlock: .sparks(300),
                 colors: [0xEAF0F6, 0x2F5D8A], motion: .rain),
        Cosmetic(id: "theme.candy", slot: .theme, name: "Candy Shop", unlock: .sparks(350),
                 colors: [0xFFF0F7, 0xC0267D], motion: .confetti),
        Cosmetic(id: "theme.snow", slot: .theme, name: "Snow Day", unlock: .sparks(350),
                 colors: [0xEEF5FB, 0x2563A8], motion: .snow),
        Cosmetic(id: "theme.lagoon", slot: .theme, name: "Lagoon", unlock: .sparks(350),
                 colors: [0xE3F6F7, 0x0F7383], motion: .waves),
        Cosmetic(id: "theme.sunset", slot: .theme, name: "Sunset", unlock: .sparks(400),
                 colors: [0xFFF0E4, 0xB83280], motion: .waves),
        Cosmetic(id: "theme.blossom", slot: .theme, name: "Blossom", unlock: .sparks(400),
                 colors: [0xFFF1F4, 0xB0306A], motion: .petals),
        Cosmetic(id: "theme.chalk", slot: .theme, name: "Chalkboard", unlock: .sparks(400),
                 colors: [0x1E3A2F, 0x2E7D5B], motion: .snow),
        Cosmetic(id: "theme.confetti", slot: .theme, name: "Confetti", unlock: .sparks(450),
                 colors: [0xFFF8EC, 0x7C3AED], motion: .confetti),
        Cosmetic(id: "theme.lava", slot: .theme, name: "Lava Lamp", unlock: .sparks(450),
                 colors: [0x1F0F1A, 0xA8341A], motion: .drift),
        Cosmetic(id: "theme.midnight", slot: .theme, name: "Midnight", unlock: .sparks(500),
                 colors: [0x0E1030, 0x4F5BE8], motion: .stars),
        Cosmetic(id: "theme.fireflies", slot: .theme, name: "Firefly Forest", unlock: .sparks(500),
                 colors: [0x0F1F17, 0x2F7D4F], motion: .fireflies),
        Cosmetic(id: "theme.aurora", slot: .theme, name: "Aurora", unlock: .sparks(550),
                 colors: [0x0B1A26, 0x0F8A7A], motion: .aurora),
        Cosmetic(id: "theme.neon", slot: .theme, name: "Neon Arcade", unlock: .sparks(600),
                 colors: [0x120A1F, 0xC2247A], motion: .grid),
        Cosmetic(id: "theme.orbit", slot: .theme, name: "Deep Space", unlock: .sparks(600),
                 colors: [0x07081A, 0x6D3FD6], motion: .orbits),
    ]

    /// Sound packs. Ids match `SoundCatalog`; every sound is synthesized
    /// on the phone. Cheaper than themes (250–450): you hear them, but they
    /// don't change the whole screen.
    static let sounds: [Cosmetic] = [
        Cosmetic(id: "sound.classic", slot: .sounds, name: "Chimes", unlock: .starter,
                 symbol: "bell.fill", colors: [0x3B5BFD], blurb: "Soft, clean chimes"),
        Cosmetic(id: "sound.marimba", slot: .sounds, name: "Marimba", unlock: .sparks(250),
                 symbol: "music.quarternote.3", colors: [0xB0753F], blurb: "Warm wooden mallets"),
        Cosmetic(id: "sound.musicbox", slot: .sounds, name: "Music Box", unlock: .sparks(300),
                 symbol: "gift.fill", colors: [0xE0559A], blurb: "Tiny tinkling bells"),
        Cosmetic(id: "sound.arcade", slot: .sounds, name: "Arcade", unlock: .sparks(350),
                 symbol: "gamecontroller.fill", colors: [0x7C3AED], blurb: "8-bit bleeps and buzzers"),
        Cosmetic(id: "sound.cartoon", slot: .sounds, name: "Cartoon", unlock: .sparks(400),
                 symbol: "theatermasks.fill", colors: [0xF4A100], blurb: "Boings and slide whistles"),
        Cosmetic(id: "sound.cosmic", slot: .sounds, name: "Cosmic", unlock: .sparks(450),
                 symbol: "sparkles", colors: [0x0F8A7A], blurb: "Spacey synth sweeps"),
    ]

    static let avatars: [Cosmetic] = [
        Cosmetic(id: "avatar.monogram", slot: .avatar, name: "Monogram", unlock: .starter, colors: [0x3B5BFD]),
        Cosmetic(id: "avatar.cat", slot: .avatar, name: "Cat", unlock: .sparks(100), symbol: "cat.fill", colors: [0xFF8A5B]),
        Cosmetic(id: "avatar.dog", slot: .avatar, name: "Dog", unlock: .sparks(100), symbol: "dog.fill", colors: [0xC48A3A]),
        Cosmetic(id: "avatar.bird", slot: .avatar, name: "Bird", unlock: .sparks(150), symbol: "bird.fill", colors: [0x2BB3C0]),
        Cosmetic(id: "avatar.hare", slot: .avatar, name: "Hare", unlock: .sparks(150), symbol: "hare.fill", colors: [0x8E6CEF]),
        Cosmetic(id: "avatar.tortoise", slot: .avatar, name: "Tortoise", unlock: .sparks(150), symbol: "tortoise.fill", colors: [0x15803D]),
        Cosmetic(id: "avatar.fish", slot: .avatar, name: "Fish", unlock: .sparks(200), symbol: "fish.fill", colors: [0x3B82F6]),
        Cosmetic(id: "avatar.brain", slot: .avatar, name: "Brain", unlock: .sparks(250), symbol: "brain.head.profile.fill", colors: [0xE0559A]),
        Cosmetic(id: "avatar.lightbulb", slot: .avatar, name: "Bright idea", unlock: .sparks(250), symbol: "lightbulb.fill", colors: [0xF4A100]),
        Cosmetic(id: "avatar.star", slot: .avatar, name: "Star", unlock: .starter, symbol: "star.fill", colors: [0xF4A100]),
        Cosmetic(id: "avatar.bolt", slot: .avatar, name: "Bolt", unlock: .starter, symbol: "bolt.fill", colors: [0x8E6CEF]),
        Cosmetic(id: "avatar.ladybug", slot: .avatar, name: "Ladybug", unlock: .sparks(100), symbol: "ladybug.fill", colors: [0xE0554B]),
        Cosmetic(id: "avatar.teddy", slot: .avatar, name: "Teddy", unlock: .sparks(150), symbol: "teddybear.fill", colors: [0xB0753F]),
        Cosmetic(id: "avatar.lizard", slot: .avatar, name: "Lizard", unlock: .sparks(150), symbol: "lizard.fill", colors: [0x4CAF50]),
        Cosmetic(id: "avatar.music", slot: .avatar, name: "Music", unlock: .sparks(150), symbol: "music.note", colors: [0xE0559A]),
        Cosmetic(id: "avatar.gamer", slot: .avatar, name: "Gamer", unlock: .sparks(200), symbol: "gamecontroller.fill", colors: [0x2E2E5C]),
        Cosmetic(id: "avatar.masks", slot: .avatar, name: "Drama", unlock: .sparks(200), symbol: "theatermasks.fill", colors: [0x7C3AED]),
        Cosmetic(id: "avatar.planet", slot: .avatar, name: "Planet", unlock: .sparks(250), symbol: "globe.europe.africa.fill", colors: [0x2BB3C0]),
        Cosmetic(id: "avatar.dice", slot: .avatar, name: "Lucky dice", unlock: .sparks(250), symbol: "dice.fill", colors: [0x17172B]),
        Cosmetic(id: "avatar.puzzle", slot: .avatar, name: "Puzzler", unlock: .sparks(300), symbol: "puzzlepiece.fill", colors: [0x3B5BFD]),
        Cosmetic(id: "avatar.flame", slot: .avatar, name: "On fire", unlock: .stamp(.tenStreak), symbol: "flame.fill", colors: [0xC2410C]),
    ]

    static let borders: [Cosmetic] = [
        Cosmetic(id: "border.ink", slot: .border, name: "Ink", unlock: .starter, colors: [0x17172B]),
        Cosmetic(id: "border.blue", slot: .border, name: "Electric", unlock: .sparks(150), colors: [0x3B5BFD]),
        Cosmetic(id: "border.mint", slot: .border, name: "Mint", unlock: .sparks(150), colors: [0x2BC48A]),
        Cosmetic(id: "border.spark", slot: .border, name: "Spark", unlock: .sparks(200), colors: [0xFFC93C]),
        Cosmetic(id: "border.dotted", slot: .border, name: "Dotted", unlock: .sparks(250), colors: [0x17172B], dashed: true),
        Cosmetic(id: "border.laurel", slot: .border, name: "Laurel", unlock: .stamp(.perfectRound), colors: [0xC9A227]),
        Cosmetic(id: "border.flame", slot: .border, name: "Streak Flame", unlock: .stamp(.dailyStreak(30)), colors: [0xC2410C, 0xFFC93C]),
        Cosmetic(id: "border.white", slot: .border, name: "Clean", unlock: .starter, colors: [0xFFFFFF]),
        Cosmetic(id: "border.coral", slot: .border, name: "Coral", unlock: .sparks(150), colors: [0xFF6F61]),
        Cosmetic(id: "border.grape", slot: .border, name: "Grape", unlock: .sparks(150), colors: [0x7C3AED]),
        Cosmetic(id: "border.ocean", slot: .border, name: "Ocean fade", unlock: .sparks(300), colors: [0x2BB3C0, 0x3B5BFD]),
        Cosmetic(id: "border.rainbow", slot: .border, name: "Rainbow", unlock: .sparks(450),
                 colors: [0xE0554B, 0xF4A100, 0x2BC48A, 0x3B82F6, 0x8E6CEF]),
        Cosmetic(id: "border.event.animals", slot: .border, name: "Wild", unlock: .event("animals"), colors: [0x6B8E23], dashed: true),
        Cosmetic(id: "border.event.nineties", slot: .border, name: "Dial-up", unlock: .event("nineties"), colors: [0xE0559A, 0x2BB3C0]),
    ]

    static let shapes: [Cosmetic] = [
        Cosmetic(id: "shape.rounded", slot: .cardShape, name: "Rounded card", unlock: .starter, shape: .rounded),
        Cosmetic(id: "shape.ticket", slot: .cardShape, name: "Ticket stub", unlock: .sparks(200), shape: .ticket),
        Cosmetic(id: "shape.hexagon", slot: .cardShape, name: "Hexagon", unlock: .sparks(300), shape: .hexagon),
        Cosmetic(id: "shape.ribbon", slot: .cardShape, name: "Ribbon", unlock: .sparks(400), shape: .ribbon),
        Cosmetic(id: "shape.pill", slot: .cardShape, name: "Capsule", unlock: .sparks(200), shape: .pill),
        Cosmetic(id: "shape.tag", slot: .cardShape, name: "Name tag", unlock: .sparks(300), shape: .tag),
    ]

    static let backgrounds: [Cosmetic] = [
        Cosmetic(id: "bg.paper", slot: .cardBackground, name: "Paper", unlock: .starter, colors: [0xF7F6F2]),
        Cosmetic(id: "bg.mint", slot: .cardBackground, name: "Mint", unlock: .sparks(100), colors: [0xCFF5E4]),
        Cosmetic(id: "bg.sky", slot: .cardBackground, name: "Sky", unlock: .sparks(100), colors: [0xD6E4FF]),
        Cosmetic(id: "bg.sunset", slot: .cardBackground, name: "Sunset", unlock: .sparks(150), colors: [0xFFD9C2]),
        Cosmetic(id: "bg.stripes", slot: .cardBackground, name: "Stripes", unlock: .sparks(200), colors: [0xFFF4CC, 0xFFC93C], pattern: .stripes),
        Cosmetic(id: "bg.dots", slot: .cardBackground, name: "Dots", unlock: .sparks(200), colors: [0xE9E4FF, 0x8E6CEF], pattern: .dots),
        Cosmetic(id: "bg.grid", slot: .cardBackground, name: "Graph paper", unlock: .sparks(300), colors: [0xF2F7FF, 0x9DB4FF], pattern: .grid),
        Cosmetic(id: "bg.white", slot: .cardBackground, name: "Snow", unlock: .starter, colors: [0xFFFFFF]),
        Cosmetic(id: "bg.lemon", slot: .cardBackground, name: "Lemon", unlock: .starter, colors: [0xFFF4CC]),
        Cosmetic(id: "bg.lilac", slot: .cardBackground, name: "Lilac", unlock: .sparks(100), colors: [0xE9E4FF]),
        Cosmetic(id: "bg.peach", slot: .cardBackground, name: "Peach fade", unlock: .sparks(250), colors: [0xFFE3C7, 0xFFC2D9], pattern: .gradient),
        Cosmetic(id: "bg.lagoon", slot: .cardBackground, name: "Lagoon", unlock: .sparks(250), colors: [0xCFF5E4, 0xBFD9FF], pattern: .gradient),
        Cosmetic(id: "bg.checker", slot: .cardBackground, name: "Checkers", unlock: .sparks(300), colors: [0xFFFFFF, 0x17172B], pattern: .checker),
        Cosmetic(id: "bg.zigzag", slot: .cardBackground, name: "Zigzag", unlock: .sparks(300), colors: [0xFFE5E5, 0xE0554B], pattern: .zigzag),
        Cosmetic(id: "bg.aurora", slot: .cardBackground, name: "Aurora", unlock: .sparks(400), colors: [0xD6E4FF, 0xCFF5E4, 0xE9E4FF], pattern: .gradient),
        Cosmetic(id: "bg.event.spooky", slot: .cardBackground, name: "Haunted", unlock: .event("spooky"), colors: [0xFFE3C7, 0xF07B1F], pattern: .dots),
        Cosmetic(id: "bg.event.eighties", slot: .cardBackground, name: "Neon Grid", unlock: .event("eighties"), colors: [0xFDE2F3, 0xE0559A], pattern: .grid),
        Cosmetic(id: "bg.event.capitals", slot: .cardBackground, name: "Atlas", unlock: .event("capitals"), colors: [0xEFE6D2, 0xB59A64], pattern: .grid),
        Cosmetic(id: "bg.event.ocean", slot: .cardBackground, name: "Tide", unlock: .event("ocean"), colors: [0xD3F1F5, 0x2BB3C0], pattern: .stripes),
        Cosmetic(id: "bg.event.food", slot: .cardBackground, name: "Picnic", unlock: .event("food"), colors: [0xFFE5E5, 0xE0554B], pattern: .grid),
    ]

    static let emblems: [Cosmetic] = [
        Cosmetic(id: "emblem.none", slot: .emblem, name: "None", unlock: .starter),
        Cosmetic(id: "emblem.lightbulb", slot: .emblem, name: "Lightbulb", unlock: .sparks(150), symbol: "lightbulb.fill"),
        Cosmetic(id: "emblem.globe", slot: .emblem, name: "Globe", unlock: .sparks(150), symbol: "globe.americas.fill"),
        Cosmetic(id: "emblem.atom", slot: .emblem, name: "Atom", unlock: .sparks(200), symbol: "atom"),
        Cosmetic(id: "emblem.owl", slot: .emblem, name: "Night owl", unlock: .sparks(250), symbol: "moon.fill"),
        Cosmetic(id: "emblem.crown", slot: .emblem, name: "Crown", unlock: .stamp(.fiftyWins), symbol: "crown.fill"),
        Cosmetic(id: "emblem.star", slot: .emblem, name: "Star", unlock: .starter, symbol: "star.fill"),
        Cosmetic(id: "emblem.book", slot: .emblem, name: "Bookworm", unlock: .sparks(150), symbol: "book.fill"),
        Cosmetic(id: "emblem.film", slot: .emblem, name: "Film buff", unlock: .sparks(150), symbol: "film.fill"),
        Cosmetic(id: "emblem.music", slot: .emblem, name: "Music nerd", unlock: .sparks(150), symbol: "music.note.list"),
        Cosmetic(id: "emblem.leaf", slot: .emblem, name: "Nature", unlock: .sparks(150), symbol: "leaf.fill"),
        Cosmetic(id: "emblem.flask", slot: .emblem, name: "Lab coat", unlock: .sparks(200), symbol: "flask.fill"),
        Cosmetic(id: "emblem.trophy", slot: .emblem, name: "Trophy", unlock: .sparks(300), symbol: "trophy.fill"),
        Cosmetic(id: "emblem.event.space", slot: .emblem, name: "Rocket", unlock: .event("space"), symbol: "airplane.departure"),
        Cosmetic(id: "emblem.event.myths", slot: .emblem, name: "Temple", unlock: .event("myths"), symbol: "building.columns.fill"),
        Cosmetic(id: "emblem.event.retro", slot: .emblem, name: "Joystick", unlock: .event("retro"), symbol: "gamecontroller.fill"),
        Cosmetic(id: "emblem.event.football", slot: .emblem, name: "Golden Boot", unlock: .event("football"), symbol: "soccerball"),
        Cosmetic(id: "emblem.event.thanksgiving", slot: .emblem, name: "Harvest Leaf", unlock: .event("thanksgiving"), symbol: "leaf.fill"),
    ]

    /// Recolors the avatar circle. "Auto" keeps each avatar's own color.
    static let avatarColors: [Cosmetic] = [
        Cosmetic(id: "color.auto", slot: .avatarColor, name: "Auto", unlock: .starter),
        Cosmetic(id: "color.cobalt", slot: .avatarColor, name: "Cobalt", unlock: .starter, colors: [0x3B5BFD]),
        Cosmetic(id: "color.ink", slot: .avatarColor, name: "Ink", unlock: .starter, colors: [0x17172B]),
        Cosmetic(id: "color.coral", slot: .avatarColor, name: "Coral", unlock: .sparks(60), colors: [0xFF6F61]),
        Cosmetic(id: "color.mint", slot: .avatarColor, name: "Mint", unlock: .sparks(60), colors: [0x2BC48A]),
        Cosmetic(id: "color.grape", slot: .avatarColor, name: "Grape", unlock: .sparks(60), colors: [0x8E6CEF]),
        Cosmetic(id: "color.bubblegum", slot: .avatarColor, name: "Bubblegum", unlock: .sparks(80), colors: [0xE0559A]),
        Cosmetic(id: "color.gold", slot: .avatarColor, name: "Gold", unlock: .sparks(120), colors: [0xC9A227]),
        Cosmetic(id: "color.sunrise", slot: .avatarColor, name: "Sunrise", unlock: .sparks(200), colors: [0xFF8A5B, 0xE0559A]),
        Cosmetic(id: "color.galaxy", slot: .avatarColor, name: "Galaxy", unlock: .sparks(250), colors: [0x2E2E5C, 0x8E6CEF]),
    ]

    static let letterings: [Cosmetic] = [
        Cosmetic(id: "letter.classic", slot: .nameStyle, name: "Classic", unlock: .starter, lettering: .classic),
        Cosmetic(id: "letter.rounded", slot: .nameStyle, name: "Bubbly", unlock: .starter, lettering: .rounded),
        Cosmetic(id: "letter.serif", slot: .nameStyle, name: "Storybook", unlock: .sparks(150), lettering: .serif),
        Cosmetic(id: "letter.typewriter", slot: .nameStyle, name: "Typewriter", unlock: .sparks(150), lettering: .typewriter),
        Cosmetic(id: "letter.wide", slot: .nameStyle, name: "Billboard", unlock: .sparks(200), lettering: .wide),
        Cosmetic(id: "letter.tall", slot: .nameStyle, name: "Marquee", unlock: .sparks(200), lettering: .tall),
    ]

    /// A tilted sticker slapped on the card's bottom corner.
    static let stickers: [Cosmetic] = [
        Cosmetic(id: "sticker.none", slot: .sticker, name: "None", unlock: .starter),
        Cosmetic(id: "sticker.star", slot: .sticker, name: "Gold star", unlock: .starter, symbol: "star.fill", colors: [0xFFC93C]),
        Cosmetic(id: "sticker.heart", slot: .sticker, name: "Heart", unlock: .sparks(100), symbol: "heart.fill", colors: [0xE0554B]),
        Cosmetic(id: "sticker.bolt", slot: .sticker, name: "Zap", unlock: .sparks(120), symbol: "bolt.fill", colors: [0xFFC93C]),
        Cosmetic(id: "sticker.smile", slot: .sticker, name: "Smiley", unlock: .sparks(120), symbol: "face.smiling.inverse", colors: [0xF4A100]),
        Cosmetic(id: "sticker.party", slot: .sticker, name: "Party", unlock: .sparks(150), symbol: "party.popper.fill", colors: [0x8E6CEF]),
        Cosmetic(id: "sticker.sparkles", slot: .sticker, name: "Sparkles", unlock: .sparks(150), symbol: "sparkles", colors: [0x2BB3C0]),
        Cosmetic(id: "sticker.popcorn", slot: .sticker, name: "Popcorn", unlock: .sparks(180), symbol: "popcorn.fill", colors: [0xE0554B]),
        Cosmetic(id: "sticker.brain", slot: .sticker, name: "Big brain", unlock: .sparks(200), symbol: "brain.fill", colors: [0xE0559A]),
        Cosmetic(id: "sticker.thumbs", slot: .sticker, name: "Thumbs up", unlock: .sparks(200), symbol: "hand.thumbsup.fill", colors: [0x2BC48A]),
        Cosmetic(id: "sticker.perfect", slot: .sticker, name: "100%", unlock: .stamp(.perfectRound), symbol: "checkmark.seal.fill", colors: [0x15803D]),
    ]

    /// Surface effects. The priciest card items: they're the flashiest.
    static let finishes: [Cosmetic] = [
        Cosmetic(id: "finish.none", slot: .finish, name: "Matte", unlock: .starter, finish: Cosmetic.Finish.none),
        Cosmetic(id: "finish.gloss", slot: .finish, name: "Gloss", unlock: .sparks(300), finish: .gloss),
        Cosmetic(id: "finish.shine", slot: .finish, name: "Shine", unlock: .sparks(450), finish: .shine),
        Cosmetic(id: "finish.sparkle", slot: .finish, name: "Glitter", unlock: .sparks(500), finish: .sparkle),
        Cosmetic(id: "finish.holo", slot: .finish, name: "Holo", unlock: .sparks(600), finish: .holo),
        Cosmetic(id: "finish.foil", slot: .finish, name: "Gold foil", unlock: .stamp(.dailyStreak(100)), colors: [0xC9A227], finish: .shine),
    ]
}

/// What the player owns and has on.
public struct Inventory: Codable, Equatable, Sendable {
    public private(set) var owned: Set<String>
    public private(set) var equipped: [CosmeticSlot: String]

    public init() {
        owned = Set(CosmeticCatalog.all.filter { $0.unlock == .starter }.map(\.id))
        equipped = CosmeticCatalog.defaults
    }

    /// Starter items count as owned even in inventories saved before they
    /// were added to the catalog.
    public func owns(_ id: String) -> Bool {
        owned.contains(id) || CosmeticCatalog.item(id)?.unlock == .starter
    }

    public func equipped(_ slot: CosmeticSlot) -> Cosmetic {
        CosmeticCatalog.item(equipped[slot] ?? "") ?? CosmeticCatalog.item(CosmeticCatalog.defaults[slot]!)!
    }

    /// Adds an item that was earned (event or stamp). Returns false if already owned.
    @discardableResult
    public mutating func grant(_ id: String) -> Bool {
        guard CosmeticCatalog.item(id) != nil else { return false }
        return owned.insert(id).inserted
    }

    /// Buys an item with Sparks. Returns false if it isn't for sale, is
    /// already owned, or the wallet is short.
    @discardableResult
    public mutating func buy(_ id: String, with wallet: inout Wallet) -> Bool {
        guard let item = CosmeticCatalog.item(id), let price = item.price, !owns(id),
              wallet.spend(price) else { return false }
        owned.insert(id)
        return true
    }

    public mutating func equip(_ id: String) {
        guard owns(id), let item = CosmeticCatalog.item(id) else { return }
        equipped[item.slot] = id
    }
}

/// The player's customizable identity card. Shown in lobbies, on the
/// scoreboard, and when a match ends. At most three layers beyond the name
/// (corner mark, title, one stat) so it stays readable at small sizes.
public struct PlayerCard: Codable, Equatable, Sendable {
    public enum Showcase: String, Codable, CaseIterable, Sendable {
        case bestStreak, dailyStreak, dailiesPlayed, wins, topCategory
        case roundsPlayed, bestSurvival, stampCount
        /// No stat line on the card.
        case hidden

        public var label: String {
            switch self {
            case .bestStreak: "Best streak"
            case .dailyStreak: "Daily streak"
            case .dailiesPlayed: "Dailies played"
            case .wins: "Friend wins"
            case .topCategory: "Top category"
            case .roundsPlayed: "Rounds played"
            case .bestSurvival: "Best survival"
            case .stampCount: "Stamps"
            case .hidden: "No stat"
            }
        }
    }

    public var name: String
    /// One of the titles the player has earned.
    public var title: String
    public var showcase: Showcase
    /// A stamp shown in the corner instead of the emblem, by `Stamp.id`.
    public var cornerStamp: String?

    public init(name: String = "Player", title: String = Stamp.defaultTitle,
                showcase: Showcase = .bestStreak, cornerStamp: String? = nil) {
        self.name = name
        self.title = title
        self.showcase = showcase
        self.cornerStamp = cornerStamp
    }

    public static let maxNameLength = 20
}
