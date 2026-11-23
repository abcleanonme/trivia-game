# App Privacy answers and App Review notes (1.0)

## App Privacy ("nutrition label")

App Store Connect → Quizio → App Privacy → Get Started.

**Do you or your third-party partners collect data from this app?** → **No, we do not collect data from this app.**

That gives the "Data Not Collected" label. Why it's accurate:
- No analytics, ads, crash-reporting or other third-party SDKs; the only framework beyond the system is GameKit.
- All progress, Sparks, settings and head-to-head history are saved on the device (UserDefaults).
- Game Center data (player identity, matches, scores, friends list) is handled by Apple, not by the app's developer. Apple's guidance is that data sent to Apple services isn't "collected" by you unless you also keep it.
- Flagged questions leave the phone only when the player opens the share sheet and sends them themselves.
- `App/Resources/PrivacyInfo.xcprivacy` already declares no tracking, no collected data types, and the UserDefaults required-reason API.

**Tracking (App Tracking Transparency):** none. No ATT prompt needed.

**Privacy Policy URL:** required even with "Data Not Collected". Host `docs/privacy.md` publicly (see `metadata.md`).

## Export compliance

`ITSAppUsesNonExemptEncryption = NO` is set in `project.yml`, so uploads skip the encryption question. Nothing more to file.

## Content rights

Answer **Yes, it contains third-party content, and I have the rights**: Open Trivia Database questions are CC BY-SA 4.0 and credited in Settings. The AI-drafted questions were reviewed and are your own content.

## App Review notes

Paste into Version → App Review Information → Notes:

> Quizio is a paid trivia game with no ads, no in-app purchases and no account. "Sparks" are an in-game currency earned only by playing; they cannot be bought with money and have no real-world value.
>
> To try single player: open the app and tap Play (Classic), Survival or Speed Round, or play today's Daily. No sign-in is needed.
>
> Multiplayer (friend challenges, group matches and friend leaderboards) uses Game Center turn-based matches. Sign in to Game Center in Settings to see it. To test a challenge with one device, sign in with a sandbox Game Center account and start a challenge from the Friends tab; the match can be played in turns at any pace. Without Game Center the rest of the app works fully.
>
> The app collects no data. All progress stays on the device.

**Sign-in required:** No (leave the demo account fields empty).
**Contact information:** your name, phone and email for Apple to reach you (stays private).

## Things reviewers commonly flag here

- **Guideline 3.1.1 (currency):** reviewers sometimes ask if Sparks can be bought. The note above answers it.
- **Guideline 4.2 (minimum functionality) / 2.1 (completeness):** any screen that says "coming soon" or "isn't live yet" can trigger a rejection. Make sure all Game Center leaderboards exist so the Friends boards aren't empty-state.
- **Broken features:** a mode that misbehaves (see Speed Round in the release checklist) is a 2.1 rejection risk.
- **Guideline 5.1.1:** the Game Center friends prompt (`NSGKFriendListUsageDescription`) is already in `App/Info.plist`.
