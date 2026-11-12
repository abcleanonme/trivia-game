import SwiftUI
import TriviaKit

/// Home card for today's Daily: play it, or (once played) see and share it.
struct DailyHomeCard: View {
    let onPlay: () -> Void

    @Environment(PlayerStore.self) private var store

    var body: some View {
        let today = store.today
        let record = store.todaysDaily
        VStack(alignment: .leading, spacing: 10) {
            HStack(alignment: .firstTextBaseline) {
                SectionLabel("Daily #\(today.dailyNumber)")
                Spacer()
                StreakBadge(days: store.dailyStreak, freezes: store.progress.streak.freezes)
            }
            if let record {
                Text(record.finished ? "\(record.correct) of \(record.marks.count) today" : "Left early today")
                    .font(Theme.display(.title2))
                    .foregroundStyle(Theme.ink)
                DailyGrid(marks: record.marks, size: 22)
                Text("A new Daily starts at midnight.")
                    .font(.subheadline)
                    .foregroundStyle(Theme.muted)
                if !record.marks.isEmpty {
                    DailyShareButton(record: record)
                }
            } else {
                Text("Same 10 questions for everyone. One try.")
                    .font(Theme.display(.title2))
                    .foregroundStyle(Theme.ink)
                    .fixedSize(horizontal: false, vertical: true)
                Text("Finish for +\(DailyChallenge.finishBonus) Sparks, or +\(DailyChallenge.perfectBonus) for a perfect 10.")
                    .font(.subheadline)
                    .foregroundStyle(Theme.muted)
                Button(action: onPlay) {
                    Text("Play the Daily")
                        .font(.headline)
                        .padding(.horizontal, 22)
                        .frame(minHeight: 48)
                }
                .buttonStyle(.chunky(fill: Theme.accent, foreground: .white, capsule: true))
            }
        }
        .padding(20)
        .frame(maxWidth: .infinity, alignment: .leading)
        .card(drop: 4)
    }
}

struct StreakBadge: View {
    let days: Int
    var freezes = 0

    var body: some View {
        HStack(spacing: 4) {
            Image(systemName: "flame.fill").foregroundStyle(days > 0 ? Theme.wrong : Theme.muted)
            Text("\(days)").monospacedDigit()
            if freezes > 0 {
                Image(systemName: "snowflake").foregroundStyle(Theme.accent)
            }
        }
        .font(.subheadline.bold())
        .foregroundStyle(Theme.ink)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("\(days)-day streak" + (freezes > 0 ? ", streak freeze ready" : ""))
    }
}

/// The spoiler-free grid: blue with a check for right, orange with a cross
/// for wrong, and a yellow ring for answers in under 5 seconds. Shape and
/// icon carry the meaning too, never color alone.
struct DailyGrid: View {
    let marks: [DailyMark]
    var size: CGFloat = 26

    var body: some View {
        HStack(spacing: size * 0.25) {
            ForEach(Array(marks.enumerated()), id: \.offset) { _, mark in
                ZStack {
                    RoundedRectangle(cornerRadius: size * 0.22, style: .continuous)
                        .fill(mark.correct ? ShareColors.right : ShareColors.wrong)
                    Image(systemName: mark.correct ? "checkmark" : "xmark")
                        .font(.system(size: size * 0.5, weight: .heavy))
                        .foregroundStyle(.white)
                }
                .frame(width: size, height: size)
                .overlay {
                    if mark.fast {
                        RoundedRectangle(cornerRadius: size * 0.32, style: .continuous)
                            .stroke(ShareColors.fast, lineWidth: max(2, size * 0.12))
                            .padding(-size * 0.14)
                    }
                }
            }
        }
        .padding(size * 0.14)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(accessibilityText)
    }

    private var accessibilityText: String {
        let right = marks.filter(\.correct).count
        let fast = marks.filter(\.fast).count
        return "\(right) of \(marks.count) right" + (fast > 0 ? ", \(fast) answered in under 5 seconds" : "")
    }
}

/// Fixed colors for the share image so it looks the same in any app it lands in.
enum ShareColors {
    static let right = Color(hex: 0x3B5BFD)
    static let wrong = Color(hex: 0xEA6A1E)
    static let fast = Color(hex: 0xFFC93C)
    static let paper = Color(hex: 0xF7F6F2)
    static let ink = Color(hex: 0x17172B)
}

