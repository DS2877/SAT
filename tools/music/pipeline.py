"""Music pipeline, run by .github/workflows/music.yml (GitHub runners have internet access).

For every entry in music/tracks.json:
  * only `query`  -> search Wikimedia Commons, print candidate recordings with their licence
                     and length (discovery; a human/agent then pins `file`)
  * `file` set    -> download, check the licence is public domain / CC0 / CC-BY, normalise
                     loudness, trim to MAX_SECONDS, encode OGG, upload to Roblox as Audio
  * `synth` set   -> encode the generated sting (tools/music/stings.py) and upload it
  * `assetId` set -> already done, skipped

Uploads use the Open Cloud Assets API with ROBLOX_API_KEY. The key is never printed.
Results (asset ids, licence and attribution) are printed and written to music-results.json.
"""

import json
import os
import subprocess
import sys
import time
import urllib.parse
import urllib.request
import uuid

UA = "StealTheTreasureMusicPipeline/1.0 (GitHub Actions; DS2877/SAT)"
COMMONS = "https://commons.wikimedia.org/w/api.php"
MAX_SECONDS = 415  # Roblox audio uploads are limited to 7 minutes
ALLOWED = ("public domain", "pd", "cc0", "cc by 1", "cc by 2", "cc by 3", "cc by 4", "cc-by")
API_KEY = os.environ.get("ROBLOX_API_KEY", "")
UNIVERSE_ID = os.environ.get("UNIVERSE_ID", "")
WORK = "music-work"


def http(url, data=None, headers=None, method=None):
    req = urllib.request.Request(url, data=data, headers={"User-Agent": UA, **(headers or {})}, method=method)
    try:
        with urllib.request.urlopen(req, timeout=120) as resp:
            return resp.status, resp.read()
    except urllib.error.HTTPError as err:
        return err.code, err.read()


def commons(params):
    params = {"format": "json", "formatversion": "2", **params}
    status, body = http(COMMONS + "?" + urllib.parse.urlencode(params))
    if status != 200:
        raise RuntimeError(f"Commons API HTTP {status}")
    return json.loads(body)


def strip_html(text):
    out, depth = [], 0
    for ch in text or "":
        if ch == "<":
            depth += 1
        elif ch == ">":
            depth = max(0, depth - 1)
        elif depth == 0:
            out.append(ch)
    return " ".join("".join(out).split())


def file_info(titles):
    data = commons({
        "action": "query",
        "titles": "|".join(titles),
        "prop": "imageinfo",
        "iiprop": "url|size|mime|extmetadata|metadata",
    })
    infos = []
    for page in data.get("query", {}).get("pages", []):
        ii = (page.get("imageinfo") or [{}])[0]
        meta = ii.get("extmetadata", {})
        length = None
        for m in ii.get("metadata") or []:
            if m.get("name") in ("length", "playtime_seconds", "duration"):
                try:
                    length = float(m.get("value"))
                except (TypeError, ValueError):
                    pass
        infos.append({
            "title": page.get("title"),
            "url": ii.get("url"),
            "mime": ii.get("mime"),
            "size": ii.get("size"),
            "seconds": length,
            "license": strip_html(meta.get("LicenseShortName", {}).get("value", "")),
            "artist": strip_html(meta.get("Artist", {}).get("value", ""))[:120],
            "credit": strip_html(meta.get("Credit", {}).get("value", ""))[:160],
            "page": "https://commons.wikimedia.org/wiki/" + urllib.parse.quote((page.get("title") or "").replace(" ", "_")),
        })
    return infos


def discover(entry):
    data = commons({
        "action": "query",
        "list": "search",
        "srsearch": entry["query"] + " filetype:audio",
        "srnamespace": "6",
        "srlimit": "15",
    })
    titles = [hit["title"] for hit in data.get("query", {}).get("search", [])]
    if not titles:
        print(f"  (no Commons audio found for '{entry['query']}')")
        return []
    infos = file_info(titles)
    for info in infos:
        secs = f"{info['seconds']:.0f}s" if info["seconds"] else "?s"
        print(f"  - {info['title']} | {info['license']} | {secs} | {info['mime']} | {info['size']} B | {info['artist']}")
    return infos


def licence_ok(licence):
    low = (licence or "").lower()
    return any(tag in low for tag in ALLOWED) and "nc" not in low.split() and "-nc" not in low


def ffmpeg(src, dst, trim=True):
    af = "loudnorm=I=-16:TP=-1.5:LRA=11"
    cmd = ["ffmpeg", "-y", "-loglevel", "error", "-i", src]
    if trim:
        af += f",afade=t=out:st={MAX_SECONDS - 6}:d=6"
        cmd += ["-t", str(MAX_SECONDS)]
    cmd += ["-af", af, "-ac", "2", "-ar", "44100", "-c:a", "libvorbis", "-q:a", "4", dst]
    subprocess.run(cmd, check=True)


