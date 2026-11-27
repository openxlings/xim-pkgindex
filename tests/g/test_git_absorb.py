"""Official git-absorb binaries: standalone fixups in a private repository."""
import json
import os
from pathlib import Path
import shutil
import subprocess

import pytest

from tests.lib.assertions import (
    assert_no_bashrc_modification,
    assert_no_direct_path_modification,
    assert_no_direct_pkg_manager,
    assert_no_exec_xvm,
    assert_no_typos,
    assert_required_fields,
    assert_uses_new_api,
    assert_valid_spec,
    assert_valid_type,
    assert_valid_xvm_node_kinds,
)
from tests.lib.platform_utils import under_test, xlings_home
from tests.lib.xpkg_parser import parse_xpkg

PKG = "git-absorb"
VERSION = "0.9.0"
PKG_FILE = "pkgs/g/git-absorb.lua"
ROOT = Path(__file__).resolve().parents[2]
SUFFIX = ".exe" if os.name == "nt" else ""


def _run(args, **kwargs):
    result = subprocess.run(
        [str(arg) for arg in args], capture_output=True, text=True,
        timeout=240, **kwargs,
    )
    assert result.returncode == 0, result.stdout + result.stderr
    return result.stdout


def _xlings(*args):
    executable = Path(xlings_home()) / "bin" / ("xlings" + SUFFIX)
    if not executable.is_file():
        found = shutil.which("xlings" + SUFFIX)
        assert found, "native xlings is required for lifecycle tests"
        executable = Path(found)
    return _run([executable, *args], cwd=ROOT)


def _subos():
    base = Path(xlings_home()) / "subos"
    explicit = os.environ.get("XLINGS_TEST_SUBOS")
    candidates = [explicit] if explicit else ["current", "default"]
    for name in candidates:
        directory = base / name
        if (directory / ".xlings.json").is_file():
            return directory
    raise AssertionError("no initialized test SubOS")


def _payload():
    namespace = under_test(PKG).split(":", 1)[0]
    return Path(xlings_home()) / "data" / "xpkgs" / f"{namespace}-x-{PKG}" / VERSION


@pytest.fixture(scope="module")
def installed():
    _xlings("install", under_test(PKG, VERSION), "-y")
    executable = _payload() / (PKG + SUFFIX)
    assert executable.is_file(), "installation must produce a real executable"
    return executable


@pytest.mark.static
@pytest.mark.parametrize("check", [
    assert_required_fields, assert_valid_spec, assert_valid_type,
    assert_valid_xvm_node_kinds,
])
def test_metadata(check):
    check(parse_xpkg(PKG_FILE))


@pytest.mark.static
def test_supported_platforms():
    assert set(parse_xpkg(PKG_FILE).platforms) == {"linux", "windows"}


@pytest.mark.isolation
@pytest.mark.parametrize("check", [
    assert_no_exec_xvm, assert_no_bashrc_modification,
    assert_no_direct_path_modification, assert_uses_new_api,
    assert_no_direct_pkg_manager, assert_no_typos,
])
def test_isolation(check):
    check(PKG_FILE)


@pytest.mark.index
def test_registration():
    _xlings("config", "--add-xpkg", ROOT / PKG_FILE)


@pytest.mark.lifecycle
def test_install_and_reinstall(installed):
    _xlings("install", under_test(PKG, VERSION), "-y")
    assert installed.is_file()
    for name in ("LICENSE.md", "README.md", "doc/git-absorb.1",
                 "doc/git-absorb.html", "doc/git-absorb.adoc"):
        assert (_payload() / name).is_file(), name
    config = json.loads((_subos() / ".xlings.json").read_text(encoding="utf-8"))
    assert PKG in config.get("workspace", {}), config
    shim = _subos() / "bin" / (PKG + SUFFIX)
    assert shim.is_file()
    assert VERSION in _run([shim, "--version"])


