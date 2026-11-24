import SwiftUI
import TriviaKit

/// A friend challenge, full screen: intro, the round (the same quiz screen
/// as solo), sending the score, then the result.
struct ChallengeGameView: View {
    let round: ChallengeRound

    @Environment(PlayerStore.self) private var store
    @Environment(GameCenter.self) private var gameCenter
    @Environment(\.dismiss) private var dismiss
    @Environment(\.scenePhase) private var scenePhase

    private enum Stage {
        case intro
        case playing(GameSession)
        case sending(GameSession)
        case failed(GameSession, String)
        case result(ChallengeData)
    }

    @State private var stage: Stage = .intro
    /// Sparks are paid once, even if sending has to be retried.
    @State private var awarded = false

    private var me: String { gameCenter.localPlayerID }

    var body: some View {
        Group {
            switch stage {
            case .intro:
                ChallengeIntroView(round: round, me: me,
                                   onStart: { stage = .playing(round.data.makeSession()) },
                                   onLater: { dismiss() })
            case .playing(let session):
                QuizView(session: session,
                         stock: { store.wallet.count(of: $0) },
                         onAnswer: { i in update { $0.answer(i) } },
                         onPowerUp: usePowerUp,
                         onNext: { update { $0.advance() } },
                         onQuit: { send(session) },
                         onReport: { q, reason in store.report(q, reason: reason) },
                         quitMessage: "Your score so far is sent to \(round.isGroup ? "the group" : round.opponentName). Questions you didn't reach count as wrong.")
            case .sending:
                ProgressView("Sending your score…")
                    .font(.headline)
                    .foregroundStyle(Theme.ink)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            case .failed(let session, let message):
                ContentUnavailableView {
                    Label("Couldn't send your score", systemImage: "wifi.exclamationmark")
                } description: {
                    Text(message)
                } actions: {
                    Button("Try again") { send(session) }
                        .buttonStyle(.chunky(fill: Theme.accent, foreground: .white, capsule: true))
                    Button("Send it later") { dismiss() }
                        .buttonStyle(.chunky(fill: Theme.card, capsule: true))
                }
            case .result(let data):
                ChallengeResultView(round: round, data: data, me: me,
                                    balance: store.wallet.sparks,
                                    onRematch: rematch,
                                    onDone: { dismiss() })
            }
        }
        .themeBackground()
        .onAppear {
            // Opening a match we've already played goes straight to the
            // result; one played offline goes straight to sending it.
            guard case .intro = stage else { return }
            if round.data.hasPlayed(me) {
                stage = .result(round.data)
            } else if gameCenter.hasPendingTurn(round.id) {
                awarded = true
                send(round.data.makeSession())
            }
        }
        .task {
            await runRoundClock(isActive: { scenePhase == .active }, tick: { s in update { $0.tick(by: s) } })
        }
        .interactiveDismissDisabled()
    }

    private func update(_ change: (inout GameSession) -> Void) {
        guard case .playing(var s) = stage else { return }
        change(&s)
        if s.phase == .finished {
            send(s)
        } else {
            stage = .playing(s)
        }
    }

    private func usePowerUp(_ powerUp: PowerUp) {
        guard case .playing(var s) = stage else { return }
        if store.use(powerUp, in: &s) { stage = .playing(s) }
    }

    private func send(_ session: GameSession) {
        if !awarded {
            store.award(sparks: session.sparksEarned)
            store.finishChallenge(session)
            awarded = true
        }
        stage = .sending(session)
        Task {
            do {
                stage = .result(try await gameCenter.submit(session, in: round))
            } catch {
                var message = GameCenter.friendly(error, doing: "send your score")
                if case ChallengeError.notYourTurn = error {} else {
                    message += " Your score is saved on this phone and sends by itself next time you open Friends."
                }
                stage = .failed(session, message)
            }
        }
    }

    private func rematch() {
        dismiss()
        Task {
            // Let this cover finish closing before the next one opens.
            try? await Task.sleep(for: .milliseconds(450))
            await gameCenter.rematch(round.id)
        }
    }
}

// MARK: Intro

private struct ChallengeIntroView: View {
    let round: ChallengeRound
    let me: String
    let onStart: () -> Void
    let onLater: () -> Void

    @Environment(\.dynamicTypeSize) private var typeSize

