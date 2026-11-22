import SwiftUI
import TriviaKit

/// A finished (or in-progress) match, question by question: final
/// standings, then every question with the answer each player picked.
/// With Live replay on, the answers play back as they happened, with a
/// skip button to jump ahead.
struct MatchBreakdownView: View {
    let match: ArchivedMatch
    let me: String
    /// Shown inside the result screen instead of as its own sheet.
    var embedded = false

    @AppStorage(SettingKey.liveReplay) private var liveReplay = true
    @Environment(\.dismiss) private var dismiss

    private var data: ChallengeData { match.data }
    private var questions: [ReplayQuestion] { data.replay(among: match.playerIDs) }

    var body: some View {
        if embedded {
            content
        } else {
            ScrollView {
                VStack(alignment: .leading, spacing: Space.l) {
                    StandingsCard(match: match, me: me)
                    content
                }
                .padding(.horizontal, Theme.gutter)
                .padding(.vertical, Space.m)
                .readableWidth()
            }
            .themeBackground()
            .navigationTitle(match.isGroup ? "Group match" : "Match breakdown")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) { Button("Done") { dismiss() } }
            }
        }
    }

    @ViewBuilder private var content: some View {
        VStack(alignment: .leading, spacing: Space.m) {
            HStack {
                SectionLabel("Question by question")
                Spacer()
                Toggle(isOn: $liveReplay) {
                    Label("Live replay", systemImage: "play.circle.fill")
                        .font(.footnote.weight(.bold))
                        .foregroundStyle(Theme.ink)
                }
                .fixedSize()
                .tint(Theme.accent)
                .disabled(!data.hasReplay)
            }
            if !data.hasReplay {
                Text("This match was played on an older Quizio, so only right and wrong were saved.")
                    .font(.footnote)
                    .foregroundStyle(Theme.muted)
                    .fixedSize(horizontal: false, vertical: true)
            } else if liveReplay {
                ReplayStage(match: match, questions: questions, me: me)
            } else {
                ForEach(questions) { q in
                    QuestionBreakdownCard(question: q, total: questions.count, match: match, me: me,
                                          shownCount: q.answers.count, revealed: true)
                }
            }
        }
    }
}

// MARK: Standings

/// Everyone's final score, best first, with places for a group.
struct StandingsCard: View {
    let match: ArchivedMatch
    let me: String

    var body: some View {
        let standings = match.data.standings(among: match.playerIDs)
        let waiting = match.playerIDs.filter { !match.data.hasPlayed($0) }
        VStack(spacing: 0) {
            ForEach(Array(standings.enumerated()), id: \.offset) { i, entry in
                if i > 0 { Divider().overlay(Theme.line) }
                row(entry.playerID, place: entry.place, winner: entry.place == 1 && standings.count > 1)
            }
            ForEach(waiting, id: \.self) { id in
                Divider().overlay(Theme.line)
                row(id, place: nil, winner: false)
            }
        }
        .padding(.horizontal, Theme.cardPadding)
        .padding(.vertical, Space.xs)
        .card()
    }

    private func row(_ id: String, place: Int?, winner: Bool) -> some View {
        let turn = match.data.turn(for: id)
        let name = id == me ? "You" : match.names[id] ?? "Player"
        return HStack(spacing: Space.m) {
            PlayerAvatar(name: name, card: match.data.player(id)?.card, size: 40,
                         badge: badge(place: place, winner: winner))
            VStack(alignment: .leading, spacing: 2) {
                HStack(spacing: 6) {
                    Text(name).font(id == me ? .headline.weight(.heavy) : .headline).lineLimit(1)
                    if winner && match.isGroup {
                        Image(systemName: "crown.fill").foregroundStyle(Theme.spark).accessibilityLabel("Winner")
                    }
                }
                Text(turn.map { "\($0.correctCount) of \($0.answers.count) correct · best streak \($0.bestStreak)" }
                     ?? "Hasn't played yet")
                    .font(.footnote)
                    .foregroundStyle(Theme.muted)
            }
            Spacer(minLength: Space.s)
            Text(turn.map { $0.points.formatted() } ?? "–")
                .font(Theme.display(.title3))
                .monospacedDigit()
        }
        .foregroundStyle(Theme.ink)
        .padding(.vertical, 10)
        .background {
            if id == me {
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .fill(Theme.spark.opacity(0.22))
                    .padding(.horizontal, -Space.s)
            }
        }
        .accessibilityElement(children: .combine)
    }

    private func badge(place: Int?, winner: Bool) -> PlayerAvatar.Badge? {
        guard let place else { return .waiting }
        if match.isGroup { return .place(place) }
        return winner ? .crown : nil
    }
}

// MARK: One question

