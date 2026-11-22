import SwiftUI
import TriviaKit

/// Everything needed to draw a Player Card, resolved from the inventory
/// (or from a preview in the shop or Card Studio).
struct CardLook: Equatable {
    var avatar: Cosmetic
    var avatarColor: Cosmetic
    var border: Cosmetic
    var shape: Cosmetic
    var background: Cosmetic
    var lettering: Cosmetic
    var sticker: Cosmetic
    var finish: Cosmetic
    /// SF Symbol in the corner: an emblem or a stamp.
    var corner: String?
    var name: String
    var title: String
    var statLabel: String
    var statValue: String
    var showsStat: Bool

    /// `previewing` swaps in one item (or several, one per slot) without
    /// equipping it; `card` swaps in unsaved text choices.
    @MainActor
    init(store: PlayerStore, previewing: Cosmetic? = nil, card: PlayerCard? = nil) {
        self.init(store: store, previewing: previewing.map { [$0.slot: $0] } ?? [:], card: card)
    }

    @MainActor
    init(store: PlayerStore, previewing: [CosmeticSlot: Cosmetic], card: PlayerCard? = nil) {
        let p = store.progress
        let card = card ?? p.card
        func pick(_ slot: CosmeticSlot) -> Cosmetic { previewing[slot] ?? p.inventory.equipped(slot) }
        avatar = pick(.avatar)
        avatarColor = pick(.avatarColor)
        border = pick(.border)
        shape = pick(.cardShape)
        background = pick(.cardBackground)
        lettering = pick(.nameStyle)
        sticker = pick(.sticker)
        finish = pick(.finish)
        let emblem = pick(.emblem)
        if previewing[.emblem] == nil, let stampID = card.cornerStamp,
           let stamp = p.stamps.first(where: { $0.id == stampID }) {
            corner = stamp.systemImage
        } else {
            corner = emblem.symbol
        }
        name = card.name
        title = card.title
        statLabel = card.showcase.label
        var withShowcase = p
        withShowcase.card.showcase = card.showcase
        statValue = withShowcase.showcaseValue(on: store.today)
        showsStat = card.showcase != .hidden
    }
}

/// The customizable identity card: shape, background, avatar with border,
/// name, one title, one stat, one corner mark, plus an optional sticker and
/// finish. Text stays on a plain area so it reads at small sizes.
struct PlayerCardView: View {
    let look: CardLook

    @ScaledMetric(relativeTo: .title) private var avatarSize: CGFloat = 64

