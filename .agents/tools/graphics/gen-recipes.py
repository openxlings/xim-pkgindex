#!/usr/bin/env python3
"""Generate the graphics-stack recipes from the publish manifest.

Design: xlings/.agents/docs/2026-08-05-graphics-stack-ecosystem-closure.md

Twenty-two recipes with the same shape — an xpm block pointing at the two
mirrors, a deps list, and a config() that registers the payload's libraries so
consumers resolve them. Hand-writing them would take longer and the errors
would be the silent kind: a wrong sha256 fails loudly, a missing dep does not.

Two conventions are enforced here rather than left to whoever edits next.

DEPENDENCY RANGES. The index's existing recipes pin exactly, but the resolver
supports ranges (semver.cppm: `@3`, `@^1.2`, `>=1.0 <2.0`), and pinning makes
this stack a single block — a libX11 patch bump would touch a dozen recipes
that only care that the library exists. So the default is a lower bound. The
one exception is mesa → libllvm, where libgallium references 97 mangled llvm::
symbols carrying an @LLVM_20.1 version tag: that coupling is exact to
major.minor and a range would suggest an upgrade path that does not exist.

exports.runtime.libdirs. This is what makes the stack work without the user
setting anything: xlings's elfpatch reads it from each dependency and writes
the consumer's RPATH. `gcc-runtime` established the pattern.
"""
import pathlib
import sys

# name -> (deps, has_libs, extra_config)
#
# deps use ranges by default; see the module docstring for why, and for the one
# place that does not.
#
# Names are BARE, without an `xim:` prefix — the majority form in this index
# (70 of 106 dependency entries) and the one that works. A namespaced dep can
# only resolve from that namespace, so a batch of new packages depending on
# each other cannot install until every one of them is published: CI registers
# changed packages under `local` and `xim:libX11` is not there yet. A bare name
# resolves from whichever repo has it.
SPEC = {
    # T1 — protocol descriptions and the kernel interface.
    "xorgproto":    ([], False, None),
    "xcb-proto":    ([], False, None),
    "xtrans":       ([], False, None),
    "libpciaccess": (["zlib@>=1.2"], True, None),
    "libdrm":       (["libpciaccess@>=0.18"], True, None),
    "libxshmfence": ([], True, None),

    # T2 — the X11 client stack. Each layer needs the one below it at run time.
    "libXau":       (["xorgproto@>=2024"], True, None),
    "libXdmcp":     (["xorgproto@>=2024"], True, None),
    "libxcb":       (["libXau@>=1.0", "libXdmcp@>=1.1"], True, None),
    "libX11":       (["libxcb@>=1.17", "xorgproto@>=2024"], True, None),
    "libXext":      (["libX11@>=1.8"], True, None),
    "libXrender":   (["libX11@>=1.8"], True, None),
    "libXfixes":    (["libX11@>=1.8"], True, None),
    "libXrandr":    (["libXext@>=1.3", "libXrender@>=0.9"], True, None),
    "libXxf86vm":   (["libXext@>=1.3"], True, None),
    "libXi":        (["libXext@>=1.3", "libXfixes@>=6.0"], True, None),
    "libXcursor":   (["libXrender@>=0.9", "libXfixes@>=6.0"], True, None),

    # T4 — the graphics core.
    "libglvnd":     (["libX11@>=1.8", "libXext@>=1.3"], True, None),
    "libllvm":      (["gcc-runtime@>=15", "glibc@>=2.38"], True, None),
}

# mesa is written separately: it is the only recipe with an exact pin, and the
# only one that declares environment through subos.env.
MESA_DEPS = [
    "libllvm@20.1.7",        # exact — see the module docstring
    "libglvnd@>=1.7",
    "libdrm@>=2.4",
    "libX11@>=1.8",
    "libxcb@>=1.17",
    "libXext@>=1.3",
    "libXfixes@>=6.0",
    "libXxf86vm@>=1.1",
    "libxshmfence@>=1.3",
    "expat@>=2.6",
    "zlib@>=1.2",
    "gcc-runtime@>=15",
    "glibc@>=2.38",
]

DESCRIPTIONS = {
    "xorgproto": "X Window System protocol headers (build-time)",
    "xcb-proto": "XML-XCB protocol descriptions (build-time)",
    "xtrans": "X transport layer macros and headers (build-time)",
    "libpciaccess": "Generic PCI device access library",
    "libdrm": "Userspace interface to the kernel DRM services",
    "libxshmfence": "Shared-memory fences for DRI3",
    "libXau": "X11 authorisation protocol library",
    "libXdmcp": "X Display Manager Control Protocol library",
    "libxcb": "X protocol C-language Binding",
    "libX11": "Core X11 client library",
    "libXext": "X11 miscellaneous extensions library",
    "libXrender": "X Rendering Extension client library",
    "libXfixes": "X Fixes extension client library",
    "libXrandr": "X Resize, Rotate and Reflect extension library",
    "libXxf86vm": "X11 XFree86 video mode extension library",
    "libXi": "X Input Extension client library",
    "libXcursor": "X cursor management library",
    "libglvnd": "The GL Vendor-Neutral Dispatch library",
    "libllvm": "LLVM as a shared library — the code generator mesa's llvmpipe and radeonsi use",
    "mesa": "Mesa 3D — OpenGL for CPU (llvmpipe), Intel, AMD and NVIDIA-open",
}

