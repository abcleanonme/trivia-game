import SwiftUI
import TriviaKit

struct HomeView: View {
    @Environment(PlayerStore.self) private var store
    @AppStorage("relaxedMode") private var relaxedMode = false
    @AppStorage("gameMode") private var mode: GameMode = .classic
    @AppStorage("difficulty") private var difficulty: Difficulty = .mixed
    @Environment(\.dynamicTypeSize) private var typeSize
    @State private var round: RoundRequest?
    /// Keeps category names lined up while the icon grows with Dynamic Type.
    @ScaledMetric(relativeTo: .footnote) private var iconWidth: CGFloat = 16

    var body: some View {
        // Sized to fit one screen on the iPhone Duo outer display and small
        // iPhones at default text sizes. It still scrolls when large text
        // needs more room, but doesn't bounce when everything fits.
        ScrollView {
            VStack(alignment: .leading, spacing: Space.l) {
                header
                DailyHomeCard { round = RoundRequest(kind: .daily(store.today)) }
                classicCard
                EventHomeCard { event, week in round = RoundRequest(kind: .event(event, week: week)) }
                categories
                powerUps
            }
            .padding(.horizontal, Theme.gutter)
            .padding(.top, Space.s)
            .padding(.bottom, Space.m)
            .frame(maxWidth: 640)
            .frame(maxWidth: .infinity)
        }
        .scrollBounceBehavior(.basedOnSize)
        .background(Theme.paper)
        .toolbar(.hidden, for: .navigationBar)
        .fullScreenCover(item: $round) { request in
            GameView(request: request, relaxed: relaxedMode)
        }
        #if DEBUG
        .onAppear {
            if ProcessInfo.processInfo.arguments.contains("-autoplaySummary"), round == nil {
                round = request(category: nil)
            }
        }
        #endif
    }

    private var header: some View {
        // Stacks at accessibility text sizes so the Sparks pill isn't squeezed.
        let layout = typeSize.isAccessibilitySize
            ? AnyLayout(VStackLayout(alignment: .leading, spacing: 8))
            : AnyLayout(HStackLayout(alignment: .center))
        return layout {
            VStack(alignment: .leading, spacing: 0) {
                Text("Quizio\(Text(".").foregroundStyle(Theme.accent))")
                    .font(Theme.display(.title))
                    .foregroundStyle(Theme.ink)
                    .accessibilityAddTraits(.isHeader)
                Text("No ads. Ever.")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(Theme.muted)
            }
            if !typeSize.isAccessibilitySize { Spacer() }
            SparksPill(amount: store.wallet.sparks)
        }
    }

