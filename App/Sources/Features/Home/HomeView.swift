import SwiftUI
import TriviaKit

struct HomeView: View {
    @Environment(PlayerStore.self) private var store
    @AppStorage(SettingKey.relaxedMode) private var relaxedMode = false
    @AppStorage(SettingKey.gameMode) private var mode: GameMode = .classic
    @AppStorage(SettingKey.difficulty) private var difficulty: Difficulty = .mixed
    @AppStorage(SettingKey.categoryPicks) private var savedPicks = ""
    @State private var showAllCategories = false
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
            .padding(.bottom, Space.xl)
            .readableWidth()
        }
        .scrollBounceBehavior(.basedOnSize)
        .themeBackground()
        .toolbar(.hidden, for: .navigationBar)
        .fullScreenCover(item: $round) { request in
            GameView(request: request, relaxed: relaxedMode)
        }
        #if DEBUG
        .onAppear {
            if ProcessInfo.processInfo.arguments.contains("-autoplaySummary"), round == nil {
                round = request()
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
                    Text(eyebrow)
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
                // The off track is hard to see on the blue card in dark
                // mode; the light variant reads well on blue in both.
                .environment(\.colorScheme, .light)
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
            round = request()
        } label: {
            Label("Play", systemImage: "play.fill")
                .font(.title3.bold())
                .padding(.horizontal, Space.l)
                .frame(minHeight: 52)
        }
        .buttonStyle(.chunky(fill: Theme.spark, foreground: Theme.onSpark, capsule: true))
        .accessibilityHint("Starts a \(mode.title) round\(topic.map { " of \($0) questions" } ?? "")")
    }

    private var categoryColumns: [GridItem] {
        // Three tiles across. Large text gets two (or one) wider columns so
        // names don't truncate.
        let count = typeSize.isAccessibilitySize ? 1 : (typeSize > .xxLarge ? 2 : 3)
        return Array(repeating: GridItem(.flexible(), spacing: Space.s), count: count)
    }

    /// Picked categories, in Home's order, limited to ones still offered.
    private var picks: [String] {
        let offered = Set(store.bank.playableCategories)
        return ChallengeSetup.ordered(savedPicks.split(separator: "|").map(String.init).filter(offered.contains))
    }

    private func setPicks(_ new: [String]) {
        savedPicks = ChallengeSetup.ordered(new).joined(separator: "|")
    }

    private var topic: String? { ChallengeSetup.topicSummary(picks) }

    /// Tiles shown before "All categories" (three rows), so Home still fits
    /// on one screen on small phones.
    private static let collapsedCount = 9

    /// The tiles on show: the first few, plus any picked further down, or
    /// every category once expanded.
    private var shownCategories: [String] {
        let all = store.bank.playableCategories
        guard !showAllCategories, all.count > Self.collapsedCount + 1 else { return all }
        let first = Array(all.prefix(Self.collapsedCount))
        return first + all.dropFirst(Self.collapsedCount).filter(picks.contains)
    }

    private var categories: some View {
        let picked = picks
        let all = store.bank.playableCategories
        return VStack(alignment: .leading, spacing: Space.s) {
            HStack(alignment: .firstTextBaseline) {
                SectionLabel(picked.isEmpty ? "Category focus" : "Category focus · \(picked.count) picked")
                Spacer()
                if !picked.isEmpty {
                    Button("Clear") { setPicks([]) }
                        .font(.footnote.weight(.bold))
                        .foregroundStyle(Theme.accent)
                        .accessibilityHint("Goes back to a mixed round")
                }
            }
            Text(picked.isEmpty ? "Tap one or more, then Play. None picked plays a mix." : "Play draws only from these.")
                .font(.caption)
                .foregroundStyle(Theme.muted)
            LazyVGrid(columns: categoryColumns, spacing: Space.s) {
                ForEach(shownCategories, id: \.self) { category in
                    let on = picked.contains(category)
                    Button {
                        setPicks(on ? picked.filter { $0 != category } : picked + [category])
                    } label: {
                        HStack(spacing: 6) {
                            Image(systemName: on ? "checkmark" : CategoryStyle.symbol(for: category))
                                .font(.footnote.weight(.bold))
                                .foregroundStyle(on ? .white : Theme.accent)
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
                    .buttonStyle(ChunkyButtonStyle(fill: on ? Theme.accent : Theme.card,
                                                   foreground: on ? .white : Theme.ink,
                                                   shape: AnyShape(RoundedRectangle(cornerRadius: 14, style: .continuous)),
                                                   depth: on ? 2 : 3))
                    .accessibilityAddTraits(on ? .isSelected : [])
                    .accessibilityHint(on ? "Removes \(category) from the round" : "Adds \(category) to the round")
                }
            }
            if all.count > Self.collapsedCount + 1 {
                Button {
                    withAnimation(.snappy) { showAllCategories.toggle() }
                } label: {
                    Label(showAllCategories ? "Fewer categories" : "All \(all.count) categories",
                          systemImage: showAllCategories ? "chevron.up" : "chevron.down")
                        .font(.footnote.weight(.bold))
                        .frame(maxWidth: .infinity, minHeight: 36)
                }
                .buttonStyle(ChunkyButtonStyle(fill: Theme.card, foreground: Theme.accent,
                                               shape: AnyShape(Theme.pill), depth: 2))
            }
        }
    }

    private func request() -> RoundRequest {
        RoundRequest(kind: .solo(mode: mode, categories: picks, difficulty: difficulty))
    }

    /// "Classic", "Classic · Relaxed", "Classic · Science & Art".
    private var eyebrow: String {
        var parts = [mode.title]
        if relaxedApplies { parts.append("Relaxed") }
        if let topic { parts.append(topic) }
        return parts.joined(separator: " · ")
    }

    private var relaxedApplies: Bool { relaxedMode && mode.supportsRelaxed }

    private var headline: String {
        switch mode {
        case .classic: "10 questions.\n\(difficulty == .mixed ? (picks.isEmpty ? "Mixed bag." : "Your picks.") : "\(difficulty.title) ones.")"
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
            HStack(alignment: .firstTextBaseline) {
                SectionLabel("Your power-ups")
                Spacer()
                NavigationLink { PowerUpShopView() } label: {
                    Label("Get more", systemImage: "bolt.fill")
                        .font(.footnote.weight(.bold))
                        .padding(.horizontal, Space.m)
                        .frame(minHeight: 32)
                }
                .buttonStyle(ChunkyButtonStyle(fill: Theme.spark, foreground: Theme.onSpark,
                                               shape: AnyShape(Theme.pill), depth: 2))
            }
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

#Preview {
    NavigationStack { HomeView() }
        .environment(PlayerStore.preview)
}
