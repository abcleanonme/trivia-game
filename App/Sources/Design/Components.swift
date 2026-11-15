import SwiftUI

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
