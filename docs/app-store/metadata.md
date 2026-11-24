# App Store listing (draft for 1.0)

Paste into App Store Connect → Quizio → App Store → iOS App 1.0.
Character limits are Apple's; counts are noted where they're tight.

## App information

| Field | Value |
|---|---|
| Name (30) | Quizio - Trivia with Friends (28) |
| Subtitle (30) | No ads. Just trivia. (20) |
| Bundle ID | com.abcapps.trivia |
| SKU | quizio-ios |
| Primary category | Games → Trivia |
| Secondary category | Games → Word *(or leave empty)* |
| Age rating | 4+ (questionnaire: answer "None" everywhere; no web access, no user-generated content, no unrestricted chat) |
| Price | Paid, tier to be picked by Dillon |
| Content rights | Contains third-party content: yes (Open Trivia Database questions, CC BY-SA 4.0, credited in Settings). |
| Copyright | 2026 <your name or company> |

Alternative subtitles if the first is taken or feels flat:
- "Ad-free trivia with friends" (27)
- "Daily trivia, no ads" (20)

## Keywords (100, comma separated, no spaces)

```
quiz,daily,brain,general knowledge,facts,challenge,multiplayer,game center,survival,pub quiz,offline
```

(100 characters, at the limit. Don't repeat words from the name or subtitle; Apple indexes those already.)

## Promotional text (170)

> Thanksgiving Feast is live: 50 holiday questions and a Harvest Leaf emblem through Nov 29. Play the Daily, then challenge your friends.

Promotional text can change any time without a new build, so update it per weekly event.

## Description (4000)

> Quizio is trivia and nothing else. No ads. No in-app purchases. No accounts. Buy it once and play.
>
> PLAY YOUR WAY
> • Classic: 10 questions, mixed or from the categories you pick.
> • Survival: three lives. How far can you go?
> • Speed Round: 60 seconds, as many as you can.
> • Relaxed mode turns off the clock when you just want to think.
>
> A NEW DAILY EVERY DAY
> Everyone gets the same Daily. Keep your streak going and see how you stack up against your Game Center friends.
>
> WEEKLY EVENTS
> Themed weeks with new questions and emblems to collect.
>
> CHALLENGE YOUR FRIENDS
> Send a challenge through Game Center and play at your own pace, or start a group match with up to 6 friends. Afterwards, see every question, every answer, and a replay of who picked what.
>
> THOUSANDS OF QUESTIONS
> General knowledge, science, history, geography, sports, film, music, anime, pop culture and more, from easy to tough. New questions are added regularly.
>
> MAKE IT YOURS
> Earn Sparks by playing. Spend them on app themes with animated backgrounds, sound packs, power-ups and Player Card styles. Sparks can't be bought; you earn every one.
>
> PRIVATE BY DESIGN
> Quizio collects no data. Your progress stays on your phone. Multiplayer uses Apple's Game Center.
>
> Made for iPhone, including the folding iPhone, and iPad.
>
> Some questions come from the Open Trivia Database (opentdb.com), used under CC BY-SA 4.0.

*If Speed Round is cut or reworked for 1.0, edit the PLAY YOUR WAY list to match. "Folding iPhone" wording: use Apple's official device name once confirmed.*

## URLs

| Field | Value | Status |
|---|---|---|
| Privacy Policy URL | must be a public web page | **Needed.** `docs/privacy.md` exists but the repo isn't a public page. Host it (GitHub Pages, Notion, any site). |
| Support URL | must be a public web page with a way to contact you | **Needed.** Can be the same site as the policy. The policy's "open a GitHub issue" contact only works if the repo is public; otherwise use an email. |
| Marketing URL | optional | Skip. |

## Screenshots

Required sets (Apple scales down from the largest size in each family):
- iPhone 6.9" (1320 × 2868 or 1290 × 2796): 3–10 shots.
- iPad 13" (2064 × 2752): required because the app runs on iPad (`TARGETED_DEVICE_FAMILY: "1,2"`).

Suggested order: Home, a question mid-round with streak, the Daily result, a group match breakdown/replay, Style shop with a theme, Friends tab.
Avoid showing placeholder leaderboard text ("This leaderboard isn't live yet"); set up the leaderboards first.

## What's New (1.0)

> Welcome to Quizio 1.0. Thanks to everyone who tested!

## Game Center

Enable Game Center on the 1.0 version page and attach all leaderboards from `docs/game-center-setup.md` (they must exist and be added to this version to go live with it).
