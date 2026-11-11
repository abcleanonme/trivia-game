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

    @Environment(\.horizontalSizeClass) private var hSize
    @Environment(\.dynamicTypeSize) private var typeSize
    @AppStorage("hapticsEnabled") private var hapticsEnabled = true
    @State private var confirmingQuit = false

    private var columns: [GridItem] {
        let count = hSize == .regular && !typeSize.isAccessibilitySize ? 2 : 1
        return Array(repeating: GridItem(.flexible(), spacing: 12), count: count)
    }

    private var lastResult: QuestionResult? {
        if case .answered(let r) = session.phase { r } else { nil }
    }

    var body: some View {
        if let question = session.currentQuestion {
            ScrollView {
                VStack(alignment: .leading, spacing: 18) {
                    topBar
                    HStack {
                        CategoryChip(name: question.category)
                        Spacer()
                        ClockView(session: session)
                    }
                    Text(question.prompt)
                        .font(Theme.display(.title))
                        .foregroundStyle(Theme.ink)
                        .fixedSize(horizontal: false, vertical: true)
                        .frame(maxWidth: .infinity, minHeight: 110, alignment: .topLeading)
                        .accessibilityAddTraits(.isHeader)
                        .id(question.id)
                    LazyVGrid(columns: columns, spacing: 12) {
                        ForEach(question.choices.indices, id: \.self) { i in
                            AnswerButton(letter: Self.letters[i],
                                         title: question.choices[i],
                                         style: style(for: i, in: question)) {
                                onAnswer(i)
                            }
                        }
                    }
                    // Fresh views per question, so old answers never crossfade
                    // into the new ones.
                    .id(question.id)
                }
                .padding(.horizontal, 20)
                .padding(.top, 8)
                .padding(.bottom, 16)
                .frame(maxWidth: 900)
                .frame(maxWidth: .infinity)
            }
            .scrollBounceBehavior(.basedOnSize)
            .safeAreaInset(edge: .bottom) {
                Group {
                    if let lastResult {
                        FeedbackBar(result: lastResult,
                                    isLast: session.isLastQuestion,
                                    secondChance: secondChanceOffer,
                                    onSecondChance: { onPowerUp(.secondChance) },
                                    onNext: onNext)
                    } else {
                        PowerUpTray(session: session, stock: stock, onUse: onPowerUp)
                    }
                }
                .padding(.horizontal, 20)
                .padding(.vertical, 12)
                .frame(maxWidth: 900)
                .frame(maxWidth: .infinity)
                .background(Theme.paper)
            }
            .sensoryFeedback(trigger: session.results.count) { old, new in
                guard hapticsEnabled, new > old, let r = session.results.last else { return nil }
                return r.correct ? .success : .error
            }
            .confirmationDialog("Quit this round?", isPresented: $confirmingQuit, titleVisibility: .visible) {
                Button("Quit round", role: .destructive, action: onQuit)
                Button("Keep playing", role: .cancel) {}
            } message: {
                Text("You won't earn Sparks for this round. Power-ups you used are spent.")
            }
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
                    .frame(width: 44, height: 44)
            }
            .buttonStyle(.chunky(fill: Theme.card, capsule: true))
            .accessibilityLabel("Quit round")

            VStack(spacing: 6) {
                HStack {
                    Text("Question \(session.index + 1) of \(session.questions.count)")
                    Spacer()
                    Label("Streak \(session.streak)", systemImage: "flame.fill")
                        .labelStyle(.titleAndIcon)
                        .foregroundStyle(session.streak >= 3 ? Theme.wrong : Theme.muted)
                }
                .font(.footnote.weight(.semibold))
                .foregroundStyle(Theme.muted)
                ProgressBar(value: Double(session.index + (lastResult == nil ? 0 : 1)),
                            total: Double(session.questions.count))
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
            .background(Capsule().fill(Theme.card))
            .overlay(Capsule().stroke(Theme.ink, lineWidth: Theme.border))
            .accessibilityLabel("Category: \(name)")
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
        .animation(.easeOut(duration: 0.25), value: value)
        .accessibilityHidden(true)
    }
}

/// Seconds left, with a ring that drains. Turns orange in the last 5 seconds.
private struct ClockView: View {
    let session: GameSession

    private var seconds: Int { Int(session.timeRemaining.rounded(.up)) }
    private var urgent: Bool { session.isTimed && session.phase == .asking && session.timeRemaining <= 5 }

