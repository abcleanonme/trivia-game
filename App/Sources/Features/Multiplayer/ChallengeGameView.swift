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
                         quitMessage: "Your score so far is sent to \(round.opponentName). Questions you didn't reach count as wrong.")
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
                }
            case .result(let data):
                ChallengeResultView(round: round, data: data, me: me,
                                    balance: store.wallet.sparks,
                                    onRematch: rematch,
                                    onDone: { dismiss() })
            }
        }
        .background(Theme.paper.ignoresSafeArea())
        .onAppear {
            // Opening a match we've already played goes straight to the result.
            if case .intro = stage, round.data.hasPlayed(me) { stage = .result(round.data) }
        }
        .task { await runClock() }
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
            awarded = true
        }
        stage = .sending(session)
        Task {
            do {
                stage = .result(try await gameCenter.submit(session, in: round))
            } catch {
                stage = .failed(session, error.localizedDescription)
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

    /// Same clock as solo rounds: real elapsed time, paused in the background.
    private func runClock() async {
        let clock = ContinuousClock()
        var last = clock.now
        while !Task.isCancelled {
            try? await Task.sleep(for: .milliseconds(100))
            let now = clock.now
            let elapsed = now - last
            last = now
            guard scenePhase == .active else { continue }
            let seconds = Double(elapsed.components.seconds) + Double(elapsed.components.attoseconds) / 1e18
            update { $0.tick(by: seconds) }
        }
    }
}

// MARK: Intro

private struct ChallengeIntroView: View {
    let round: ChallengeRound
    let me: String
    let onStart: () -> Void
    let onLater: () -> Void

    var body: some View {
        ScrollView {
            VStack(spacing: 22) {
                VStack(spacing: 10) {
                    SectionLabel("Challenge")
                    HStack(spacing: 14) {
                        PlayerBadge(name: "You", size: 64)
                        Text("vs").font(Theme.display(.title2)).foregroundStyle(Theme.muted)
                        PlayerBadge(name: round.opponentName, size: 64)
                    }
                    .accessibilityHidden(true)
                    Text("You vs \(round.opponentName)")
                        .font(Theme.display(.title))
                        .foregroundStyle(Theme.ink)
                        .multilineTextAlignment(.center)
                        .accessibilityAddTraits(.isHeader)
                }

                if let target = round.data.scoreToBeat(for: me) {
                    VStack(spacing: 4) {
                        Text("Score to beat").font(.subheadline.weight(.semibold))
                        Text(target, format: .number).font(Theme.display(.largeTitle))
                    }
                    .foregroundStyle(Theme.onSpark)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 18)
                    .card(fill: Theme.spark, drop: 5)
                    .accessibilityElement(children: .combine)
                }

                VStack(alignment: .leading, spacing: 14) {
                    rule("list.number", "\(round.data.questions.count) questions, the same ones \(round.opponentName) gets")
                    rule("timer", "\(Int(GameRules.questionTime)) seconds each. Answer fast for bonus points")
                    rule("bolt.fill", "Up to \(round.data.powerUpLimit) power-ups from your own stock")
                    rule("trophy", "Highest score wins. Ties go to more correct answers")
                }
                .font(.body)
                .foregroundStyle(Theme.ink)
                .padding(20)
                .frame(maxWidth: .infinity, alignment: .leading)
                .card()
            }
            .padding(.horizontal, 20)
            .padding(.top, 40)
            .padding(.bottom, 16)
            .frame(maxWidth: 640)
            .frame(maxWidth: .infinity)
        }
        .scrollBounceBehavior(.basedOnSize)
        .safeAreaInset(edge: .bottom) {
            VStack(spacing: 12) {
                Button(action: onStart) {
                    Text("Start round").font(.title3.bold()).frame(maxWidth: .infinity, minHeight: 56)
                }
                .buttonStyle(.chunky(fill: Theme.accent, foreground: .white, capsule: true))
                Button(action: onLater) {
                    Text("Not now").font(.headline).frame(maxWidth: .infinity, minHeight: 52)
                }
                .buttonStyle(.chunky(fill: Theme.card, capsule: true))
            }
            .padding(.horizontal, 20)
            .padding(.vertical, 12)
            .frame(maxWidth: 640)
            .frame(maxWidth: .infinity)
            .background(Theme.paper)
        }
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
    private var theirs: ChallengeTurn? { round.opponentID.flatMap(data.turn(for:)) }
    private var outcome: ChallengeOutcome? { data.outcome(for: me, among: round.playerIDs) }

    private var headline: String {
        switch outcome {
        case .won: "You won!"
        case .lost: "\(round.opponentName) won"
        case .tied: "It's a tie"
        case nil: "Sent to \(round.opponentName)"
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
                        Text("We'll let you know when they've played.")
                            .font(.callout)
                            .foregroundStyle(Theme.muted)
                    }
                }

                VStack(spacing: 14) {
                    scoreRow(name: "You", turn: mine, highlight: outcome == .won)
                    Rectangle().fill(Theme.line).frame(height: 2)
                    scoreRow(name: round.opponentName, turn: theirs, highlight: outcome == .lost)
                }
                .padding(20)
                .card()

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
                    .padding(.horizontal, 20)
                    .padding(.vertical, 16)
                    .card(fill: Theme.spark, drop: 5)
                    .accessibilityElement(children: .combine)
                }
            }
            .padding(.horizontal, 20)
            .padding(.top, 40)
            .padding(.bottom, 16)
            .frame(maxWidth: 640)
            .frame(maxWidth: .infinity)
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
            .padding(.horizontal, 20)
            .padding(.vertical, 12)
            .frame(maxWidth: 640)
            .frame(maxWidth: .infinity)
            .background(Theme.paper)
        }
    }

    private func scoreRow(name: String, turn: ChallengeTurn?, highlight: Bool) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 12) {
                PlayerBadge(name: name, size: 40)
                VStack(alignment: .leading, spacing: 2) {
                    HStack(spacing: 6) {
                        Text(name).font(.headline)
                        if highlight {
                            Image(systemName: "crown.fill").foregroundStyle(Theme.spark)
                                .accessibilityLabel("Winner")
                        }
                    }
                    Text(turn.map { "\($0.correctCount) of \($0.answers.count) correct · best streak \($0.bestStreak)" }
                         ?? "Hasn't played yet")
                        .font(.footnote)
                        .foregroundStyle(Theme.muted)
                }
                Spacer(minLength: 8)
                Text(turn.map { $0.points.formatted() } ?? "–")
                    .font(Theme.display(.title2))
            }
            if let turn { AnswerStrip(answers: turn.answers) }
        }
        .foregroundStyle(Theme.ink)
        .accessibilityElement(children: .combine)
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
