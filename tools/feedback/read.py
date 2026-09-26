"""Read in-game player feedback (Services/FeedbackService) from the Roblox DataStore via
Open Cloud and print a summary. Entries hold no user ids or names.

Env: ROBLOX_API_KEY (needs DataStore list + read on the universe), UNIVERSE_ID, DAYS (default 7).
Writes a Markdown report to $GITHUB_STEP_SUMMARY when set, and to stdout.
"""

import datetime
import json
import os
import sys
import urllib.error
import urllib.parse
import urllib.request

STORE = "PlayerFeedback"
BASE = "https://apis.roblox.com/datastores/v1/universes/{universe}/standard-datastores/datastore/entries"


def call(url: str, key: str):
    request = urllib.request.Request(url, headers={"x-api-key": key})
    with urllib.request.urlopen(request, timeout=30) as response:
        return json.loads(response.read().decode("utf-8"))


def main() -> int:
    key = os.environ.get("ROBLOX_API_KEY", "")
    universe = os.environ.get("UNIVERSE_ID", "")
    days = int(os.environ.get("DAYS") or "7")
    if not key or not universe:
        print("ROBLOX_API_KEY and UNIVERSE_ID are required")
        return 1
    base = BASE.format(universe=universe)
    today = datetime.datetime.now(datetime.timezone.utc).date()
    wanted = [(today - datetime.timedelta(days=i)).isoformat() for i in range(days)]

    entries = []
    for day in wanted:
        url = base + "/entry?" + urllib.parse.urlencode({"datastoreName": STORE, "entryKey": day})
        try:
            value = call(url, key)
        except urllib.error.HTTPError as err:
            if err.code == 404:
                continue  # nothing that day
            if err.code in (401, 403):
                print(f"HTTP {err.code}: the API key needs DataStore read access (universe-datastores.objects:read) for universe {universe}.")
                return 1
            print(f"HTTP {err.code} reading {day}")
            return 1
        if isinstance(value, list):
            for entry in value:
                if isinstance(entry, dict):
                    entry["day"] = day
                    entries.append(entry)

    up = sum(1 for e in entries if e.get("v") == 1)
    down = sum(1 for e in entries if e.get("v") == -1)
    lines = [
        f"# Player feedback - last {days} days",
        "",
        f"**{len(entries)} entries** - 👍 {up} / 👎 {down}",
        "",
        "| When (UTC) | Vote | Banks | Asc | Message |",
        "|---|---|---|---|---|",
    ]
    for entry in sorted(entries, key=lambda e: e.get("t", 0), reverse=True):
        when = datetime.datetime.fromtimestamp(entry.get("t", 0), datetime.timezone.utc).strftime("%m-%d %H:%M")
        vote = {1: "👍", -1: "👎"}.get(entry.get("v"), "-")
        message = str(entry.get("m") or "").replace("|", "/").replace("\n", " ")
        lines.append(f"| {when} | {vote} | {entry.get('x', 0)} | {entry.get('a', 0)} | {message} |")
    report = "\n".join(lines)
    print(report)
    summary = os.environ.get("GITHUB_STEP_SUMMARY")
    if summary:
        with open(summary, "a", encoding="utf-8") as handle:
            handle.write(report + "\n")
    return 0


if __name__ == "__main__":
    sys.exit(main())
