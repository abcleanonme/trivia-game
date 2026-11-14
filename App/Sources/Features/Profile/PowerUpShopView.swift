import SwiftUI
import TriviaKit

/// Spend Sparks on power-ups: one at a time, a pack of three, or a kit
/// with one of each. Sparks are earned only by playing, so nothing here
/// costs real money. Reached from Home ("Get more") and Profile.
struct PowerUpShopView: View {
    @Environment(PlayerStore.self) private var store
    /// Bumped on each purchase for the success haptic.
    @State private var bought = 0

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: Space.l) {
                HStack {
                    SectionLabel("Power-ups")
                    Spacer()
                    SparksPill(amount: store.wallet.sparks)
                        .contentTransition(.numericText(value: Double(store.wallet.sparks)))
                        .animation(.snappy, value: store.wallet.sparks)
                }

                kitCard

                VStack(spacing: Space.m) {
                    ForEach(PowerUpShop.order) { p in
                        PowerUpRow(powerUp: p, onBuy: buy)
                    }
                }

                VStack(alignment: .leading, spacing: Space.xs) {
                    Text("One power-up per question, up to \(GameRules.soloPowerUpsPerRound) a round. Using one skips that question's speed bonus. You can hold up to \(PowerUpShop.maxStock) of each.")
                    Text("Sparks are earned only by playing. There's nothing to buy with real money.")
                }
                .font(.footnote)
                .foregroundStyle(Theme.muted)
            }
            .padding(.horizontal, Theme.gutter)
            .padding(.vertical, Space.m)
            .frame(maxWidth: 640)
            .frame(maxWidth: .infinity)
        }
        .background(Theme.paper)
        .navigationTitle("Power-up shop")
        .navigationBarTitleDisplayMode(.inline)
        .sensoryFeedback(.success, trigger: bought)
    }

    private var kitCard: some View {
        let kit = PowerUpShop.kit
        return VStack(alignment: .leading, spacing: Space.m) {
            HStack(alignment: .firstTextBaseline) {
                VStack(alignment: .leading, spacing: 2) {
                    Text(kit.title).font(Theme.display(.title3))
                    Text("One of each power-up. Save \(kit.savings) Sparks.")
                        .font(.subheadline)
                }
                Spacer(minLength: 0)
            }
            HStack(spacing: Space.s) {
                ForEach(PowerUp.allCases) { p in
                    Image(systemName: p.systemImage)
                        .font(.subheadline.weight(.bold))
                        .frame(width: 32, height: 32)
                        .background(Circle().fill(Theme.card))
                        .overlay(Circle().stroke(Theme.ink, lineWidth: 1.5))
                        .accessibilityLabel(p.title)
                }
            }
            BuyButton(offer: kit, label: "Get kit", prominent: true, onBuy: buy)
        }
        .foregroundStyle(Theme.onSpark)
        .padding(Theme.cardPadding)
        .card(fill: Theme.spark, drop: 4)
    }

    private func buy(_ offer: PowerUpOffer) {
        guard store.buy(offer) else { return }
        bought += 1
    }
}

private struct PowerUpRow: View {
    let powerUp: PowerUp
    let onBuy: (PowerUpOffer) -> Void

    @Environment(PlayerStore.self) private var store
    @Environment(\.dynamicTypeSize) private var typeSize

    var body: some View {
        let count = store.wallet.count(of: powerUp)
        VStack(alignment: .leading, spacing: Space.m) {
            HStack(alignment: .top, spacing: Space.m) {
                Image(systemName: powerUp.systemImage)
                    .font(.title3.weight(.bold))
                    .foregroundStyle(Theme.ink)
                    .frame(width: 44, height: 44)
                    .background(Circle().fill(Theme.spark))
                    .overlay(Circle().stroke(Theme.ink, lineWidth: Theme.border))
                    .accessibilityHidden(true)
                VStack(alignment: .leading, spacing: 2) {
                    Text(powerUp.title).font(.headline)
                    Text(powerUp.summary)
                        .font(.subheadline)
                        .foregroundStyle(Theme.muted)
                        .fixedSize(horizontal: false, vertical: true)
                }
                Spacer(minLength: 0)
                Text("\(count)/\(PowerUpShop.maxStock)")
                    .font(.caption.weight(.heavy).monospacedDigit())
                    .padding(.horizontal, 8)
                    .padding(.vertical, 3)
                    .background(Capsule().fill(count > 0 ? Theme.spark.opacity(0.5) : Theme.line))
                    .contentTransition(.numericText(value: Double(count)))
                    .animation(.snappy, value: count)
                    .accessibilityLabel("You have \(count)")
            }
            .foregroundStyle(Theme.ink)

            (typeSize.isAccessibilitySize
                ? AnyLayout(VStackLayout(spacing: Space.s))
                : AnyLayout(HStackLayout(spacing: Space.s))) {
                BuyButton(offer: PowerUpShop.single(powerUp), label: "Buy 1", onBuy: onBuy)
                BuyButton(offer: PowerUpShop.pack(powerUp), label: "Buy \(PowerUpShop.packSize)", onBuy: onBuy)
            }
        }
        .padding(Theme.cardPadding)
        .card()
    }
}

/// "Buy 1 · ⚡25". Disabled with a reason when the player can't afford it
/// or their stock is full.
private struct BuyButton: View {
    let offer: PowerUpOffer
    let label: String
    var prominent = false
    let onBuy: (PowerUpOffer) -> Void

    @Environment(PlayerStore.self) private var store

    var body: some View {
        let check = store.wallet.check(offer)
        Button { onBuy(offer) } label: {
            VStack(spacing: 0) {
                HStack(spacing: 6) {
                    Text(label)
                    Label("\(offer.price)", systemImage: "bolt.fill")
                        .labelStyle(CompactLabelStyle())
                        .monospacedDigit()
                }
                .font(.subheadline.weight(.bold))
                if let note = note(check) {
                    Text(note).font(.caption2.weight(.semibold)).opacity(0.8)
                }
            }
            .frame(maxWidth: .infinity, minHeight: 44)
            .padding(.vertical, 2)
        }
        .buttonStyle(ChunkyButtonStyle(fill: prominent ? Theme.ink : (check == .ok ? Theme.spark : Theme.card),
                                       foreground: prominent ? Theme.paper : Theme.ink,
                                       shape: AnyShape(Theme.pill), depth: 3))
        .disabled(check != .ok)
        .accessibilityLabel("\(label) \(offer.title.lowercased()) for \(offer.price) Sparks")
        .accessibilityHint(note(check) ?? "")
    }

    private func note(_ check: Wallet.PurchaseCheck) -> String? {
        switch check {
        case .ok: offer.savings > 0 ? "Save \(offer.savings)" : nil
        case .needSparks(let n): "Need \(n) more"
        case .full: "Stock full"
        }
    }
}

#Preview {
    NavigationStack { PowerUpShopView() }
        .environment(PlayerStore.preview)
}
