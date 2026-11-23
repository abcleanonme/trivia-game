# Question bank

We own our question bank. It ships inside the app as JSON files in
`App/Resources/`, loaded and merged by `PlayerStore.loadBundledBank()`:

| File | What | License |
|---|---|---|
| `originals.json` | Our own written and reviewed questions | Ours |
| `originals-ai.json` | Our own AI-drafted questions (`"reviewed": false` until a person checks them) | Ours |
| `events.json` | Questions written for one weekly event, tagged `"event": "<id>"`. They play only in that event (see [content-updates.md](content-updates.md)) | Ours |
| `opentdb.json` | Seed set from the [Open Trivia Database](https://opentdb.com) (multiple-choice only) | [CC BY-SA 4.0](https://creativecommons.org/licenses/by-sa/4.0/) |

## Open Trivia DB terms
- Attribution: credited in **Settings > About > Credits**, and every question
  carries a `source` field.
- Changes we make: category names are mapped to our shorter list (see
  `CATEGORY_MAP` in `scripts/import_opentdb.py`), some difficulty tags are
  changed (see "Difficulty"), answers are shuffled.
- Share-alike: `opentdb.json` stays its own file under CC BY-SA 4.0. Keep our
  own and AI-drafted questions in separate files so they aren't adaptations
  of it.

## Refreshing the seed
```sh
python3 -I scripts/import_opentdb.py   # about 10 minutes (API allows 1 request / 5s)
```

**Careful:** `opentdb.json` has been hand-edited since the import (see
"Difficulty" below), so a fresh import loses those re-tags. Diff against
the current file and carry the `difficulty` changes over.

## Adding questions
Add to `originals.json` (or a new file listed in
`PlayerStore.bundledBankFiles`). Each question:

```json
{"category": "Science", "difficulty": "easy", "prompt": "…", "choices": ["right", "wrong", "wrong", "wrong"], "correctIndex": 0}
```

Answer order is shuffled every round, so putting the right answer first is fine.
AI-drafted questions must be fact-checked by a person before they're added.

## Categories
`QuestionBank.preferredCategoryOrder` is the full list and Home's order.
A category only shows up as a pick (Home tiles, challenge rules) once it
has `QuestionBank.minimumCategorySize` (50) questions; until then its
questions still play in mixed rounds. Newer categories:

| Category | What goes in it |
|---|---|
| Food | Dishes, drinks, ingredients, cuisines |
| Space | Planets, stars, missions, astronauts |
| Human Body | Anatomy, health, senses |
| Words | Word meanings, spelling, idioms, languages |
| Holidays | Holidays and traditions around the world |
| Brands | Logos, slogans, company origins |
| Mythology | Gods, heroes, legends (was part of History) |
| Vehicles | Cars, planes, trains, ships (was part of General) |
| Cartoons | Animated shows and films (was part of Pop Culture) |
| Comics | Comic books, superheroes, comic strips (was part of Pop Culture) |

Players can pick several categories for a round. A multi-category round
spreads its questions across the picks.

## Difficulty
Tags mean: **easy** — most adults know it or can work it out; **medium** —
a casual fan or a good guess gets it; **hard** — needs real specialist
knowledge. OpenTDB's own tags ran far too hard for that, so in Nov 2026
about 2,000 obscure OpenTDB questions were re-tagged hard (and ~350 "easy"
ones to medium). Mixed-level rounds lean easy: of 13 dealt (10 plus Skip
spares) at most 2 hard and 5 medium (`maxHardPerRound`,
`maxMediumPerRound`), the rest easy, when the pool has them.

## Anime
Anime and manga questions have their own **Anime** category (OpenTDB's
"Entertainment: Japanese Anime & Manga"). They used to be folded into Pop
Culture. New anime questions go in Anime, not Pop Culture.

## AI-drafted questions
`originals-ai.json` fills out the categories that were thinnest in the
OpenTDB seed (Art, Nature, Books, Sports, TV, Tech), the newer categories
above, and General Knowledge, plus recent (2022–2025) Pop Culture
questions. New batches are mostly easy. Pop Culture dates fast: refresh it regularly and
retire questions that stop being "current". Every entry has
`"reviewed": false` until a person fact-checks it; flip it to `true` (or
delete the question) as you go. **Finish the review before an App Store
release.** TestFlight testers can flag bad ones with Report in the meantime.

Drafts are de-duplicated against the existing bank (exact and near-match
prompts) before they're added.

## Not repeating questions
`PlayerStore` keeps a `SeenQuestions` list of every question a player has
been shown (oldest first). Rounds deal only unseen questions until a pool
(category + difficulty) is used up, then reuse the ones seen longest ago.
Only questions actually shown count, including ones swapped out by Skip, so
a long Survival deal doesn't burn through the pool.
