"""平台检测与路径工具"""
import os
import platform
import functools
import pytest


def current_platform() -> str:
    s = platform.system()
    return {"Linux": "linux", "Darwin": "macosx", "Windows": "windows"}.get(s, s.lower())


def current_arch() -> str:
    m = platform.machine()
    return {"AMD64": "x86_64", "aarch64": "arm64"}.get(m, m)


def xlings_home() -> str:
    return os.environ.get("XLINGS_HOME", os.path.expanduser("~/.xlings"))


def subos_bin_dir() -> str:
    return os.path.join(xlings_home(), "subos", "current", "bin")


def xpkgs_dir() -> str:
    return os.path.join(xlings_home(), "data", "xpkgs")


def under_test(pkg: str, version: str = "") -> str:
    """The name that installs the recipe under test: `<namespace>:<pkg>[@<version>]`.

    A recipe a change edits is in the home once. The install step writes it over
    its published copy, where it answers as `xim:`; a recipe the index has no
    copy of is registered beside it (`xlings config --add-xpkg`) and answers as
    `local:`. Registering a recipe identical to the published one adds nothing,
    so `local:` does not name a published recipe that nobody registered.

    The namespace is therefore read from the home, when the test runs. A module
    states the package and, where it pins one, the version; a namespace written
    into a module is right in one of the two states only. The name is always
    qualified: a bare name is ambiguous where a sub-index carries the package
    too (scode:ncurses).
    """
    registered = os.path.join(xlings_home(), "data", "xim-pkgindex-local",
                              "pkgs", pkg[0], pkg + ".lua")
    name = ("local:" if os.path.isfile(registered) else "xim:") + pkg
    return f"{name}@{version}" if version else name


def pkgindex_dir() -> str:
    root = os.path.dirname(os.path.dirname(os.path.dirname(os.path.abspath(__file__))))
    return os.path.join(root, "pkgs")


def project_root() -> str:
    return os.path.dirname(os.path.dirname(os.path.dirname(os.path.abspath(__file__))))


def skip_if_not(plat: str):
    """跳过不匹配的平台"""
    return pytest.mark.skipif(
        current_platform() != plat,
        reason=f"仅在 {plat} 上运行"
    )


def subos_sysroot_pkgconfig_dir() -> str:
    """Where library packages declare their .pc files.

    The sealed search path a pkg-config assertion should use: if a name
    resolves here it resolves from index packages, and if it does not, the
    host's /usr/lib/pkgconfig is not going to be asked to cover for it.

    `current` is a symlink an established home has and a freshly created one
    does not -- a throwaway XLINGS_HOME comes up with `subos/default` and no
    `current` at all, so a hardcoded path finds nothing there and every
    assertion built on it reports the whole index missing.
    """
    base = os.path.join(xlings_home(), "subos")
    for name in ("current", "default"):
        d = os.path.join(base, name, "usr", "lib", "pkgconfig")
        if os.path.isdir(d):
            return d
    # Any subos with a populated sysroot, newest first.
    try:
        for name in sorted(os.listdir(base)):
            d = os.path.join(base, name, "usr", "lib", "pkgconfig")
            if os.path.isdir(d):
                return d
    except OSError:
        pass
    return os.path.join(base, "current", "usr", "lib", "pkgconfig")
