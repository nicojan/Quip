#!/bin/bash
# Saves real Giphy search results for the queries a demo scene types, so a search
# in the harness shows GIFs that match the words. Writes
# Demo/assets/search/<slug>/{manifest.json,<id>.gif} (git-ignored, like assets/).
#
# Reads your Giphy key from the Keychain (macOS asks once) and hands it to the
# fetcher through the environment; it is never printed or written to disk.
#
# Usage: Demo/fetch-search.sh "shocked" "celebrate"
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
OUT="$ROOT/Demo/assets/search"
[ "$#" -gt 0 ] || { echo "usage: fetch-search.sh <query>..."; exit 1; }

GIPHY_KEY="$(security find-generic-password -s com.nicojan.Quip -a giphyApiKey -w)"
[ -n "$GIPHY_KEY" ] || { echo "no Giphy key in the Keychain"; exit 1; }
export GIPHY_KEY

python3 -I - "$OUT" "$@" <<'EOF'
import json, os, sys, urllib.parse, urllib.request

out, queries = sys.argv[1], sys.argv[2:]
key = os.environ["GIPHY_KEY"]
for query in queries:
    slug = "-".join(query.lower().split())
    params = urllib.parse.urlencode({"api_key": key, "q": query, "limit": 36, "rating": "pg-13"})
    with urllib.request.urlopen(f"https://api.giphy.com/v1/gifs/search?{params}", timeout=30) as r:
        data = json.load(r)["data"]
    folder = os.path.join(out, slug)
    os.makedirs(folder, exist_ok=True)
    manifest = []
    for g in data:
        url = g.get("images", {}).get("fixed_width", {}).get("url")
        if not url:
            continue
        path = os.path.join(folder, g["id"] + ".gif")
        if not os.path.exists(path):
            with urllib.request.urlopen(url, timeout=30) as r, open(path, "wb") as f:
                f.write(r.read())
        manifest.append({"id": g["id"], "title": g.get("title", "")})
    with open(os.path.join(folder, "manifest.json"), "w") as f:
        json.dump(manifest, f, indent=1)
    print(f"{query}: {len(manifest)} GIFs -> {folder}")
EOF