/// A question with its choices and who picked what. `shownCount` answers
/// (fastest first) are visible; `revealed` marks the right answer.
struct QuestionBreakdownCard: View {
    let question: ReplayQuestion
    let total: Int
    let match: ArchivedMatch
    let me: String
    var shownCount: Int
    var revealed: Bool

    private var shown: [ReplayQuestion.Answer] { Array(question.answers.prefix(shownCount)) }

    var body: some View {
        let q = question.question
        VStack(alignment: .leading, spacing: Space.m) {
            HStack(spacing: Space.s) {
                Text(question.isSpare ? "Skip swap" : "Question \(question.index + 1) of \(total)")
                    .eyebrow()
                    .foregroundStyle(Theme.muted)
                Spacer()
                Label(q.category, systemImage: CategoryStyle.symbol(for: q.category))
                    .labelStyle(CompactLabelStyle())
                    .font(.caption.weight(.bold))
                    .foregroundStyle(Theme.muted)
            }
            Text(q.prompt)
                .font(.headline)
                .fixedSize(horizontal: false, vertical: true)
            VStack(spacing: Space.s) {
                ForEach(q.choices.indices, id: \.self) { i in choiceRow(i) }
                let timedOut = shown.filter { $0.pick.timedOut }
                if !timedOut.isEmpty { extraRow("Out of time", "timer", timedOut.map(\.playerID)) }
            }
            if revealed {
                let others = question.skipped + question.didNotReach
                if !question.skipped.isEmpty {
                    note("forward.fill", "\(names(question.skipped)) used Skip here")
                }
                if !question.didNotReach.isEmpty {
                    note("flag.checkered", "\(names(question.didNotReach)) didn't get this far")
                }
                if others.isEmpty, let fastest = question.answers.first(where: { $0.pick.correct }),
                   question.answers.count > 1 {
                    note("hare.fill", "Fastest right answer: \(name(fastest.playerID)), \(fastest.pick.seconds.formatted(.number.precision(.fractionLength(1))))s")
                }
            }
        }
        .foregroundStyle(Theme.ink)
        .padding(Theme.cardPadding)
        .frame(maxWidth: .infinity, alignment: .leading)
        .card()
    }

    private func choiceRow(_ i: Int) -> some View {
        let q = question.question
        let pickers = shown.filter { $0.pick.choice == i }
        let isRight = q.isCorrect(i)
        let fill: Color = revealed && isRight ? Theme.correct.opacity(0.18)
            : revealed && !pickers.isEmpty ? Theme.wrong.opacity(0.12) : Theme.paper
        let stroke: Color = revealed && isRight ? Theme.correct : Theme.line
        return HStack(spacing: Space.s) {
            if revealed {
                Image(systemName: isRight ? "checkmark.circle.fill" : pickers.isEmpty ? "circle" : "xmark.circle.fill")
                    .foregroundStyle(isRight ? Theme.correct : pickers.isEmpty ? Theme.line : Theme.wrong)
                    .accessibilityHidden(true)
            }
            // Picks sit beside the answer when they fit on one line,
            // and drop under it when they don't, so they never spill out of the row.
            ViewThatFits(in: .horizontal) {
                HStack(spacing: Space.s) {
                    choiceText(i, bold: revealed && isRight).lineLimit(1)
                    Spacer(minLength: 0)
                    pickerFaces(pickers)
                }
                VStack(alignment: .leading, spacing: Space.xs) {
                    choiceText(i, bold: revealed && isRight)
                        .fixedSize(horizontal: false, vertical: true)
                        .frame(maxWidth: .infinity, alignment: .leading)
                    if !pickers.isEmpty { pickerFaces(pickers) }
                }
            }
        }
        .padding(.horizontal, Space.m)
        .padding(.vertical, Space.xs)
        .frame(minHeight: 44)
        .background(RoundedRectangle(cornerRadius: 14, style: .continuous).fill(fill))
        .overlay(RoundedRectangle(cornerRadius: 14, style: .continuous).stroke(stroke, lineWidth: 1.5))
        .animation(.spring(response: 0.35, dampingFraction: 0.7), value: pickers.map(\.playerID))
        .animation(.easeOut(duration: 0.25), value: revealed)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(q.choices[i] + (revealed && isRight ? ", correct answer" : "")
                            + (pickers.isEmpty ? "" : ". Picked by \(names(pickers.map(\.playerID)))"))
    }

    private func extraRow(_ label: String, _ icon: String, _ ids: [String]) -> some View {
        HStack(spacing: Space.s) {
            Label(label, systemImage: icon)
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(Theme.muted)
                .frame(maxWidth: .infinity, alignment: .leading)
            pickerFaces(shown.filter { ids.contains($0.playerID) })
        }
        .padding(.horizontal, Space.m)
        .frame(minHeight: 44)
        .accessibilityElement(children: .combine)
    }

