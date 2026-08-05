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
# Names carry the `xim:` namespace, and getting here took one wrong turn worth
# recording.
#
# Bare names were tried first, because a namespaced dep can only resolve from
# that namespace and these packages all depend on each other — before they were
# published, CI registered them under `local` and `xim:libX11` was not there.
#
# Once published, bare names became AMBIGUOUS instead: the same package now
# exists in `xim` and, during the install test, in `local` too, and the resolver
# refuses to guess. Namespacing is right in both directions — it is unambiguous
# by construction, and the unpublished-sibling case it loses is handled where it
# belongs, by the pre-registration pass in .github/scripts/posix-test.sh.

# glibc is pinned where every other dep is a range, and the reason is a client
# bug rather than an ABI one. Before 2026.8.5.2, xlings matched a dep's version
# half by string equality, so `xim:glibc@>=2.38` matched no plan node, glibc's
# exports were dropped, and elfpatch concluded "no loader provider in deps" and
# patched nothing -- the package installed reporting success and its libraries
# kept a build-time RPATH, so anything dlopen'd out of them failed to find its
# siblings. glibc is the only dep that carries `exports.runtime.loader`, so it
# is the only one where the miss is fatal: for the rest, closure_lib_paths
# falls back to the {lib64, lib} convention and the RPATH still comes out
# right. Pinning this one keeps the stack usable on clients already released.
#
# The measured floor is 2.38 (libgallium's highest required symbol version).
# Widen this to a range once the fixed client is the floor worth assuming.
GLIBC = "xim:glibc@2.39"

SPEC = {
    # T1 — protocol descriptions and the kernel interface.
    "xorgproto":    ([], False, None),
    "xcb-proto":    ([], False, None),
    "xtrans":       ([], False, None),
    "libpciaccess": (["xim:zlib@>=1.2"], True, None),
    "libdrm":       (["xim:libpciaccess@>=0.18"], True, None),
    "libxshmfence": ([], True, None),

    # T2 — the X11 client stack. Each layer needs the one below it at run time.
    "libXau":       (["xim:xorgproto@>=2024"], True, None),
    "libXdmcp":     (["xim:xorgproto@>=2024"], True, None),
    "libxcb":       (["xim:libXau@>=1.0", "xim:libXdmcp@>=1.1"], True, None),
    "libX11":       (["xim:libxcb@>=1.17", "xim:xorgproto@>=2024"], True, None),
    "libXext":      (["xim:libX11@>=1.8"], True, None),
    "libXrender":   (["xim:libX11@>=1.8"], True, None),
    "libXfixes":    (["xim:libX11@>=1.8"], True, None),
    "libXrandr":    (["xim:libXext@>=1.3", "xim:libXrender@>=0.9"], True, None),
    "libXxf86vm":   (["xim:libXext@>=1.3"], True, None),
    "libXi":        (["xim:libXext@>=1.3", "xim:libXfixes@>=6.0"], True, None),
    "libXcursor":   (["xim:libXrender@>=0.9", "xim:libXfixes@>=6.0"], True, None),

    # T4 — the graphics core.
    "libglvnd":     (["xim:libX11@>=1.8", "xim:libXext@>=1.3"], True, None),
    "libllvm":      (["xim:gcc-runtime@>=15", GLIBC], True, None),
}

# mesa is written separately: it is the only recipe with an exact pin, and the
# only one that declares environment through subos.env.
MESA_DEPS = [
    "xim:libllvm@20.1.7",        # exact — see the module docstring
    "xim:libglvnd@>=1.7",
    "xim:libdrm@>=2.4",
    "xim:libX11@>=1.8",
    "xim:libxcb@>=1.17",
    "xim:libXext@>=1.3",
    "xim:libXfixes@>=6.0",
    "xim:libXxf86vm@>=1.1",
    "xim:libxshmfence@>=1.3",
    "xim:expat@>=2.6",
    "xim:zlib@>=1.2",
    "xim:gcc-runtime@>=15",
    GLIBC,
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
import("xim.libxpkg.system")
import("xim.libxpkg.xvm")
import("xim.pkgindex.sysroot")
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
    local binding = package.name .. "@" .. pkginfo.version()

    xvm.add(package.name)
{libs}{headers}    return true
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

# Packages whose payload carries headers a consumer compiles against. A subos
# with the graphics stack installed should be able to BUILD a GL program, not
# only run one — and headers reach the sysroot only if a recipe declares them.
# glibc is the model: its headers are in the sysroot because glibc declares
# them, and nothing else appears there by accident.
HEADERS = {"libglvnd", "libdrm", "libX11", "libxcb", "libXext", "libXfixes",
           "libXrender", "libXrandr", "libXi", "libXcursor", "libXxf86vm",
           "libXau", "libXdmcp", "libpciaccess", "libxshmfence", "xorgproto"}

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
    hdr = ""
    if name in HEADERS:
        # type(), not truthiness — xvm.files is a function on clients that have
        # it and genuinely absent on those that do not, so the plain form is
        # correct here. Kept as a probe so an older client installs the payload
        # and simply does not get the headers, rather than aborting the whole
        # registration on an unknown node kind.
        hdr = ("""
    -- Headers into the subos sysroot, so a compiler in this subos can build
    -- against this package, not only run it. Declared rather than copied, so
    -- xlings removes them with the package.
    --
    -- _tree, not declare_headers: eight packages in this stack contribute to
    -- one `X11/`, and declaring that directory places it as a single asset --
    -- rename(2) over the sysroot's copy, so the last install wins and the
    -- other seven vanish. See libs/sysroot.lua for why neither of the
    -- non-recursive helpers can express a shared namespace.
    if not sysroot.declare_headers_tree(pkginfo.install_dir(), "include",
                                        "usr/include", binding) then
        sysroot.install_headers_tree(
            path.join(pkginfo.install_dir(), "include"),
            path.join(system.subos_sysrootdir(), "usr", "include"))
    end
""")
    libs = ""
    if has_libs:
        # So a program in this subos can be LINKED against the stack, not only
        # run against it. See sysroot.declare_libs.
        libs = ("\n    sysroot.declare_libs(pkginfo.install_dir(), \"lib\", "
                "binding, pkginfo.version())\n")
    out += CONFIG_LIB.format(headers=hdr, libs=libs)
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
