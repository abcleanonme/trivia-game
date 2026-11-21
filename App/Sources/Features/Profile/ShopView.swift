import SwiftUI
import TriviaKit

/// Profile > Style shop. Cosmetics only change how your card looks, never
/// how the game plays. Paid with Sparks (earned only by playing) or
/// unlocked by stamps and events. No real money anywhere.
struct ShopView: View {
    @Environment(PlayerStore.self) private var store
    @State private var slot: CosmeticSlot = .theme
    @State private var previewing: Cosmetic?

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: Space.l) {
                HStack {
                    SectionLabel(previewing == nil ? (slot == .theme ? "Your theme" : "Your card") : "Preview")
                    Spacer()
                    SparksPill(amount: store.wallet.sparks)
                }
                if slot == .theme {
                    ThemePreview(palette: previewPalette)
                        .frame(height: 210)
                        .animation(.default, value: previewPalette.id)
                } else {
                    PlayerCardView(look: CardLook(store: store, previewing: previewing))
                        .animation(.default, value: previewing?.id)
                }

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
        .themeBackground()
        .navigationTitle("Style shop")
        .navigationBarTitleDisplayMode(.inline)
    }

    /// The theme being previewed, or the one in use.
    private var previewPalette: ThemePalette {
        if let previewing, previewing.slot == .theme { return ThemePalette.palette(for: previewing.id) }
        return ThemePalette.palette(for: store.progress.inventory.equipped(.theme).id)
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

/// A small mock screen in a theme's colors over its animated background,
/// so players can see a theme before spending Sparks on it.
private struct ThemePreview: View {
    let palette: ThemePalette

    var body: some View {
        let shape = RoundedRectangle(cornerRadius: 24, style: .continuous)
        ZStack {
            ThemeBackground(palette: palette)
            VStack(alignment: .leading, spacing: 10) {
                Text("SCIENCE")
                    .font(.caption.bold())
                    .foregroundStyle(Theme.muted)
                Text("What planet is known as the Red Planet?")
                    .font(Theme.display(.headline))
                    .foregroundStyle(Theme.ink)
                HStack(spacing: 8) {
                    answer("Mars", fill: palette.accent, text: .white)
                    answer("Venus", fill: palette.card, text: Theme.ink)
                }
            }
            .padding(16)
            .background(RoundedRectangle(cornerRadius: 18, style: .continuous).fill(palette.card))
            .overlay(RoundedRectangle(cornerRadius: 18, style: .continuous).stroke(Theme.ink, lineWidth: Theme.border))
            .padding(18)
        }
        .clipShape(shape)
        .overlay(shape.stroke(Theme.ink, lineWidth: Theme.border))
        // Dark themes preview in dark mode, as they'll look once applied.
        .environment(\.colorScheme, palette.scheme ?? colorScheme)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("Theme preview")
    }

    @Environment(\.colorScheme) private var colorScheme

    private func answer(_ title: String, fill: Color, text: Color) -> some View {
        Text(title)
            .font(.subheadline.bold())
            .foregroundStyle(text)
            .frame(maxWidth: .infinity, minHeight: 36)
            .background(Theme.pill.fill(fill))
            .overlay(Theme.pill.stroke(Theme.ink, lineWidth: 1.5))
    }
}

/// Shop tile swatch for a theme: its background with an accent dot.
private struct ThemeSwatch: View {
    let palette: ThemePalette
    @Environment(\.colorScheme) private var colorScheme

    var body: some View {
        let shape = RoundedRectangle(cornerRadius: 12, style: .continuous)
        ZStack(alignment: .bottomTrailing) {
            // Still frame: six animating tiles would cost battery for little.
            ThemeBackground(palette: palette, animated: false)
            Circle().fill(palette.accent)
                .frame(width: 18, height: 18)
                .overlay(Circle().stroke(Theme.ink, lineWidth: 1.5))
                .padding(8)
        }
        .clipShape(shape)
        .overlay(shape.stroke(Theme.ink, lineWidth: 1.5))
        .environment(\.colorScheme, palette.scheme ?? colorScheme)
    }
}
