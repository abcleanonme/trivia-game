# Question pipeline run history

The writer and reviewer tasks each append a row per run. Rules live in writer-rules.md and reviewer-rules.md next to this file.

## Writer

| Run date | PR | Questions | Outcome |
|---|---|---|---|
| 2026-11-16 | #13 "Weekly questions 2026-11-16 (400, unreviewed)" | 400 (thin categories: Science, History, Geography, Movies, Art, Nature, Books, Tech, Sports, TV, Music) | Reviewer kept 372 and removed 28 duplicates of OpenTDB facts. Folded into #15 and merged to main on 2026-11-22. |
| 2026-11-22 | #24 "Weekly questions 2026-11-22 (400, unreviewed)" | 400 (General 100; Food, Space, Human Body, Words, Holidays, Brands 40 each; Mythology 20, Vehicles 15, Comics 15, Cartoons 10). 207 easy, 153 medium, 40 hard | Reviewed 2026-11-22: 379 kept (8 fixed, 92 difficulty relabels, mostly hard/medium down to easier), 21 removed as duplicates of facts already in the bank. Now 262 easy, 108 medium, 9 hard. Open, not merged. |
| 2026-11-23 | #PRNUM "Weekly questions 2026-11-23 (400, unreviewed)" | 400 (General 100; Food, Space, Human Body, Words, Holidays, Brands 40 each; Mythology 20, Vehicles 15, Comics 15, Cartoons 10). 223 easy, 142 medium, 35 hard | Open, awaiting reviewer |

## Reviewer

| Run date | PRs reviewed | Backlog reviewed | Outcome |
|---|---|---|---|
| 2026-11-18 | #13 | Part of the PR #7 backlog | Removed 28 duplicates from #13. About 608 backlog questions still unreviewed on 2026-11-22. |
| 2026-11-22 | #24 | 150 (Books and Nature, oldest first) | #24: 379 kept (8 fixed, 92 relabeled easier), 21 duplicates removed. Backlog: 128 kept (7 fixed, 19 relabeled), 22 removed (18 duplicates, 4 minutiae or giveaways). 458 backlog questions still unreviewed. |

## Notes for future runs

- The most common problem in drafts is restating a fact OpenTDB already has. Dedupe hard.
- From 2026-11-22 on (rules rewritten for easier questions): General gets 100 a week, about 55% are easy, and new categories (Food, Space, Human Body, Words, Holidays, Brands) get 40 each until they reach 150.
- 2026-11-22 writer run: the bank already covers most obvious easy facts (about half of first drafts were duplicates), so draft extra and check every draft against the bank before choosing the 400. Easy Words and Brands questions ran short, so those came in nearer 45% easy.
- 2026-11-22 reviewer run: the writer labeled many common-knowledge questions medium or hard (only 9 hard survived in #24), so the writer should aim harder when it means hard. Backlog drafts always put the answer first; that is fine because the app shuffles choices.
- 2026-11-23 writer run: about 480 drafted and about 140 dropped as repeats of bank facts (General and Human Body basics are nearly all taken: baby animal names, group names, color mixing, currencies, famous firsts). Future General drafts should go for less obvious everyday facts. Stacked on #24, so #24 should merge first.
