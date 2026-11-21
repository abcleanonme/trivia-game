import SwiftUI
import TriviaKit

/// Profile > Customize card. One place for every part of the Player Card:
/// the live preview stays on top, parts are tabs underneath. Tapping
/// something you own puts it on right away; tapping something you don't
/// tries it on, with a buy button at the bottom.
struct CardStudioView: View {
    @Environment(PlayerStore.self) private var store
    @State private var part: Part = .avatar
    /// A locked item being tried on.
    @State private var tryingOn: Cosmetic?
    @State private var name = ""
    @State private var equipTick = 0

    enum Part: String, CaseIterable, Identifiable {
        case avatar, name, border, background, shape, corner, sticker, finish

        var id: String { rawValue }

        var title: String {
            switch self {
            case .avatar: "Avatar"
            case .name: "Name"
            case .border: "Border"
            case .background: "Background"
            case .shape: "Shape"
            case .corner: "Corner"
            case .sticker: "Sticker"
            case .finish: "Finish"
            }
        }

        var systemImage: String {
            switch self {
            case .avatar: "person.crop.circle.fill"
            case .name: "textformat"
            case .border: "circle.dashed"
            case .background: "square.fill.on.square.fill"
            case .shape: "rectangle.on.rectangle.angled"
            case .corner: "seal.fill"
            case .sticker: "star.bubble.fill"
            case .finish: "sparkles"
            }
        }

        /// Cosmetic slots shown in this tab, each with its own heading.
        var slots: [CosmeticSlot] {
            switch self {
            case .avatar: [.avatar, .avatarColor]
            case .name: [.nameStyle]
            case .border: [.border]
            case .background: [.cardBackground]
            case .shape: [.cardShape]
            case .corner: [.emblem]
            case .sticker: [.sticker]
            case .finish: [.finish]
            }
        }
    }

