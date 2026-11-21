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
                    SectionLabel(previewing == nil ? heading : "Preview")
                    Spacer()
                    SparksPill(amount: store.wallet.sparks)
                }
                if slot == .theme {
                    ThemePreview(palette: previewPalette)
                        .frame(height: 210)
                        .animation(.default, value: previewPalette.id)
                } else if slot == .sounds {
                    SoundPreview(pack: previewing ?? store.progress.inventory.equipped(.sounds))
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
                            // Hear a pack as soon as it's picked.
                            if item.slot == .sounds { SoundEffects.shared.preview(.streak, pack: item.id) }
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
            .readableWidth()
        }
        .themeBackground()
        .navigationTitle("Style shop")
        .navigationBarTitleDisplayMode(.inline)
    }

    private var heading: String {
        switch slot {
        case .theme: "Your theme"
        case .sounds: "Your sounds"
        default: "Your card"
        }
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
            Text(item.lockReason)
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(Theme.muted)
                .frame(maxWidth: .infinity, minHeight: 52)
                .multilineTextAlignment(.center)
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
                CosmeticSwatch(item: item).frame(height: 48)
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
struct ThemeSwatch: View {
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

/// Sound pack preview: what it sounds like, one button per moment, so
/// players can listen before spending Sparks.
private struct SoundPreview: View {
    let pack: Cosmetic

    private static let cues: [SoundCue] = [.correct, .wrong, .streak, .tick, .powerUp, .roundEnd]

    var body: some View {
        VStack(alignment: .leading, spacing: Space.m) {
            HStack(spacing: Space.m) {
                SoundSwatch(item: pack).frame(width: 56, height: 56)
                VStack(alignment: .leading, spacing: 2) {
                    Text(pack.name).font(Theme.display(.title3)).foregroundStyle(Theme.ink)
                    if let blurb = pack.blurb {
                        Text(blurb).font(.subheadline).foregroundStyle(Theme.muted)
                    }
                }
            }
            LazyVGrid(columns: [GridItem(.adaptive(minimum: 96), spacing: Space.s)], spacing: Space.s) {
                ForEach(Self.cues, id: \.self) { cue in
                    Button { SoundEffects.shared.preview(cue, pack: pack.id) } label: {
                        Label(cue.title, systemImage: "play.fill")
                            .font(.footnote.weight(.bold))
                            .frame(maxWidth: .infinity, minHeight: 40)
                    }
                    .buttonStyle(ChunkyButtonStyle(fill: Theme.paper, shape: AnyShape(Theme.pill), depth: 2))
                    .accessibilityLabel("Play \(cue.title) sound")
                }
            }
            Text("Your ring/silent switch mutes these previews.")
                .font(.caption)
                .foregroundStyle(Theme.muted)
        }
        .padding(Theme.cardPadding)
        .card()
        .animation(.default, value: pack.id)
    }
}

/// Shop tile swatch for a sound pack: its symbol on its color, with a
/// speaker badge so it reads as "sound" at a glance.
struct SoundSwatch: View {
    let item: Cosmetic

    var body: some View {
        ZStack(alignment: .bottomTrailing) {
            Circle()
                .fill(Color(hex: item.colors.first ?? 0x3B5BFD))
                .overlay(Circle().stroke(Theme.ink, lineWidth: 1.5))
                .overlay {
                    Image(systemName: item.symbol ?? "speaker.wave.2.fill")
                        .font(.title3.bold())
                        .foregroundStyle(.white)
                }
                .aspectRatio(1, contentMode: .fit)
            Image(systemName: "speaker.wave.2.fill")
                .font(.caption2.bold())
                .foregroundStyle(Theme.ink)
                .padding(4)
                .background(Circle().fill(Theme.card))
                .overlay(Circle().stroke(Theme.ink, lineWidth: 1))
        }
        .accessibilityHidden(true)
    }
}
