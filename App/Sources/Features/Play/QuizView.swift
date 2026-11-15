import SwiftUI
import TriviaKit

/// The question screen: progress, clock, question, answers, and either the
/// power-up tray (while asking) or the feedback bar (once answered).
///
/// iPhone Duo: answers lay out from size class and Dynamic Type, never device
/// type, so the same view works on the outer and inner displays and in Split
/// View. The bottom bar sits in the safe-area inset so it never lands under
/// the fold or the inner camera.
struct QuizView: View {
    let session: GameSession
    let stock: (PowerUp) -> Int
    let onAnswer: (Int) -> Void
    let onPowerUp: (PowerUp) -> Void
    let onNext: () -> Void
    let onQuit: () -> Void
    var onReport: (Question, QuestionReport.Reason) -> Void = { _, _ in }
    var quitMessage = "You won't earn Sparks for this round. Power-ups you used are spent."

    @Environment(\.horizontalSizeClass) private var hSize
    @Environment(\.dynamicTypeSize) private var typeSize
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @AppStorage("hapticsEnabled") private var hapticsEnabled = true
    @State private var confirmingQuit = false
    @State private var reporting: Question?
    @State private var reported: Set<UUID> = []

    private var columns: [GridItem] {
        let count = hSize == .regular && !typeSize.isAccessibilitySize ? 2 : 1
        return Array(repeating: GridItem(.flexible(), spacing: 12), count: count)
    }

    private var lastResult: QuestionResult? {
        if case .answered(let r) = session.phase { r } else { nil }
    }

    var body: some View {
        if let question = session.currentQuestion {
            ScrollViewReader { proxy in
                ScrollView {
                    VStack(alignment: .leading, spacing: 12) {
                        topBar
                        rowLayout {
                            HStack(spacing: 8) {
                                CategoryChip(name: question.category)
                                reportButton(question)
                            }
                            if !typeSize.isAccessibilitySize { Spacer() }
                            ClockView(session: session)
                        }
                        Text(question.prompt)
                            .font(Theme.display(.title2))
                            .foregroundStyle(Theme.ink)
                            .fixedSize(horizontal: false, vertical: true)
                            // Room for two lines, so answers don't jump
                            // between short and long questions.
                            .frame(maxWidth: .infinity, minHeight: 64, alignment: .topLeading)
                            .padding(.vertical, 4)
                            .accessibilityAddTraits(.isHeader)
                            .staggeredAppear(0, distance: 10)
                            .id(question.id)
                        LazyVGrid(columns: columns, spacing: 10) {
                            ForEach(question.choices.indices, id: \.self) { i in
                                AnswerButton(letter: Self.letters[i],
                                             title: question.choices[i],
                                             style: style(for: i, in: question)) {
                                    onAnswer(i)
                                }
                                // Answers deal in one after another.
                                .staggeredAppear(i + 1)
                            }
                        }
                        // Fresh views per question, so old answers never crossfade
                        // into the new ones.
                        .id(question.id)
                        // At accessibility text sizes the bar is too tall to pin
                        // over the question, so it scrolls with the content.
                        if inlineBottomBar {
                            bottomBar.id(Self.bottomBarID)
                        }
                    }
                    .padding(.horizontal, Theme.gutter)
                    .padding(.top, 8)
                    .padding(.bottom, 16)
                    .frame(maxWidth: 760)
                    .frame(maxWidth: .infinity)
                }
                .scrollBounceBehavior(.basedOnSize)
                .onChange(of: lastResult == nil) { _, waiting in
                    if inlineBottomBar {
                        withAnimation {
                            if waiting {
                                proxy.scrollTo(question.id, anchor: .top)
                            } else {
                                proxy.scrollTo(Self.bottomBarID, anchor: .bottom)
                            }
                        }
                    }
                }
            }
            .safeAreaInset(edge: .bottom) {
                if !inlineBottomBar {
                    bottomBar
                        .padding(.horizontal, Theme.gutter)
                        .padding(.top, 8)
                        .padding(.bottom, 10)
                        .frame(maxWidth: 760)
                        .frame(maxWidth: .infinity)
                        .background(Theme.paper)
                }
            }
            .animation(Motion.choose(Motion.settle, reduce: reduceMotion), value: lastResult == nil)
            .overlay {
                ConfettiBurst(trigger: session.results.count,
                              active: session.results.last?.correct == true,
                              intensity: (session.results.last?.streak ?? 0) >= 3 ? 1 : 0.5)
                    .ignoresSafeArea()
            }
            .sensoryFeedback(trigger: session.results.count) { old, new in
                guard hapticsEnabled, new > old, let r = session.results.last else { return nil }
                return r.correct ? .success : .error
            }
            .confirmationDialog("Quit this round?", isPresented: $confirmingQuit, titleVisibility: .visible) {
                Button("Quit round", role: .destructive, action: onQuit)
                Button("Keep playing", role: .cancel) {}
            } message: {
                Text(quitMessage)
            }
            .confirmationDialog("Report this question?", isPresented: reportingBinding, titleVisibility: .visible,
                                presenting: reporting) { q in
                ForEach(QuestionReport.Reason.allCases, id: \.self) { reason in
                    Button(reason.label) {
                        onReport(q, reason)
                        reported.insert(q.id)
                    }
                }
                Button("Cancel", role: .cancel) {}
            } message: { _ in
                Text("Reports go to the people who review questions. Thanks for keeping the bank honest.")
            }
        }
    }

