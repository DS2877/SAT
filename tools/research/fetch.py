"""Fetches public web pages listed in research/urls.txt and prints their readable text, so
design research can reach sites the development sandbox can't (e.g. the Roblox DevForum).
Discourse forums (the DevForum) are read through their public JSON: search results and
every post of a topic. Read-only; sends no credentials."""

import html
import json
import re
import urllib.request

UA = "StealTheTreasureResearch/1.0"
LIMIT = 20000  # characters printed per page


def get(url):
    req = urllib.request.Request(url, headers={"User-Agent": UA, "Accept": "application/json, text/html"})
    try:
        with urllib.request.urlopen(req, timeout=30) as r:
            return r.status, r.read().decode("utf-8", "replace")
    except urllib.error.HTTPError as e:
        return e.code, e.read().decode("utf-8", "replace")
    except Exception as e:  # network error
        return 0, str(e)


def text(fragment):
    fragment = re.sub(r"(?is)<(script|style).*?</\1>", "", fragment)
    fragment = re.sub(r"(?i)<br\s*/?>|</p>|</li>|</h\d>|</pre>", "\n", fragment)
    fragment = re.sub(r"<[^>]+>", "", fragment)
    return re.sub(r"\n{3,}", "\n\n", html.unescape(fragment)).strip()


def youtube(body):
    """Title + full description of a YouTube video page (kits often list asset ids there)."""
    title = re.search(r'"title":"(.*?)","lengthSeconds"', body)
    desc = re.search(r'"shortDescription":"(.*?)","isCrawlable"', body)
    print("TITLE:", json.loads(f'"{title.group(1)}"') if title else "?")
    print(json.loads(f'"{desc.group(1)}"') if desc else "(no description found)")


def show(url):
    print(f"\n######## {url}")
    status, body = get(url)
    if status != 200:
        print(f"HTTP {status}: {body[:300]}")
        return
    if "youtube.com/watch" in url:
        youtube(body)
        return
    try:
        data = json.loads(body)
    except ValueError:
        print(text(body)[:LIMIT])
        return
    if "topics" in data or "posts" in data and "post_stream" not in data:  # search.json
        for t in data.get("topics", [])[:25]:
            print(f"- {t.get('title')} -> https://devforum.roblox.com/t/{t.get('slug')}/{t.get('id')}")
        for p in data.get("posts", [])[:25]:
            print(f"  * topic {p.get('topic_id')}: {p.get('blurb', '')[:200]}")
        return
    posts = data.get("post_stream", {}).get("posts", [])
    print(f"TITLE: {data.get('title')}")
    out = []
    for p in posts:
        out.append(f"--- post {p.get('post_number')} by {p.get('username')}\n{text(p.get('cooked', ''))}")
    print("\n".join(out)[:LIMIT])


if __name__ == "__main__":
    with open("research/urls.txt") as f:
        urls = [line.strip() for line in f if line.strip() and not line.startswith("#")]
    for url in urls:
        show(url)
