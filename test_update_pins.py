import datetime
import importlib.util
import pathlib

# The script name has a dash, so it cannot be imported by name
spec = importlib.util.spec_from_file_location("pins", pathlib.Path(__file__).with_name("update-pins.py"))
assert spec and spec.loader
pins = importlib.util.module_from_spec(spec)
spec.loader.exec_module(pins)

NOW = datetime.datetime(2026, 10, 22, tzinfo=datetime.timezone.utc)


def ago(days):
    return (NOW - datetime.timedelta(days=days)).isoformat().replace("+00:00", "Z")


def rel(tag, days_old, assets=("a",), prerelease=False, asset_days_old=None):
    updated = ago(days_old if asset_days_old is None else asset_days_old)
    return {"tag_name": tag, "draft": False, "prerelease": prerelease, "published_at": ago(days_old),
            "assets": [{"name": n, "updated_at": updated} for n in assets]}


def test_pick_release():
    releases = [
        rel("bun-v1.10.0", 3),                    # too new
        rel("bun-v1.9.0", 20, prerelease=True),   # prerelease
        rel("bun-v1.8.0", 20, assets=("b",)),     # missing asset
        rel("bun-v1.7.0", 40, asset_days_old=2),  # asset replaced recently
        rel("bun-v1.4.2", 40),
        rel("bun-v1.10.0-canary", 40),            # tag does not match
        rel("bun-v1.3.14", 100),
    ]
    assert pins.pick_release(releases, "bun-v{v}", ["a"], NOW)[0] == "1.4.2"
    assert pins.pick_release([rel("1.7.7", 400)], "{v}", ["a"], NOW)[0] == "1.7.7"
    assert pins.pick_release([rel("v1.0", 1)], "v{v}", ["a"], NOW) is None


def test_set_arg():
    text = "ARG BUN_VERSION=1.4.2\nARG BUN_SHA256_AMD64=aa\n"
    assert pins.set_arg(text, "BUN_SHA256_AMD64", "bb") == "ARG BUN_VERSION=1.4.2\nARG BUN_SHA256_AMD64=bb\n"


if __name__ == "__main__":
    test_pick_release()
    test_set_arg()
    print("ok")
