# Quizio - Trivia with Friends

An ad-free trivia game for iPhone and iPad, built in SwiftUI, with
async "challenge a friend" multiplayer over Game Center.

- **Minimum OS:** iOS 27.1
- **Devices:** all iPhones (including full **iPhone Duo** support) and iPad
- **No ads, no ad SDKs, no tracking.**

## Getting started

Requirements: Xcode 27.1+, [XcodeGen](https://github.com/yonaskolb/XcodeGen).

```sh
brew install xcodegen
xcodegen generate
open Trivia.xcodeproj
```

The `.xcodeproj` is generated from `project.yml` and not committed.

Run the core logic tests without the simulator:

```sh
cd Packages/TriviaKit && swift test
```

## Layout

```
App/
  Sources/App/          App entry + root TabView
  Sources/Features/     Home, Play (quiz), Multiplayer (Friends: Game Center challenges), Settings
  Resources/            Asset catalog
Packages/TriviaKit/     Pure Swift game logic (models, scoring) + tests
docs/iphone-duo.md      iPhone Duo rules and test checklist
project.yml             XcodeGen project definition
.github/workflows/      CI: package tests + simulator build
```

## iPhone Duo

See [docs/iphone-duo.md](docs/iphone-duo.md). Short version: stay resizable,
lay out from size classes and local geometry only, use system containers, and
test every pose in Xcode's Device Hub.

## Question bank

About 4,500 questions ship in the app: our own (`originals.json`) plus a seed
from the Open Trivia Database (`opentdb.json`, CC BY-SA 4.0, credited in
Settings > Credits). See [docs/question-bank.md](docs/question-bank.md).

## TestFlight

```sh
scripts/testflight.sh
```

Archives with automatic signing (team 433TNCP697, bundle ID
`com.abcapps.trivia`) and uploads to App Store Connect. The app record must
exist in App Store Connect first; see the comments in the script.

## Roadmap
- [x] Question bank (bundled JSON + categories)
- [x] Timed rounds, streaks, power-ups, haptics
- [ ] Sparks shop for power-ups
- [ ] Game Center sign-in, leaderboards
- [ ] Real-time and turn-based multiplayer
- [ ] Duo: fold-aware layout, side-by-side scoreboard
