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
