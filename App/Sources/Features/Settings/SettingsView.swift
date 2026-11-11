import SwiftUI

struct SettingsView: View {
    @Environment(PlayerStore.self) private var store
    @AppStorage("soundEnabled") private var soundEnabled = true
    @AppStorage("hapticsEnabled") private var hapticsEnabled = true
    @AppStorage("relaxedMode") private var relaxedMode = false

    var body: some View {
        Form {
            Section {
                Toggle("Relaxed mode", isOn: $relaxedMode)
            } footer: {
                Text("No timer and no speed bonus. You still earn points, streaks and Sparks.")
            }
            Section {
                Toggle("Sound", isOn: $soundEnabled)
                Toggle("Haptics", isOn: $hapticsEnabled)
            }
            Section("About") {
                NavigationLink("Credits") { CreditsView() }
                LabeledContent("Questions", value: store.bank.questions.count.formatted())
                LabeledContent("Version", value: Self.version)
            }
        }
        .navigationTitle("Settings")
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
        .navigationTitle("Credits")
    }
}

#Preview {
    NavigationStack { SettingsView() }
        .environment(PlayerStore.preview)
}
