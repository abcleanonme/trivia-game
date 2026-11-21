import SwiftUI
import TriviaKit

struct SettingsView: View {
    @Environment(PlayerStore.self) private var store
    @AppStorage(SettingKey.haptics) private var hapticsEnabled = true
    @AppStorage(SettingKey.relaxedMode) private var relaxedMode = false
    @AppStorage(SettingKey.animatedBackgrounds) private var animatedBackgrounds = true
    @State private var confirmingClear = false

    var body: some View {
        Form {
            Section {
                Toggle("Relaxed mode", isOn: $relaxedMode)
            } footer: {
                Text("No timer and no speed bonus. You still earn points, streaks and Sparks.")
            }
            Section {
                Toggle("Haptics", isOn: $hapticsEnabled)
            }
            Section {
                Toggle("Animated backgrounds", isOn: $animatedBackgrounds)
            } footer: {
                Text("Backgrounds also hold still when Reduce Motion or Low Power Mode is on. Change your theme in Profile > Style shop.")
            }
            flaggedQuestions
            Section("About") {
                NavigationLink("Credits") { CreditsView() }
                LabeledContent("Questions", value: store.bank.questions.count.formatted())
                LabeledContent("Version", value: Self.version)
            }
        }
        .scrollContentBackground(.hidden)
        .themeBackground()
        .navigationTitle("Settings")
    }

    /// Questions flagged during play stay on this phone until they're sent,
    /// so there's a way to get them to whoever reviews the question bank.
    @ViewBuilder private var flaggedQuestions: some View {
        let reports = store.progress.reports
        if !reports.isEmpty {
            Section {
                ShareLink(item: QuestionReport.summary(of: reports)) {
                    Label("Send \(reports.count) flagged question\(reports.count == 1 ? "" : "s")",
                          systemImage: "flag.fill")
                }
                Button("Clear flagged questions", role: .destructive) { confirmingClear = true }
            } header: {
                Text("Flagged questions")
            } footer: {
                Text("Share them by Mail, Messages or TestFlight feedback so bad questions get fixed. Clear the list once they're sent.")
            }
            .confirmationDialog("Clear flagged questions?", isPresented: $confirmingClear, titleVisibility: .visible) {
                Button("Clear", role: .destructive) { store.clearReports() }
            }
        }
    }

    private static var version: String {
        let info = Bundle.main.infoDictionary
        let short = info?["CFBundleShortVersionString"] as? String ?? "?"
        let build = info?["CFBundleVersion"] as? String ?? "?"
        return "\(short) (\(build))"
    }
}

/// Attribution required by the Open Trivia Database's CC BY-SA 4.0 license.
struct CreditsView: View {
    var body: some View {
        List {
            Section {
                VStack(alignment: .leading, spacing: 8) {
                    Text("Open Trivia Database").font(.headline)
                    Text("Many questions come from the Open Trivia Database, a free, user-contributed trivia question database. They are used under the Creative Commons Attribution-ShareAlike 4.0 license. We renamed categories and shuffle answer order.")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
                .padding(.vertical, 4)
                Link("opentdb.com", destination: URL(string: "https://opentdb.com")!)
                Link("CC BY-SA 4.0 license", destination: URL(string: "https://creativecommons.org/licenses/by-sa/4.0/")!)
            } header: {
                Text("Questions")
            }
            Section {
                Text("No ads, no tracking, no in-app purchases. Sparks are earned only by playing.")
                    .font(.subheadline)
            }
        }
        .scrollContentBackground(.hidden)
        .themeBackground()
        .navigationTitle("Credits")
    }
}

#Preview {
    NavigationStack { SettingsView() }
        .environment(PlayerStore.preview)
}
