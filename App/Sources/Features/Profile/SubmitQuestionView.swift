import SwiftUI
import TriviaKit

/// Profile > Write a question. Every submission is reviewed by a person
/// before anyone sees it; nothing is published automatically.
struct SubmitQuestionView: View {
    @Environment(PlayerStore.self) private var store
    @Environment(\.dismiss) private var dismiss

    @State private var prompt = ""
    @State private var answers = ["", "", "", ""]
    @State private var correct = 0
    @State private var category = ""
    @State private var source = ""
    @State private var problem: String?
    @State private var sent = false

    var body: some View {
        Form {
            Section {
                TextField("Question", text: $prompt, axis: .vertical)
                    .lineLimit(2...5)
            } header: {
                Text("Question")
            } footer: {
                Text("\(prompt.count)/\(QuestionSubmission.maxPromptLength)")
            }
            Section {
                ForEach(0..<4, id: \.self) { i in
                    HStack {
                        Button { correct = i } label: {
                            Image(systemName: correct == i ? "checkmark.circle.fill" : "circle")
                                .font(.title3)
                                .foregroundStyle(correct == i ? Theme.correct : Theme.muted)
                        }
                        .buttonStyle(.plain)
                        .accessibilityLabel(correct == i ? "Correct answer" : "Mark answer \(i + 1) correct")
                        TextField("Answer \(i + 1)", text: $answers[i])
                    }
                }
            } header: {
                Text("Answers")
            } footer: {
                Text("Tap the circle next to the right answer.")
            }
            Section("Details") {
                Picker("Category", selection: $category) {
                    Text("Choose…").tag("")
                    ForEach(QuestionBank.preferredCategoryOrder, id: \.self) { Text($0).tag($0) }
                }
                TextField("Source link (optional)", text: $source)
                    .keyboardType(.URL)
                    .textInputAutocapitalization(.never)
                    .autocorrectionDisabled()
            }
            if let problem {
                Section {
                    Label(problem, systemImage: "exclamationmark.triangle.fill")
                        .foregroundStyle(Theme.wrong)
                }
            }
            Section {
                Button("Send for review", action: submit)
                    .font(.headline)
            } footer: {
                Text("A person checks every question before it's used. If it's accepted you'll be credited as \"Submitted by \(store.progress.card.name)\" and earn \(QuestionSubmission.acceptedSparks) Sparks and the Question Writer title. Up to \(QuestionSubmission.perDay) a day.")
            }
        }
        .navigationTitle("Write a question")
        .alert("Thanks!", isPresented: $sent) {
            Button("Done") { dismiss() }
        } message: {
            Text("Your question is saved. You'll see its status on your Profile.")
        }
    }

    private func submit() {
        do {
            let s = try QuestionSubmission.make(prompt: prompt, choices: answers, correctIndex: correct,
                                                category: category, source: source,
                                                previous: store.progress.submissions)
            store.submit(s)
            problem = nil
            sent = true
        } catch {
            problem = error.message
        }
    }
}
