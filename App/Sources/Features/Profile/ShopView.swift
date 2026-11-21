import SwiftUI
import TriviaKit

/// Profile > Style shop. Cosmetics only change how your card looks, never
/// how the game plays. Paid with Sparks (earned only by playing) or
/// unlocked by stamps and events. No real money anywhere.
struct ShopView: View {
    @Environment(PlayerStore.self) private var store
    @State private var slot: CosmeticSlot = .avatar
    @State private var previewing: Cosmetic?

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: Space.l) {
                HStack {
                    SectionLabel(previewing == nil ? "Your card" : "Preview")
                    Spacer()
                    SparksPill(amount: store.wallet.sparks)
                }
                PlayerCardView(look: CardLook(store: store, previewing: previewing))
                    .animation(.default, value: previewing?.id)

                // Every slot visible at once as chips, instead of hidden
                // behind a menu.
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 6) {
                        ForEach(CosmeticSlot.allCases, id: \.self) { s in
                            let on = s == slot
                            Button { slot = s } label: {
                                Text(s.title)
                                    .font(.footnote.weight(.bold))
                                    .padding(.horizontal, Space.m)
                                    .frame(minHeight: 36)
                            }
                            .buttonStyle(ChunkyButtonStyle(fill: on ? Theme.ink : Theme.card,
                                                           foreground: on ? Theme.paper : Theme.ink,
                                                           shape: AnyShape(Theme.pill),
                                                           depth: 2))
                            .accessibilityAddTraits(on ? .isSelected : [])
                        }
                    }
                    .padding(.vertical, 2)
                    .padding(.horizontal, Theme.gutter)
                }
                .padding(.horizontal, -Theme.gutter)
                .onChange(of: slot) { previewing = nil }

                LazyVGrid(columns: [GridItem(.adaptive(minimum: 100), spacing: Space.s)], spacing: Space.s) {
                    ForEach(CosmeticCatalog.items(in: slot)) { item in
                        ShopTile(item: item, selected: previewing?.id == item.id) {
                            previewing = item
                        }
                    }
                }

                if let previewing {
                    action(for: previewing)
                }

                Text("Sparks are earned only by playing. There's nothing to buy with real money.")
                    .font(.footnote)
                    .foregroundStyle(Theme.muted)
            }
            .padding(.horizontal, Theme.gutter)
            .padding(.vertical, Space.m)
            .frame(maxWidth: 640)
            .frame(maxWidth: .infinity)
        }
        .background(Theme.paper)
        .navigationTitle("Style shop")
        .navigationBarTitleDisplayMode(.inline)
    }

    @ViewBuilder private func action(for item: Cosmetic) -> some View {
        let inv = store.progress.inventory
        if inv.equipped(item.slot).id == item.id {
            Label("Wearing \(item.name)", systemImage: "checkmark.circle.fill")
                .font(.headline)
                .foregroundStyle(Theme.correct)
                .frame(maxWidth: .infinity, minHeight: 52)
        } else if inv.owns(item.id) {
            Button("Use \(item.name)") { store.equip(item); previewing = nil }
                .font(.headline)
                .frame(maxWidth: .infinity, minHeight: 52)
                .buttonStyle(.chunky(fill: Theme.accent, foreground: .white, capsule: true))
        } else if let price = item.price {
            Button {
                if store.buy(item) { previewing = nil }
            } label: {
                Label(store.wallet.sparks >= price ? "Get for \(price) Sparks" : "Need \(price - store.wallet.sparks) more Sparks",
                      systemImage: "bolt.fill")
                    .font(.headline)
                    .frame(maxWidth: .infinity, minHeight: 52)
            }
            .buttonStyle(.chunky(fill: Theme.spark, foreground: Theme.onSpark, capsule: true))
            .disabled(store.wallet.sparks < price)
        } else {
            Text(lockReason(item))
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(Theme.muted)
                .frame(maxWidth: .infinity, minHeight: 52)
                .multilineTextAlignment(.center)
        }
    }

    private func lockReason(_ item: Cosmetic) -> String {
        switch item.unlock {
        case .stamp(let stamp): "Earned with the \(stamp.name) stamp."
        case .event(let id): "Finish the \(WeeklyEvent.all.first { $0.id == id }?.title ?? "event") track to unlock."
        default: ""
        }
    }
}

private struct ShopTile: View {
    let item: Cosmetic
    let selected: Bool
    let onTap: () -> Void

    @Environment(PlayerStore.self) private var store

    var body: some View {
        let inv = store.progress.inventory
        let owned = inv.owns(item.id)
        let wearing = inv.equipped(item.slot).id == item.id
        Button(action: onTap) {
            VStack(spacing: 6) {
                swatch.frame(height: 48)
                Text(item.name).font(.footnote.bold()).multilineTextAlignment(.center)
                    .lineLimit(2).minimumScaleFactor(0.85)
                Group {
                    if wearing { Label("On", systemImage: "checkmark") }
                    else if owned { Text("Owned") }
                    else if let price = item.price { Label("\(price)", systemImage: "bolt.fill") }
                    else { Label("Earned", systemImage: "lock.fill") }
                }
                .font(.caption.weight(.bold))
                .foregroundStyle(Theme.muted)
            }
            .padding(10)
            .frame(maxWidth: .infinity, minHeight: 112)
        }
        .buttonStyle(ChunkyButtonStyle(fill: selected ? Theme.spark.opacity(0.35) : Theme.card, depth: 3))
        .accessibilityLabel("\(item.name), \(wearing ? "wearing" : owned ? "owned" : item.price.map { "\($0) Sparks" } ?? "locked")")
        .accessibilityAddTraits(selected ? .isSelected : [])
    }

    private var swatch: some View { CosmeticSwatch(item: item) }
}