    var body: some View {
        let shape = CardShape(kind: look.shape.shape ?? .rounded)
        HStack(spacing: 16) {
            AvatarView(avatar: look.avatar, border: look.border, name: look.name,
                       size: min(avatarSize, 96), tint: look.avatarColor)
            VStack(alignment: .leading, spacing: 4) {
                Text(look.name)
                    .font(NameLettering.font(look.lettering.lettering ?? .classic))
                    .lineLimit(2)
                    .minimumScaleFactor(0.8)
                Text(look.title)
                    .font(.subheadline.weight(.semibold))
                    .opacity(0.75)
                if look.showsStat {
                    HStack(spacing: 6) {
                        Text(look.statLabel.uppercased())
                            .font(.caption2.weight(.bold))
                            .kerning(0.8)
                            .opacity(0.6)
                        Text(look.statValue)
                            .font(.subheadline.bold())
                    }
                    .padding(.top, 2)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .foregroundStyle(ShareColors.ink)
        .padding(.vertical, 22)
        .padding(.horizontal, horizontalPadding)
        .frame(maxWidth: .infinity)
        .background {
            ZStack {
                CardPattern(background: look.background)
                CardFinishOverlay(finish: look.finish)
            }
            .clipShape(shape)
        }
        .overlay(alignment: .topTrailing) {
            if let corner = look.corner {
                Image(systemName: corner)
                    .font(.title3.bold())
                    .foregroundStyle(ShareColors.ink)
                    .padding(.top, 14)
                    .padding(.trailing, horizontalPadding - 6)
                    .accessibilityHidden(true)
            }
        }
        .overlay(shape.stroke(ShareColors.ink, lineWidth: 2.5))
        .overlay(alignment: .bottomTrailing) {
            if let symbol = look.sticker.symbol {
                StickerView(symbol: symbol, color: Color(hex: look.sticker.colors.first ?? 0xFFC93C), size: 34)
                    .rotationEffect(.degrees(-12))
                    .offset(x: -horizontalPadding + 10, y: 12)
                    .accessibilityHidden(true)
            }
        }
        .background(shape.fill(Theme.shadow).offset(y: 5))
        .padding(.bottom, 5)
        .environment(\.colorScheme, .light)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("Player Card: \(look.name), \(look.title)."
                            + (look.showsStat ? " \(look.statLabel) \(look.statValue)." : ""))
    }

    private var horizontalPadding: CGFloat {
        switch look.shape.shape ?? .rounded {
        case .hexagon, .ribbon, .pill, .slant: 40
        case .ticket, .tag, .stamp, .scoop: 30
        case .rounded: 20
        }
    }
}

enum NameLettering {
    static func font(_ lettering: Cosmetic.Lettering, style: Font.TextStyle = .title2) -> Font {
        switch lettering {
        case .classic: Theme.display(style)
        case .rounded: .system(style, design: .rounded, weight: .black)
        case .serif: .system(style, design: .serif, weight: .bold).italic()
        case .typewriter: .system(style, design: .monospaced, weight: .semibold)
        case .wide: .system(style, weight: .heavy).width(.expanded)
        case .tall: .system(style, weight: .black).width(.compressed)
        case .sporty: .system(style, weight: .black).italic()
        case .newsprint: .system(style, design: .serif, weight: .black)
        case .arcade: .system(style, design: .monospaced, weight: .black)
        case .whisper: .system(style, design: .rounded, weight: .medium).width(.expanded)
        }
    }
}

/// A die-cut sticker: a white outline around a filled symbol.
struct StickerView: View {
    let symbol: String
    let color: Color
    var size: CGFloat = 34

    var body: some View {
        ZStack {
            Circle().fill(.white)
            Circle().stroke(ShareColors.ink, lineWidth: 2)
            Image(systemName: symbol)
                .font(.system(size: size * 0.5, weight: .bold))
                .foregroundStyle(color)
        }
        .frame(width: size, height: size)
        .shadow(color: .black.opacity(0.2), radius: 0, x: 1.5, y: 2)
    }
}

/// The small version used in live rounds and lists: avatar plus border.
struct AvatarView: View {
    let avatar: Cosmetic
    let border: Cosmetic
    let name: String
    var size: CGFloat = 44
    /// Avatar color override; "Auto" (no colors) keeps the avatar's own.
    var tint: Cosmetic? = nil

    var body: some View {
        ZStack {
            Circle().fill(fill)
            if let symbol = avatar.symbol {
                Image(systemName: symbol)
                    .font(.system(size: size * 0.45, weight: .bold))
            } else {
                Text(String(name.first ?? "?").uppercased())
                    .font(.system(size: size * 0.45, weight: .heavy, design: .rounded))
            }
        }
        .foregroundStyle(.white)
        .frame(width: size, height: size)
        .overlay(borderRing)
        .accessibilityHidden(true)
    }

    private var fill: AnyShapeStyle {
        let colors = (tint?.colors.isEmpty == false ? tint!.colors : avatar.colors).map { Color(hex: $0) }
        if colors.count > 1 {
            return AnyShapeStyle(LinearGradient(colors: colors, startPoint: .topLeading, endPoint: .bottomTrailing))
        }
        return AnyShapeStyle(colors.first ?? Color(hex: 0x3B5BFD))
    }

    @ViewBuilder private var borderRing: some View {
        let width = max(3, size * 0.07)
        let colors = border.colors.map { Color(hex: $0) }
        let style = StrokeStyle(lineWidth: width, lineCap: .round, dash: border.dashed ? [width * 0.2, width * 1.6] : [])
        if colors.count > 1 {
            Circle().stroke(AngularGradient(colors: colors + [colors[0]], center: .center), style: style)
                .padding(-width / 2)
        } else {
            Circle().stroke(colors.first ?? ShareColors.ink, style: style)
                .padding(-width / 2)
        }
    }
}

/// Gloss, shine, glitter and holo effects over the card background. The
/// moving ones hold still with Reduce Motion.
struct CardFinishOverlay: View {
    let finish: Cosmetic

    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        switch finish.finish ?? .none {
        case .none:
            EmptyView()
        case .gloss:
            LinearGradient(colors: [.white.opacity(0.55), .white.opacity(0)], startPoint: .top, endPoint: .center)
                .allowsHitTesting(false)
        case .shine:
            moving(period: 3.2) { t, size in
                let tint = finish.colors.first.map { Color(hex: $0) } ?? .white
                let x = -size.width * 0.5 + (size.width * 2) * t
                LinearGradient(colors: [tint.opacity(0), tint.opacity(0.6), .white.opacity(0.8), tint.opacity(0)],
                               startPoint: .leading, endPoint: .trailing)
                    .frame(width: size.width * 0.35)
                    .rotationEffect(.degrees(20))
                    .frame(height: size.height * 2)
                    .position(x: x, y: size.height / 2)
            }
        case .holo:
            moving(period: 6) { t, _ in
                AngularGradient(colors: [.pink, .yellow, .mint, .cyan, .purple, .pink],
                                center: .center, angle: .degrees(360 * t))
                    .opacity(0.28)
                    .blendMode(.overlay)
            }
        case .prism:
            // Still rainbow wash, like light through a prism.
            LinearGradient(colors: [.pink, .orange, .yellow, .mint, .cyan, .purple],
                           startPoint: .topLeading, endPoint: .bottomTrailing)
                .opacity(0.22)
                .blendMode(.overlay)
                .allowsHitTesting(false)
        case .frost:
            // Icy edges with a few still flakes.
            ZStack {
                LinearGradient(colors: [.white.opacity(0.6), .white.opacity(0), .white.opacity(0.45)],
                               startPoint: .top, endPoint: .bottom)
                Canvas { ctx, size in
                    for i in 0..<18 {
                        let fx = CGFloat((i * 43) % 100) / 100, fy = CGFloat((i * 71) % 100) / 100
                        let r = CGFloat(1 + (i % 3))
                        ctx.fill(Path(ellipseIn: CGRect(x: fx * size.width, y: fy * size.height, width: r * 2, height: r * 2)),
                                 with: .color(.white.opacity(0.7)))
                    }
                }
            }
            .allowsHitTesting(false)
        case .aurora:
            moving(period: 8) { t, size in
                let shift = sin(t * 2 * .pi)
                LinearGradient(colors: [Color(hex: 0x3BE8B0), Color(hex: 0x6C7CFF), Color(hex: 0xC86BFA), Color(hex: 0x3BE8B0)],
                               startPoint: UnitPoint(x: 0.5 * shift, y: 0), endPoint: UnitPoint(x: 1 + 0.5 * shift, y: 1))
                    .opacity(0.3)
                    .blendMode(.overlay)
                    .frame(width: size.width, height: size.height)
            }
        case .sparkle:
            moving(period: 2.4) { t, _ in
                Canvas { ctx, size in
                    for i in 0..<14 {
                        // Fixed spots, each twinkling on its own beat.
                        let fx = CGFloat((i * 37) % 100) / 100, fy = CGFloat((i * 61) % 100) / 100
                        let phase = (t + Double(i) / 14).truncatingRemainder(dividingBy: 1)
                        let a = reduceMotion ? 0.6 : sin(phase * .pi)
                        let r = 2 + 3 * a
                        let c = CGPoint(x: fx * size.width, y: fy * size.height)
                        var star = Path()
                        star.move(to: CGPoint(x: c.x, y: c.y - r * 1.6)); star.addLine(to: CGPoint(x: c.x + r * 0.4, y: c.y))
                        star.addLine(to: CGPoint(x: c.x, y: c.y + r * 1.6)); star.addLine(to: CGPoint(x: c.x - r * 0.4, y: c.y))
                        star.closeSubpath()
                        var cross = Path()
                        cross.move(to: CGPoint(x: c.x - r * 1.6, y: c.y)); cross.addLine(to: CGPoint(x: c.x, y: c.y - r * 0.4))
                        cross.addLine(to: CGPoint(x: c.x + r * 1.6, y: c.y)); cross.addLine(to: CGPoint(x: c.x, y: c.y + r * 0.4))
                        cross.closeSubpath()
                        ctx.fill(star, with: .color(glitter.opacity(a)))
                        ctx.fill(cross, with: .color(glitter.opacity(a)))
                    }
                }
            }
        }
    }

    /// Glitter color: white unless the finish has its own tint.
    private var glitter: Color { finish.colors.first.map { Color(hex: $0) } ?? .white }

    /// Drives `content` with a 0...1 phase, capped at 30 fps; a still frame
    /// with Reduce Motion.
    private func moving<C: View>(period: Double, @ViewBuilder content: @escaping (Double, CGSize) -> C) -> some View {
        GeometryReader { geo in
            if reduceMotion {
                content(0.35, geo.size)
            } else {
                TimelineView(.animation(minimumInterval: 1 / 30)) { tl in
                    let t = tl.date.timeIntervalSinceReferenceDate.truncatingRemainder(dividingBy: period) / period
                    content(t, geo.size)
                }
            }
        }
        .allowsHitTesting(false)
        .accessibilityHidden(true)
    }
}

/// Background color plus an optional stripes/dots/grid pattern.
struct CardPattern: View {
    let background: Cosmetic

    var body: some View {
        let base = Color(hex: background.colors.first ?? 0xF7F6F2)
        let ink = Color(hex: background.colors.dropFirst().first ?? 0x17172B).opacity(0.35)
        if background.pattern == .gradient {
            LinearGradient(colors: background.colors.map { Color(hex: $0) },
                           startPoint: .topLeading, endPoint: .bottomTrailing)
        } else {
            canvas(base: base, ink: ink)
        }
    }

    private func canvas(base: Color, ink: Color) -> some View {
        Canvas { ctx, size in
            ctx.fill(Path(CGRect(origin: .zero, size: size)), with: .color(base))
            switch background.pattern {
            case .solid:
                break
            case .stripes:
                var path = Path()
                var x: CGFloat = -size.height
                while x < size.width {
                    path.move(to: CGPoint(x: x, y: size.height))
                    path.addLine(to: CGPoint(x: x + size.height, y: 0))
                    x += 18
                }
                ctx.stroke(path, with: .color(ink), lineWidth: 6)
            case .dots:
                for x in stride(from: CGFloat(8), to: size.width, by: 18) {
                    for y in stride(from: CGFloat(8), to: size.height, by: 18) {
                        ctx.fill(Path(ellipseIn: CGRect(x: x, y: y, width: 5, height: 5)), with: .color(ink))
                    }
                }
            case .grid:
                var path = Path()
                for x in stride(from: CGFloat(0), to: size.width, by: 16) {
                    path.move(to: CGPoint(x: x, y: 0)); path.addLine(to: CGPoint(x: x, y: size.height))
                }
                for y in stride(from: CGFloat(0), to: size.height, by: 16) {
                    path.move(to: CGPoint(x: 0, y: y)); path.addLine(to: CGPoint(x: size.width, y: y))
                }
                ctx.stroke(path, with: .color(ink), lineWidth: 1)
            case .checker:
                let step: CGFloat = 16
                var path = Path()
                for (i, x) in stride(from: CGFloat(0), to: size.width, by: step).enumerated() {
                    for (j, y) in stride(from: CGFloat(0), to: size.height, by: step).enumerated() where (i + j) % 2 == 0 {
                        path.addRect(CGRect(x: x, y: y, width: step, height: step))
                    }
                }
                // Lighter than other patterns so the name stays readable.
                ctx.fill(path, with: .color(ink.opacity(0.3)))
            case .zigzag:
                var path = Path()
                for y in stride(from: CGFloat(10), to: size.height, by: 20) {
                    path.move(to: CGPoint(x: 0, y: y))
                    for (i, x) in stride(from: CGFloat(10), through: size.width + 10, by: 10).enumerated() {
                        path.addLine(to: CGPoint(x: x, y: y + (i % 2 == 0 ? -5 : 0)))
                    }
                }
                ctx.stroke(path, with: .color(ink), lineWidth: 2.5)
            case .waves:
                var path = Path()
                for y in stride(from: CGFloat(10), to: size.height + 10, by: 16) {
                    path.move(to: CGPoint(x: 0, y: y))
                    for x in stride(from: CGFloat(0), through: size.width, by: 4) {
                        path.addLine(to: CGPoint(x: x, y: y + sin(x / 12) * 3))
                    }
                }
                ctx.stroke(path, with: .color(ink), lineWidth: 2)
            case .plaid:
                // Wide soft bands both ways, with thin lines between.
                var bands = Path(), lines = Path()
                for x in stride(from: CGFloat(0), to: size.width, by: 36) {
                    bands.addRect(CGRect(x: x, y: 0, width: 14, height: size.height))
                    lines.move(to: CGPoint(x: x + 24, y: 0)); lines.addLine(to: CGPoint(x: x + 24, y: size.height))
                }
                for y in stride(from: CGFloat(0), to: size.height, by: 36) {
                    bands.addRect(CGRect(x: 0, y: y, width: size.width, height: 14))
                    lines.move(to: CGPoint(x: 0, y: y + 24)); lines.addLine(to: CGPoint(x: size.width, y: y + 24))
                }
                ctx.fill(bands, with: .color(ink.opacity(0.45)))
                ctx.stroke(lines, with: .color(ink), lineWidth: 1)
            case .stars:
                for (i, x) in stride(from: CGFloat(10), to: size.width, by: 26).enumerated() {
                    for (j, y) in stride(from: CGFloat(10), to: size.height, by: 26).enumerated() {
                        let c = CGPoint(x: x + ((j % 2 == 0) ? 0 : 13), y: y)
                        let r: CGFloat = (i + j) % 3 == 0 ? 5 : 3.5
                        ctx.fill(Self.star(at: c, radius: r), with: .color(ink))
                    }
                }
            case .hearts:
                for x in stride(from: CGFloat(12), to: size.width, by: 28) {
                    for (j, y) in stride(from: CGFloat(12), to: size.height + 10, by: 24).enumerated() {
                        var heart = ctx
                        heart.translateBy(x: x + ((j % 2 == 0) ? 0 : 14), y: y)
                        heart.fill(BackgroundPainter.heart(width: 10), with: .color(ink))
                    }
                }
            case .argyle:
                let w: CGFloat = 28, h: CGFloat = 36
                var diamonds = Path()
                for (i, x) in stride(from: CGFloat(0), to: size.width + w, by: w).enumerated() {
                    for (j, y) in stride(from: CGFloat(0), to: size.height + h, by: h).enumerated() where (i + j) % 2 == 0 {
                        diamonds.move(to: CGPoint(x: x, y: y - h / 2))
                        diamonds.addLine(to: CGPoint(x: x + w / 2, y: y))
                        diamonds.addLine(to: CGPoint(x: x, y: y + h / 2))
                        diamonds.addLine(to: CGPoint(x: x - w / 2, y: y))
                        diamonds.closeSubpath()
                    }
                }
                ctx.fill(diamonds, with: .color(ink.opacity(0.5)))
            case .sprinkles:
                // Short tilted dashes in every color after the base.
                let inks = background.colors.dropFirst().map { Color(hex: $0).opacity(0.75) }
                for i in 0..<60 where !inks.isEmpty {
                    let x = CGFloat((i * 37) % 101) / 101 * size.width
                    let y = CGFloat((i * 59) % 97) / 97 * size.height
                    let angle = Double((i * 47) % 180) * .pi / 180
                    var p = Path()
                    p.move(to: CGPoint(x: x - 4 * cos(angle), y: y - 4 * sin(angle)))
                    p.addLine(to: CGPoint(x: x + 4 * cos(angle), y: y + 4 * sin(angle)))
                    ctx.stroke(p, with: .color(inks[i % inks.count]), style: StrokeStyle(lineWidth: 3, lineCap: .round))
                }
            case .gradient:
                break
            }
        }
    }
}

extension CardPattern {
    /// A five-point star centered on `c`.
    static func star(at c: CGPoint, radius r: CGFloat) -> Path {
        var p = Path()
        for k in 0..<10 {
            let a = Double(k) * .pi / 5 - .pi / 2
            let len = k % 2 == 0 ? r : r * 0.45
            let pt = CGPoint(x: c.x + len * cos(a), y: c.y + len * sin(a))
            if k == 0 { p.move(to: pt) } else { p.addLine(to: pt) }
        }
        p.closeSubpath()
        return p
    }
}

struct CardShape: Shape {
    let kind: Cosmetic.Shape

    func path(in r: CGRect) -> Path {
        switch kind {
        case .rounded:
            return RoundedRectangle(cornerRadius: 24, style: .continuous).path(in: r)
        case .ticket:
            // Rounded card with a half-circle notch bitten out of each side.
            let notch: CGFloat = 14
            var p = RoundedRectangle(cornerRadius: 18, style: .continuous).path(in: r)
            p = p.subtracting(Path(ellipseIn: CGRect(x: r.minX - notch, y: r.midY - notch, width: notch * 2, height: notch * 2)))
            return p.subtracting(Path(ellipseIn: CGRect(x: r.maxX - notch, y: r.midY - notch, width: notch * 2, height: notch * 2)))
        case .hexagon:
            let inset = min(r.height * 0.35, 30)
            var p = Path()
            p.move(to: CGPoint(x: r.minX + inset, y: r.minY))
            p.addLine(to: CGPoint(x: r.maxX - inset, y: r.minY))
            p.addLine(to: CGPoint(x: r.maxX, y: r.midY))
            p.addLine(to: CGPoint(x: r.maxX - inset, y: r.maxY))
            p.addLine(to: CGPoint(x: r.minX + inset, y: r.maxY))
            p.addLine(to: CGPoint(x: r.minX, y: r.midY))
            p.closeSubpath()
            return p
        case .ribbon:
            let cut = min(r.height * 0.3, 26)
            var p = Path()
            p.move(to: CGPoint(x: r.minX, y: r.minY))
            p.addLine(to: CGPoint(x: r.maxX, y: r.minY))
            p.addLine(to: CGPoint(x: r.maxX - cut, y: r.midY))
            p.addLine(to: CGPoint(x: r.maxX, y: r.maxY))
            p.addLine(to: CGPoint(x: r.minX, y: r.maxY))
            p.addLine(to: CGPoint(x: r.minX + cut, y: r.midY))
            p.closeSubpath()
            return p
        case .pill:
            return Capsule(style: .continuous).path(in: r)
        case .tag:
            // Clipped corners, like a conference name tag.
            let c = min(r.height * 0.22, 18)
            var p = Path()
            p.move(to: CGPoint(x: r.minX + c, y: r.minY))
            p.addLine(to: CGPoint(x: r.maxX - c, y: r.minY))
            p.addLine(to: CGPoint(x: r.maxX, y: r.minY + c))
            p.addLine(to: CGPoint(x: r.maxX, y: r.maxY - c))
            p.addLine(to: CGPoint(x: r.maxX - c, y: r.maxY))
            p.addLine(to: CGPoint(x: r.minX + c, y: r.maxY))
            p.addLine(to: CGPoint(x: r.minX, y: r.maxY - c))
            p.addLine(to: CGPoint(x: r.minX, y: r.minY + c))
            p.closeSubpath()
            return p
        case .stamp:
            // Postage stamp: small round bites all the way around the edge.
            let bite: CGFloat = 5, step: CGFloat = 16
            var p = Rectangle().path(in: r)
            var holes = Path()
            for x in stride(from: r.minX + step / 2, to: r.maxX, by: step) {
                holes.addEllipse(in: CGRect(x: x - bite, y: r.minY - bite, width: bite * 2, height: bite * 2))
                holes.addEllipse(in: CGRect(x: x - bite, y: r.maxY - bite, width: bite * 2, height: bite * 2))
            }
            for y in stride(from: r.minY + step / 2, to: r.maxY, by: step) {
                holes.addEllipse(in: CGRect(x: r.minX - bite, y: y - bite, width: bite * 2, height: bite * 2))
                holes.addEllipse(in: CGRect(x: r.maxX - bite, y: y - bite, width: bite * 2, height: bite * 2))
            }
            p = p.subtracting(holes)
            return p
        case .slant:
            // Leaning parallelogram, like it's moving fast.
            let lean = min(r.height * 0.3, 24)
            var p = Path()
            p.move(to: CGPoint(x: r.minX + lean, y: r.minY))
            p.addLine(to: CGPoint(x: r.maxX, y: r.minY))
            p.addLine(to: CGPoint(x: r.maxX - lean, y: r.maxY))
            p.addLine(to: CGPoint(x: r.minX, y: r.maxY))
            p.closeSubpath()
            return p
        case .scoop:
            // Corners scooped inward, like a vintage label.
            let s = min(r.height * 0.2, 16)
            var corners = Path()
            for c in [CGPoint(x: r.minX, y: r.minY), CGPoint(x: r.maxX, y: r.minY),
                      CGPoint(x: r.minX, y: r.maxY), CGPoint(x: r.maxX, y: r.maxY)] {
                corners.addEllipse(in: CGRect(x: c.x - s, y: c.y - s, width: s * 2, height: s * 2))
            }
            return Rectangle().path(in: r).subtracting(corners)
        }
    }
}
