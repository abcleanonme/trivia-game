import SwiftUI
import TriviaKit

/// A row of small stats in one card: icon and label on top, value below,
/// hairlines between. Four across on phones; two rows of two when large
/// text needs the room.
struct StatStrip: View {
    struct Item: Identifiable {
        let label: String
        let value: String
        let systemImage: String
        var id: String { label }
    }

    let items: [Item]

    @Environment(\.dynamicTypeSize) private var typeSize

    var body: some View {
        let perRow = typeSize > .xLarge ? 2 : max(items.count, 1)
        let rows = stride(from: 0, to: items.count, by: perRow).map {
            Array(items[$0..<min($0 + perRow, items.count)])
        }
        VStack(spacing: 0) {
            ForEach(rows.indices, id: \.self) { r in
                if r > 0 { Rectangle().fill(Theme.line).frame(height: 1) }
                HStack(spacing: 0) {
                    ForEach(Array(rows[r].enumerated()), id: \.element.id) { i, item in
                        if i > 0 { Rectangle().fill(Theme.line).frame(width: 1) }
                        cell(item)
                    }
                }
                .fixedSize(horizontal: false, vertical: true)
            }
        }
        .card()
    }

    private func cell(_ item: Item) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Label(item.label, systemImage: item.systemImage)
                .labelStyle(CompactLabelStyle())
                .font(.caption2.weight(.semibold))
                .foregroundStyle(Theme.muted)
                .lineLimit(1)
                .minimumScaleFactor(0.8)
            Text(item.value)
                .font(Theme.display(.title3))
                .foregroundStyle(Theme.ink)
                .lineLimit(1)
                .minimumScaleFactor(0.7)
        }
        .padding(.horizontal, Space.m)
        .padding(.vertical, Space.m)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .accessibilityElement(children: .combine)
    }
}

/// Icon and title with a tight gap, for small captions.
struct CompactLabelStyle: LabelStyle {
    func makeBody(configuration: Configuration) -> some View {
        HStack(spacing: 3) {
            configuration.icon
            configuration.title
        }
    }
}

/// A labeled row of compact pill choices on the accent card. The label sits
/// beside the pills so each option set takes a single line.
struct OptionRow<Option: Hashable>: View {
    let label: String
    let options: [Option]
    @Binding var selection: Option
    let title: KeyPath<Option, String>
    /// For light cards: the picked chip is the blue one. Home's blue card
    /// uses the default, where the picked chip is white.
    var inverted = false

    @Environment(\.dynamicTypeSize) private var typeSize
    @ScaledMetric(relativeTo: .caption) private var labelWidth: CGFloat = 44

    var body: some View {
        let layout = typeSize > .xxLarge
            ? AnyLayout(VStackLayout(alignment: .leading, spacing: Space.xs))
            : AnyLayout(HStackLayout(alignment: .firstTextBaseline, spacing: Space.s))
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
                    .buttonStyle(ChunkyButtonStyle(fill: on != inverted ? Theme.card : Theme.accent,
                                                   foreground: on != inverted ? Theme.ink : .white,
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
        case "anime": "sparkles"
        case "food": "fork.knife"
        case "space": "moon.stars.fill"
        case "human body": "heart.fill"
        case "words": "textformat.abc"
        case "mythology": "shield.lefthalf.filled"
        case "holidays": "gift.fill"
        case "brands": "tag.fill"
        case "vehicles": "car.fill"
        case "cartoons": "face.smiling.fill"
        case "comics": "text.bubble.fill"
        default: "questionmark.circle.fill"
        }
    }
}

/// Pick any number of categories as chips. None picked means a mixed
/// round, shown by the "Mixed" chip; tapping it clears the picks.
struct CategoryChips: View {
    let categories: [String]
    @Binding var selection: [String]

    var body: some View {
        FlowLayout(spacing: 6) {
            chip("Mixed", symbol: "shuffle", on: selection.isEmpty) { selection = [] }
            ForEach(categories, id: \.self) { category in
                chip(category, symbol: CategoryStyle.symbol(for: category),
                     on: selection.contains(category)) { toggle(category) }
            }
        }
        .accessibilityElement(children: .contain)
        .accessibilityLabel("Categories")
    }

