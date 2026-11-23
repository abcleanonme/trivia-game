# Weekly events and content updates

How the weekly event calendar works, what's already stocked, and how to ship
new questions every two weeks or every month.

## What's bundled now

Every week (Monday to Sunday, player's local time) runs one event. Holidays
take over the week their day falls in; the other weeks cycle through the
10-theme rotation, and every rotation theme gets its turn before any repeats.
The rules live in `WeeklyEvent.swift` and repeat every year on their own,
so the calendar never runs out. Only Lunar New Year needs a date table
(`WeeklyEvent.lunarNewYearDates`, filled through 2036).

| Week of | Event | Kind |
|---|---|---|
| Nov 23, 2026 | Thanksgiving Feast | Holiday |
| Nov 30, 2026 | Space Week | Rotation |
| Dec 7, 2026 | Totally 80s | Rotation |
| Dec 14, 2026 | Wild Week | Rotation |
| Dec 21, 2026 | Christmas Week | Holiday |
| Dec 28, 2026 | New Year Countdown | Holiday |
| Jan 4, 2027 | Myths and Legends | Rotation |
| Jan 11, 2027 | Capital Cities | Rotation |
| Jan 18, 2027 | Dream Week (MLK Day) | Holiday |
| Jan 25, 2027 | Retro Games | Rotation |
| Feb 1, 2027 | Big Game Week | Holiday |
| Feb 8, 2027 | Sweetheart Week (Valentine's) | Holiday |
| Feb 15, 2027 | Lunar New Year | Holiday |
| Feb 22, 2027 | Ocean Week | Rotation |
| Mar 1, 2027 | 90s Throwback | Rotation |
| Mar 8, 2027 | Pi Day | Holiday |
| Mar 15, 2027 | Luck of the Irish (St. Patrick's) | Holiday |
| Mar 22, 2027 | Egg Hunt (Easter) | Holiday |
| Mar 29, 2027 | Fact or Fool (April Fools') | Holiday |
| Apr 5, 2027 | Football Fever | Rotation |
| Apr 12, 2027 | Food Fight | Rotation |
| Apr 19, 2027 | Earth Week | Holiday |
| Apr 26 – Jun 27, 2027 | Rotation (Space, 80s, Wild, Myths, Capitals, Retro, Ocean, 90s, Football, Food) | Rotation |
| Oct 25, 2027 | Spooky Week (Halloween) | Holiday |

`EventCalendarTests.winterAndSpring2027Schedule` pins the holiday weeks above,
so a code change that moves one fails the tests.

**Clashes.** Holidays are listed most important first in `WeeklyEvent.holidays`.
When two land in one week, the later one tries its next allowed week, or sits
that year out. In 2027 the Big Game falls on Valentine's Day, so Big Game Week
runs the week before (Feb 1), and Lunar New Year (Feb 6) moves to Feb 15,
still inside the 15-day festival. `noHolidayIsCrowdedOutForYears` checks
that no holiday is skipped from 2027 through 2036.

The Big Game event avoids the NFL's "Super Bowl" trademark in its title and
art. Questions can still name it, which is ordinary factual use.

## Where event questions come from

An event's pool is its own tagged questions plus any bank question its
keyword pattern matches:

- `App/Resources/events.json` holds questions written for one event. Each has
  an `"event"` field with the event's id (`christmas`, `valentines`...). These
  play **only** in their event, never in everyday rounds or the Daily, so a
  holiday's questions are still fresh when its week comes.
- The keyword `pattern` also pulls matching questions from the main bank
  (`originals.json`, `originals-ai.json`, `opentdb.json`). Keep patterns
  tight. Use `(?-i:...)` for words that clash with proper nouns (Turkey, The
  Cranberries, the Romantic art movement).

Every event needs `WeeklyEvent.minimumPool` (50) questions, which is five
rounds before a repeat. `BundledEventTests.everyThemeHasEnoughQuestions`
fails if one drops below. Current pools:

| Event | Pool | Event | Pool |
|---|---|---|---|
| Christmas | 64 | Easter | 64 |
| New Year | 58 | April Fools | 55 |
| MLK Day | 56 | Earth Day | 56 |
| Lunar New Year | 55 | Thanksgiving | 60 |
| Big Game | 71 | Halloween | 103 |
| Valentine's | 55 | Football (rotation) | 78 |
| Pi Day | 63 | Other rotation themes | 75 to 279 |
| St. Patrick's | 57 | | |

The 601 questions in `events.json` were AI-drafted for this release and
carry `"reviewed": false` until the reviewer task checks them.

## Adding or changing an event

1. Add a `WeeklyEvent` in `WeeklyEvent.swift`: id, title, blurb, SF Symbol,
   a tight keyword pattern, and a `rewardID`.
2. Holiday: add a `Holiday` to `WeeklyEvent.holidays` with its date rule and
   allowed weeks, in priority order. Rotation theme: append it to `rotation`
   (appending keeps the order of the others).
3. Add the reward to `CosmeticCatalog` with `unlock: .event("<id>")`.
4. Write at least 50 questions (60+ is better) into `events.json`, tagged with
   the event id. Skip facts that are already in the main bank.
5. Run the TriviaKit tests and update the calendar table above.

Never rename or remove an event id that has run: saved progress is keyed by
it (`<id>@<week>`). Retire an event by taking it out of the schedule only.

## Shipping question updates

The app works offline and has no server, so new questions ship inside an app
update. A content-only update is a normal App Store version (1.0.1, 1.0.2...)
with only JSON changes.

**Cadence: monthly, on the first Monday.** Every two weeks also works if the
writer and reviewer are keeping up. The bundled calendar runs well past three
months, so a missed update never breaks anything; the app just repeats
questions sooner.

Each update:

1. **Merge reviewed questions.** Merge the reviewer's open "Weekly questions"
   PRs (only `reviewed: true` batches) into `main`.
2. **Top up the next two months of events.** Check the calendar above for the
   events in the next 8 weeks. Any holiday under 60 questions gets 10 to 20
   more in `events.json`.
3. **Run the tests.** `cd Packages/TriviaKit && swift test` (or Cmd-U in
   Xcode). The bundled-bank and event tests catch broken JSON, duplicates and
   thin pools.
4. **Bump the version** in `project.yml`: `MARKETING_VERSION` up one patch
   (1.0.0 → 1.0.1) and `CURRENT_PROJECT_VERSION` up one.
5. **Notes.** Add a short entry to `CHANGELOG.md` and `scripts/testflight-notes.txt`,
   for example "200 new questions, plus fresh ones for Valentine's and Lunar
   New Year."
6. **Upload** with `scripts/testflight.sh`, give it a day on TestFlight, then
   submit it in App Store Connect with the same note as "What's New".

Ship each update at least a week before the first holiday it adds questions
for: App Review usually takes a day or two, and players need time to update.
Avoid counting on review over Christmas week.

## Proposal: a remote question feed (not built)

A feed would let new questions reach players without an App Store release.
It's doable without breaking "Data Not Collected", but it isn't worth
building for 1.0.

**How it would work**
- A static, versioned JSON file (same schema as `events.json`) on GitHub Pages
  or a CDN. No accounts, no IDs, no analytics, no cookies.
- The app fetches it at most once a day, checks a signature (an Ed25519 key
  bundled in the app) and the schema, and caches it. If anything fails, it
  keeps using the bundled and cached questions.
- Bundled questions stay the floor, so the app still works fully offline.

**Why it's safe for a paid, no-data app**
- Apple counts data as "collected" only when it leaves the device and is kept.
  A plain download sends nothing of the player's, so the privacy label stays
  "Data Not Collected". The host still sees IP addresses in its logs; pick one
  that doesn't keep or use them, and mention the download in the privacy policy.
- App Review allows downloading content such as questions (guideline 2.5.2 bans
  only downloaded code).

**Why not now**
- About a day of work plus a signing step on every publish, and a new way for
  bad content to reach players without TestFlight first.
- Monthly releases already cover the need, and the bundle holds three months
  or more of events.
- Revisit after 1.0 if releases start feeling slow, or if events need to change
  on short notice.
