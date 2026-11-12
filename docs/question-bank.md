# Question bank

We own our question bank. It ships inside the app as JSON files in
`App/Resources/`, loaded and merged by `PlayerStore.loadBundledBank()`:

| File | What | License |
|---|---|---|
| `originals.json` | Our own written and reviewed questions | Ours |
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
