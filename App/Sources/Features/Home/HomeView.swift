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

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                header
                classicCard
                categories
                powerUps
                Text("No ads. Ever.")
                    .font(.footnote)
                    .foregroundStyle(Theme.muted)
                    .frame(maxWidth: .infinity)
            }
            .padding(.horizontal, 20)
            .padding(.vertical, 12)
            .frame(maxWidth: 640)
            .frame(maxWidth: .infinity)
        }
        .background(Theme.paper)
        .toolbar(.hidden, for: .navigationBar)
        .fullScreenCover(item: $round) { request in
            GameView(category: request.category, relaxed: relaxedMode)
        }
    }

    private var header: some View {
        // Stacks at accessibility text sizes so the Sparks pill isn't squeezed.
        let layout = typeSize.isAccessibilitySize
            ? AnyLayout(VStackLayout(alignment: .leading, spacing: 12))
            : AnyLayout(HStackLayout())
        return layout {
            Text("Trivia\(Text(".").foregroundStyle(Theme.accent))")
                .font(Theme.display(.largeTitle))
                .foregroundStyle(Theme.ink)
                .accessibilityAddTraits(.isHeader)
            if !typeSize.isAccessibilitySize { Spacer() }
            SparksPill(amount: store.wallet.sparks)
        }
    }

    private var classicCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(relaxedMode ? "Classic · Relaxed" : "Classic")
                .font(.footnote.weight(.semibold))
                .textCase(.uppercase)
                .kerning(1)
                .opacity(0.9)
            Text("10 questions.\nMixed bag.")
                .font(Theme.display(.largeTitle))
            Text(relaxedMode ? "No clock. Take your time, still earn Sparks."
                             : "Answer fast, build a streak, earn Sparks.")
                .font(.subheadline)
                .opacity(0.92)
            Button {
                round = RoundRequest(category: nil)
            } label: {
                Text("Play")
                    .font(.title3.bold())
                    .padding(.horizontal, 28)
                    .padding(.vertical, 12)
            }
            .buttonStyle(.chunky(fill: Theme.spark, foreground: Theme.onSpark, capsule: true))
            .padding(.top, 4)
        }
        .foregroundStyle(.white)
        .padding(24)
        .frame(maxWidth: .infinity, alignment: .leading)
        .card(fill: Theme.accent, radius: 28, drop: 6)
    }

    private var categories: some View {
        VStack(alignment: .leading, spacing: 10) {
            SectionLabel("Pick a category")
            FlowLayout(spacing: 8) {
                ForEach(store.bank.categories, id: \.self) { category in
                    Button { round = RoundRequest(category: category) } label: {
                        Text(category)
                            .font(.subheadline.weight(.semibold))
                            .padding(.horizontal, 16)
                            .frame(minHeight: 44)
                    }
                    .buttonStyle(.chunky(fill: Theme.card, capsule: true))
                        .accessibilityHint("Starts a round of \(category) questions")
                }
            }
        }
    }

    private var powerUps: some View {
        VStack(alignment: .leading, spacing: 10) {
            SectionLabel("Your power-ups")
            FlowLayout(spacing: 8) {
                ForEach(PowerUp.allCases) { p in
                    Label("\(p.title) × \(store.wallet.count(of: p))", systemImage: p.systemImage)
                        .font(.footnote.weight(.semibold))
                        .foregroundStyle(Theme.ink)
                        .padding(.horizontal, 12)
                        .padding(.vertical, 8)
                        .background(Theme.pill.fill(Theme.card))
                        .overlay(Theme.pill.stroke(Theme.line, lineWidth: 1))
                }
            }
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
        .padding(.horizontal, 14)
        .frame(minHeight: 44)
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