    private static let bottomBarID = "bottomBar"

    private var reportingBinding: Binding<Bool> {
        Binding(get: { reporting != nil }, set: { if !$0 { reporting = nil } })
    }

    private func reportButton(_ question: Question) -> some View {
        let done = reported.contains(question.id)
        return Button { reporting = question } label: {
            Image(systemName: done ? "flag.fill" : "flag")
                .font(.footnote.weight(.bold))
                .dynamicTypeSize(...DynamicTypeSize.xxxLarge)
                .foregroundStyle(Theme.muted)
                .frame(width: 44, height: 44)
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .disabled(done)
        .accessibilityLabel(done ? "Question reported" : "Report question")
    }

    /// "Question 3 of 10", or the mode's own progress.
    private var progressText: String {
        switch session.mode {
        case .classic: "Question \(session.index + 1) of \(session.questions.count)"
        case .survival: "Question \(session.index + 1)"
        case .speed: "\(session.correctCount) right"
        }
    }

    @ViewBuilder private var modeProgress: some View {
        switch session.mode {
        case .classic:
            ProgressBar(value: Double(session.index + (lastResult == nil ? 0 : 1)),
                        total: Double(session.questions.count))
        case .survival:
            StrikesView(left: session.strikesLeft ?? 0)
        case .speed:
            ProgressBar(value: session.roundTimeRemaining ?? 0,
                        total: max(GameMode.speedRoundSeconds, session.roundTimeRemaining ?? 0))
        }
    }

    private var inlineBottomBar: Bool { typeSize.isAccessibilitySize }

    /// Side by side normally; stacked when large text would squash it.
    private var rowLayout: AnyLayout {
        typeSize.isAccessibilitySize
            ? AnyLayout(VStackLayout(alignment: .leading, spacing: 8))
            : AnyLayout(HStackLayout())
    }

    @ViewBuilder private var bottomBar: some View {
        if let lastResult {
            FeedbackBar(result: lastResult,
                        isLast: session.isLastQuestion,
                        secondChance: secondChanceOffer,
                        onSecondChance: { onPowerUp(.secondChance) },
                        onNext: onNext)
                .transition(.motion(.bottom, reduce: reduceMotion))
        } else {
            PowerUpTray(session: session, stock: stock, onUse: onPowerUp)
                .transition(.opacity)
        }
    }

    private static let letters = ["A", "B", "C", "D", "E", "F"]

    /// How many Second chances the player has, if one can be used right now.
    private var secondChanceOffer: Int? {
        let count = stock(.secondChance)
        return count > 0 && session.canUse(.secondChance) ? count : nil
    }

    private var topBar: some View {
        HStack(spacing: 12) {
            Button { confirmingQuit = true } label: {
                Image(systemName: "xmark")
                    .font(.body.weight(.bold))
                    // The 44pt circle is fixed, so keep the glyph inside it.
                    .dynamicTypeSize(...DynamicTypeSize.xxxLarge)
                    .frame(width: 44, height: 44)
            }
            .buttonStyle(.chunky(fill: Theme.card, capsule: true))
            .accessibilityLabel("Quit round")

            VStack(spacing: 6) {
                rowLayout {
                    Text(progressText)
                    if !typeSize.isAccessibilitySize { Spacer() }
                    InRoundStreak(streak: session.streak)
                }
                .font(.footnote.weight(.semibold))
                .foregroundStyle(Theme.muted)
                modeProgress
            }
            .accessibilityElement(children: .combine)
        }
    }

    private func style(for i: Int, in q: Question) -> AnswerButton.Style {
        if let r = lastResult {
            if q.isCorrect(i) { return .correct }
            if i == r.choice { return .wrong }
            return .dimmed
        }
        return session.eliminated.contains(i) ? .eliminated : .idle
    }
}

// MARK: - Pieces

private struct CategoryChip: View {
    let name: String