/// The image that gets shared: day number, grid, score and streak. No
/// question text, so it can't spoil anyone's Daily.
struct DailyShareCard: View {
    let record: DailyRecord

    var body: some View {
        VStack(spacing: 14) {
            HStack {
                Text("Quizio\(Text(".").foregroundStyle(ShareColors.right))")
                    .font(.system(size: 30, weight: .bold, design: .rounded))
                Spacer()
                Text("Daily #\(record.day.dailyNumber)")
                    .font(.system(size: 20, weight: .bold, design: .rounded))
            }
            DailyGrid(marks: record.marks, size: 28)
            HStack(alignment: .firstTextBaseline) {
                Text("\(record.correct)/\(record.marks.count)")
                    .font(.system(size: 34, weight: .heavy, design: .rounded))
                Text("\(record.points.formatted()) pts")
                    .font(.system(size: 20, weight: .semibold, design: .rounded))
                Spacer()
                if record.streak > 1 {
                    Label("\(record.streak) days", systemImage: "flame.fill")
                        .font(.system(size: 18, weight: .bold, design: .rounded))
                }
            }
            if record.relaxed {
                Text("Relaxed mode · no clock")
                    .font(.system(size: 14, weight: .semibold))
                    .opacity(0.7)
            }
        }
        .foregroundStyle(ShareColors.ink)
        .padding(24)
        .frame(width: 420)
        .background(ShareColors.paper)
        .overlay(RoundedRectangle(cornerRadius: 28, style: .continuous).stroke(ShareColors.ink, lineWidth: 3))
        .clipShape(RoundedRectangle(cornerRadius: 28, style: .continuous))
        .environment(\.colorScheme, .light)
    }

    @MainActor
    func renderImage() -> Image? {
        let renderer = ImageRenderer(content: self.padding(12).background(Color.clear))
        renderer.scale = 3
        return renderer.uiImage.map { Image(uiImage: $0) }
    }
}

struct DailyShareButton: View {
    let record: DailyRecord

    var body: some View {
        let card = DailyShareCard(record: record)
        if let image = card.renderImage() {
            ShareLink(item: image, subject: Text("Quizio Daily #\(record.day.dailyNumber)"),
                      message: Text(record.shareText),
                      preview: SharePreview("Quizio Daily #\(record.day.dailyNumber)", image: image)) {
                Label("Share", systemImage: "square.and.arrow.up")
                    .font(.headline)
                    .padding(.horizontal, 22)
                    .frame(minHeight: 48)
            }
            .buttonStyle(.chunky(fill: Theme.spark, foreground: Theme.onSpark, capsule: true))
        } else {
            ShareLink(item: record.shareText) {
                Label("Share", systemImage: "square.and.arrow.up")
                    .font(.headline)
                    .padding(.horizontal, 22)
                    .frame(minHeight: 48)
            }
            .buttonStyle(.chunky(fill: Theme.spark, foreground: Theme.onSpark, capsule: true))
        }
    }
}

/// On the summary after a Daily: the card preview and the share button.
struct DailyShareSection: View {
    let record: DailyRecord

    var body: some View {
        VStack(spacing: 12) {
            DailyGrid(marks: record.marks, size: 26)
            if record.streak > 0 {
                Text(record.finished ? "\(record.streak)-day streak" : "Left early, so today won't extend your streak")
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(Theme.muted)
                    .multilineTextAlignment(.center)
            }
            DailyShareButton(record: record)
        }
        .frame(maxWidth: .infinity)
    }
}

extension Color {
    init(hex: UInt32) {
        self.init(red: Double((hex >> 16) & 0xFF) / 255,
                  green: Double((hex >> 8) & 0xFF) / 255,
                  blue: Double(hex & 0xFF) / 255)
    }
}

#Preview {
    DailyShareCard(record: DailyRecord(day: .launch, marks: (0..<10).map {
        DailyMark(correct: $0 % 3 != 0, fast: $0 % 4 == 0)
    }, points: 1_240, relaxed: false, finished: true, streak: 5))
}
