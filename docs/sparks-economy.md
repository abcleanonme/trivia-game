# Sparks economy

Sparks are earned only by playing and never sold. This is how prices are set.

## What players earn

| Source | Sparks |
|---|---|
| Classic round (1 per 10 points) | about 80–130 for a typical 6–8 of 10; up to ~300 for a perfect hard round on a streak |
| Daily | the round's Sparks + 50 for finishing, +100 for a perfect 10 |
| Mastery level-up | 25 × the new level |
| Weekly event track | milestone payouts |

A player who does the Daily and two Classic rounds earns roughly 300–400 Sparks a day.

## Power-up prices

| Power-up | One | Pack of 3 (15% off) |
|---|---|---|
| +10s | 25 | 65 |
| Skip | 35 | 90 |
| 50/50 | 40 | 100 |
| Double down | 50 | 130 |
| Second chance | 50 | 130 |
| Starter kit (one of each) | 170 (full price 200) | |

Why these numbers:
- **One power-up a round costs a quarter to a half of what the round pays.** Using one every round is easy to sustain.
- **Filling all three slots costs about a whole round**, so maxing out every round isn't free. Power-ups stay a choice, not the default.
- **Double down can't farm Sparks.** Its best possible payout (hard question on a 5+ streak; power-ups skip the speed bonus) adds 300 points, which is 30 Sparks, well under its 50 price. A unit test guards this.
- **Second chance is priced with Double down** because it saves a streak, which is worth more than the half points it pays.
- **Cosmetics (100–600) stay a few days of play**, so saving for one is still a goal even after buying power-ups.
- **Stock is capped at 9 of each** so nobody hoards a huge pile and the tray badge stays one digit.

Prices before this change were 20–40, which let one round buy about four power-ups, more than a round can use.

Prices live in `PowerUp.cost`; packs, the kit, the stock cap and the discount live in `PowerUpShop` (TriviaKit).
