"""Creates the game passes and developer products listed in src/shared/Config/Monetization.luau
on Roblox (Open Cloud), for entries whose Id is still 0, and prints the new ids to paste back
into the config. Run ONLY through the manual "Monetization setup" workflow.

Needs ROBLOX_API_KEY with the game-pass:write and developer-product:write scopes and
UNIVERSE_ID. The key is never printed."""

import json
import os
import re
import sys
import urllib.request
import uuid

API_KEY = os.environ.get("ROBLOX_API_KEY", "")
UNIVERSE_ID = os.environ.get("UNIVERSE_ID", "")
DRY_RUN = os.environ.get("DRY_RUN", "true").lower() != "false"
SOURCE = "src/shared/Config/Monetization.luau"
LABEL = {"Passes": "Pass", "Products": "Product"}


def section(text, name):
    start = text.index(f"Monetization.{name} = {{")
    depth, i = 0, text.index("{", start)
    for j in range(i, len(text)):
        if text[j] == "{":
            depth += 1
        elif text[j] == "}":
            depth -= 1
            if depth == 0:
                return text[i + 1 : j]
    raise ValueError(name)


def entries(body):
    out = []
    for m in re.finditer(r"\n\t(\w+) = \{(.*?)\n?\t?\}", body, re.S):
        key, fields = m.group(1), m.group(2)
        def field(name):
            f = re.search(rf'{name} = ("([^"]*)"|(\d+))', fields)
            return None if not f else (f.group(2) if f.group(2) is not None else int(f.group(3)))
        out.append({"key": key, "id": field("Id") or 0, "name": field("Name"), "price": field("Price"),
                    "description": field("Description") or field("Name")})
    return out


def multipart(fields):
    boundary = uuid.uuid4().hex
    parts = []
    for name, value in fields.items():
        parts.append(f"--{boundary}\r\nContent-Disposition: form-data; name=\"{name}\"\r\n\r\n{value}\r\n".encode())
    parts.append(f"--{boundary}--\r\n".encode())
    return b"".join(parts), f"multipart/form-data; boundary={boundary}"


def post(url, fields):
    body, content_type = multipart(fields)
    req = urllib.request.Request(url, data=body, method="POST", headers={"x-api-key": API_KEY, "Content-Type": content_type})
    try:
        with urllib.request.urlopen(req, timeout=60) as r:
            return r.status, json.loads(r.read() or b"{}")
    except urllib.error.HTTPError as e:
        return e.code, e.read()[:400].decode(errors="replace")


def main():
    text = open(SOURCE).read()
    passes = entries(section(text, "Passes"))
    products = entries(section(text, "Products"))
    print(f"{'DRY RUN - ' if DRY_RUN else ''}universe {UNIVERSE_ID}: {len(passes)} passes, {len(products)} products")
    results = {"Passes": {}, "Products": {}}
    for kind, items, url in (
        ("Passes", passes, f"https://apis.roblox.com/game-passes/v1/universes/{UNIVERSE_ID}/game-passes"),
        ("Products", products, f"https://apis.roblox.com/developer-products/v2/universes/{UNIVERSE_ID}/developer-products"),
    ):
        for item in items:
            if item["id"]:
                print(f"  {LABEL[kind]} {item['key']}: already has id {item['id']}, skipped")
                continue
            print(f"  {LABEL[kind]} {item['key']}: '{item['name']}' for {item['price']} R$")
            if DRY_RUN:
                continue
            status, resp = post(url, {"name": item["name"], "description": item["description"], "price": str(item["price"]), "isForSale": "true"})
            new_id = isinstance(resp, dict) and (resp.get("gamePassId") or resp.get("productId") or resp.get("id"))
            print(f"    HTTP {status} -> {new_id or resp}")
            if new_id:
                results[kind][item["key"]] = new_id
    print("\n=== PASTE INTO Config/Monetization.luau ===")
    print(json.dumps(results, indent=2))


if __name__ == "__main__":
    if not API_KEY or not UNIVERSE_ID:
        print("::error::ROBLOX_API_KEY and UNIVERSE_ID are required")
        sys.exit(1)
    main()