    var body: some View {
        VStack(spacing: 0) {
            header
            ScrollView {
                VStack(alignment: .leading, spacing: Space.xl) {
                    if part == .name { textOptions }
                    ForEach(part.slots, id: \.self) { slot in
                        VStack(alignment: .leading, spacing: Space.s) {
                            if part.slots.count > 1 || part == .name { SectionLabel(slot.title) }
                            grid(for: slot)
                        }
                    }
                    if part == .corner { stampCorners }
                }
                .padding(.horizontal, Theme.gutter)
                .padding(.vertical, Space.l)
                .frame(maxWidth: 640)
                .frame(maxWidth: .infinity)
            }
            .scrollDismissesKeyboard(.interactively)
        }
        .background(Theme.paper)
        .safeAreaInset(edge: .bottom) {
            if let tryingOn { buyBar(for: tryingOn) }
        }
        .animation(.snappy, value: tryingOn?.id)
        .sensoryFeedback(.selection, trigger: equipTick)
        .navigationTitle("Customize card")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                Button("Shuffle", systemImage: "dice.fill", action: shuffle)
                    .accessibilityHint("Puts on a random mix of things you own")
            }
        }
        .onAppear { name = store.progress.card.name }
        .onChange(of: part) { tryingOn = nil }
    }

    // MARK: Header: preview and part tabs

    private var header: some View {
        VStack(spacing: Space.m) {
            HStack {
                SectionLabel(tryingOn.map { "Trying on \($0.name)" } ?? "Your card")
                Spacer()
                SparksPill(amount: store.wallet.sparks)
            }
            PlayerCardView(look: CardLook(store: store, previewing: tryingOn))
                .animation(.snappy, value: CardLook(store: store, previewing: tryingOn))
            ScrollViewReader { proxy in
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 6) {
                        ForEach(Part.allCases) { p in
                            let on = p == part
                            Button { part = p } label: {
                                Label(p.title, systemImage: p.systemImage)
                                    .font(.footnote.weight(.bold))
                                    .padding(.horizontal, Space.m)
                                    .frame(minHeight: 38)
                            }
                            .buttonStyle(ChunkyButtonStyle(fill: on ? Theme.ink : Theme.card,
                                                           foreground: on ? Theme.paper : Theme.ink,
                                                           shape: AnyShape(Theme.pill), depth: 2))
                            .accessibilityAddTraits(on ? .isSelected : [])
                            .id(p)
                        }
                    }
                    .padding(.vertical, 2)
                    .padding(.horizontal, Theme.gutter)
                }
                .padding(.horizontal, -Theme.gutter)
                .onChange(of: part) { _, p in withAnimation { proxy.scrollTo(p, anchor: .center) } }
            }
        }
        .padding(.horizontal, Theme.gutter)
        .padding(.top, Space.s)
        .padding(.bottom, Space.m)
        .frame(maxWidth: 640)
        .frame(maxWidth: .infinity)
        .background(Theme.paper)
        .overlay(alignment: .bottom) { Rectangle().fill(Theme.line).frame(height: 1) }
    }

    // MARK: Grids

    private func grid(for slot: CosmeticSlot) -> some View {
        // Owned first, then cheapest first, so what you can use now is on top.
        let inv = store.progress.inventory
        let items = CosmeticCatalog.items(in: slot).enumerated().sorted { a, b in
            let ao = inv.owns(a.element.id), bo = inv.owns(b.element.id)
            if ao != bo { return ao }
            let ap = a.element.price ?? .max, bp = b.element.price ?? .max
            return ap != bp ? ap < bp : a.offset < b.offset
        }.map(\.element)
        return LazyVGrid(columns: [GridItem(.adaptive(minimum: 92), spacing: Space.s)], spacing: Space.s) {
            ForEach(items) { item in
                StudioTile(item: item,
                           wearing: isWearing(item),
                           tryingOn: tryingOn?.id == item.id) { tap(item) }
            }
        }
    }

    private func isWearing(_ item: Cosmetic) -> Bool {
        if item.slot == .emblem, store.progress.card.cornerStamp != nil { return false }
        return store.progress.inventory.equipped(item.slot).id == item.id
    }

    private func tap(_ item: Cosmetic) {
        if store.progress.inventory.owns(item.id) {
            store.equip(item)
            if item.slot == .emblem { store.updateCard { $0.cornerStamp = nil } }
            tryingOn = nil
            equipTick += 1
        } else {
            tryingOn = tryingOn?.id == item.id ? nil : item
        }
    }

    /// Earned stamps can sit in the corner instead of an emblem.
    @ViewBuilder private var stampCorners: some View {
        let stamps = store.progress.stamps.sorted { $0.name < $1.name }
        VStack(alignment: .leading, spacing: Space.s) {
            SectionLabel("Your stamps")
            if stamps.isEmpty {
                Text("Earn stamps from big moments, like a perfect round, and show one off here.")
                    .font(.footnote).foregroundStyle(Theme.muted)
            } else {
                LazyVGrid(columns: [GridItem(.adaptive(minimum: 92), spacing: Space.s)], spacing: Space.s) {
                    ForEach(stamps) { stamp in
                        let on = store.progress.card.cornerStamp == stamp.id
                        Button {
                            store.updateCard { $0.cornerStamp = stamp.id }
                            tryingOn = nil
                            equipTick += 1
                        } label: {
                            TileLabel(name: stamp.name, status: on ? .wearing : .owned) {
                                Image(systemName: stamp.systemImage).font(.title.bold())
                            }
                        }
                        .buttonStyle(ChunkyButtonStyle(fill: on ? Theme.accent.opacity(0.15) : Theme.card, depth: 3))
                        .accessibilityLabel("\(stamp.name) stamp\(on ? ", in your corner" : "")")
                    }
                }
            }
        }
    }

    // MARK: Name, title, stat

    @ViewBuilder private var textOptions: some View {
        let p = store.progress
        VStack(alignment: .leading, spacing: Space.s) {
            SectionLabel("Name")
            TextField("Your name", text: $name)
                .textInputAutocapitalization(.words)
                .submitLabel(.done)
                .font(.headline)
                .foregroundStyle(Theme.ink)
                .padding(.horizontal, Space.l)
                .frame(minHeight: 48)
                .background(Theme.pill.fill(Theme.card))
                .overlay(Theme.pill.stroke(Theme.ink, lineWidth: Theme.border))
                .onChange(of: name) { _, new in
                    let trimmed = String(new.prefix(PlayerCard.maxNameLength))
                    if trimmed != new { name = trimmed }
                    store.updateCard { $0.name = trimmed }
                }
            Text("\(name.count)/\(PlayerCard.maxNameLength)")
                .font(.caption).foregroundStyle(Theme.muted)
        }
        chipSection("Title", footer: "Titles are earned from stamps, never bought.",
                    options: p.titles, label: { $0 }, selected: p.card.title) { t in
            store.updateCard { $0.title = t }
        }
        chipSection("Stat to show off", footer: nil,
                    options: PlayerCard.Showcase.allCases, label: \.label, selected: p.card.showcase) { s in
            store.updateCard { $0.showcase = s }
        }
    }

    private func chipSection<T: Hashable>(_ title: String, footer: String?, options: [T], label: @escaping (T) -> String,
                                          selected: T, onPick: @escaping (T) -> Void) -> some View {
        VStack(alignment: .leading, spacing: Space.s) {
            SectionLabel(title)
            FlowLayout(spacing: 6) {
                ForEach(options, id: \.self) { option in
                    let on = option == selected
                    Button {
                        onPick(option)
                        equipTick += 1
                    } label: {
                        Text(label(option))
                            .font(.footnote.weight(.bold))
                            .padding(.horizontal, Space.m)
                            .frame(minHeight: 36)
                    }
                    .buttonStyle(ChunkyButtonStyle(fill: on ? Theme.accent : Theme.card,
                                                   foreground: on ? .white : Theme.ink,
                                                   shape: AnyShape(Theme.pill), depth: 2))
                    .accessibilityAddTraits(on ? .isSelected : [])
                }
            }
            if let footer {
                Text(footer).font(.footnote).foregroundStyle(Theme.muted)
            }
        }
    }

    // MARK: Buying

    private func buyBar(for item: Cosmetic) -> some View {
        HStack(spacing: Space.s) {
            Button { tryingOn = nil } label: {
                Image(systemName: "xmark").font(.headline).frame(width: 52, height: 52)
            }
            .buttonStyle(.chunky(fill: Theme.card, capsule: true))
            .accessibilityLabel("Stop trying on")

            if let price = item.price {
                let canAfford = store.wallet.sparks >= price
                Button {
                    if store.buy(item) {
                        tryingOn = nil
                        equipTick += 1
                    }
                } label: {
                    Label(canAfford ? "Get \(item.name) · \(price)" : "Need \(price - store.wallet.sparks) more Sparks",
                          systemImage: "bolt.fill")
                        .font(.headline)
                        .lineLimit(1).minimumScaleFactor(0.8)
                        .frame(maxWidth: .infinity, minHeight: 52)
                }
                .buttonStyle(.chunky(fill: Theme.spark, foreground: Theme.onSpark, capsule: true))
                .disabled(!canAfford)
            } else {
                Text(lockReason(item))
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(Theme.ink)
                    .multilineTextAlignment(.center)
                    .frame(maxWidth: .infinity, minHeight: 52)
                    .background(Theme.pill.fill(Theme.card))
                    .overlay(Theme.pill.stroke(Theme.ink, lineWidth: Theme.border))
            }
        }
        .padding(.horizontal, Theme.gutter)
        .padding(.vertical, Space.s)
        .frame(maxWidth: 640)
        .frame(maxWidth: .infinity)
        .background(.bar)
        .transition(.move(edge: .bottom).combined(with: .opacity))
    }

    private func lockReason(_ item: Cosmetic) -> String {
        switch item.unlock {
        case .stamp(let stamp): "Unlocks with the \(stamp.name) stamp"
        case .event(let id): "Finish the \(WeeklyEvent.all.first { $0.id == id }?.title ?? "weekly event") track"
        default: ""
        }
    }

    /// A random mix of owned items, one per slot.
    private func shuffle() {
        let inv = store.progress.inventory
        for slot in CosmeticSlot.allCases where slot != .emblem || store.progress.card.cornerStamp == nil {
            if let pick = CosmeticCatalog.items(in: slot).filter({ inv.owns($0.id) }).randomElement() {
                store.equip(pick)
            }
        }
        tryingOn = nil
        equipTick += 1
    }
}

