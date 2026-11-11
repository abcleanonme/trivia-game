import SwiftUI
import TriviaKit

struct HomeView: View {
    var body: some View {
        List {
            Section {
                NavigationLink("Quick Play") {
                    QuizView(session: GameSession(questions: Question.samples))
                }
            } footer: {
                Text("No ads. Ever.")
            }
        }
        .navigationTitle("Trivia")
    }
}
