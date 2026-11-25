"""Read the magpie recipes' V2 resource tables without a Lua runtime.

Both recipes use Shape B — one `{ url, sha256 }` per architecture — because
upstream asset names encode the OS as `darwin`/`linux`/`windows` and carry no
version at all. These helpers let the tests lock the exact asset each
architecture resolves to: a wrong-architecture URL is the defect V2 exists to
prevent, and a checksum typo only surfaces after a ~100 MB download.

The parser is deliberately layout-tolerant (comments are stripped, braces are
matched, depth-1 keys are scanned) but fails closed: a table it cannot read
raises instead of returning an empty result that a test might read as "fine".
"""
import re

ARCHES = ("x86_64", "aarch64")
PLATFORMS = ("linux", "macosx", "windows")


def _code(path):
    return re.sub(r"--[^\n]*", "", open(path, encoding="utf-8").read())


def _block(text, start):
    assert text[start] == "{", f"expected '{{' at offset {start}"
    depth = 0
    for i in range(start, len(text)):
        char = text[i]
        if char == "{":
            depth += 1
        elif char == "}":
            depth -= 1
            if depth == 0:
                return text[start:i + 1]
    raise AssertionError("unbalanced braces in recipe")


def _entries(block):
    """Yield (key, value block) for the table's depth-1 table-valued keys."""
    body = block[1:-1]
    i = 0
    while i < len(body):
        match = re.match(r'\s*(?:\["([^"]+)"\]|([A-Za-z_][\w-]*))\s*=\s*\{', body[i:])
        if not match:
            i += 1
            continue
        key = match.group(1) or match.group(2)
        brace = i + match.end() - 1
        value = _block(body, brace)
        yield key, value
        i = brace + len(value)


def xpm_platforms(path):
    """Return {platform: platform table block} from the recipe's `xpm`."""
    text = _code(path)
    match = re.search(r"(?m)^\s*xpm\s*=\s*\{", text)
    assert match, f"{path}: no xpm table"
    xpm = _block(text, text.index("{", match.start()))
    return {key: value for key, value in _entries(xpm) if key in PLATFORMS}


def latest_refs(path):
    refs = {}
    for platform, block in xpm_platforms(path).items():
        latest = dict(_entries(block)).get("latest")
        assert latest, f"{path}: {platform} has no latest entry"
        match = re.search(r'ref\s*=\s*"([^"]+)"', latest)
        assert match, f"{path}: {platform}.latest has no ref"
        refs[platform] = match.group(1)
    return refs


def platform_resources(path, version):
    """Return {platform: {arch: {"url": ..., "sha256": ...}}}."""
    result = {}
    for platform, block in xpm_platforms(path).items():
        entries = dict(_entries(block))
        assert version in entries, f"{path}: {platform} has no {version} entry"
        arches = {key: value for key, value in _entries(entries[version]) if key in ARCHES}
        assert set(arches) == set(ARCHES), \
            f"{path}: {platform} declares {sorted(arches)}, expected {sorted(ARCHES)}"
        parsed = {}
        for arch, asset in arches.items():
            url = re.search(r'url\s*=\s*"([^"]+)"', asset)
            sha = re.search(r'sha256\s*=\s*"([0-9a-f]{64})"', asset)
            assert url and sha, f"{path}: {platform}/{arch} is not a {{url, sha256}} pair"
            parsed[arch] = {"url": url.group(1), "sha256": sha.group(1)}
        result[platform] = parsed
    return result