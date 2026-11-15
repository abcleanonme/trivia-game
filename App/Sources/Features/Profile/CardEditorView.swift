import SwiftUI
import TriviaKit

/// Profile > Edit card: name, title, showcase stat and corner mark, with a
/// live preview. Looks come from the Style shop.
struct CardEditorView: View {
    @Environment(PlayerStore.self) private var store
    @State private var name = ""

    var body: some View {
        let p = store.progress
        Form {
            Section {
                PlayerCardView(look: CardLook(store: store))
                    .listRowInsets(EdgeInsets(top: 12, leading: 12, bottom: 12, trailing: 12))
                    .listRowBackground(Color.clear)
            }
            Section("Name") {
                TextField("Your name", text: $name)
                    .textInputAutocapitalization(.words)
                    .onChange(of: name) { _, new in store.updateCard { $0.name = new } }
            }
            Section {
                Picker("Title", selection: binding(\.title)) {
                    ForEach(p.titles, id: \.self) { Text($0).tag($0) }
                }
            } footer: {
                Text("Titles are earned from stamps, never bought.")
            }
            Section("Showcase stat") {
                Picker("Stat", selection: binding(\.showcase)) {
                    ForEach(PlayerCard.Showcase.allCases, id: \.self) { Text($0.label).tag($0) }
                }
            }
            Section {
                Picker("Corner", selection: binding(\.cornerStamp)) {
                    Text("Emblem from the shop").tag(String?.none)
                    ForEach(p.stamps.sorted { $0.name < $1.name }) { stamp in
                        Label(stamp.name, systemImage: stamp.systemImage).tag(Optional(stamp.id))
                    }
                }
            } footer: {
                Text("Show a stamp you've earned in the card's corner instead of your emblem.")
            }
        }
        .scrollContentBackground(.hidden)
        .background(Theme.paper)
        .navigationTitle("Player Card")
        .onAppear { name = p.card.name }
    }

    private func binding<T>(_ keyPath: WritableKeyPath<PlayerCard, T>) -> Binding<T> {
        Binding(get: { store.progress.card[keyPath: keyPath] },
                set: { value in store.updateCard { $0[keyPath: keyPath] = value } })
    }
}
