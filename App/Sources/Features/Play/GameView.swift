import SwiftUI
import TriviaKit

/// One round from first question to summary. Owns the session and drives
/// its clock; the child views only read it and send actions.
struct GameView: View {
    let request: RoundRequest
    let relaxed: Bool

    @Environment(PlayerStore.self) private var store
    @Environment(\.dismiss) private var dismiss
    @Environment(\.scenePhase) private var scenePhase
    @State private var current: RoundRequest
    @State private var session: GameSession?
    @State private var rewards: RoundRewards?
    @State private var alreadyPlayed = false

    init(request: RoundRequest, relaxed: Bool) {
        self.request = request
        self.relaxed = relaxed
        _current = State(initialValue: request)
    }

    var body: some View {
        Group {
            if let session {
                if session.phase == .finished {
                    summary(session)
                } else {
                    quiz(session)
                }
            } else if alreadyPlayed {
                ContentUnavailableView {
                    Label("Already played today", systemImage: "calendar.badge.checkmark")
                } description: {
                    Text("The Daily is one try a day. A new one starts at midnight.")
                } actions: {
                    Button("Home") { dismiss() }
                        .buttonStyle(.chunky(fill: Theme.card, capsule: true))
                }
            }
        }
        .background(Theme.paper.ignoresSafeArea())
        .onAppear { if session == nil { start() } }
        .onChange(of: session?.phase == .finished) { _, finished in
            if finished, let session { rewards = store.finish(session, for: current) }
        }
        .task { await runClock() }
    }

    private func summary(_ session: GameSession) -> SummaryView {
        let again: (() -> Void)? = current.isDaily ? nil : { playAgain() }
        return SummaryView(session: session,
                           balance: store.wallet.sparks,
                           rewards: rewards,
                           onPlayAgain: again,
                           onHome: { dismiss() })
    }

    private func quiz(_ session: GameSession) -> QuizView {
        let store = store
        let report: (Question, QuestionReport.Reason) -> Void = { q, reason in store.report(q, reason: reason) }
        return QuizView(session: session,
                        stock: { store.wallet.count(of: $0) },
                        onAnswer: { self.session?.answer($0) },
                        onPowerUp: { usePowerUp($0) },
                        onNext: { self.session?.advance() },
                        onQuit: { quit() },
                        onReport: report,
                        quitMessage: quitMessage)
    }

    private var quitMessage: String {
        current.isDaily
            ? "This is your only try at today's Daily. Leaving now keeps the score you have, and the day won't count toward your streak."
            : "You won't earn Sparks for this round. Power-ups you used are spent."
    }

    private func start() {
        rewards = nil
        session = store.newSession(for: current, relaxed: relaxed)
        alreadyPlayed = session == nil
        #if DEBUG
        // Screenshot helper: launch with `-autoplaySummary` to jump straight
        // to the results screen (answers alternate right and wrong).
        if ProcessInfo.processInfo.arguments.contains("-autoplaySummary"), var s = session {
            var i = 0
            while let q = s.currentQuestion {
                s.answer(i % 3 == 2 ? (q.correctIndex + 1) % q.choices.count : q.correctIndex)
                s.advance()
                i += 1
            }
            session = s
        }
        #endif
    }

    private func playAgain() {
        current = RoundRequest(kind: current.kind)
        start()
    }

    private func quit() {
        // Correct answers still count toward mastery, and the Daily keeps
        // the attempt.
        if let session, !session.results.isEmpty || current.isDaily {
            store.finish(session, for: current, finished: false)
        }
        dismiss()
    }

    private func usePowerUp(_ powerUp: PowerUp) {
        guard var s = session else { return }
        if store.use(powerUp, in: &s) { session = s }
    }

    /// Ticks the round clock about ten times a second using real elapsed
    /// time, and pauses while the app isn't active so nobody loses a
    /// question to a phone call.
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
            session?.tick(by: seconds)
        }
    }
}

#Preview {
    GameView(request: .classic(category: nil), relaxed: false)
        .environment(PlayerStore.preview)
}
