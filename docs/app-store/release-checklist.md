# Quizio 1.0 release checklist

Status as of 2026-11-23. Owner: **D** = Dillon (App Store Connect, Mac, decisions), **C** = Claude (repo).

## 1. Release blockers

- [ ] **D** Decide the Speed Round fix (answer spamming). Options on the table: wrong-answer penalty (time loss, or 3 misses ends the round) plus a streak multiplier, or hide the mode for 1.0. No code change until you pick.
- [ ] **C** Land the friend fixes from the "Add friend management and tidy challenges" thread: dedicated Add friend, Remove friend, collapsible/archivable challenges, full-size Use button in the customization screens.
- [ ] **D** Ship that as the last TestFlight build (0.2.0 build 10 or later) and smoke-test it.
- [ ] **D** Create every Game Center leaderboard in App Store Connect (`docs/game-center-setup.md`). The weekly board `com.abcapps.trivia.weekly` is still missing; check the rest too.

## 2. Repo (after that TestFlight build is uploaded)

PR audit (open PRs, 2026-11-23):

| PR | What | 1.0? | Plan |
|---|---|---|---|
| #23 | Build 9 integration: #19–#22 + questions #24/#25 | Yes | Merge to main (or the build 10 integration PR that contains it). |
| #19 | Replay picks fit answer rows; readable Group button | Yes | Included in #23; close after merge. |
| #20 | Style shop expansion | Yes | Included in #23; close after merge. |
| #21 | Easier rounds, new categories, multi-category picks | Yes | Included in #23; close after merge. |
| #22 | Daily and Weekly tabs | Yes | Included in #23; close after merge. |
| #24 | Weekly questions 2026-11-22 | Yes (reviewed copy) | Included in #23; close after merge. |
| #25 | Backlog review 2026-11-22 | Yes | Included in #23; close after merge. |
| (new) | Friend management + challenge tidy-up | Yes | Merge once in build 10. |

- [ ] **C** Merge the build 10 integration to main.
- [ ] **C** Close #19–#22, #24, #25 as included.
- [ ] **C** Delete merged/stale branches. Every `claude/*` branch except the ones above is already fully in main (0 commits ahead): 1ut7zb, 1zq0os, 29b6d7, 30eb0y, 346gd7, 3u0fqz, 54zp6w, 5mqjpj, 70aqqx, fl7339, mkxhqv, ps1m4m, qluyia, tra32a, questions-review-2026-11-18, questions-week-2026-11-16, snazzy-animations, ui-cleanup.
- [ ] **C** Bump `MARKETING_VERSION` to 1.0.0 and `CURRENT_PROJECT_VERSION` past the last TestFlight build in `project.yml`; update `CHANGELOG.md`.
- [ ] **C** Tag `v1.0.0` on main.

## 3. App Store Connect

- [ ] **D** Pick the price tier and availability (countries).
- [ ] **D** Host the privacy policy (`docs/privacy.md`) and a support page at public URLs. If the repo stays private, swap the policy's "open a GitHub issue" contact for an email.
- [ ] **D** Paste metadata from `docs/app-store/metadata.md` (name, subtitle, keywords, description, promo text, categories, copyright).
- [ ] **D** Fill App Privacy as "Data Not Collected", content rights and age rating (`docs/app-store/privacy-and-review.md`).
- [ ] **D** Screenshots: iPhone 6.9" and iPad 13". Take them on build 1.0 with leaderboards live.
- [ ] **D** Agreements, Tax and Banking: Paid Apps agreement signed and banking set up (paid apps can't go on sale without it).
- [ ] **D** Enable Game Center on the 1.0 version and attach the leaderboards.

## 4. Build and submit

- [ ] **D** On the Mac: `cd ~/Developer/trivia-game && git checkout main && git pull && scripts/testflight.sh` (uploads 1.0.0).
- [ ] **D** Quick pass on TestFlight: fresh install, Daily, Classic, Survival, a challenge, Style shop purchase with Sparks.
- [ ] **D** Select the build on the 1.0 version, paste the review notes, choose manual or automatic release, Submit for Review.

## 5. After approval

- [ ] Release (if manual).
- [ ] Keep the weekly question writer/reviewer going; new questions ship in updates.
- [ ] Update promotional text for each weekly event (no build needed).
