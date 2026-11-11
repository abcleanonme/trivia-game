import SwiftUI

struct SettingsView: View {
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
        }
        .navigationTitle("Settings")
    }
}