    var body: some View {
        Text(name)
            .font(.footnote.bold())
            .textCase(.uppercase)
            .kerning(1)
            .foregroundStyle(Theme.ink)
            .padding(.horizontal, 12)
            .padding(.vertical, 6)
            .background(Theme.pill.fill(Theme.card))
            .overlay(Theme.pill.stroke(Theme.ink, lineWidth: Theme.border))
            .accessibilityLabel("Category: \(name)")
    }
}

/// Survival lives: filled hearts for misses left.
private struct StrikesView: View {
    let left: Int

    var body: some View {
        HStack(spacing: 4) {
            ForEach(0..<GameMode.survivalStrikes, id: \.self) { i in
                Image(systemName: i < left ? "heart.fill" : "heart")
                    .foregroundStyle(i < left ? Theme.wrong : Theme.line)
            }
            Spacer()
        }
        .font(.footnote.weight(.bold))
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("\(left) of \(GameMode.survivalStrikes) lives left")
    }
}

private struct ProgressBar: View {
    let value: Double
    let total: Double

    var body: some View {
        GeometryReader { geo in
            ZStack(alignment: .leading) {
                Capsule().fill(Theme.line)
                Capsule().fill(Theme.accent)
                    .frame(width: total > 0 ? geo.size.width * value / total : 0)
            }
        }
        .frame(height: 10)
        .animation(Motion.settle, value: value)
        .accessibilityHidden(true)
    }
}

/// Seconds left, with a ring that drains. Turns orange in the last 5 seconds.
private struct ClockView: View {
    let session: GameSession

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    /// Bumped when Extra time lands, to float a "+10s" over the clock.
    @State private var bonus = 0

    private var left: Double { session.roundTimeRemaining ?? session.timeRemaining }
    private var full: Double { session.roundTimeRemaining == nil ? GameRules.questionTime : GameMode.speedRoundSeconds }
    private var seconds: Int { Int(left.rounded(.up)) }
    private var urgent: Bool {
        session.isTimed && session.phase == .asking && left <= (session.mode == .speed ? 10 : 5)
    }

