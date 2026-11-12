import SwiftUI
import TriviaKit

/// A round the player asked to start. Identifiable so it can drive a cover.
struct RoundRequest: Identifiable {
    let id = UUID()
    let category: String?
}

struct HomeView: View {
    @Environment(PlayerStore.self) private var store
    @AppStorage("relaxedMode") private var relaxedMode = false
    @Environment(\.dynamicTypeSize) private var typeSize
    @State private var round: RoundRequest?
    /// Keeps category names lined up while the icon grows with Dynamic Type.
    @ScaledMetric(relativeTo: .footnote) private var iconWidth: CGFloat = 16

    var body: some View {
        // Sized to fit one screen on the iPhone Duo outer display and small
        // iPhones at default text sizes. It still scrolls when large text
        // needs more room, but doesn't bounce when everything fits.
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                header
                classicCard
                categories
                powerUps
            }
            .padding(.horizontal, 20)
            .padding(.top, 8)
            .padding(.bottom, 12)
            .frame(maxWidth: 640)
            .frame(maxWidth: .infinity)
        }
        .scrollBounceBehavior(.basedOnSize)
        .background(Theme.paper)
        .toolbar(.hidden, for: .navigationBar)
        .fullScreenCover(item: $round) { request in
            GameView(category: request.category, relaxed: relaxedMode)
        }
        #if DEBUG
        .onAppear {
            if ProcessInfo.processInfo.arguments.contains("-autoplaySummary"), round == nil {
                round = RoundRequest(category: nil)
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
        // the button drops below so the headline keeps its width.
        let layout = typeSize.isAccessibilitySize
            ? AnyLayout(VStackLayout(alignment: .leading, spacing: 14))
            : AnyLayout(HStackLayout(alignment: .center, spacing: 12))
        return layout {
            VStack(alignment: .leading, spacing: 6) {
                Text(relaxedMode ? "Classic · Relaxed" : "Classic")
                    .font(.caption.weight(.bold))
                    .textCase(.uppercase)
                    .kerning(1)
                    .opacity(0.9)
                Text("10 questions.\nMixed bag.")
                    .font(Theme.display(.title2))
                    .fixedSize(horizontal: false, vertical: true)
                Text(relaxedMode ? "No clock. Still earn Sparks."
                                 : "Answer fast, build a streak.")
                    .font(.footnote)
                    .opacity(0.92)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            Button {
                round = RoundRequest(category: nil)
            } label: {
                Label("Play", systemImage: "play.fill")
                    .font(.title3.bold())
                    .padding(.horizontal, 20)
                    .frame(minHeight: 52)
            }
            .buttonStyle(.chunky(fill: Theme.spark, foreground: Theme.onSpark, capsule: true))
            .accessibilityHint("Starts a 10 question mixed round")
        }
        .foregroundStyle(.white)
        .padding(18)
        .frame(maxWidth: .infinity, alignment: .leading)
        .card(fill: Theme.accent, radius: 26, drop: 5)
    }

    private var categoryColumns: [GridItem] {
        // Three tiles across fits 14 categories in five short rows. Large
        // text gets two (or one) wider columns so names don't truncate.
        let count = typeSize.isAccessibilitySize ? 1 : (typeSize > .xxLarge ? 2 : 3)
        return Array(repeating: GridItem(.flexible(), spacing: 8), count: count)
    }

    private var categories: some View {
        VStack(alignment: .leading, spacing: 8) {
            SectionLabel("Pick a category")
            LazyVGrid(columns: categoryColumns, spacing: 8) {
                ForEach(store.bank.categories, id: \.self) { category in
                    Button { round = RoundRequest(category: category) } label: {
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
                        .padding(.horizontal, 8)
                        .frame(maxWidth: .infinity, minHeight: 44, alignment: .leading)
                    }
                    .buttonStyle(ChunkyButtonStyle(fill: Theme.card,
                                                   shape: AnyShape(RoundedRectangle(cornerRadius: 14, style: .continuous)),
                                                   depth: 3))
                    .accessibilityHint("Starts a round of \(category) questions")
                }
            }
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
            .font(.footnote.weight(.semibold))
            .textCase(.uppercase)
            .kerning(1)
            .foregroundStyle(Theme.muted)
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
