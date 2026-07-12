#!/usr/bin/env python3
"""Offline tests for tools/xpkg_ci.py."""

import importlib.util
import json
import subprocess
import tarfile
import tempfile
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
spec = importlib.util.spec_from_file_location("xpkg_ci", ROOT / "tools" / "xpkg_ci.py")
mod = importlib.util.module_from_spec(spec)
spec.loader.exec_module(mod)

try:  # under pytest these run in the L2 isolation pass; standalone still works
    import pytest
    pytestmark = pytest.mark.isolation
except ImportError:
    pytest = None


class FakeRun:
    """Records subprocess.run calls and answers from a routing callback."""

    def __init__(self, route):
        self.route = route
        self.calls = []
        self.envs = []

    def __call__(self, cmd, *args, **kwargs):
        self.calls.append(list(cmd))
        self.envs.append(kwargs.get("env"))
        rc, out, err = self.route(list(cmd))
        return subprocess.CompletedProcess(cmd, rc, out, err)

    def env_for(self, *prefix):
        prefix = list(prefix)
        for call, env in zip(self.calls, self.envs):
            if call[: len(prefix)] == prefix:
                return env
        return None

    def ran(self, *prefix):
        prefix = list(prefix)
        return any(call[: len(prefix)] == prefix for call in self.calls)


def test_verify_mirror_content():
    good = "a" * 64
    assets = [{"os": "linux", "arch": "x86_64", "filename": "foo.tar.gz",
               "size": 10, "sha256": good, "source_url": "https://x.test/foo.tar.gz"}]
    original = mod._download_sha256
    try:
        # Both mirrors serve the authoritative bytes -> pass.
        mod._download_sha256 = lambda url, timeout=300: (good, "")
        assert mod.verify_mirror_content("xlings-res/foo", "xlings-res/foo", "1.0.0", assets) is None

        # GitCode serves different bytes -> fail closed.
        def mismatched(url, timeout=300):
            return (good if "github.com" in url else "b" * 64, "")
        mod._download_sha256 = mismatched
        problem = mod.verify_mirror_content("xlings-res/foo", "xlings-res/foo", "1.0.0", assets)
        assert problem and "GitCode content mismatch" in problem, problem

        # A mirror that cannot be fetched fails closed too.
        mod._download_sha256 = lambda url, timeout=300: (None, "boom")
        problem = mod.verify_mirror_content("xlings-res/foo", "xlings-res/foo", "1.0.0", assets)
        assert problem and "content fetch failed" in problem, problem
    finally:
        mod._download_sha256 = original


def test_ensure_mirror_repos():
    original = mod.subprocess.run
    try:
        # Both repos already present and non-empty -> no write calls.
        def both_exist(cmd):
            if cmd[:3] == ["gh", "repo", "view"]:
                return (0, "{}", "")
            if cmd[:2] == ["git", "ls-remote"]:
                return (0, "abc123\trefs/heads/main\n", "")
            raise AssertionError(f"unexpected call: {cmd}")
        fake = FakeRun(both_exist)
        mod.subprocess.run = fake
        assert mod.ensure_mirror_repos("foo", "xlings-res/foo", "xlings-res/foo") is None
        assert not fake.ran("gh", "repo", "create")
        assert not fake.ran("tools/gtc", "repo", "create")

        # Neither repo exists -> create both, seed GitCode.
        def none_exist(cmd):
            if cmd[:3] == ["gh", "repo", "view"]:
                return (1, "", "not found")
            if cmd[:3] == ["gh", "repo", "create"]:
                return (0, "", "")
            if cmd[:2] == ["git", "ls-remote"]:
                return (0, "", "")  # empty -> no main branch
            if cmd[:3] == ["tools/gtc", "repo", "create"]:
                return (0, "created", "")
            if cmd[:3] == ["tools/gtc", "repo", "push"]:
                return (0, "pushed", "")
            raise AssertionError(f"unexpected call: {cmd}")
        fake = FakeRun(none_exist)
        mod.subprocess.run = fake
        assert mod.ensure_mirror_repos("foo", "xlings-res/foo", "xlings-res/foo") is None
        assert fake.ran("gh", "repo", "create")
        assert fake.ran("tools/gtc", "repo", "create")
        assert fake.ran("tools/gtc", "repo", "push")
        # the seed push must carry a git identity so the commit works on a bare
        # CI runner (no global git user.name/email)
        push_env = fake.env_for("tools/gtc", "repo", "push")
        assert push_env and push_env.get("GIT_AUTHOR_NAME") and push_env.get("GIT_COMMITTER_EMAIL"), push_env

        # GitCode seed push failure is reported, fail closed.
        def push_fails(cmd):
            if cmd[:3] == ["gh", "repo", "view"]:
                return (0, "{}", "")
            if cmd[:2] == ["git", "ls-remote"]:
                return (0, "", "")
            if cmd[:3] == ["tools/gtc", "repo", "create"]:
                return (0, "created", "")
            if cmd[:3] == ["tools/gtc", "repo", "push"]:
                return (1, "", "auth denied")
            raise AssertionError(f"unexpected call: {cmd}")
        mod.subprocess.run = FakeRun(push_fails)
        problem = mod.ensure_mirror_repos("foo", "xlings-res/foo", "xlings-res/foo")
        assert problem and "seed GitCode repo" in problem, problem
    finally:
        mod.subprocess.run = original


