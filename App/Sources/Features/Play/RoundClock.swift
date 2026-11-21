import Foundation

/// Drives a round's clock about ten times a second from real elapsed time.
/// Time that passes while `isActive` is false (app in the background) is
/// skipped, so nobody loses a question to a phone call. Runs until the
/// calling task is cancelled; solo rounds and friend challenges share it.
@MainActor
func runRoundClock(isActive: () -> Bool, tick: (TimeInterval) -> Void) async {
    let clock = ContinuousClock()
    var last = clock.now
    while !Task.isCancelled {
        try? await Task.sleep(for: .milliseconds(100))
        let now = clock.now
        let elapsed = now - last
        last = now
        if isActive() { tick(elapsed / .seconds(1)) }
    }
}