def creator():
    status, body = http(f"https://games.roblox.com/v1/games?universeIds={UNIVERSE_ID}")
    if status != 200:
        raise RuntimeError(f"games API HTTP {status}")
    game = json.loads(body)["data"][0]["creator"]
    kind = "userId" if game["type"] == "User" else "groupId"
    print(f"Experience owner: {game['type']} {game['id']}")
    return {kind: str(game["id"])}


def upload(path, display_name, description, owner):
    boundary = uuid.uuid4().hex
    request = {
        "assetType": "Audio",
        "displayName": display_name[:50],
        "description": description[:1000],
        "creationContext": {"creator": owner},
    }
    with open(path, "rb") as f:
        content = f.read()
    body = b"".join([
        f"--{boundary}\r\nContent-Disposition: form-data; name=\"request\"\r\nContent-Type: application/json\r\n\r\n".encode(),
        json.dumps(request).encode(),
        f"\r\n--{boundary}\r\nContent-Disposition: form-data; name=\"fileContent\"; filename=\"{os.path.basename(path)}\"\r\nContent-Type: audio/ogg\r\n\r\n".encode(),
        content,
        f"\r\n--{boundary}--\r\n".encode(),
    ])
    status, resp = http(
        "https://apis.roblox.com/assets/v1/assets",
        data=body,
        headers={"x-api-key": API_KEY, "Content-Type": f"multipart/form-data; boundary={boundary}"},
        method="POST",
    )
    if status != 200:
        return None, f"upload HTTP {status}: {resp[:400].decode(errors='replace')}"
    op = json.loads(resp)
    for _ in range(60):
        if op.get("done"):
            break
        time.sleep(3)
        op_id = op.get("operationId") or op.get("path", "").split("/")[-1]
        status, resp = http(f"https://apis.roblox.com/assets/v1/operations/{op_id}", headers={"x-api-key": API_KEY})
        if status != 200:
            return None, f"operation HTTP {status}: {resp[:400].decode(errors='replace')}"
        op = json.loads(resp)
    if not op.get("done"):
        return None, "operation did not finish in time"
    if op.get("error"):
        return None, f"operation error: {json.dumps(op['error'])[:400]}"
    asset_id = (op.get("response") or {}).get("assetId")
    return asset_id, None


def main():
    with open("music/tracks.json") as f:
        tracks = json.load(f)["tracks"]
    os.makedirs(WORK, exist_ok=True)
    results = {"discovery": {}, "uploaded": {}, "errors": {}}
    pending = [t for t in tracks if not t.get("assetId") and (t.get("file") or t.get("synth"))]
    owner = None
    if pending:
        if not API_KEY:
            print("::error::ROBLOX_API_KEY is not available")
            sys.exit(1)
        owner = creator()
        subprocess.run([sys.executable, "tools/music/stings.py", WORK], check=True)

    for entry in tracks:
        key = entry["key"]
        if entry.get("assetId"):
            continue
        print(f"\n== {key}: {entry['name']}")
        try:
            if entry.get("synth"):
                src = os.path.join(WORK, entry["synth"])
                dst = os.path.join(WORK, key + ".ogg")
                ffmpeg(src, dst, trim=False)
                description = "Original sting generated for Steal the Treasure."
                credit = {"license": "Original (generated)", "source": "tools/music/stings.py"}
            elif entry.get("file"):
                info = file_info([entry["file"]])[0]
                if not info.get("url"):
                    raise RuntimeError(f"file not found on Commons: {entry['file']}")
                if not licence_ok(info["license"]):
                    raise RuntimeError(f"licence not allowed: {info['license']}")
                ext = os.path.splitext(info["url"])[1] or ".ogg"
                src = os.path.join(WORK, key + "_src" + ext)
                status, data = http(info["url"])
                if status != 200:
                    raise RuntimeError(f"download HTTP {status}")
                with open(src, "wb") as f:
                    f.write(data)
                dst = os.path.join(WORK, key + ".ogg")
                ffmpeg(src, dst, trim=True)
                description = f"{entry['name']} by {entry.get('composer', '')}. Recording: {info['artist']} ({info['license']}), {info['page']}"
                credit = {"license": info["license"], "artist": info["artist"], "source": info["page"]}
            else:
                results["discovery"][key] = discover(entry)
                continue
            asset_id, error = upload(dst, entry["name"], description, owner)
            if error:
                raise RuntimeError(error)
            print(f"  uploaded -> rbxassetid://{asset_id}")
            results["uploaded"][key] = {"assetId": asset_id, "name": entry["name"], "role": entry["role"], **credit}
        except Exception as err:  # keep going: one bad track must not block the rest
            print(f"  ERROR: {err}")
            results["errors"][key] = str(err)

    with open("music-results.json", "w") as f:
        json.dump(results, f, indent=2)
    print("\n=== RESULTS ===")
    print(json.dumps({"uploaded": results["uploaded"], "errors": results["errors"]}, indent=2))


if __name__ == "__main__":
    main()