    private var classicCard: some View {
        // Text and the Play button sit side by side; at accessibility sizes
        // the button drops below so the headline keeps its width. Mode,
        // difficulty and Relaxed sit underneath as one compact options block.
        let layout = typeSize.isAccessibilitySize
            ? AnyLayout(VStackLayout(alignment: .leading, spacing: Space.m))
            : AnyLayout(HStackLayout(alignment: .center, spacing: Space.m))
        return VStack(alignment: .leading, spacing: Space.m) {
            layout {
                VStack(alignment: .leading, spacing: Space.xs) {
                    Text(relaxedApplies ? "\(mode.title) · Relaxed" : mode.title)
                        .eyebrow()
                        .opacity(0.9)
                    Text(headline)
                        .font(Theme.display(.title2))
                        .fixedSize(horizontal: false, vertical: true)
                    Text(relaxedApplies ? "No clock. Still earn Sparks." : subtitle)
                        .font(.footnote)
                        .opacity(0.92)
                        .fixedSize(horizontal: false, vertical: true)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                playButton
            }
            Divider().overlay(Color.white.opacity(0.35))
            VStack(alignment: .leading, spacing: Space.s) {
                OptionRow(label: "Mode", options: GameMode.allCases, selection: $mode, title: \.title)
                OptionRow(label: "Level", options: Difficulty.allCases, selection: $difficulty, title: \.title)
                Toggle(isOn: $relaxedMode) {
                    Label("Relaxed (no timer)", systemImage: "leaf")
                        .font(.footnote.weight(.semibold))
                }
                .tint(Theme.spark)
                .disabled(!mode.supportsRelaxed)
                .opacity(mode.supportsRelaxed ? 1 : 0.6)
            }
        }
        .foregroundStyle(.white)
        .padding(Theme.cardPadding)
        .frame(maxWidth: .infinity, alignment: .leading)
        .card(fill: Theme.accent, radius: Theme.cardRadius, drop: 5)
    }

    private var playButton: some View {
        Button {
            round = request(category: nil)
        } label: {
            Label("Play", systemImage: "play.fill")
                .font(.title3.bold())
                .padding(.horizontal, Space.l)
                .frame(minHeight: 52)
        }
        .buttonStyle(.chunky(fill: Theme.spark, foreground: Theme.onSpark, capsule: true))
        .accessibilityHint("Starts a \(mode.title) round")
    }

    private var categoryColumns: [GridItem] {
        // Three tiles across fits 14 categories in five short rows. Large
        // text gets two (or one) wider columns so names don't truncate.
        let count = typeSize.isAccessibilitySize ? 1 : (typeSize > .xxLarge ? 2 : 3)
        return Array(repeating: GridItem(.flexible(), spacing: Space.s), count: count)
    }

    private var categories: some View {
        VStack(alignment: .leading, spacing: Space.s) {
            SectionLabel("Category focus")
            LazyVGrid(columns: categoryColumns, spacing: Space.s) {
                ForEach(store.bank.categories, id: \.self) { category in
                    Button { round = request(category: category) } label: {
                        HStack(spacing: 6) {
                            Image(systemName: CategoryStyle.symbol(for: category))
                                .font(.footnote.weight(.bold))
                                .foregroundStyle(Theme.accent)
                                .frame(width: iconWidth)
                                .accessibilityHidden(true)
                            Text(category)
                                .font(.footnote.weight(.semibold))
                                .lineLimit(typeSize.isAccessibilitySize ? 2 : 1)
                                .minimumScaleFactor(0.8)
                        }
                        .padding(.horizontal, Space.s)
                        .frame(maxWidth: .infinity, minHeight: 44, alignment: .leading)
                    }
                    .buttonStyle(ChunkyButtonStyle(fill: Theme.card,
                                                   shape: AnyShape(RoundedRectangle(cornerRadius: 14, style: .continuous)),
                                                   depth: 3))
                    .accessibilityHint("Starts a \(mode.title) round of \(category) questions")
                }
            }
        }
    }

    private func request(category: String?) -> RoundRequest {
        RoundRequest(kind: .solo(mode: mode, category: category, difficulty: difficulty))
    }

    private var relaxedApplies: Bool { relaxedMode && mode.supportsRelaxed }

    private var headline: String {
        switch mode {
        case .classic: "10 questions.\n\(difficulty == .mixed ? "Mixed bag." : "\(difficulty.title) ones.")"
        case .survival: "Three lives.\nHow far can you go?"
        case .speed: "60 seconds.\nGo go go."
        }
    }

    private var subtitle: String {
        switch mode {
        case .classic: "Answer fast, build a streak."
        case .survival: "Every miss costs a life."
        case .speed: "No stops. Relaxed doesn't apply."
        }
    }

    private var powerUps: some View {
        VStack(alignment: .leading, spacing: 8) {
            SectionLabel("Your power-ups")
            FlowLayout(spacing: 6) {
                ForEach(PowerUp.allCases) { p in
                    let count = store.wallet.count(of: p)
                    HStack(spacing: 4) {
                        Image(systemName: p.systemImage)
                            .font(.caption.weight(.bold))
                        Text(p.shortTitle)
                            .font(.caption.weight(.semibold))
                        Text("\(count)")
                            .font(.caption.weight(.heavy).monospacedDigit())
                            .padding(.horizontal, 5)
                            .background(Capsule().fill(count > 0 ? Theme.spark : Theme.line))
                            .foregroundStyle(Theme.onSpark)
                    }
                    .foregroundStyle(count > 0 ? Theme.ink : Theme.muted)
                    .padding(.horizontal, 10)
                    .frame(minHeight: 30)
                    .background(Theme.pill.fill(Theme.card))
                    .overlay(Theme.pill.stroke(Theme.line, lineWidth: 1))
                    .accessibilityElement(children: .ignore)
                    .accessibilityLabel("\(p.title), \(count)")
                }
            }
        }
    }
}

/// A labeled row of compact pill choices on the accent card. The label sits
/// beside the pills so each option set takes a single line.
private struct OptionRow<Option: Hashable>: View {
    let label: String
    let options: [Option]
    @Binding var selection: Option
    let title: KeyPath<Option, String>

    @Environment(\.dynamicTypeSize) private var typeSize
    @ScaledMetric(relativeTo: .caption) private var labelWidth: CGFloat = 44

