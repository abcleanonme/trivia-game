import SwiftUI

struct SettingsView: View {
    @AppStorage("soundEnabled") private var soundEnabled = true
    @AppStorage("hapticsEnabled") private var hapticsEnabled = true

    var body: some View {
        Form {
            Toggle("Sound", isOn: $soundEnabled)
            Toggle("Haptics", isOn: $hapticsEnabled)
        }
        .navigationTitle("Settings")
    }
}