class FakeResp:
    status = 206

    def __enter__(self):
        return self

    def __exit__(self, *a):
        return False

    def read(self, n=-1):
        return b"x"


def test_cmd_mirror_execute_content_gate():
    good = "a" * 64
    manifest = {
        "format": 1, "package": "foo", "version": "1.0.0",
        "assets": [{"os": "linux", "arch": "x86_64", "filename": "foo.tar.gz",
                    "size": 10, "sha256": good, "source_url": "https://x.test/foo.tar.gz"}],
    }

    def route(cmd):
        if cmd[:3] == ["gh", "repo", "view"]:
            return (0, "{}", "")
        if cmd[:2] == ["git", "ls-remote"]:
            return (0, "ref\trefs/heads/main\n", "")
        if cmd[:3] == ["gh", "release", "view"]:
            return (0, json.dumps({"assets": [{"name": "manifest.json"}]}), "")
        raise AssertionError(f"unexpected call: {cmd}")

    orig_run = mod.subprocess.run
    orig_urlopen = mod.urllib.request.urlopen
    orig_dl = mod._download_sha256
    try:
        with tempfile.TemporaryDirectory() as d:
            mpath = Path(d) / "manifest.json"
            mpath.write_text(json.dumps(manifest), encoding="utf-8")
            mod.subprocess.run = FakeRun(route)
            mod.urllib.request.urlopen = lambda req, timeout=None: FakeResp()
            args = type("A", (), {"manifest": str(mpath), "execute": True,
                                  "ensure_repos": True, "content_verify": True})()
            # Mirrors serve the authoritative bytes -> publish succeeds.
            mod._download_sha256 = lambda url, timeout=300: (good, "")
            assert mod.cmd_mirror(args) == 0
            # A mirror serving wrong bytes must block publication.
            mod._download_sha256 = lambda url, timeout=300: ("b" * 64, "")
            assert mod.cmd_mirror(args) == 2
    finally:
        mod.subprocess.run = orig_run
        mod.urllib.request.urlopen = orig_urlopen
        mod._download_sha256 = orig_dl


def test_resolve_platform_arches():
    r = mod.resolve_platform_arches
    # arch-parameterized template -> every declared arch
    assert r(["x86_64", "aarch64"], "u/{arch}.tar.gz", {}) == (["x86_64", "aarch64"], None)
    assert r(["x86_64", "aarch64"], "u/${arch}.tar.gz", {}) == (["x86_64", "aarch64"], None)
    # single declared arch -> that arch
    assert r(["x86_64"], "u/bat-x86_64-linux.tar.gz", {}) == (["x86_64"], None)
    # multi declared, single arch baked into the URL -> infer it (bat's shape)
    assert r(["x86_64", "aarch64"], "u/bat-x86_64-unknown-linux-musl.tar.gz", {}) == (["x86_64"], None)
    assert r(["x86_64", "aarch64"], "u/bat-aarch64-apple-darwin.tar.gz", {}) == (["aarch64"], None)
    # arch alias present in the URL (e.g. arm64) resolves to the declared arch
    assert r(["x86_64", "aarch64"], "u/foo-arm64.zip", {"aarch64": "arm64"}) == (["aarch64"], None)
    # default aliases apply even when the recipe declares none (jq's shape:
    # jq-linux-amd64 / jq-macos-arm64, archs = {x86_64, aarch64}, aliases = {})
    assert r(["x86_64", "aarch64"], "u/jq-linux-amd64", {}) == (["x86_64"], None)
    assert r(["x86_64", "aarch64"], "u/jq-macos-arm64", {}) == (["aarch64"], None)
    # non-parameterized URL with no matchable arch -> error, fail closed
    arches, err = r(["x86_64", "aarch64"], "u/foo-universal.tar.gz", {})
    assert arches is None and err and "cannot infer arch" in err, (arches, err)


def test_archive_suffix_gate():
    # Recognized archives are validated; raw binaries are not (no container).
    assert "jq-linux-amd64".endswith(mod.ARCHIVE_SUFFIXES) is False
    assert "xmake-bundle-v3.0.7.win64.exe".endswith(mod.ARCHIVE_SUFFIXES) is False
    assert "bat-v0.26.1-x86_64-unknown-linux-musl.tar.gz".endswith(mod.ARCHIVE_SUFFIXES) is True
    assert "foo.zip".endswith(mod.ARCHIVE_SUFFIXES) is True


def main() -> int:
    test_verify_mirror_content()
    test_ensure_mirror_repos()
    test_cmd_mirror_execute_content_gate()
    test_resolve_platform_arches()
    test_archive_suffix_gate()
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
