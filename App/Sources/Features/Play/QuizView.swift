import SwiftUI
import TriviaKit

/// Answers sit in a grid that adapts to the available width (size class),
/// not to device type, so the same view works on the outer and inner
/// iPhone Duo displays, in Split View, and on every other iPhone/iPad.
struct QuizView: View {
    @State var session: GameSession
    @Environment(\.horizontalSizeClass) private var hSize

    private var columns: [GridItem] {
        Array(repeating: GridItem(.flexible(), spacing: 12), count: hSize == .regular ? 2 : 1)
    }

    var body: some View {
        ScrollView {
            if let question = session.currentQuestion {
                VStack(alignment: .leading, spacing: 20) {
                    Text(question.category.uppercased())
                        .font(.caption.bold())
                        .foregroundStyle(.secondary)
                    Text(question.prompt)
                        .font(.title2.bold())
                    LazyVGrid(columns: columns, spacing: 12) {
                        ForEach(question.choices.indices, id: \.self) { i in
                            AnswerButton(title: question.choices[i], style: style(for: i)) {
                                session.answer(i)
                            }
                        }
                    }
                    if case .answered = session.state {
                        Button("Next") { session.advance() }
                            .buttonStyle(.borderedProminent)
                            .frame(maxWidth: .infinity)
                    }
                }
                .padding()
                .frame(maxWidth: 900)
                .frame(maxWidth: .infinity)
            } else {
                ContentUnavailableView("Round over",
                                       systemImage: "trophy",
                                       description: Text("You scored \(session.score) of \(session.questions.count)."))
            }
        }
        .navigationTitle("Score: \(session.score)")
        .navigationBarTitleDisplayMode(.inline)
    }

    private func style(for i: Int) -> AnswerButton.Style {
        guard case .answered(_, let choice, _) = session.state,
              let q = session.currentQuestion else { return .idle }
        if q.isCorrect(i) { return .correct }
        return i == choice ? .wrong : .idle
    }
}

private struct AnswerButton: View {
    enum Style { case idle, correct, wrong }
    let title: String
    let style: Style
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Text(title)
                .frame(maxWidth: .infinity, minHeight: 44)
                .padding(.vertical, 8)
        }
        .buttonStyle(.bordered)
        .tint(tint)
    }

    private var tint: Color {
        switch style {
        case .idle: .accentColor
        case .correct: .green
        case .wrong: .red
        }
    }
}

#Preview {
    NavigationStack { QuizView(session: GameSession(questions: Question.samples)) }
}
