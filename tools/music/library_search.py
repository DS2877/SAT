"""Searches Roblox's licensed audio library (Creator Store) for tracks that can be used in any
experience without uploading anything. Prints candidates (id, name, creator, length) for the
queries in music/library_queries.txt. Tries the public toolbox endpoints; the API key is only
sent as a header and never printed."""

import json
import os
import urllib.parse
import urllib.request

API_KEY = os.environ.get("ROBLOX_API_KEY", "")
UA = "StealTheTreasureMusicPipeline/1.0"


def get(url, key=False):
    headers = {"User-Agent": UA, "Accept": "application/json"}
    if key and API_KEY:
        headers["x-api-key"] = API_KEY
    try:
        with urllib.request.urlopen(urllib.request.Request(url, headers=headers), timeout=30) as r:
            return r.status, r.read()
    except urllib.error.HTTPError as e:
        return e.code, e.read()
    except Exception as e:  # network error
        return 0, str(e).encode()


def details(ids):
    if not ids:
        return {}
    status, body = get("https://apis.roblox.com/toolbox-service/v1/items/details?assetIds=" + ",".join(map(str, ids)))
    out = {}
    if status == 200:
        for item in json.loads(body).get("data", []):
            asset = item.get("asset", {})
            creator = item.get("creator", {})
            out[asset.get("id")] = {
                "name": asset.get("name"),
                "duration": asset.get("duration"),
                "creator": creator.get("name"),
                "verified": creator.get("isVerifiedCreator"),
                "type": asset.get("typeId"),
            }
    else:
        print(f"    details HTTP {status}: {body[:160]!r}")
    return out


def search(query):
    q = urllib.parse.quote(query)
    attempts = [
        (f"https://apis.roblox.com/toolbox-service/v1/marketplace/3?limit=30&keyword={q}&includeOnlyVerifiedCreators=true", False),
        (f"https://apis.roblox.com/toolbox-service/v1/marketplace/3?limit=30&keyword={q}", False),
        (f"https://apis.roblox.com/toolbox-service/v2/assets:search?searchCategoryType=Audio&query={q}&maxPageSize=30", True),
    ]
    for url, key in attempts:
        status, body = get(url, key)
        label = url.split("?")[0].split("apis.roblox.com")[-1]
        if status != 200:
            print(f"  [{label}] HTTP {status}: {body[:160]!r}")
            continue
        data = json.loads(body)
        ids = [d.get("id") for d in data.get("data", []) if d.get("id")]
        if not ids and "creatorStoreAssets" in data:
            ids = [a.get("asset", {}).get("id") for a in data["creatorStoreAssets"]]
        info = details(ids[:30])
        print(f"  [{label}] {len(ids)} results")
        for i in ids[:30]:
            d = info.get(i, {})
            print(f"    {i} | {d.get('name')} | {d.get('creator')} (verified={d.get('verified')}) | {d.get('duration')}s")
        if ids:
            return


if __name__ == "__main__":
    with open("music/library_queries.txt") as f:
        queries = [line.strip() for line in f if line.strip() and not line.startswith("#")]
    for query in queries:
        print(f"\n== {query}")
        search(query)