    private func toggle(_ category: String) {
        if let i = selection.firstIndex(of: category) {
            selection.remove(at: i)
        } else {
            selection = ChallengeSetup.ordered(selection + [category])
        }
    }

    private func chip(_ title: String, symbol: String, on: Bool, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Label(title, systemImage: on && title != "Mixed" ? "checkmark" : symbol)
                .labelStyle(CompactLabelStyle())
                .font(.footnote.weight(.bold))
                .padding(.horizontal, Space.m)
                .frame(minHeight: 36)
        }
        .buttonStyle(.chip(selected: on, depth: on ? 2 : 3))
        .accessibilityAddTraits(on ? .isSelected : [])
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
    /// The bolt grows with Dynamic Type alongside the number.
    @ScaledMetric(relativeTo: .subheadline) private var iconSize: CGFloat = 16

    var body: some View {
        HStack(spacing: 6) {
            SparkIcon(size: iconSize)
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
/// Each subview is measured once per pass and reused for placement.
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
            for (i, size) in zip(row.indices, row.sizes) {
                subviews[i].place(at: CGPoint(x: x, y: y), proposal: ProposedViewSize(size))
                x += size.width + spacing
            }
            y += row.height + spacing
        }
    }

    private struct Row {
        var indices: [Int] = []
        var sizes: [CGSize] = []
        var width: CGFloat = 0
        var height: CGFloat = 0
    }

    private func arrange(width: CGFloat, subviews: Subviews) -> [Row] {
        var rows: [Row] = []
        var row = Row()
        for i in subviews.indices {
            let size = subviews[i].sizeThatFits(.unspecified)
            if !row.indices.isEmpty, row.width + spacing + size.width > width {
                rows.append(row)
                row = Row()
            }
            row.width += (row.indices.isEmpty ? 0 : spacing) + size.width
            row.height = max(row.height, size.height)
            row.indices.append(i)
            row.sizes.append(size)
        }
        rows.append(row)
        return rows
    }
}

extension View {
    /// Caps a screen's content at a comfortable reading width and centers
    /// it, so iPad and the iPhone Duo inner display don't stretch lines.
    func readableWidth(_ maxWidth: CGFloat = 640) -> some View {
        frame(maxWidth: maxWidth).frame(maxWidth: .infinity)
    }
}

/// Rows in one outlined card with hairlines between them, so a list reads
/// as one block instead of loose cards.
struct DividedCard<Data: RandomAccessCollection, ID: Hashable, Row: View>: View {
    let data: Data
    let id: KeyPath<Data.Element, ID>
    let verticalPadding: CGFloat
    let row: (Data.Element) -> Row

    init(_ data: Data, id: KeyPath<Data.Element, ID>, verticalPadding: CGFloat = Space.xs,
         @ViewBuilder row: @escaping (Data.Element) -> Row) {
        self.data = data
        self.id = id
        self.verticalPadding = verticalPadding
        self.row = row
    }

    var body: some View {
        let firstID = data.first?[keyPath: id]
        VStack(spacing: 0) {
            ForEach(Array(data), id: id) { element in
                if element[keyPath: id] != firstID { Rectangle().fill(Theme.line).frame(height: 1) }
                row(element)
            }
        }
        .padding(.horizontal, Theme.cardPadding)
        .padding(.vertical, verticalPadding)
        .card()
    }
}

extension DividedCard where Data.Element: Identifiable, ID == Data.Element.ID {
    init(_ data: Data, verticalPadding: CGFloat = Space.xs, @ViewBuilder row: @escaping (Data.Element) -> Row) {
        self.init(data, id: \.id, verticalPadding: verticalPadding, row: row)
    }
}

extension ButtonStyle where Self == ChunkyButtonStyle {
    /// One pill in a row of choices; the picked one is filled with the accent.
    static func chip(selected: Bool, depth: CGFloat = 2) -> ChunkyButtonStyle {
        ChunkyButtonStyle(fill: selected ? Theme.accent : Theme.card,
                          foreground: selected ? .white : Theme.ink,
                          shape: AnyShape(Theme.pill), depth: depth)
    }
}
