"""Bump the pinned release binaries in the Dockerfile to their latest GitHub release.

Usage: update-pins.py [Dockerfile]

Only releases at least MIN_AGE_DAYS old are taken, so a compromised or broken
release has time to be noticed and pulled before it lands in the image.
Prints one line per bumped tool; prints nothing when everything is current.
"""
import datetime
import hashlib
import json
import os
import re
import sys
import urllib.request

MIN_AGE_DAYS = 14

# ARG prefix -> GitHub repo, tag format, release asset per architecture
# (an empty arch key means one asset for all architectures)
TOOLS = {
    "TTYD": ("tsl0922/ttyd", "{v}", {"AMD64": "ttyd.x86_64", "ARM64": "ttyd.aarch64"}),
    "STARSHIP": ("starship/starship", "v{v}", {
        "AMD64": "starship-x86_64-unknown-linux-musl.tar.gz",
        "ARM64": "starship-aarch64-unknown-linux-musl.tar.gz",
    }),
    "BUN": ("oven-sh/bun", "bun-v{v}", {"AMD64": "bun-linux-x64.zip", "ARM64": "bun-linux-aarch64.zip"}),
    "NERDFONT": ("ryanoasis/nerd-fonts", "v{v}", {"": "JetBrainsMono.tar.xz"}),
}


def fetch(url, accept="application/vnd.github+json"):
    req = urllib.request.Request(url, headers={"Accept": accept, "User-Agent": "update-pins"})
    # Token only for the API, and as unredirected header: urllib forwards normal headers on redirects
    if os.environ.get("GH_TOKEN") and url.startswith("https://api.github.com/"):
        req.add_unredirected_header("Authorization", f"Bearer {os.environ['GH_TOKEN']}")
    with urllib.request.urlopen(req, timeout=120) as r:
        return r.read()


def parse_time(t):
    return datetime.datetime.fromisoformat(t.replace("Z", "+00:00"))


def parse_version(v):
    return tuple(int(p) for p in v.split("."))


def pick_release(releases, tag_format, asset_names, now):
    """Newest stable release old enough and carrying every needed asset, as (version, release)."""
    pattern = re.compile("^" + re.escape(tag_format).replace(re.escape("{v}"), r"(\d+(?:\.\d+)*)") + "$")
    best = None
    for rel in releases:
        m = pattern.match(rel["tag_name"])
        if not m or rel["draft"] or rel["prerelease"]:
            continue
        by_name = {a["name"]: a for a in rel["assets"]}
        if not set(asset_names) <= by_name.keys():
            continue
        # Assets can be replaced after publishing, so they must be old enough too
        stamps = [rel["published_at"]] + [by_name[n]["updated_at"] for n in asset_names]
        if any(now - parse_time(t) < datetime.timedelta(days=MIN_AGE_DAYS) for t in stamps):
            continue
        if best is None or parse_version(m.group(1)) > parse_version(best[0]):
            best = (m.group(1), rel)
    return best


def asset_sha256(asset):
    digest = asset.get("digest") or ""
    if digest.startswith("sha256:"):
        return digest.removeprefix("sha256:")
    # Older releases have no GitHub-computed digest; hash the download instead
    return hashlib.sha256(fetch(asset["browser_download_url"], "application/octet-stream")).hexdigest()


def get_arg(text, name):
    m = re.search(rf"^ARG {name}=(\S+)$", text, re.M)
    if not m:
        sys.exit(f"ARG {name} not found in Dockerfile")
    return m.group(1)


def set_arg(text, name, value):
    get_arg(text, name)
    return re.sub(rf"^ARG {name}=\S+$", f"ARG {name}={value}", text, count=1, flags=re.M)


def main():
    path = sys.argv[1] if len(sys.argv) > 1 else "Dockerfile"
    text = open(path, encoding="utf-8").read()
    now = datetime.datetime.now(datetime.timezone.utc)
    for prefix, (repo, tag_format, assets) in TOOLS.items():
        current = get_arg(text, f"{prefix}_VERSION")
        releases = json.loads(fetch(f"https://api.github.com/repos/{repo}/releases?per_page=50"))
        picked = pick_release(releases, tag_format, assets.values(), now)
        if not picked or parse_version(picked[0]) <= parse_version(current):
            continue
        version, rel = picked
        by_name = {a["name"]: a for a in rel["assets"]}
        text = set_arg(text, f"{prefix}_VERSION", version)
        for arch, name in assets.items():
            arg = f"{prefix}_SHA256" + (f"_{arch}" if arch else "")
            text = set_arg(text, arg, asset_sha256(by_name[name]))
        print(f"{prefix.lower()} {current} -> {version}")
    open(path, "w", encoding="utf-8").write(text)


if __name__ == "__main__":
    main()