    var body: some View {
        if session.isTimed {
            HStack(spacing: 8) {
                ZStack {
                    Circle().stroke(Theme.line, lineWidth: 4)
                    Circle()
                        .trim(from: 0, to: min(left / full, 1))
                        .stroke(urgent ? Theme.wrong : Theme.accent, style: StrokeStyle(lineWidth: 4, lineCap: .round))
                        .rotationEffect(.degrees(-90))
                }
                .frame(width: 24, height: 24)
                Text("\(seconds)s")
                    .font(Theme.display(.title2).monospacedDigit())
                    .foregroundStyle(urgent ? Theme.wrong : Theme.ink)
                    .contentTransition(.numericText(countsDown: true))
                    // Each of the last five seconds thumps.
                    .keyframeAnimator(initialValue: 1.0, trigger: seconds) { view, scale in
                        view.scaleEffect(scale)
                    } keyframes: { _ in
                        if urgent && !reduceMotion {
                            SpringKeyframe(1.25, duration: 0.1, spring: .snappy)
                            SpringKeyframe(1, duration: 0.3, spring: .bouncy)
                        } else {
                            LinearKeyframe(1, duration: 0.01)
                        }
                    }
                    .overlay(alignment: .top) {
                        if bonus > 0 {
                            FloatingCallout(text: "+\(Int(GameRules.extraTimeSeconds))s", color: Theme.accent)
                                .offset(y: -18)
                                .id(bonus)
                        }
                    }
            }
            .animation(Motion.fade, value: urgent)
            .animation(Motion.settle, value: session.timeRemaining > GameRules.questionTime)
            .onChange(of: session.powerUpThisQuestion) { _, new in
                if new == .extraTime { bonus += 1 }
            }
            .accessibilityElement(children: .ignore)
            .accessibilityLabel("\(seconds) seconds left")
        } else {
            Label("Relaxed", systemImage: "leaf")
                .font(.footnote.weight(.semibold))
                .foregroundStyle(Theme.muted)
        }
    }
}

private struct AnswerButton: View {
    enum Style { case idle, eliminated, correct, wrong, dimmed }

    let letter: String
    let title: String
    let style: Style
    let action: () -> Void

    /// Grows with Dynamic Type so the letter always fits its badge.
    @ScaledMetric(relativeTo: .headline) private var badgeSize: CGFloat = 34
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    /// Drives the pop (correct) or shake (your wrong pick).
    private var outcome: Bool? {
        switch style {
        case .correct: true
        case .wrong: false
        default: nil
        }
    }

    var body: some View {
        Button(action: action) {
            HStack(spacing: 12) {
                Text(letter)
                    .font(.headline)
                    // The letter is a label, not content: cap it so long
                    // answers keep the width at accessibility sizes.
                    .dynamicTypeSize(...DynamicTypeSize.accessibility1)
                    .frame(width: min(badgeSize, 56), height: min(badgeSize, 56))
                    .background(RoundedRectangle(cornerRadius: 12, style: .continuous).fill(badgeFill))
                    .foregroundStyle(badgeText)
                Text(style == .eliminated ? "Removed" : title)
                    .font(.title3.weight(.semibold))
                    .strikethrough(style == .eliminated)
                    .multilineTextAlignment(.leading)
                    .frame(maxWidth: .infinity, alignment: .leading)
                if let icon {
                    Image(systemName: icon).font(.title3.bold())
                        .drawOnTransition()
                }
            }
            .padding(.leading, 9)
            .padding(.trailing, 14)
            .padding(.vertical, 8)
            .frame(minHeight: 52)
        }
        .buttonStyle(ChunkyButtonStyle(fill: fill, foreground: foreground,
                                       depth: 4,
                                       outlined: style == .correct || style == .wrong))
        .disabled(style != .idle)
        .scaleEffect(style == .eliminated && !reduceMotion ? 0.97 : 1)
        .animation(Motion.choose(Motion.pop, reduce: reduceMotion), value: style)
        .revealEffect(outcome)
        .accessibilityLabel(accessibilityText)
    }

    private var fill: Color {
        switch style {
        case .idle: Theme.card
        case .eliminated, .dimmed: Theme.disabled
        case .correct: Theme.correct
        case .wrong: Theme.wrong
        }
    }

    private var foreground: Color {
        switch style {
        case .idle: Theme.ink
        case .eliminated, .dimmed: Theme.muted
        case .correct, .wrong: .white
        }
    }

