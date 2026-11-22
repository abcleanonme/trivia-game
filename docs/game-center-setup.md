# Game Center setup (App Store Connect)

The Friends tab's leaderboards read and post to these Game Center
leaderboards. Until they exist in App Store Connect, each board in the app
says "This leaderboard isn't live yet" and posting fails quietly (it retries
on the next refresh). Challenges don't need any of this.

App Store Connect → Apps → Quizio → Services → Game Center → Leaderboards → +.
The ID must match exactly (see `FriendBoard.leaderboardID`).

| Reference name   | Leaderboard ID                      | Type                    | Score submission | Sort         | Format  |
|------------------|-------------------------------------|-------------------------|------------------|--------------|---------|
| Daily            | `com.abcapps.trivia.daily`          | Recurring, every 1 day  | Best score       | High to low  | Integer |
| Weekly event     | `com.abcapps.trivia.weekly`         | Recurring, every 7 days | Best score       | High to low  | Integer |
| Daily streak     | `com.abcapps.trivia.streak`         | Classic                 | Most recent      | High to low  | Integer |
| Challenge wins   | `com.abcapps.trivia.challengewins`  | Classic                 | Best score       | High to low  | Integer |
| Correct answers  | `com.abcapps.trivia.correct`        | Classic                 | Best score       | High to low  | Integer |
| Survival         | `com.abcapps.trivia.survival`       | Classic                 | Best score       | High to low  | Integer |
| Speed round      | `com.abcapps.trivia.speed`          | Classic                 | Best score       | High to low  | Integer |

Notes

- **Daily** is a recurring leaderboard so it resets every day. Its start time
  is in UTC, but the Daily changes at each player's local midnight, so every
  score is tagged with the Daily's day number (the score's context) and the
  app shows only scores for today's Daily. Relaxed (no clock) Dailies are
  never posted.
- **Weekly event** is recurring every 7 days, starting Monday 2026-11-16
  00:00 UTC. The score is the player's best *timed* round in that week's
  event (not their track total, so replaying more doesn't beat playing
  well), tagged with the week number as its context. The Weekly tab shows
  this week and last week.
- The Daily and Weekly tabs also show yesterday's Daily and last week's
  event by reading the leaderboard's previous occurrence. Game Center keeps
  only the current and previous occurrence for friends, so older history is
  your own results, kept on the phone.
- **Daily streak** must be "Most recent score" so a broken streak drops back
  down instead of keeping the old best.
- Each leaderboard needs at least one localization (English: display name and
  a score format suffix like "points", "days", "wins" or "correct").
- The app shows friends only (`.friendsOnly`). Global ranks are still visible
  in Apple's Games app.

## Friends list

The Friends section asks for access to the player's Game Center friends the
first time they tap "Show friends". The prompt text is
`NSGKFriendListUsageDescription` in `App/Info.plist`.

Game Center doesn't let one player see matches between two *other* players,
so head-to-head history is your own games against each friend, kept on the
phone (`ChallengeHistory`). Showing friend-vs-friend records would need a
server of our own.
