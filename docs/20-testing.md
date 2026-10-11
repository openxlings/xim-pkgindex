# Testing

**English** | [简体中文](zh/20-testing.md)

Every recipe has a pytest module beside it, and the repository has checks of its
own. This chapter is how to run them, how to add one, and what CI runs.

## Levels

| Level | Marker | Needs | Checks |
|---|---|---|---|
| L0 static | `static` | nothing | Lua syntax, required fields, `spec` / `type` values, known misspellings |
| L1 index | `index` | xlings | the recipe registers (`xlings config --add-xpkg`) |
| L2 isolation | `isolation` | nothing | no `os.exec("xvm ...")`, no shell profile edits, no `PATH` edits, `xim.libxpkg.*` APIs, no host package manager |
| L3 lifecycle | `lifecycle` | xlings, network | install and remove succeed |
| L4 verify | `verify` | the package installed | its programs run and do what they should |

## Running them

```bash
pip install pytest
pytest tests/ -m static                                  # seconds, no xlings
pytest tests/ -m "static or isolation"                   # what every pull request runs first
pytest tests/c/test_cmake.py -m "static or isolation" -v # one package
```

L1, L3 and L4 call xlings and install for real. Run them only with an isolated
`XLINGS_HOME`, never against your own home:

```bash
XLINGS_HOME="$(mktemp -d)" pytest tests/c/test_cmake.py -m "lifecycle or verify" -v
```

## Adding a test

The module mirrors the recipe: `pkgs/n/my-package.lua` →
`tests/n/test_my_package.py` (`-` becomes `_`).

```python
"""mypackage"""
import pytest
from tests.lib.xpkg_parser import parse_xpkg
from tests.lib.assertions import (
    assert_required_fields, assert_valid_spec, assert_valid_type,
    assert_no_typos, assert_no_exec_xvm, assert_no_bashrc_modification,
    assert_no_direct_path_modification, assert_uses_new_api,
    assert_xim_add_succeeds, assert_install_succeeds,
    assert_command_output, assert_xvm_registered,
)
from tests.lib.platform_utils import skip_if_not

PKG = "mypackage"
PKG_FILE = "pkgs/m/mypackage.lua"


@pytest.fixture(scope="module")
def meta():
    return parse_xpkg(PKG_FILE)


class TestStatic:
    @pytest.mark.static
    def test_required_fields(self, meta):
        assert_required_fields(meta)

    @pytest.mark.static
    def test_valid_spec(self, meta):
        assert_valid_spec(meta)

    @pytest.mark.static
    def test_valid_type(self, meta):
        assert_valid_type(meta)

    @pytest.mark.static
    def test_no_typos(self):
        assert_no_typos(PKG_FILE)


class TestIndex:
    @pytest.mark.index
    def test_xim_add(self):
        assert_xim_add_succeeds(PKG_FILE)


class TestIsolation:
    @pytest.mark.isolation
    def test_no_exec_xvm(self):
        assert_no_exec_xvm(PKG_FILE)

    @pytest.mark.isolation
    def test_no_bashrc(self):
        assert_no_bashrc_modification(PKG_FILE)

    @pytest.mark.isolation
    def test_no_path_modification(self):
        assert_no_direct_path_modification(PKG_FILE)

    @pytest.mark.isolation
    def test_new_api(self):
        assert_uses_new_api(PKG_FILE)


class TestLifecycle:
    @pytest.mark.lifecycle
    @skip_if_not("linux")
    def test_install(self):
        assert_install_succeeds(PKG)


class TestVerify:
    @pytest.mark.verify
    @skip_if_not("linux")
    def test_version(self):
        assert_command_output("mypackage --version", contains="mypackage")

    @pytest.mark.verify
    @skip_if_not("linux")
    def test_xvm_registered(self):
        assert_xvm_registered("mypackage")
```

- An alias package (`ref`) asserts `meta.is_ref` and little else.
- A platform-specific test is marked `@skip_if_not("windows")`.
- A known problem is `@pytest.mark.xfail(reason=...)`, which does not block CI.
- A verify test does real work where it can (a compiler compiles, a VM boots);
  `--version` does not show a broken library path.

## Shared modules

| Module | Provides |
|---|---|
| `tests/lib/xpkg_parser.py` | `parse_xpkg()` → `XpkgMeta`, without running Lua |
| `tests/lib/assertions.py` | every assertion above |
| `tests/lib/xvm_client.py` | `XvmClient.info()`, `.is_registered()`, `.shim_exists()` |
| `tests/lib/xlings_client.py` | `XlingsClient.install()`, `.remove()`, `.xim_add_xpkg()` |
| `tests/lib/platform_utils.py` | `current_platform()`, `skip_if_not()`, `xlings_home()` |

## Repository-wide checks

Some rules span every recipe, and each has its own test or script:

| Check | Where |
|---|---|
| dependency coordinates and the split `deps` form | `tests/test_dep_query_coordinates.py`, `tests/test_deps_shape.py` |
| no compiler runtime in a library payload | `tests/test_no_compiler_runtime_in_payloads.py` |
| a published Luban version's output never changes | `tests/test_luban_published.py` |
| a changed resource raises `revision` | `.github/scripts/check-revision.lua` |
| no hard link in a payload | `.github/scripts/check-payload-hard-links.py` |
| a dependency's namespace resolves in this index | `.github/scripts/check-dep-namespace.sh` |
| no host package manager in workflows or scripts | `tools/lint_host_deps.sh` |
| the docs' structure and links | `tests/test_docs.py` |

## What CI runs

| Workflow | When | Runs |
|---|---|---|
| `ci-xpkg-test.yml` | a change to `pkgs/`, `libs/`, `tests/` | L0 and L2 on every recipe, then L1 |
| `ci-test.yml` | a change to `pkgs/` or `libs/` | installs what the change touched, on Linux, macOS and Windows |
| `ci-tools.yml` | a change to `tools/`, `scripts/` or workflows | the tools' own tests and the repository lints |
| `ci-sweep.yml` | weekly | installs one slice of every recipe, by ISO week |
| `luban-agent-workspace.yml` | a change to Luban's recipes or what they pin | builds and boots the editions on x86_64 and aarch64 |
| `site-check.yml` | a change to `pkgs/`, `docs/` or the site config | builds the site in strict mode |

L3 and L4 run in CI only for what a change touched and in the weekly sweep: a
full install of every recipe on every platform is not a per-push budget.