    private var badgeFill: Color {
        switch style {
        case .correct, .wrong: .white
        default: Theme.paper
        }
    }

    private var badgeText: Color {
        switch style {
        case .correct: Theme.correct
        case .wrong: Theme.wrong
        case .idle: Theme.ink
        default: Theme.muted
        }
    }

    private var icon: String? {
        switch style {
        case .correct: "checkmark.circle.fill"
        case .wrong: "xmark.circle.fill"
        default: nil
        }
    }

    private var accessibilityText: String {
        switch style {
        case .idle, .dimmed: "\(letter), \(title)"
        case .eliminated: "\(letter), removed"
        case .correct: "\(letter), \(title), correct answer"
        case .wrong: "\(letter), \(title), your answer, wrong"
        }
    }
}

/// "Streak N" with a flame that hops each time the streak grows and keeps
/// flickering while it's hot (3+).
private struct InRoundStreak: View {
    let streak: Int

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var hops = 0

    private var hot: Bool { streak >= 3 }

    var body: some View {
        Label {
            Text("Streak \(streak)")
                .contentTransition(.numericText(value: Double(streak)))
        } icon: {
            Image(systemName: "flame.fill")
                .symbolEffect(.bounce.up, options: .nonRepeating, value: hops)
                .symbolEffect(.breathe, options: .repeating, isActive: hot && !reduceMotion)
        }
        .labelStyle(.titleAndIcon)
        .foregroundStyle(hot ? Theme.wrong : Theme.muted)
        .animation(Motion.choose(Motion.pop, reduce: reduceMotion), value: streak)
        .onChange(of: streak) { old, new in
            if new > old { hops += 1 }
        }
    }
}

private struct PowerUpTray: View {
    let session: GameSession
    let stock: (PowerUp) -> Int
    let onUse: (PowerUp) -> Void

    @Environment(\.dynamicTypeSize) private var typeSize

    private var columns: [GridItem] {
        Array(repeating: GridItem(.flexible(), spacing: 8), count: typeSize.isAccessibilitySize ? 2 : 4)
    }

    private var limitLeft: Int { session.powerUpLimit - session.powerUpsUsed }

    var body: some View {
        VStack(spacing: 6) {
            (typeSize.isAccessibilitySize
                ? AnyLayout(VStackLayout(alignment: .leading, spacing: 4))
                : AnyLayout(HStackLayout())) {
                SectionLabel("Power-ups")
                if !typeSize.isAccessibilitySize { Spacer() }
                Text("1 per question · \(limitLeft) left")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(Theme.muted)
            }
            LazyVGrid(columns: columns, spacing: 8) {
                ForEach(PowerUp.trayOrder) { p in
                    let count = stock(p)
                    let active = session.powerUpThisQuestion == p
                    Button { onUse(p) } label: {
                        VStack(spacing: 1) {
                            HStack(spacing: 4) {
                                Image(systemName: p.systemImage).font(.footnote.bold())
                                    .symbolEffect(.bounce, options: .nonRepeating, value: active)
                                Text(p.shortTitle).font(.subheadline.bold())
                            }
                            .lineLimit(1)
                            .minimumScaleFactor(0.7)
                            Text(active ? "Active" : "\(count) left")
                                .font(.caption2.weight(.semibold))
                                .opacity(count == 0 && !active ? 0.7 : 1)
                        }
                        .padding(.horizontal, 4)
                        .frame(maxWidth: .infinity, minHeight: 50)
                    }
                    .buttonStyle(ChunkyButtonStyle(fill: active ? Theme.spark : Theme.card,
                                                   foreground: active ? Theme.onSpark : Theme.ink))
                    .animation(Motion.pop, value: active)
                    .disabled(active || count == 0 || !session.canUse(p))
                    .accessibilityLabel("\(p.title), \(count) left")
                    .accessibilityHint(p.summary)
                }
            }
        }
    }
}

private struct FeedbackBar: View {
    let result: QuestionResult
    let isLast: Bool
    /// Number of Second chances available, if one can be used now.
    let secondChance: Int?
    let onSecondChance: () -> Void
    let onNext: () -> Void