    private func choiceText(_ i: Int, bold: Bool) -> some View {
        Text(question.question.choices[i])
            .font(.subheadline.weight(bold ? .bold : .semibold))
    }

    /// Each pick as a small chip: the player's face with their time or points
    /// beside it once revealed. Sized to sit inside a 44pt row.
    private func pickerFaces(_ answers: [ReplayQuestion.Answer]) -> some View {
        HStack(spacing: 4) {
            ForEach(answers, id: \.playerID) { a in
                HStack(spacing: 4) {
                    PlayerAvatar(name: name(a.playerID), card: match.data.player(a.playerID)?.card, size: 22,
                                 expands: false)
                        .padding(3) // room for a card border ring
                    if revealed {
                        Text(a.pick.points > 0 ? "+\(a.pick.points)" : "\(a.pick.seconds.formatted(.number.precision(.fractionLength(1))))s")
                            .font(.caption2.weight(.heavy))
                            .foregroundStyle(a.pick.points > 0 ? Theme.correct : Theme.muted)
                            .monospacedDigit()
                            .lineLimit(1)
                            .fixedSize()
                            .padding(.trailing, 6)
                    }
                }
                .background(Capsule().fill(Theme.card.opacity(revealed ? 1 : 0)))
                .dynamicTypeSize(...DynamicTypeSize.xxLarge)
                .transition(.scale(scale: 0.2).combined(with: .opacity))
            }
        }
        .fixedSize()
    }

    private func note(_ icon: String, _ text: String) -> some View {
        Label(text, systemImage: icon)
            .font(.caption.weight(.semibold))
            .foregroundStyle(Theme.muted)
            .fixedSize(horizontal: false, vertical: true)
    }

    private func name(_ id: String) -> String { id == me ? "You" : match.names[id] ?? "Player" }
    private func names(_ ids: [String]) -> String { ids.map(name).formatted(.list(type: .and)) }
}

// MARK: Live replay

/// Plays a match back in real time: each player's avatar lands on their
/// pick when they picked it, then the right answer shows. Skip shows the
/// rest of this question's answers at once; pressed again, it moves on.
struct ReplayStage: View {
    let match: ArchivedMatch
    let questions: [ReplayQuestion]
    let me: String

    @State private var index = 0
    @State private var elapsed: Double = 0
    @State private var revealed = false
    @State private var playing = true
    @State private var finished = false
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    /// A slow untimed answer is squeezed so no question plays longer than this.
    private static let longestQuestion = GameRules.questionTime
    /// Pause on the revealed answer before moving on.
    private static let revealPause: Double = 2.4

    private var current: ReplayQuestion? { questions.indices.contains(index) ? questions[index] : nil }

    /// Playback seconds for a pick, squeezed for slow untimed rounds.
    private func playbackTime(_ seconds: Double, in q: ReplayQuestion) -> Double {
        let scale = q.duration > Self.longestQuestion ? Self.longestQuestion / q.duration : 1
        return seconds * scale
    }

    private func shownCount(_ q: ReplayQuestion) -> Int {
        revealed ? q.answers.count : q.answers.filter { playbackTime($0.pick.seconds, in: q) <= elapsed }.count
    }

    var body: some View {
        VStack(alignment: .leading, spacing: Space.m) {
            if finished || current == nil {
                finishedCard
            } else if let q = current {
                progress(q)
                QuestionBreakdownCard(question: q, total: questions.filter { !$0.isSpare }.count, match: match,
                                      me: me, shownCount: shownCount(q), revealed: revealed)
                    .id(q.id)
                    .transition(reduceMotion ? .opacity : .asymmetric(insertion: .move(edge: .trailing).combined(with: .opacity),
                                                                      removal: .move(edge: .leading).combined(with: .opacity)))
                playerStrip(q)
                controls
            }
        }
        .task(id: "\(index)-\(playing)-\(revealed)-\(finished)") { await run() }
    }

    /// Advances the clock while playing; reveals once everyone has
    /// answered, then moves on after a pause.
    private func run() async {
        guard playing, !finished, let q = current else { return }
        let clock = ContinuousClock()
        var last = clock.now
        let end = playbackTime(q.duration, in: q) + 0.5
        while !Task.isCancelled && !revealed {
            try? await Task.sleep(for: .milliseconds(50))
            let now = clock.now
            elapsed += (now - last) / .seconds(1)
            last = now
            if elapsed >= end {
                withAnimation { revealed = true }
                return
            }
        }
        guard revealed, !Task.isCancelled else { return }
        try? await Task.sleep(for: .seconds(Self.revealPause))
        if !Task.isCancelled { next() }
    }

