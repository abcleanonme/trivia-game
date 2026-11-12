import SwiftUI
import TriviaKit

/// One classic round from first question to summary. Owns the session and
/// drives its clock; the child views only read it and send actions.
struct GameView: View {
    let category: String?
    let relaxed: Bool

    @Environment(PlayerStore.self) private var store
    @Environment(\.dismiss) private var dismiss
    @Environment(\.scenePhase) private var scenePhase
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var session: GameSession?
    /// Bumped on Play again so the quiz screen arrives fresh.
    @State private var round = 0

    var body: some View {
        Group {
            if let session {
                if session.phase == .finished {
                    SummaryView(session: session,
                                balance: store.wallet.sparks,
                                onPlayAgain: start,
                                onHome: { dismiss() })
                        .transition(.pop(reduce: reduceMotion))
                } else {
                    QuizView(session: session,
                             stock: { store.wallet.count(of: $0) },
                             onAnswer: { self.session?.answer($0) },
                             onPowerUp: usePowerUp,
                             onNext: { self.session?.advance() },
                             onQuit: { dismiss() })
                        .id(round)
                        .transition(.motion(.trailing, reduce: reduceMotion))
                }
            }
        }
        .animation(Motion.choose(Motion.settle, reduce: reduceMotion), value: session?.phase == .finished)
        .animation(Motion.choose(Motion.settle, reduce: reduceMotion), value: round)
        .background(Theme.paper.ignoresSafeArea())
        .onAppear { if session == nil { start() } }
        .onChange(of: session?.phase == .finished) { _, finished in
            if finished, let session { store.award(sparks: session.sparksEarned) }
        }
        .task { await runClock() }
    }

    private func start() {
        session = store.newSession(category: category, relaxed: relaxed)
        round += 1
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
    GameView(category: nil, relaxed: false)
        .environment(PlayerStore.preview)
}
