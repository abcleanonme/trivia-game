# Question pipeline run history

The writer and reviewer tasks each append a row per run. Rules live in writer-rules.md and reviewer-rules.md next to this file.

## Writer

| Run date | PR | Questions | Outcome |
|---|---|---|---|
| 2026-11-16 | #13 "Weekly questions 2026-11-16 (400, unreviewed)" | 400 (thin categories: Science, History, Geography, Movies, Art, Nature, Books, Tech, Sports, TV, Music) | Reviewer kept 372 and removed 28 duplicates of OpenTDB facts. Folded into #15 and merged to main on 2026-11-22. |

## Reviewer

| Run date | PRs reviewed | Backlog reviewed | Outcome |
|---|---|---|---|
| 2026-11-18 | #13 | Part of the PR #7 backlog | Removed 28 duplicates from #13. About 608 backlog questions still unreviewed on 2026-11-22. |
| 2026-11-22 | #24 | 150 (Books and Nature, oldest first) | #24: 379 kept (8 fixed, 92 relabeled easier), 21 duplicates removed. Backlog: 128 kept (7 fixed, 19 relabeled), 22 removed (19 duplicates, 3 minutiae or giveaways). 458 backlog questions still unreviewed. |

## Notes for future runs

- The most common problem in drafts is restating a fact OpenTDB already has. Dedupe hard.
- From 2026-11-22 on (rules rewritten for easier questions): General gets 100 a week, about 55% are easy, and new categories (Food, Space, Human Body, Words, Holidays, Brands) get 40 each until they reach 150.
- 2026-11-22 reviewer run: the writer labeled many common-knowledge questions medium or hard (only 9 hard survived in #24), so the writer should aim harder when it means hard. Backlog drafts always put the answer first; that is fine because the app shuffles choices.