    @Environment(\.dynamicTypeSize) private var typeSize
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var landed = false

    /// Streaks of 3 and up get a callout chip.
    private var hotStreak: Bool { result.correct && result.streak >= 3 }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            if hotStreak {
                Label("\(result.streak) in a row!", systemImage: "flame.fill")
                    .font(.subheadline.bold())
                    .foregroundStyle(Theme.onSpark)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 5)
                    .background(Theme.pill.fill(Theme.spark))
                    .overlay(Theme.pill.stroke(Theme.ink, lineWidth: Theme.border))
                    .scaleEffect(landed || reduceMotion ? 1 : 0.4, anchor: .leading)
                    .opacity(landed ? 1 : 0)
                    .symbolEffect(.bounce.up, options: .nonRepeating, value: landed)
            }
            if typeSize.isAccessibilitySize {
                // Too big to sit side by side: stack, full-width Next.
                Text(title).font(Theme.display(.title2))
                Text(detail).font(.subheadline)
                nextButton(fullWidth: true)
            } else {
                HStack(alignment: .center, spacing: 12) {
                    Image(systemName: icon)
                        .font(.title.bold())
                        .symbolEffect(.bounce, options: .nonRepeating, value: landed)
                        .accessibilityHidden(true)
                    VStack(alignment: .leading, spacing: 2) {
                        Text(title).font(Theme.display(.title2))
                        Text(detail).font(.subheadline)
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    nextButton(fullWidth: false)
                }
            }
            if let secondChance {
                Button(action: onSecondChance) {
                    Label("Second chance · half points (\(secondChance) left)", systemImage: PowerUp.secondChance.systemImage)
                        .font(.subheadline.bold())
                        .frame(maxWidth: .infinity, minHeight: 44)
                }
                .buttonStyle(.chunky(fill: Theme.spark, foreground: Theme.onSpark, capsule: true))
            }
        }
        .foregroundStyle(.white)
        .padding(Theme.cardPadding)
        .card(fill: result.correct ? Theme.correct : Theme.wrong, radius: Theme.cardRadius)
        .accessibilityElement(children: .contain)
        .onAppear {
            withAnimation(Motion.choose(Motion.pop, reduce: reduceMotion).delay(0.12)) { landed = true }
        }
    }

    private var icon: String {
        result.correct ? "checkmark.circle.fill" : (result.timedOut ? "clock.badge.xmark" : "xmark.circle.fill")
    }

    private func nextButton(fullWidth: Bool) -> some View {
        Button(action: onNext) {
            Text(isLast ? "Results" : "Next")
                .font(.headline)
                .padding(.horizontal, Theme.gutter)
                .frame(maxWidth: fullWidth ? .infinity : nil, minHeight: 44)
        }
        .buttonStyle(.chunky(fill: Theme.card, capsule: true))
    }

    private var title: String {
        if result.correct { return "Correct! +\(result.points)" }
        return result.timedOut ? "Time's up" : "Not quite"
    }

    private var detail: String {
        guard result.correct else {
            return "Answer: \(result.question.correctAnswer). Streak reset."
        }
        let b = result.breakdown
        var parts = ["\(b.base) base"]
        if b.speed > 0 { parts.append("\(b.speed) speed") }
        if b.streakBonus > 0 { parts.append("\(b.streakBonus) streak") }
        switch result.powerUp {
        case .doubleDown: parts.append("doubled")
        case .secondChance: parts.append("halved")
        default: break
        }
        var text = parts.joined(separator: " + ")
        if result.streak >= 2 { text += ". Streak \(result.streak)." }
        return text
    }
}

#Preview {
    QuizView(session: GameSession(questions: Question.samples, reserve: [Question.samples[0]]),
             stock: { _ in 2 }, onAnswer: { _ in }, onPowerUp: { _ in }, onNext: {}, onQuit: {})
        .background(Theme.paper)
}
