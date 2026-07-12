#!/usr/bin/env python3
"""Offline tests for tools/xpkg_ci.py."""

import importlib.util
import json
import tarfile
import tempfile
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
spec = importlib.util.spec_from_file_location("xpkg_ci", ROOT / "tools" / "xpkg_ci.py")
mod = importlib.util.module_from_spec(spec)
spec.loader.exec_module(mod)


def main() -> int:
    with tempfile.TemporaryDirectory() as d:
        root = Path(d)
        payload = root / "payload.txt"
        payload.write_text("payload\n", encoding="utf-8")
        archive = root / "payload.tar.gz"
        with tarfile.open(archive, "w:gz") as tar:
            tar.add(payload, arcname="payload.txt")
        assert mod.validate_archive(archive) is None

        p = Path(d) / "foo.lua"
        p.write_text(
            'package = { name = "foo", repo = "https://github.com/acme/foo", '
            'ci = { mirror = true, update = true }, xpm = { linux = {} } }',
            encoding="utf-8",
        )
        record = mod.inspect_package(p)
        assert record["mirror"] is True
        assert record["update"] is True
        assert record["source"] is None

        mapped = Path(d) / "mapped.lua"
        mapped.write_text(
            'package = { name = "mapped", xpm = { source = { '
            'GLOBAL = "https://github.com/acme/mapped/${version}.tar.gz", '
            'CN = "https://gitcode.com/acme/mapped/${version}.tar.gz" } } }',
            encoding="utf-8",
        )
        mapped_record = mod.inspect_package(mapped)
        assert mapped_record["source"]["GLOBAL"].endswith("${version}.tar.gz")
        assert mapped_record["source"]["CN"].startswith("https://gitcode.com/")

        manifest = {
            "format": 1,
            "package": "foo",
            "version": "1.0.0",
            "assets": [{
                "os": "linux",
                "arch": "x86_64",
                "filename": "foo.tar.gz",
                "size": 10,
                "sha256": "a" * 64,
                "source_url": "https://example.test/foo.tar.gz",
            }],
        }
        assert mod.validate_manifest(manifest) == []
        broken = dict(manifest)
        broken["assets"] = [{**manifest["assets"][0], "sha256": "bad"}]
        assert mod.validate_manifest(broken)
        manifest_path = Path(d) / "manifest.json"
        manifest_path.write_text(json.dumps(manifest), encoding="utf-8")
        args = type("Args", (), {"manifest": str(manifest_path), "execute": False})()
        assert mod.cmd_mirror(args) == 0
    print("all xpkg-ci tests passed")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
