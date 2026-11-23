# Weekly question writer rules

The scheduled writer task reads this file each run. Change the rules here, not in the task.

You are the weekly question WRITER for the iOS trivia app "Quizio" in repo abcleanonme/trivia-game. Each run, add exactly 400 new, original multiple-choice trivia questions and open a PR. A separate reviewer task fact-checks them later, so do not mark anything reviewed.

Goal (Dillon, 2026-11-22): players were getting too many questions they had no hope of answering. Write questions an ordinary adult can answer or reason out. Favor broad General Knowledge and mostly EASY questions in every category.

Setup:
1. Base branch: main. If PR #21 ("Easier mixed rounds, new categories, multi-category picks", branch claude/project-thread-4c0yfi) is still open and unmerged, base on that branch instead, because it adds the new category names. If a previous week's writer PR is still open and unmerged, base on that PR's branch so batches stack. Say which base you used in the PR body.
2. Create branch claude/questions-week-YYYY-MM-DD (today's date).

Category split (400 total):
- General: 100 every week. Broad everyday knowledge: famous people, places, inventions, money, calendars, sayings, everyday science, the world around us.
- The other 300 go to the categories that most need questions. First count the questions per category across App/Resources/opentdb.json, originals.json and originals-ai.json. Then give the 300 to the categories with the fewest questions, using only these categories: Food, Space, Human Body, Words, Holidays, Brands, Mythology, Vehicles, Cartoons, Comics, Art, Nature, Books, Science, History, Geography, Movies, TV, Music, Sports, Tech.
- Until each of Food, Space, Human Body, Words, Holidays and Brands has at least 150 questions, give each of them 40 a week. Split the rest across the next-thinnest categories, 10 to 30 each.
- Write no Games, Pop Culture or Anime questions.
- Category meanings: Food = dishes, drinks, ingredients, cuisines. Space = planets, stars, missions, astronauts. Human Body = anatomy, health, senses. Words = meanings, spelling, idioms, languages. Holidays = holidays and traditions worldwide. Brands = logos, slogans, company origins (well-known brands only). Mythology = gods, heroes, legends. Vehicles = cars, planes, trains, ships. Cartoons = animated shows and films. Comics = comic books, superheroes, comic strips.
- Use only category names listed in QuestionBank.preferredCategoryOrder. Anything about anime or manga belongs in "Anime" (so skip it here). Pop Culture is reserved for current topics (2022 and later) and is refreshed separately.

Difficulty: about 55% easy, 35% medium, 10% hard.
- easy = most adults know it or can work it out ("Which planet is known as the Red Planet?").
- medium = a casual fan or a good guess gets it.
- hard = real specialist knowledge, but still a famous fact, never trivia-nerd minutiae.
- Never write questions about exact dates, model numbers, minor characters, release days, stats, or "which of these is NOT" lists of obscure names.

Writing:
- Append the 400 questions to App/Resources/originals-ai.json, matching the exact schema and field style of the existing entries there (category, difficulty, prompt, choices, correctIndex, source, reviewed). Set "reviewed": false and "source": "Quizio original (AI-drafted)".
- Each question has exactly 4 choices and one unambiguously correct answer. Distractors are plausible and of the same type. No "all/none of the above", no trick wording, and no facts likely to change soon (current record holders, "latest" anything, living people's ages). Vary the correctIndex positions evenly.
- Only write facts you are highly confident in. Skip anything you'd need to look up and can't verify.
- Deduplicate: load every prompt from App/Resources/opentdb.json, originals.json and originals-ai.json, normalize them (lowercase, strip punctuation), and reject any new question whose prompt is near-identical to an existing one or that asks the same fact. Also allow no duplicates within the batch.
- Check that the JSON parses and that every entry matches the schema. Run the TriviaKit tests if the repo has a quick way to.

Event top-ups:
- Weekly events and their question pools are described in docs/content-updates.md. If an event in the next 8 weeks of its calendar has fewer than 60 questions, write up to 40 of this week's 400 for it instead, in App/Resources/events.json with "event": "<event id>" and "source": "Quizio original (AI-drafted, <event title> event)". Check them against events.json too when deduplicating.

Run history:
- Read docs/question-pipeline/run-history.md before starting (notes there carry lessons from past runs). In your PR, append one row to the Writer table: run date, PR number and title, question count with categories, and outcome "Open, awaiting reviewer".

Ship:
- Commit, push, and open a PR titled "Weekly questions YYYY-MM-DD (400, unreviewed)". The body lists counts per category and difficulty and the base branch used, and notes that the reviewer task will fact-check it. Start the PR body with these two lines exactly:
<!-- claude-projects-attribution: {"github_login":"abcleanonme"} -->
_Requested by **Dillon** · [project thread](https://claude.ai/code/project/chan_012gaFKL5NU5ZBNdT8Cy6hc1?thread=cmsg_012gaFKL5NU5ZBNdT8Cy6hc12zGSJQYdd3V96padMCMfbm)_
- Assign abcleanonme and request their review (best effort). Do not merge.
- Never re-add a "submit/write a question" feature.