    var body: some View {
        ScrollView {
            VStack(spacing: Space.l) {
                MatchHeader(round: round)

                VersionNotice(seats: round.seats)

                if let target = round.data.scoreToBeat(for: me) {
                    VStack(spacing: 4) {
                        Text("Score to beat").font(.subheadline.weight(.semibold))
                        Text(target, format: .number).font(Theme.display(.largeTitle))
                    }
                    .foregroundStyle(Theme.onSpark)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, Space.l)
                    .card(fill: Theme.spark, drop: 5)
                    .accessibilityElement(children: .combine)
                }

                VStack(alignment: .leading, spacing: Space.m) {
                    ForEach(rules, id: \.text) { rule($0.icon, $0.text) }
                }
                .font(.subheadline)
                .foregroundStyle(Theme.ink)
                .padding(Theme.cardPadding)
                .frame(maxWidth: .infinity, alignment: .leading)
                .card()

                if round.canInvite {
                    InviteButton(round: round)
                }
            }
            .padding(.horizontal, Theme.gutter)
            .padding(.top, Space.xl)
            .padding(.bottom, Space.m)
            .readableWidth()
        }
        .scrollBounceBehavior(.basedOnSize)
        .safeAreaInset(edge: .bottom) {
            // Same footer as the round summary: small secondary, big primary.
            (typeSize.isAccessibilitySize
                ? AnyLayout(VStackLayout(spacing: 10))
                : AnyLayout(HStackLayout(spacing: 10))) {
                Button(action: onLater) {
                    Text("Not now").font(.headline)
                        .padding(.horizontal, 18)
                        .frame(maxWidth: typeSize.isAccessibilitySize ? .infinity : nil, minHeight: 52)
                }
                .buttonStyle(.chunky(fill: Theme.card, capsule: true))
                Button(action: onStart) {
                    Label("Start round", systemImage: "play.fill")
                        .font(.title3.bold()).frame(maxWidth: .infinity, minHeight: 52)
                }
                .buttonStyle(.chunky(fill: Theme.accent, foreground: .white, capsule: true))
            }
            .padding(.horizontal, Theme.gutter)
            .padding(.vertical, 12)
            .readableWidth()
            .background(Theme.paper)
        }
    }

    /// The match's rules, as the challenger set them.
    private var rules: [(icon: String, text: String)] {
        let data = round.data
        let them = round.isGroup ? "everyone else" : round.opponentName
        var lines: [(icon: String, text: String)] = []
        switch data.gameMode {
        case .classic:
            lines.append(("list.number", "\(data.questions.count) questions, the same ones \(them) gets"))
        case .survival:
            lines.append(("heart.fill", "Survival: keep going until you miss \(GameMode.survivalStrikes). Same questions as \(them)"))
        case .speed:
            lines.append(("stopwatch.fill", "Speed round: as many as you can in \(Int(GameMode.speedRoundSeconds)) seconds. A miss costs \(Int(GameMode.speedMissPenaltySeconds))s, and \(GameMode.survivalStrikes) misses ends it. Same questions as \(them)"))
        }
        let level = data.level == .mixed ? "Mixed levels" : "\(data.level.title) questions"
        lines.append(("chart.bar.fill", ChallengeSetup.topicSummary(data.categories).map { "\(level) from \($0)" } ?? level))
        if data.gameMode != .speed {
            lines.append(data.isTimed
                ? ("timer", "\(Int(GameRules.questionTime)) seconds each. Answer fast for bonus points")
                : ("tortoise.fill", "No clock. Take your time on every question"))
        }
        lines.append(data.powerUpLimit > 0
            ? ("bolt.fill", "Up to \(data.powerUpLimit) power-up\(data.powerUpLimit == 1 ? "" : "s") from your own stock")
            : ("bolt.slash.fill", "No power-ups this time"))
        lines.append(("trophy", round.isGroup
            ? "Highest score in the group wins. Ties go to more correct answers"
            : "Highest score wins. Ties go to more correct answers"))
        return lines
    }

    private func rule(_ icon: String, _ text: String) -> some View {
        Label {
            Text(text).fixedSize(horizontal: false, vertical: true)
        } icon: {
            Image(systemName: icon).foregroundStyle(Theme.accent)
        }
    }
}

// MARK: Result

private struct ChallengeResultView: View {
    let round: ChallengeRound
    let data: ChallengeData
    let me: String
    let balance: Int
    let onRematch: () -> Void
    let onDone: () -> Void

    private var mine: ChallengeTurn? { data.turn(for: me) }
    private var outcome: ChallengeOutcome? { data.outcome(for: me, among: round.playerIDs) }
    private var place: Int? { data.standings(among: round.playerIDs).first { $0.playerID == me }?.place }
    private var waitingOn: [String] { round.playerIDs.filter { !data.hasPlayed($0) } }

    /// The round as a match record, for the standings and breakdown.
    private var record: ArchivedMatch {
        var names: [String: String] = [:]
        for id in round.playerIDs { names[id] = round.name(of: id) }
        var data = data
        for seat in round.seats where data.player(seat.id) == nil {
            if let card = seat.card { data.setPlayer(ChallengePlayer(card: card, build: seat.build ?? 0), for: seat.id) }
        }
        return ArchivedMatch(matchID: round.id, data: data, playerIDs: round.playerIDs,
                             names: names, finishedAt: Date())
    }

