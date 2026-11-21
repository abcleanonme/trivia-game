# Question bank

We own our question bank. It ships inside the app as JSON files in
`App/Resources/`, loaded and merged by `PlayerStore.loadBundledBank()`:

| File | What | License |
|---|---|---|
| `originals.json` | Our own written and reviewed questions | Ours |
| `originals-ai.json` | Our own AI-drafted questions (`"reviewed": false` until a person checks them) | Ours |
| `opentdb.json` | Seed set from the [Open Trivia Database](https://opentdb.com) (multiple-choice only) | [CC BY-SA 4.0](https://creativecommons.org/licenses/by-sa/4.0/) |

## Open Trivia DB terms
- Attribution: credited in **Settings > About > Credits**, and every question
  carries a `source` field.
- Changes we make: category names are mapped to our shorter list (see
  `CATEGORY_MAP` in `scripts/import_opentdb.py`), answers are shuffled.
- Share-alike: `opentdb.json` stays its own file under CC BY-SA 4.0. Keep our
  own and AI-drafted questions in separate files so they aren't adaptations
  of it.

## Refreshing the seed
```sh
python3 -I scripts/import_opentdb.py   # about 10 minutes (API allows 1 request / 5s)
```

## Adding questions
Add to `originals.json` (or a new file listed in
`PlayerStore.bundledBankFiles`). Each question:

```json
{"category": "Science", "difficulty": "easy", "prompt": "…", "choices": ["right", "wrong", "wrong", "wrong"], "correctIndex": 0}
```

Answer order is shuffled every round, so putting the right answer first is fine.
AI-drafted questions must be fact-checked by a person before they're added.

## Anime
Anime and manga questions have their own **Anime** category (OpenTDB's
"Entertainment: Japanese Anime & Manga"). They used to be folded into Pop
Culture. New anime questions go in Anime, not Pop Culture.

## AI-drafted questions
`originals-ai.json` fills out the categories that were thinnest in the
OpenTDB seed (Art, Nature, Books, Sports, TV, Tech), plus recent (2022–2025)
Pop Culture questions. Pop Culture dates fast: refresh it regularly and
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