    private func next() {
        withAnimation(.snappy) {
            if index + 1 < questions.count {
                index += 1
                elapsed = 0
                revealed = false
            } else {
                finished = true
            }
        }
    }

    private func skip() {
        if revealed {
            next()
        } else {
            withAnimation { revealed = true }
        }
    }

    private func restart() {
        withAnimation(.snappy) {
            index = 0
            elapsed = 0
            revealed = false
            finished = false
            playing = true
        }
    }

    private func progress(_ q: ReplayQuestion) -> some View {
        let length = max(playbackTime(q.duration, in: q) + 0.5, 0.1)
        let fraction = revealed ? 1 : min(elapsed / length, 1)
        return VStack(alignment: .leading, spacing: Space.xs) {
            HStack {
                Label(revealed ? "Answers in" : playing ? "Replaying live" : "Paused",
                      systemImage: revealed ? "checkmark.seal.fill" : playing ? "dot.radiowaves.left.and.right" : "pause.fill")
                    .font(.caption.weight(.heavy))
                    .foregroundStyle(revealed ? Theme.correct : Theme.accent)
                Spacer()
                Text("\(index + 1)/\(questions.count)")
                    .font(.caption.weight(.heavy).monospacedDigit())
                    .foregroundStyle(Theme.muted)
            }
            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    Capsule().fill(Theme.line)
                    Capsule().fill(revealed ? Theme.correct : Theme.accent)
                        .frame(width: geo.size.width * fraction)
                }
            }
            .frame(height: 6)
            .accessibilityHidden(true)
        }
    }

    /// Everyone in the match: thinking, or locked in (right or wrong once revealed).
    private func playerStrip(_ q: ReplayQuestion) -> some View {
        let shown = Set(q.answers.prefix(shownCount(q)).map(\.playerID))
        let ids = match.playerIDs.filter { match.data.hasPlayed($0) }
        return FlowLayout(spacing: Space.s) {
            ForEach(ids, id: \.self) { id in
                let answer = q.answer(for: id)
                let badge = stripBadge(locked: shown.contains(id), answer: answer)
                VStack(spacing: 2) {
                    PlayerAvatar(name: name(id), card: match.data.player(id)?.card, size: 36, badge: badge)
                        .opacity(answer == nil ? 0.4 : 1)
                    Text(name(id))
                        .font(.caption2.weight(.bold))
                        .foregroundStyle(Theme.ink)
                        .lineLimit(1)
                }
                .frame(width: 56)
            }
        }
    }

    private func stripBadge(locked: Bool, answer: ReplayQuestion.Answer?) -> PlayerAvatar.Badge? {
        if locked { return revealed && answer?.pick.correct != true ? nil : .check }
        return answer == nil ? nil : .waiting
    }

    private var controls: some View {
        HStack(spacing: Space.s) {
            Button(action: restart) {
                Image(systemName: "backward.end.fill").font(.headline).frame(width: 44, height: 44)
            }
            .buttonStyle(.chunky(fill: Theme.card, capsule: true))
            .accessibilityLabel("Restart replay")
            Button { playing.toggle() } label: {
                Image(systemName: playing ? "pause.fill" : "play.fill").font(.headline).frame(width: 44, height: 44)
            }
            .buttonStyle(.chunky(fill: Theme.card, capsule: true))
            .accessibilityLabel(playing ? "Pause" : "Play")
            Button(action: skip) {
                Label(revealed ? (index + 1 < questions.count ? "Next question" : "Finish") : "Skip",
                      systemImage: revealed ? "arrow.right" : "forward.fill")
                    .font(.headline)
                    .frame(maxWidth: .infinity, minHeight: 44)
            }
            .buttonStyle(.chunky(fill: Theme.accent, foreground: .white, capsule: true))
            .accessibilityHint(revealed ? "Shows the next question" : "Shows everyone's answer now")
        }
    }

    private var finishedCard: some View {
        VStack(spacing: Space.m) {
            Image(systemName: "flag.checkered")
                .font(.system(size: 34, weight: .bold))
                .foregroundStyle(Theme.accent)
                .accessibilityHidden(true)
            Text("That's the whole match").font(Theme.display(.title3))
            Button(action: restart) {
                Label("Watch again", systemImage: "arrow.counterclockwise")
                    .font(.headline)
                    .padding(.horizontal, Space.l)
                    .frame(minHeight: 44)
            }
            .buttonStyle(.chunky(fill: Theme.accent, foreground: .white, capsule: true))
        }
        .foregroundStyle(Theme.ink)
        .frame(maxWidth: .infinity)
        .padding(Theme.cardPadding)
        .card()
    }

    private func name(_ id: String) -> String { id == me ? "You" : match.names[id] ?? "Player" }
}