@pytest.mark.verify
def test_fixup_targets_earlier_commit_without_git_on_path(installed, tmp_path):
    # Git is fixture tooling, not a dependency of standalone libgit2 fixups.
    git = shutil.which("git")
    assert git, "Git is required to construct and inspect the private test fixture"
    git = str(Path(git).absolute())
    home = tmp_path / "home"
    home.mkdir()
    hooks = tmp_path / "empty-hooks"
    hooks.mkdir()
    template = tmp_path / "empty-template"
    template.mkdir()
    empty_path = tmp_path / "empty-path"
    empty_path.mkdir()
    repo = tmp_path / "repository"
    repo.mkdir()
    env = {key: value for key, value in os.environ.items()
           if not key.upper().startswith("GIT_") and key.upper() != "EMAIL"}
    env.update({
        "HOME": str(home), "USERPROFILE": str(home),
        "XDG_CONFIG_HOME": str(home), "GIT_CONFIG_NOSYSTEM": "1",
        "GIT_CONFIG_GLOBAL": os.devnull, "GIT_CONFIG_SYSTEM": os.devnull,
        "GIT_ATTR_NOSYSTEM": "1", "GIT_TERMINAL_PROMPT": "0",
        "GIT_AUTHOR_NAME": "Absorb Fixture",
        "GIT_AUTHOR_EMAIL": "absorb-fixture@example.invalid",
        "GIT_COMMITTER_NAME": "Absorb Fixture",
        "GIT_COMMITTER_EMAIL": "absorb-fixture@example.invalid",
        "GIT_AUTHOR_DATE": "2001-01-01T00:00:00+0000",
        "GIT_COMMITTER_DATE": "2001-01-01T00:00:00+0000",
    })

    def run_git(*args):
        return _run([git, *args], cwd=repo, env=env)

    run_git("init", "--initial-branch=fixture", f"--template={template}")
    settings = {
        "user.name": "Absorb Fixture", "user.email": "absorb-fixture@example.invalid",
        "commit.gpgsign": "false", "tag.gpgsign": "false",
        "core.hooksPath": str(hooks), "core.autocrlf": "false",
        "core.safecrlf": "false", "core.fsmonitor": "false",
        "core.attributesFile": os.devnull, "commit.template": os.devnull,
        "absorb.autoStageIfNothingStaged": "false",
    }
    for key, value in settings.items():
        run_git("config", "--local", key, value)

    alpha = repo / "alpha.txt"
    beta = repo / "beta.txt"
    alpha.write_bytes(b"original alpha\n")
    run_git("add", "alpha.txt")
    run_git("commit", "-m", "Introduce alpha")
    first = run_git("rev-parse", "HEAD").strip()
    beta.write_bytes(b"original beta\n")
    run_git("add", "beta.txt")
    run_git("commit", "-m", "Introduce beta")
    second = run_git("rev-parse", "HEAD").strip()
    alpha.write_bytes(b"corrected alpha\n")
    run_git("add", "alpha.txt")
    beta.write_bytes(b"unstaged beta\n")

    # An empty PATH proves fixup creation does not silently depend on host Git.
    _run([installed], cwd=repo, env={**env, "PATH": str(empty_path)})
    assert run_git("log", "-1", "--format=%s").strip() == "fixup! Introduce alpha"
    assert run_git("rev-list", "--count", "HEAD").strip() == "3"
    assert run_git("rev-parse", "HEAD^").strip() == second
    assert run_git("rev-parse", "HEAD^^").strip() == first
    assert run_git("show", "HEAD:alpha.txt") == "corrected alpha\n"
    assert run_git("show", "HEAD:beta.txt") == "original beta\n"
    assert run_git("diff", "--cached", "--exit-code") == ""
    assert run_git("show", ":alpha.txt") == "corrected alpha\n"
    assert beta.read_bytes() == b"unstaged beta\n"
    assert run_git("status", "--porcelain") == " M beta.txt\n"
    assert not (repo / ".git" / "rebase-merge").exists()
    assert not (repo / ".git" / "rebase-apply").exists()