    var body: some View {
        if session.isTimed {
            HStack(spacing: 8) {
                ZStack {
                    Circle().stroke(Theme.line, lineWidth: 4)
                    Circle()
                        .trim(from: 0, to: min(session.timeRemaining / GameRules.questionTime, 1))
                        .stroke(urgent ? Theme.wrong : Theme.accent, style: StrokeStyle(lineWidth: 4, lineCap: .round))
                        .rotationEffect(.degrees(-90))
                }
                .frame(width: 24, height: 24)
                Text("\(seconds)s")
                    .font(Theme.display(.title2).monospacedDigit())
                    .foregroundStyle(urgent ? Theme.wrong : Theme.ink)
                    .contentTransition(.numericText(countsDown: true))
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

    var body: some View {
        Button(action: action) {
            HStack(spacing: 14) {
                Text(letter)
                    .font(.headline)
                    .frame(width: 38, height: 38)
                    .background(RoundedRectangle(cornerRadius: 12, style: .continuous).fill(badgeFill))
                    .foregroundStyle(badgeText)
                Text(style == .eliminated ? "Removed" : title)
                    .font(.title3.weight(.semibold))
                    .strikethrough(style == .eliminated)
                    .multilineTextAlignment(.leading)
                    .frame(maxWidth: .infinity, alignment: .leading)
                if let icon {
                    Image(systemName: icon).font(.title3.bold())
                }
            }
            .padding(.leading, 10)
            .padding(.trailing, 16)
            .padding(.vertical, 10)
            .frame(minHeight: 60)
        }
        .buttonStyle(ChunkyButtonStyle(fill: fill, foreground: foreground, depth: style == .idle ? 4 : 0))
        .disabled(style != .idle)
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

private struct PowerUpTray: View {
    let session: GameSession
    let stock: (PowerUp) -> Int
    let onUse: (PowerUp) -> Void

    @Environment(\.dynamicTypeSize) private var typeSize

    private var columns: [GridItem] {
        Array(repeating: GridItem(.flexible(), spacing: 10), count: typeSize.isAccessibilitySize ? 2 : 4)
    }

    private var limitLeft: Int { session.powerUpLimit - session.powerUpsUsed }

    var body: some View {
        VStack(spacing: 8) {
            HStack {
                SectionLabel("Power-ups")
                Spacer()
                Text("1 per question · \(limitLeft) left this round")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(Theme.muted)
            }
            LazyVGrid(columns: columns, spacing: 10) {
                ForEach(PowerUp.trayOrder) { p in
                    let count = stock(p)
                    let active = session.powerUpThisQuestion == p
                    Button { onUse(p) } label: {
                        VStack(spacing: 2) {
                            Image(systemName: p.systemImage).font(.headline)
                            Text(p.shortTitle).font(.subheadline.bold()).lineLimit(1).minimumScaleFactor(0.7)
                            Text(active ? "Active" : "\(count) left").font(.caption2.weight(.semibold))
                        }
                        .frame(maxWidth: .infinity, minHeight: 64)
                    }
                    .buttonStyle(ChunkyButtonStyle(fill: active ? Theme.spark : Theme.card,
                                                   foreground: active ? Color(light: 0x17172B, dark: 0x17172B) : Theme.ink))
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

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(alignment: .center, spacing: 12) {
                Image(systemName: result.correct ? "checkmark.circle.fill" : (result.timedOut ? "clock.badge.xmark" : "xmark.circle.fill"))
                    .font(.title.bold())
                    .accessibilityHidden(true)
                VStack(alignment: .leading, spacing: 2) {
                    Text(title).font(Theme.display(.title2))
                    Text(detail).font(.subheadline)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                Button(action: onNext) {
                    Text(isLast ? "Results" : "Next")
                        .font(.headline)
                        .padding(.horizontal, 20)
                        .frame(minHeight: 44)
                }
                .buttonStyle(.chunky(fill: Theme.card, capsule: true))
            }
            if let secondChance {
                Button(action: onSecondChance) {
                    Label("Second chance · half points (\(secondChance) left)", systemImage: PowerUp.secondChance.systemImage)
                        .font(.subheadline.bold())
                        .frame(maxWidth: .infinity, minHeight: 44)
                }
                .buttonStyle(.chunky(fill: Theme.spark, foreground: Color(light: 0x17172B, dark: 0x17172B), capsule: true))
            }
        }
        .foregroundStyle(.white)
        .padding(16)
        .card(fill: result.correct ? Theme.correct : Theme.wrong, radius: 22)
        .accessibilityElement(children: .contain)
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