/// A Studio or shop tile: swatch, name, and what it takes to wear it.
private struct StudioTile: View {
    let item: Cosmetic
    let wearing: Bool
    let tryingOn: Bool
    let onTap: () -> Void

    @Environment(PlayerStore.self) private var store

    var body: some View {
        let owned = store.progress.inventory.owns(item.id)
        let status: TileStatus =
            wearing ? .wearing : owned ? .owned : item.price.map { .price($0) } ?? .locked
        Button(action: onTap) {
            TileLabel(name: item.name, status: status) { CosmeticSwatch(item: item) }
        }
        .buttonStyle(ChunkyButtonStyle(fill: tryingOn ? Theme.spark.opacity(0.35)
                                       : wearing ? Theme.accent.opacity(0.15) : Theme.card, depth: 3))
        .accessibilityLabel("\(item.name), \(wearing ? "wearing" : owned ? "owned" : item.price.map { "\($0) Sparks, tap to try on" } ?? "locked, tap to see how to unlock")")
        .accessibilityAddTraits(wearing || tryingOn ? .isSelected : [])
    }
}

enum TileStatus { case wearing, owned, price(Int), locked }

struct TileLabel<Swatch: View>: View {
    let name: String
    let status: TileStatus
    @ViewBuilder let swatch: () -> Swatch

