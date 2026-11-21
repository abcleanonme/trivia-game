import SwiftUI
import TriviaKit
import UIKit

/// This install's app version, so match players can tell who needs updating.
enum AppBuild {
    static var number: Int {
        Int(Bundle.main.object(forInfoDictionaryKey: "CFBundleVersion") as? String ?? "") ?? 0
    }

    static var version: String {
        Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "?"
    }

    /// Opens TestFlight (testers) or the App Store page, wherever updates come from.
    @MainActor
    static func openUpdate() {
        let testFlight = URL(string: "itms-beta://")!
        UIApplication.shared.open(testFlight, options: [:]) { opened in
            if !opened, let store = URL(string: "itms-apps://apps.apple.com/app/quizio") {
                UIApplication.shared.open(store)
            }
        }
    }
}

/// One player's seat in a match, for lobby rows, intros and results.
struct MatchSeat: Identifiable, Equatable {
    enum State: Equatable {
        case played
        /// It's their turn now.
        case up
        /// Waiting for the turn to reach them.
        case waiting
        /// Declined, quit or timed out without playing.
        case out
    }

    let id: String
    let name: String
    let isMe: Bool
    var state: State
    var points: Int?
    var card: SharedCard?
    var build: Int?
}

extension SharedCard {
    /// Your equipped Player Card, as opponents will see it.
    @MainActor
    init(store: PlayerStore, fallbackName: String) {
        let look = CardLook(store: store)
        let inventory = store.progress.inventory
        var items: [String: String] = [:]
        for slot in SharedCard.slots { items[slot.rawValue] = inventory.equipped(slot).id }
        let name = look.name == PlayerCard().name ? fallbackName : look.name
        self.init(name: name, title: look.title,
                  statLabel: look.showsStat ? look.statLabel : nil,
                  statValue: look.showsStat ? look.statValue : nil,
                  corner: look.corner, items: items)
    }
}

extension CardLook {
    /// Someone else's card, from match data.
    init(shared card: SharedCard) {
        avatar = card.item(.avatar)
        avatarColor = card.item(.avatarColor)
        border = card.item(.border)
        shape = card.item(.cardShape)
        background = card.item(.cardBackground)
        lettering = card.item(.nameStyle)
        sticker = card.item(.sticker)
        finish = card.item(.finish)
        corner = card.corner
        name = card.name
        title = card.title
        statLabel = card.statLabel ?? ""
        statValue = card.statValue ?? ""
        showsStat = card.statLabel != nil && card.statValue != nil
    }
}

// MARK: Avatars

/// A player's avatar from their Player Card (or an initial when they
/// haven't shared one yet). Tap to see the full card.
struct PlayerAvatar: View {
    let name: String
    let card: SharedCard?
    var size: CGFloat = 44
    /// A small mark in the corner: a crown, a check, a place.
    var badge: Badge? = nil
    var expands = true

    enum Badge: Equatable {
        case crown, check, waiting, place(Int)
    }

    @State private var showingCard = false

    var body: some View {
        Group {
            if expands {
                Button { showingCard = true } label: { face }
                    .buttonStyle(.plain)
                    .accessibilityLabel("\(name)'s Player Card")
                    .accessibilityHint("Shows the full card")
            } else {
                face
            }
        }
        .sheet(isPresented: $showingCard) {
            PlayerCardSheet(name: name, card: card)
        }
    }

    private var face: some View {
        Group {
            if let card {
                AvatarView(avatar: card.item(.avatar), border: card.item(.border), name: card.name,
                           size: size, tint: card.item(.avatarColor))
            } else {
                PlayerBadge(name: name, size: size)
            }
        }
        .overlay(alignment: .bottomTrailing) { badgeView.offset(x: size * 0.08, y: size * 0.08) }
        .contentShape(Circle())
    }

    @ViewBuilder private var badgeView: some View {
        let d = max(size * 0.42, 16)
        switch badge {
        case .crown?:
            mark("crown.fill", fill: Theme.spark, ink: Theme.onSpark, d: d)
        case .check?:
            mark("checkmark", fill: Theme.correct, ink: .white, d: d)
        case .waiting?:
            mark("hourglass", fill: Theme.card, ink: Theme.muted, d: d)
        case .place(let n)?:
            Text("\(n)")
                .font(.system(size: d * 0.6, weight: .heavy, design: .rounded))
                .foregroundStyle(n == 1 ? Theme.onSpark : Theme.ink)
                .frame(width: d, height: d)
                .background(Circle().fill(n == 1 ? Theme.spark : Theme.card))
                .overlay(Circle().stroke(Theme.ink, lineWidth: 1.5))
                .accessibilityHidden(true)
        case nil:
            EmptyView()
        }
    }

