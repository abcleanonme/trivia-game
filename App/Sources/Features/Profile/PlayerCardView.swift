import SwiftUI
import TriviaKit

/// Everything needed to draw a Player Card, resolved from the inventory
/// (or from a preview in the shop).
struct CardLook: Equatable {
    var avatar: Cosmetic
    var border: Cosmetic
    var shape: Cosmetic
    var background: Cosmetic
    /// SF Symbol in the corner: an emblem or a stamp.
    var corner: String?
    var name: String
    var title: String
    var statLabel: String
    var statValue: String

    @MainActor
    init(store: PlayerStore, previewing: Cosmetic? = nil) {
        let p = store.progress
        func pick(_ slot: CosmeticSlot) -> Cosmetic {
            if let previewing, previewing.slot == slot { return previewing }
            return p.inventory.equipped(slot)
        }
        avatar = pick(.avatar)
        border = pick(.border)
        shape = pick(.cardShape)
        background = pick(.cardBackground)
        let emblem = pick(.emblem)
        if previewing?.slot != .emblem, let stampID = p.card.cornerStamp,
           let stamp = p.stamps.first(where: { $0.id == stampID }) {
            corner = stamp.systemImage
        } else {
            corner = emblem.symbol
        }
        name = p.card.name
        title = p.card.title
        statLabel = p.card.showcase.label
        statValue = p.showcaseValue(on: store.today)
    }
}

/// The customizable identity card: shape, background, avatar with border,
/// name, one title, one stat, one corner mark. Kept to three layers beyond
/// the name so it reads at small sizes.
struct PlayerCardView: View {
    let look: CardLook

    @ScaledMetric(relativeTo: .title) private var avatarSize: CGFloat = 64

    var body: some View {
        let shape = CardShape(kind: look.shape.shape ?? .rounded)
        HStack(spacing: 16) {
            AvatarView(avatar: look.avatar, border: look.border, name: look.name, size: min(avatarSize, 96))
            VStack(alignment: .leading, spacing: 4) {
                Text(look.name)
                    .font(Theme.display(.title2))
                    .lineLimit(2)
                Text(look.title)
                    .font(.subheadline.weight(.semibold))
                    .opacity(0.75)
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
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .foregroundStyle(ShareColors.ink)
        .padding(.vertical, 22)
        .padding(.horizontal, horizontalPadding)
        .frame(maxWidth: .infinity)
        .background {
            CardPattern(background: look.background).clipShape(shape)
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
        .background(shape.fill(Theme.shadow).offset(y: 5))
        .padding(.bottom, 5)
        .environment(\.colorScheme, .light)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("Player Card: \(look.name), \(look.title). \(look.statLabel) \(look.statValue).")
    }

    private var horizontalPadding: CGFloat {
        switch look.shape.shape ?? .rounded {
        case .hexagon, .ribbon: 40
        case .ticket: 30
        case .rounded: 20
        }
    }
}

/// The small version used in live rounds and lists: avatar plus border.
struct AvatarView: View {
    let avatar: Cosmetic
    let border: Cosmetic
    let name: String
    var size: CGFloat = 44

    var body: some View {
        ZStack {
            Circle().fill(Color(hex: avatar.colors.first ?? 0x3B5BFD))
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

/// Background color plus an optional stripes/dots/grid pattern.
struct CardPattern: View {
    let background: Cosmetic

    var body: some View {
        let base = Color(hex: background.colors.first ?? 0xF7F6F2)
        let ink = Color(hex: background.colors.dropFirst().first ?? 0x17172B).opacity(0.35)
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
            }
        }
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
        }
    }
}

/// Head-to-head record chip for lobbies and friend lists.
struct RivalryBadge: View {
    let record: RivalRecord

    var body: some View {
        Label("You \(record.summary)", systemImage: "person.2.fill")
            .font(.footnote.weight(.bold))
            .foregroundStyle(Theme.ink)
            .padding(.horizontal, 10)
            .padding(.vertical, 5)
            .background(Theme.pill.fill(Theme.card))
            .overlay(Theme.pill.stroke(Theme.ink, lineWidth: 1.5))
            .accessibilityLabel("Your record against \(record.name): \(record.wins) wins, \(record.losses) losses"
                                + (record.ties > 0 ? ", \(record.ties) ties" : ""))
    }
}
