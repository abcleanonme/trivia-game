import SwiftUI
import TriviaKit

// Pieces shared by the Daily and Weekly tabs.

/// One chip on a challenge tab's friends board: a board, and whether it's
/// the current period or the one before.
struct BoardChoice: Identifiable, Hashable {
    let label: String
    let systemImage: String
    let board: FriendBoard
    var previous = false
    var id: String { "\(board.rawValue).\(previous)" }
}

/// Friends-only leaderboard with a row of period chips (Today / Yesterday,
/// This week / Last week). Handles Game Center being signed out.
struct ChallengeBoardPanel: View {
    let choices: [BoardChoice]
    /// Shown when no friends have posted for the chosen period.
    let emptyMessage: (BoardChoice) -> String

    @Environment(GameCenter.self) private var gameCenter
    @State private var picked = 0

    var body: some View {
        let choice = choices[min(picked, choices.count - 1)]
        VStack(alignment: .leading, spacing: Space.s) {
            HStack(alignment: .firstTextBaseline) {
                SectionLabel("Friends")
                Spacer()
            }
            switch gameCenter.auth {
            case .checking:
                ProgressView().frame(maxWidth: .infinity).padding(.vertical, Space.l)
            case .signedOut:
                signIn
            case .restricted:
                note("Screen Time or a device profile blocks Game Center, so friends' scores can't load.")
            case .signedIn:
                FlowLayout(spacing: 6) {
                    ForEach(Array(choices.enumerated()), id: \.element.id) { i, c in
                        let on = c == choice
                        Button { picked = i } label: {
                            Label(c.label, systemImage: c.systemImage)
                                .labelStyle(CompactLabelStyle())
                                .font(.footnote.weight(.bold))
                                .padding(.horizontal, Space.m)
                                .frame(minHeight: 36)
                                .contentShape(Rectangle())
                        }
                        .buttonStyle(.chip(selected: on, depth: on ? 2 : 3))
                        .accessibilityAddTraits(on ? .isSelected : [])
                    }
                }
                BoardContent(state: gameCenter.boardState(choice.board, previous: choice.previous),
                             board: choice.board, emptyMessage: emptyMessage(choice))
            }
        }
        .task(id: "\(choice.id).\(gameCenter.auth == .signedIn)") {
            await gameCenter.loadBoard(choice.board, previous: choice.previous)
        }
    }

    private var signIn: some View {
        HStack(alignment: .center, spacing: Space.m) {
            Text("Sign in to Game Center to see how your friends did.")
                .font(.subheadline)
                .foregroundStyle(Theme.muted)
                .fixedSize(horizontal: false, vertical: true)
                .frame(maxWidth: .infinity, alignment: .leading)
            Button("Sign in") { gameCenter.signIn() }
                .font(.subheadline.bold())
                .padding(.horizontal, Space.m)
                .frame(minHeight: 36)
                .buttonStyle(.chunky(fill: Theme.accent, foreground: .white, capsule: true))
        }
        .padding(Theme.cardPadding)
        .card()
    }

    private func note(_ text: String) -> some View {
        Text(text)
            .font(.subheadline)
            .foregroundStyle(Theme.muted)
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(Theme.cardPadding)
            .card()
    }
}

/// Big screen title with an optional trailing accessory, matching Home.
struct ChallengeTabHeader<Trailing: View>: View {
    let title: String
    let subtitle: String
    @ViewBuilder var trailing: Trailing

    var body: some View {
        HStack(alignment: .center) {
            VStack(alignment: .leading, spacing: 0) {
                Text(title)
                    .font(Theme.display(.title))
                    .foregroundStyle(Theme.ink)
                    .accessibilityAddTraits(.isHeader)
                Text(subtitle)
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(Theme.muted)
            }
            Spacer()
            trailing
        }
    }
}

extension Day {
    /// "Nov 17" (or "Mon, Nov 17" with `weekday`).
    func shortDate(weekday: Bool = false) -> String {
        var style = Date.FormatStyle.dateTime.month(.abbreviated).day()
        if weekday { style = style.weekday(.abbreviated) }
        style.timeZone = .gmt
        return utcDate.formatted(style)
    }

    /// "Nov 17 – 23" style range for a week that starts on this day.
    func weekRange() -> String {
        let end = self + 6
        if end.components.month == components.month {
            var dayOnly = Date.FormatStyle.dateTime.day()
            dayOnly.timeZone = .gmt
            return "\(shortDate()) – \(end.utcDate.formatted(dayOnly))"
        }
        return "\(shortDate()) – \(end.shortDate())"
    }
}

/// "5h 12m" until local midnight `days` from today (1 = tonight).
struct MidnightCountdown: View {
    var days = 1
    var prefix = ""

    var body: some View {
        TimelineView(.periodic(from: .now, by: 30)) { context in
            Text(prefix + Self.text(until: days, from: context.date))
                .monospacedDigit()
        }
    }

    static func text(until days: Int, from now: Date) -> String {
        let calendar = Calendar.current
        let target = calendar.date(byAdding: .day, value: days, to: calendar.startOfDay(for: now)) ?? now
        let minutes = max(Int(target.timeIntervalSince(now) / 60), 0)
        let d = minutes / 1_440, h = (minutes % 1_440) / 60, m = minutes % 60
        if d > 0 { return "\(d)d \(h)h" }
        if h > 0 { return "\(h)h \(m)m" }
        return "\(max(m, 1))m"
    }
}

/// A small rounded tag, like "Relaxed" or "Perfect".
struct TagPill: View {
    let text: String
    var systemImage: String? = nil
    var fill: Color = Theme.line
    var foreground: Color = Theme.ink

    var body: some View {
        Group {
            if let systemImage {
                Label(text, systemImage: systemImage).labelStyle(CompactLabelStyle())
            } else {
                Text(text)
            }
        }
        .font(.caption2.weight(.bold))
        .padding(.horizontal, 7)
        .padding(.vertical, 3)
        .background(Capsule().fill(fill))
        .foregroundStyle(foreground)
    }
}