    private func mark(_ symbol: String, fill: Color, ink: Color, d: CGFloat) -> some View {
        Image(systemName: symbol)
            .font(.system(size: d * 0.5, weight: .heavy))
            .foregroundStyle(ink)
            .frame(width: d, height: d)
            .background(Circle().fill(fill))
            .overlay(Circle().stroke(Theme.ink, lineWidth: 1.5))
            .accessibilityHidden(true)
    }
}

/// Overlapping avatars for a group: "You, Maya, Sam +2".
struct AvatarStack: View {
    let seats: [MatchSeat]
    var size: CGFloat = 34
    var limit = 4

    var body: some View {
        HStack(spacing: -size * 0.32) {
            ForEach(seats.prefix(limit)) { seat in
                PlayerAvatar(name: seat.name, card: seat.card, size: size, expands: false)
            }
            if seats.count > limit {
                Text("+\(seats.count - limit)")
                    .font(.system(size: size * 0.36, weight: .heavy, design: .rounded))
                    .foregroundStyle(Theme.ink)
                    .frame(width: size, height: size)
                    .background(Circle().fill(Theme.paper))
                    .overlay(Circle().stroke(Theme.ink, lineWidth: Theme.border))
            }
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(seats.map(\.name).joined(separator: ", "))
    }
}

/// The full Player Card in a small sheet.
struct PlayerCardSheet: View {
    let name: String
    let card: SharedCard?

    @Environment(\.dismiss) private var dismiss

    var body: some View {
        VStack(spacing: Space.l) {
            if let card {
                PlayerCardView(look: CardLook(shared: card))
            } else {
                VStack(spacing: Space.s) {
                    PlayerBadge(name: name, size: 72)
                    Text(name).font(Theme.display(.title2))
                    Text("Their Player Card shows up once they play a match on the latest Quizio.")
                        .font(.footnote)
                        .foregroundStyle(Theme.muted)
                        .multilineTextAlignment(.center)
                }
                .foregroundStyle(Theme.ink)
            }
            Button { dismiss() } label: {
                Text("Close").font(.headline).padding(.horizontal, Space.xl).frame(minHeight: 44)
            }
            .buttonStyle(.chunky(fill: Theme.card, capsule: true))
        }
        .padding(.horizontal, Theme.gutter)
        .padding(.vertical, Space.l)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .themeBackground()
        .presentationDetents([.height(card == nil ? 300 : 260)])
        .presentationDragIndicator(.visible)
    }
}

// MARK: Version reminder

/// Tells you when someone in the match is on a different Quizio, so
/// everyone plays on the same version.
struct VersionNotice: View {
    let seats: [MatchSeat]

    private var ahead: [MatchSeat] {
        seats.filter { !$0.isMe && ($0.build ?? 0) > AppBuild.number }
    }
    private var behind: [MatchSeat] {
        seats.filter { !$0.isMe && $0.build != nil && $0.build! < AppBuild.number }
    }

    var body: some View {
        if !ahead.isEmpty {
            banner(icon: "arrow.down.app.fill",
                   text: "\(names(ahead)) \(ahead.count == 1 ? "is" : "are") on a newer Quizio. Update so you're all on the same version.",
                   action: "Update")
        } else if !behind.isEmpty {
            banner(icon: "exclamationmark.arrow.circlepath",
                   text: "\(names(behind)) \(behind.count == 1 ? "is" : "are") on an older Quizio. Remind them to update so you're all on the same version.",
                   action: nil)
        }
    }

    private func names(_ seats: [MatchSeat]) -> String {
        seats.map(\.name).formatted(.list(type: .and))
    }

    private func banner(icon: String, text: String, action: String?) -> some View {
        HStack(alignment: .top, spacing: Space.m) {
            Image(systemName: icon)
                .font(.title3.weight(.bold))
                .foregroundStyle(Theme.accent)
                .accessibilityHidden(true)
            Text(text)
                .font(.footnote.weight(.semibold))
                .fixedSize(horizontal: false, vertical: true)
                .frame(maxWidth: .infinity, alignment: .leading)
            if let action {
                Button { AppBuild.openUpdate() } label: {
                    Text(action).font(.footnote.bold()).padding(.horizontal, Space.m).frame(minHeight: 36)
                }
                .buttonStyle(.chunky(fill: Theme.accent, foreground: .white, capsule: true))
                .fixedSize()
            }
        }
        .foregroundStyle(Theme.ink)
        .padding(Theme.cardPadding)
        .frame(maxWidth: .infinity, alignment: .leading)
        .card()
        .accessibilityElement(children: .combine)
    }
}