    var body: some View {
        VStack(spacing: 6) {
            swatch().frame(height: 44)
            Text(name).font(.footnote.bold()).multilineTextAlignment(.center)
                .lineLimit(2).minimumScaleFactor(0.85)
            Group {
                switch status {
                case .wearing: Label("On", systemImage: "checkmark.circle.fill").foregroundStyle(Theme.accent)
                case .owned: Text("Owned").foregroundStyle(Theme.muted)
                case .price(let n): Label("\(n)", systemImage: "bolt.fill").foregroundStyle(Theme.ink)
                case .locked: Label("Earn", systemImage: "lock.fill").foregroundStyle(Theme.muted)
                }
            }
            .font(.caption.weight(.bold))
        }
        .padding(8)
        .frame(maxWidth: .infinity, minHeight: 104)
    }
}

/// A small picture of one cosmetic, drawn with the rest of your card so you
/// can judge it in context.
struct CosmeticSwatch: View {
    let item: Cosmetic
    @Environment(PlayerStore.self) private var store

    var body: some View {
        let look = CardLook(store: store, previewing: item)
        switch item.slot {
        case .avatar, .border, .avatarColor:
            AvatarView(avatar: look.avatar, border: look.border, name: look.name, size: 40, tint: look.avatarColor)
        case .cardBackground:
            CardPattern(background: item)
                .clipShape(RoundedRectangle(cornerRadius: 10))
                .overlay(RoundedRectangle(cornerRadius: 10).stroke(Theme.ink, lineWidth: 1.5))
        case .cardShape:
            CardShape(kind: item.shape ?? .rounded)
                .stroke(Theme.ink, lineWidth: 2)
                .frame(maxWidth: 76)
        case .emblem:
            Image(systemName: item.symbol ?? "circle.slash")
                .font(.title.bold())
                .foregroundStyle(item.symbol == nil ? Theme.muted : Theme.ink)
        case .nameStyle:
            Text("Aa")
                .font(NameLettering.font(item.lettering ?? .classic, style: .title))
                .foregroundStyle(Theme.ink)
        case .sticker:
            if let symbol = item.symbol {
                StickerView(symbol: symbol, color: Color(hex: item.colors.first ?? 0xFFC93C), size: 38)
                    .rotationEffect(.degrees(-10))
            } else {
                Image(systemName: "circle.slash").font(.title.bold()).foregroundStyle(Theme.muted)
            }
        case .finish:
            ZStack {
                CardPattern(background: look.background)
                CardFinishOverlay(finish: item)
            }
            .clipShape(RoundedRectangle(cornerRadius: 10))
            .overlay(RoundedRectangle(cornerRadius: 10).stroke(Theme.ink, lineWidth: 1.5))
            .frame(maxWidth: 76)
            .environment(\.colorScheme, .light)
        }
    }
}

#Preview {
    NavigationStack { CardStudioView() }.environment(PlayerStore.preview)
}