HEADER = '''package = {{
    spec = "2",

    homepage = "{homepage}",
    name = "{name}",
    description = "{desc}",

    authors = {{{authors}}},
    licenses = {{{licenses}}},
    repo = "{repo}",

    type = "package",
    archs = {{"x86_64"}},
    status = "stable",
    categories = {{"graphics", "lib"}},
    keywords = {{{keywords}}},

    xpm = {{
        linux = {{
            deps = {{{deps}}},
{exports}            ["latest"] = {{ ref = "{version}" }},
            ["{version}"] = {{
                url = {{
                    GLOBAL = "{global_url}",
                    CN     = "{cn}",
                }},
                sha256 = "{sha}",
            }},
        }},
    }},
}}

import("xim.libxpkg.pkginfo")
import("xim.libxpkg.xvm")
'''

EXPORTS = """            -- elfpatch reads this from each dependency and writes the consumer's
            -- RPATH, which is what makes the stack resolve without anyone
            -- setting LD_LIBRARY_PATH. Same mechanism `gcc-runtime` uses.
            exports = {
                runtime = { libdirs = { "lib" } },
            },
"""

INSTALL = '''
function install()
    local dir = pkginfo.install_dir()
    os.tryrm(dir)
    os.mv("{name}-{version}", dir)
    return true
end
'''

CONFIG_LIB = '''
function config()
    xvm.add(package.name)
    return true
end

function uninstall()
    xvm.remove(package.name)
    return true
end
'''

# Licences per package, verified against each upstream's own LICENSE/COPYING.
#
# A single default would be wrong and wrong quietly: LLVM is Apache-2.0 WITH
# LLVM-exception, not MIT, and the index's existing `llvm` recipe already says
# so. The X.Org libraries use the X11 variant of MIT, which SPDX labels MIT;
# libglvnd's is the Khronos/NVIDIA "Materials" wording, also MIT; mesa declares
# `SPDX-License-Identifier: MIT` in its own meson.build.
LICENSES = {
    "libllvm": '"Apache-2.0 WITH LLVM-exception"',
}
DEFAULT_LICENSE = '"MIT"'


HOMEPAGES = {
    "libdrm": "https://dri.freedesktop.org/",
    "libglvnd": "https://gitlab.freedesktop.org/glvnd/libglvnd",
    "libllvm": "https://llvm.org",
    "mesa": "https://mesa3d.org",
}

# The source repository, which is NOT the homepage. Every X.Org library lives
# under gitlab.freedesktop.org/xorg/{lib,proto}/<name>; pointing `repo` at
# x.org sends anyone looking for the source to a landing page.
REPOS = {
    "libdrm":   "https://gitlab.freedesktop.org/mesa/drm",
    "libglvnd": "https://gitlab.freedesktop.org/glvnd/libglvnd",
    "libllvm":  "https://github.com/llvm/llvm-project",
    "mesa":     "https://gitlab.freedesktop.org/mesa/mesa",
}
_XORG_PROTO = ("xorgproto", "xcb-proto")

AUTHORS = {
    "libllvm":  '"LLVM Project"',
    "libglvnd": '"NVIDIA Corporation", "libglvnd contributors"',
    "libdrm":   '"Mesa contributors"',
}
DEFAULT_AUTHORS = '"X.Org Foundation"'


def homepage(name):
    return HOMEPAGES.get(name, "https://www.x.org")


def repo(name):
    if name in REPOS:
        return REPOS[name]
    kind = "proto" if name in _XORG_PROTO else "lib"
    return f"https://gitlab.freedesktop.org/xorg/{kind}/{name}"


def render(name, version, sha, global_url, cn_url):
    deps, has_libs, _ = SPEC[name]
    deps_s = ""
    if deps:
        deps_s = " " + ", ".join(f'"{d}"' for d in deps) + " "
    kw = ", ".join(f'"{k}"' for k in (name.lower(), "graphics", "x11" if name.startswith(("libX", "libx", "xorg", "xcb", "xtrans")) else "gl"))
    out = HEADER.format(
        homepage=homepage(name), name=name, desc=DESCRIPTIONS[name],
        repo=repo(name), authors=AUTHORS.get(name, DEFAULT_AUTHORS),
        licenses=LICENSES.get(name, DEFAULT_LICENSE),
        keywords=kw, deps=deps_s, version=version, sha=sha,
        global_url=global_url, cn=cn_url,
        exports=(EXPORTS if has_libs else ""),
    )
    out += INSTALL.format(name=name, version=version)
    out += CONFIG_LIB
    return out


def main():
    manifest = pathlib.Path(sys.argv[1])
    outdir = pathlib.Path(sys.argv[2]) if len(sys.argv) > 2 else pathlib.Path("pkgs")
    written = 0
    for line in manifest.read_text().splitlines():
        if not line.strip():
            continue
        name, version, sha, global_url, cn_url, cn_ok = line.split("|")
        if name not in SPEC:
            print(f"  skip {name} (not in SPEC — mesa is written by hand)")
            continue
        d = outdir / name[0].lower()
        d.mkdir(parents=True, exist_ok=True)
        (d / f"{name}.lua").write_text(
            render(name, version, sha, global_url, cn_url))
        print(f"  wrote {d / (name + '.lua')}")
        written += 1
    print(f"{written} recipes")


if __name__ == "__main__":
    main()