    var body: some View {
        let layout = typeSize > .xxLarge
            ? AnyLayout(VStackLayout(alignment: .leading, spacing: Space.xs))
            : AnyLayout(HStackLayout(alignment: .center, spacing: Space.s))
        layout {
            Text(label)
                .eyebrow()
                .opacity(0.85)
                .frame(minWidth: typeSize > .xxLarge ? nil : labelWidth, alignment: .leading)
            FlowLayout(spacing: 6) {
                ForEach(options, id: \.self) { option in
                    let on = option == selection
                    Button { selection = option } label: {
                        Text(option[keyPath: title])
                            .font(.footnote.weight(.bold))
                            .padding(.horizontal, Space.m)
                            .frame(minHeight: 36)
                            .contentShape(Rectangle())
                    }
                    .buttonStyle(ChunkyButtonStyle(fill: on ? Theme.card : Theme.accent,
                                                   foreground: on ? Theme.ink : .white,
                                                   shape: AnyShape(Theme.pill),
                                                   depth: on ? 3 : 2))
                    .accessibilityAddTraits(on ? .isSelected : [])
                }
            }
        }
        .accessibilityElement(children: .contain)
        .accessibilityLabel(label)
    }
}

/// An SF Symbol for each category, so tiles read at a glance.
enum CategoryStyle {
    static func symbol(for category: String) -> String {
        switch category.lowercased() {
        case "general": "lightbulb.fill"
        case "science": "atom"
        case "history": "building.columns.fill"
        case "geography": "globe.americas.fill"
        case "movies": "film.fill"
        case "tv": "tv.fill"
        case "music": "music.note"
        case "sports": "figure.run"
        case "games": "gamecontroller.fill"
        case "books": "book.fill"
        case "art": "paintpalette.fill"
        case "nature": "leaf.fill"
        case "tech": "cpu.fill"
        case "pop culture": "star.fill"
        default: "questionmark.circle.fill"
        }
    }
}

struct SectionLabel: View {
    let text: String
    init(_ text: String) { self.text = text }

    var body: some View {
        Text(text)
            .eyebrow()
            .foregroundStyle(Theme.muted)
            .accessibilityAddTraits(.isHeader)
    }
}

struct SparksPill: View {
    let amount: Int

    var body: some View {
        HStack(spacing: 6) {
            SparkIcon()
            Text("\(amount) Sparks").font(.subheadline.bold())
        }
        .foregroundStyle(Theme.ink)
        .padding(.horizontal, 12)
        .frame(minHeight: 36)
        .background(Theme.pill.fill(Theme.card))
        .overlay(Theme.pill.stroke(Theme.ink, lineWidth: Theme.border))
        .accessibilityElement(children: .combine)
    }
}

/// Wrapping row layout for chips; wraps naturally at large text sizes.
struct FlowLayout: Layout {
    var spacing: CGFloat = 8

    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        let rows = arrange(width: proposal.width ?? .infinity, subviews: subviews)
        let height = rows.map(\.height).reduce(0, +) + spacing * CGFloat(max(rows.count - 1, 0))
        let width = rows.map(\.width).max() ?? 0
        return CGSize(width: proposal.width ?? width, height: height)
    }

    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
        var y = bounds.minY
        for row in arrange(width: bounds.width, subviews: subviews) {
            var x = bounds.minX
            for i in row.indices {
                let size = subviews[i].sizeThatFits(.unspecified)
                subviews[i].place(at: CGPoint(x: x, y: y), proposal: ProposedViewSize(size))
                x += size.width + spacing
            }
            y += row.height + spacing
        }
    }

    private struct Row { var indices: [Int] = []; var width: CGFloat = 0; var height: CGFloat = 0 }

    private func arrange(width: CGFloat, subviews: Subviews) -> [Row] {
        var rows: [Row] = [Row()]
        for i in subviews.indices {
            let size = subviews[i].sizeThatFits(.unspecified)
            let needed = rows[rows.count - 1].indices.isEmpty ? size.width : rows[rows.count - 1].width + spacing + size.width
            if needed > width, !rows[rows.count - 1].indices.isEmpty {
                rows.append(Row())
            }
            var row = rows[rows.count - 1]
            row.width = row.indices.isEmpty ? size.width : row.width + spacing + size.width
            row.height = max(row.height, size.height)
            row.indices.append(i)
            rows[rows.count - 1] = row
        }
        return rows
    }
}

#Preview {
    NavigationStack { HomeView() }
        .environment(PlayerStore.preview)
}
