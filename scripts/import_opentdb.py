#!/usr/bin/env python3
"""Seed the bundled question bank from the Open Trivia Database.

Fetches every multiple-choice question from https://opentdb.com, maps its
categories to the app's shorter category names, and writes
App/Resources/opentdb.json in the app's Question format.

Open Trivia DB content is licensed CC BY-SA 4.0
(https://creativecommons.org/licenses/by-sa/4.0/). We keep it in its own
file so the share-alike terms stay attached to it, credit it in the app
(Settings > Credits), and note our changes (category names, answer order).

Usage: python3 -I scripts/import_opentdb.py [--out PATH]
Takes about 10 minutes because the API allows one request per 5 seconds.
"""
from __future__ import annotations

import argparse
import base64
import json
import pathlib
import re
import sys
import time
import urllib.parse
import urllib.request

API = "https://opentdb.com"
DELAY = 5.5  # seconds between requests (API limit is 1 per 5s per IP)
SOURCE = "Open Trivia Database (opentdb.com), CC BY-SA 4.0"

# OpenTDB category -> app category. Keeps the Home screen to a short list.
CATEGORY_MAP = {
    "General Knowledge": "General",
    "Entertainment: Books": "Books",
    "Entertainment: Film": "Movies",
    "Entertainment: Music": "Music",
    "Entertainment: Musicals & Theatres": "Music",
    "Entertainment: Television": "TV",
    "Entertainment: Video Games": "Games",
    "Entertainment: Board Games": "Games",
    "Entertainment: Comics": "Pop Culture",
    "Entertainment: Japanese Anime & Manga": "Anime",
    "Entertainment: Cartoon & Animations": "Pop Culture",
    "Celebrities": "Pop Culture",
    "Science & Nature": "Science",
    "Science: Computers": "Tech",
    "Science: Gadgets": "Tech",
    "Science: Mathematics": "Science",
    "Animals": "Nature",
    "Vehicles": "General",
    "Mythology": "History",
    "Sports": "Sports",
    "Geography": "Geography",
    "History": "History",
    "Politics": "History",
    "Art": "Art",
}


def get(path: str, **params: str) -> dict:
    url = f"{API}/{path}?{urllib.parse.urlencode(params)}"
    req = urllib.request.Request(url, headers={"User-Agent": "trivia-bank-import/1.0"})
    with urllib.request.urlopen(req, timeout=30) as resp:
        return json.load(resp)


def b64(s: str) -> str:
    return base64.b64decode(s).decode("utf-8").strip()


# Song lyrics are copyrighted, and Open Trivia DB's license can't grant rights
# to them, so skip questions that quote lyrics (in the prompt or answers).
LYRIC_PATTERN = re.compile(
    r"(finish|complete) (these|the) lyrics?|which lyric|these lyrics|were lyrics|are lyrics"
    r"|is a lyric|the lyrics? (from|of|to|in)|lyrics? follow|lyric follows",
    re.IGNORECASE,
)


def quotes_lyrics(prompt: str, choices: list[str]) -> bool:
    return bool(LYRIC_PATTERN.search(prompt)) or any(" / " in c for c in choices)


def convert(raw: dict) -> dict | None:
    category = CATEGORY_MAP.get(b64(raw["category"]))
    if category is None:
        return None
    correct = b64(raw["correct_answer"])
    wrong = [b64(a) for a in raw["incorrect_answers"]]
    if len(wrong) != 3 or not correct or correct in wrong:
        return None
    if quotes_lyrics(b64(raw["question"]), [correct, *wrong]):
        return None
    return {
        "category": category,
        "difficulty": b64(raw["difficulty"]),
        "prompt": b64(raw["question"]),
        # Correct answer first; the app shuffles answer order every round.
        "choices": [correct, *wrong],
        "correctIndex": 0,
        "source": SOURCE,
    }


def fetch_all() -> list[dict]:
    token = get("api_token.php", command="request")["token"]
    out: list[dict] = []
    amount = 50
    while True:
        time.sleep(DELAY)
        data = get("api.php", amount=str(amount), type="multiple", encode="base64", token=token)
        code = data["response_code"]
        if code == 0:
            out.extend(data["results"])
            print(f"fetched {len(out)}", file=sys.stderr)
        elif code == 5:  # rate limited
            time.sleep(DELAY)
        elif code in (1, 4):  # not enough left for this batch size, or token exhausted
            if amount == 1 or code == 4:
                break
            amount = 10 if amount > 10 else 1
        else:
            raise SystemExit(f"OpenTDB error code {code}")
    return out


def main() -> None:
    parser = argparse.ArgumentParser()
    parser.add_argument("--out", default="App/Resources/opentdb.json")
    args = parser.parse_args()

    seen: set[str] = set()
    questions = []
    for raw in fetch_all():
        q = convert(raw)
        if q and q["prompt"].lower() not in seen:
            seen.add(q["prompt"].lower())
            questions.append(q)
    questions.sort(key=lambda q: (q["category"], q["prompt"]))
    path = pathlib.Path(args.out)
    path.write_text(json.dumps(questions, ensure_ascii=False, indent=0) + "\n", encoding="utf-8")
    counts: dict[str, int] = {}
    for q in questions:
        counts[q["category"]] = counts.get(q["category"], 0) + 1
    print(f"wrote {len(questions)} questions to {path}", file=sys.stderr)
    for name, n in sorted(counts.items()):
        print(f"  {name}: {n}", file=sys.stderr)


if __name__ == "__main__":
    main()
