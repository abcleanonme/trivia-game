import StoreKit
import SwiftUI
import TriviaKit

/// Asks for an App Store rating after a good moment, using the throttling in
/// `ReviewPrompt`. Apple decides whether its prompt actually shows.
extension View {
    /// Call on a results screen. `moment` is nil when there's nothing to count
    /// (for example a challenge still waiting on the other player).
    func ratingPrompt(after moment: ReviewPrompt.Moment?) -> some View {
        modifier(RatingPromptModifier(moment: moment))
    }
}

private struct RatingPromptModifier: ViewModifier {
    let moment: ReviewPrompt.Moment?
    @Environment(\.requestReview) private var requestReview
    @State private var checked = false

    func body(content: Content) -> some View {
        content.task {
            guard !checked, let moment else { return }
            checked = true
            guard RatingPromptState.shouldAsk(after: moment) else { return }
            // Let the score count up and the confetti land first.
            try? await Task.sleep(for: .seconds(2.5))
            guard !Task.isCancelled else { return }
            requestReview()
        }
    }
}

enum RatingPromptState {
    private static let key = "reviewPrompt"

    @MainActor
    static func shouldAsk(after moment: ReviewPrompt.Moment, defaults: UserDefaults = .standard) -> Bool {
        var state = defaults.decoded(ReviewPrompt.self, forKey: key) ?? ReviewPrompt()
        let version = Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "0"
        let ask = state.shouldAsk(after: moment, on: .today(), version: version)
        defaults.setEncoded(state, forKey: key)
        return ask
    }
}