    private var headline: String {
        if round.isGroup, outcome != nil, let place {
            return place == 1 ? (outcome == .tied ? "Tied for first!" : "You won the group!")
                : "You placed \(place)\(Self.suffix(place)) of \(round.playerIDs.count)"
        }
        switch outcome {
        case .won: return "You won!"
        case .lost: return "\(round.opponentName) won"
        case .tied: return "It's a tie"
        case nil: return round.isGroup ? "Score sent to the group" : "Sent to \(round.opponentName)"
        }
    }

    private static func suffix(_ n: Int) -> String {
        switch (n % 10, n % 100) {
        case (1, let t) where t != 11: "st"
        case (2, let t) where t != 12: "nd"
        case (3, let t) where t != 13: "rd"
        default: "th"
        }
    }

    var body: some View {
        ScrollView {
            VStack(spacing: 20) {
                VStack(spacing: 6) {
                    SectionLabel(outcome == nil ? "Your turn is done" : "Challenge complete")
                    Text(headline)
                        .font(Theme.display(.largeTitle))
                        .foregroundStyle(Theme.ink)
                        .multilineTextAlignment(.center)
                        .accessibilityAddTraits(.isHeader)
                    if outcome == nil {
                        Text(waitingOn.count > 1
                             ? "Waiting on \(waitingOn.count) players. We'll let you know when they've played."
                             : "We'll let you know when they've played.")
                            .font(.callout)
                            .foregroundStyle(Theme.muted)
                            .multilineTextAlignment(.center)
                    }
                }

                StandingsCard(match: record, me: me)

                VersionNotice(seats: round.seats)

                if let mine {
                    HStack(spacing: 14) {
                        Image(systemName: "bolt.fill")
                            .font(.system(size: 30, weight: .bold))
                            .accessibilityHidden(true)
                        VStack(alignment: .leading, spacing: 2) {
                            Text("+\(Scoring.sparks(forPoints: mine.points)) Sparks").font(Theme.display(.title3))
                            Text("Balance \(balance)").font(.subheadline)
                        }
                        .frame(maxWidth: .infinity, alignment: .leading)
                    }
                    .foregroundStyle(Theme.onSpark)
                    .padding(.horizontal, Theme.gutter)
                    .padding(.vertical, 16)
                    .card(fill: Theme.spark, drop: 5)
                    .accessibilityElement(children: .combine)
                }

                if outcome == nil && round.canInvite {
                    InviteButton(round: round)
                }

                MatchBreakdownView(match: record, me: me, embedded: true)
            }
            .padding(.horizontal, Theme.gutter)
            .padding(.top, Space.xl)
            .padding(.bottom, Space.m)
            .readableWidth()
        }
        .scrollBounceBehavior(.basedOnSize)
        .safeAreaInset(edge: .bottom) {
            VStack(spacing: 12) {
                if outcome != nil {
                    Button(action: onRematch) {
                        Label("Rematch", systemImage: "arrow.triangle.2.circlepath")
                            .font(.title3.bold()).frame(maxWidth: .infinity, minHeight: 56)
                    }
                    .buttonStyle(.chunky(fill: Theme.accent, foreground: .white, capsule: true))
                }
                Button(action: onDone) {
                    Text("Done").font(.headline).frame(maxWidth: .infinity, minHeight: 52)
                }
                .buttonStyle(.chunky(fill: Theme.card, capsule: true))
            }
            .padding(.horizontal, Theme.gutter)
            .padding(.vertical, 12)
            .readableWidth()
            .background(Theme.paper)
        }
    }
}

/// Right/wrong per question, as in the solo summary.
struct AnswerStrip: View {
    let answers: [Bool]

    var body: some View {
        HStack(spacing: 5) {
            ForEach(Array(answers.enumerated()), id: \.offset) { _, correct in
                Capsule()
                    .fill(correct ? Theme.correct : Theme.wrong)
                    .frame(maxWidth: 24)
                    .frame(height: 8)
            }
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("\(answers.filter { $0 }.count) correct, \(answers.filter { !$0 }.count) wrong")
    }
}

/// A round initial badge standing in for a Game Center photo (and, later,
/// the Player Card).
struct PlayerBadge: View {
    let name: String
    var size: CGFloat = 44

    private static let fills = [Theme.accent, Theme.correct, Theme.wrong, Color(light: 0x7C3AED, dark: 0x8B5CF6)]

    var body: some View {
        let fill = Self.fills[abs(name.unicodeScalars.reduce(0) { $0 &+ Int($1.value) }) % Self.fills.count]
        Text(name.first.map(String.init)?.uppercased() ?? "?")
            .font(.system(size: size * 0.42, weight: .heavy, design: .rounded))
            .foregroundStyle(.white)
            .frame(width: size, height: size)
            .background(Circle().fill(fill))
            .overlay(Circle().stroke(Theme.ink, lineWidth: Theme.border))
            .dynamicTypeSize(...DynamicTypeSize.xxxLarge)
            .accessibilityHidden(true)
    }
}
