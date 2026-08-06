#!/usr/bin/env python3
"""Write each xlings-res payload repo a README that makes the build reproducible.

Design: xlings/.agents/docs/2026-08-05-graphics-stack-ecosystem-closure.md §10 (O5)

A payload repo holds one tarball per release and nothing else, so six months
from now the only record of HOW those bytes were produced is whatever is
written down. O5 in the design names this as the long-term risk: thirty
prebuilt packages whose build exists only in someone's shell history.

Each README therefore carries the things that are not recoverable from the
tarball: the upstream source, the exact configure flags, which compiler and
why, what was deliberately left out, and the command to rebuild it.

Usage:  readme.py <manifest> [--push]
"""
import pathlib
import subprocess
import sys

LICENSES = {"libllvm": "Apache-2.0 WITH LLVM-exception"}
DEFAULT_LICENSE = "MIT"

TIERS = {
    "xorgproto": "T1", "xcb-proto": "T1", "xtrans": "T1",
    "libpciaccess": "T1", "libdrm": "T1", "libxshmfence": "T1",
    "libXau": "T2", "libXdmcp": "T2", "libxcb": "T2", "libX11": "T2",
    "libXext": "T2", "libXrender": "T2", "libXfixes": "T2",
    "libXrandr": "T2", "libXxf86vm": "T2", "libXi": "T2", "libXcursor": "T2",
    "libglvnd": "T4", "libllvm": "T4", "mesa": "T5",
}

UPSTREAM = {
    "xorgproto":    "https://xorg.freedesktop.org/archive/individual/proto/xorgproto-{v}.tar.xz",
    "xcb-proto":    "https://xorg.freedesktop.org/archive/individual/proto/xcb-proto-{v}.tar.xz",
    "xtrans":       "https://xorg.freedesktop.org/archive/individual/lib/xtrans-{v}.tar.xz",
    "libpciaccess": "https://xorg.freedesktop.org/archive/individual/lib/libpciaccess-{v}.tar.xz",
    "libdrm":       "https://dri.freedesktop.org/libdrm/libdrm-{v}.tar.xz",
    "libxshmfence": "https://xorg.freedesktop.org/archive/individual/lib/libxshmfence-{v}.tar.xz",
    "libglvnd":     "https://gitlab.freedesktop.org/glvnd/libglvnd/-/archive/v{v}/libglvnd-v{v}.tar.gz",
    "libllvm":      "https://github.com/llvm/llvm-project/releases/download/llvmorg-{v}/llvm-project-{v}.src.tar.xz",
    "mesa":         "https://archive.mesa3d.org/mesa-{v}.tar.xz",
    "wayland":      "https://gitlab.freedesktop.org/wayland/wayland/-/releases/{v}/downloads/wayland-{v}.tar.xz",
    "wayland-protocols": "https://gitlab.freedesktop.org/wayland/wayland-protocols/-/releases/{v}/downloads/wayland-protocols-{v}.tar.xz",
    "libxkbcommon": "https://xkbcommon.org/download/libxkbcommon-{v}.tar.xz",
    "glslang":      "https://github.com/KhronosGroup/glslang/archive/refs/tags/{v}.tar.gz",
    "elfutils":     "https://sourceware.org/elfutils/ftp/{v}/elfutils-{v}.tar.bz2",
}
for _n in ("libXau", "libXdmcp", "libxcb", "libX11", "libXext", "libXrender",
           "libXfixes", "libXrandr", "libXxf86vm", "libXi", "libXcursor"):
    UPSTREAM[_n] = ("https://xorg.freedesktop.org/archive/individual/lib/"
                    + _n + "-{v}.tar.xz")

# Only where the flags are not the harness default.
FLAGS = {
    "libdrm": "-Dintel=enabled -Dradeon=enabled -Damdgpu=enabled -Dnouveau=enabled "
              "-Dvalgrind=disabled -Dman-pages=disabled -Dtests=false",
    "libglvnd": "-Dgles1=false -Dasm=enabled",
    "mesa": "-Dgallium-drivers=llvmpipe -Dvulkan-drivers= -Dglvnd=enabled "
            "-Dplatforms=x11 -Dllvm=enabled -Dshared-llvm=enabled "
            "-Dlmsensors=disabled -Dvalgrind=disabled -Dbuild-tests=false "
            "-Dgallium-extra-hud=false",
    "libllvm": "-DLLVM_TARGETS_TO_BUILD=X86;AMDGPU -DLLVM_BUILD_LLVM_DYLIB=ON "
               "-DLLVM_LINK_LLVM_DYLIB=ON -DLLVM_ENABLE_RTTI=ON "
               "-DLLVM_ENABLE_{TERMINFO,LIBEDIT,LIBXML2,ZLIB,ZSTD,LIBPFM}=OFF "
               "-DLLVM_INCLUDE_{TESTS,EXAMPLES,BENCHMARKS,DOCS,UTILS}=OFF",
}

# The decisions that are not visible in the flags and cost real time to
# rediscover. Empty means "nothing surprising".
NOTES = {
    "wayland": """
The Wayland protocol library and its scanner. `wayland-scanner` is a build
tool the rest of the stack runs — mesa and wayland-protocols both invoke it —
so this payload ships a binary as well as libraries, and that binary is the
reason the build harness had to learn to patch RPATHs on the copy it installs
into the build subos.

libxml2 is a build dependency of the scanner alone (DTD validation). It is
supplied from the xlings package rather than the sysroot, because that package
predates the header/library declarations the rest of this stack uses.
""",
    "wayland-protocols": """
XML protocol definitions, no library. mesa reads them at build time through
`wayland-scanner`; nothing loads this at run time.
""",
    "libxkbcommon": """
Keymap handling for Wayland clients. Built with `-Denable-wayland=false`: that
option builds an extra *tool*, and enabling it would make this package depend
on wayland-protocols for no benefit to what the stack uses it for.
""",
    "glslang": """
Khronos's GLSL front end. mesa's Vulkan drivers compile built-in shaders at
build time and meson looks for `glslangValidator` **by name**, so this has to
be on PATH during mesa's build — not merely installed.

`-DENABLE_OPT=OFF` keeps SPIRV-Tools out: that optimiser serves glslang's own
command line, and mesa does not ask for it.
""",
    "elfutils": """
Built for `libelf` and nothing else. radeonsi links it to read the ELF that
LLVM's AMDGPU backend emits for a compiled shader.

Everything else elfutils ships — the debuginfo tooling — is configured out, and
`CFLAGS=-Wno-error` is required because 0.191 predates gcc 15 and its
warnings-as-errors default turns new diagnostics into build failures.
""",

    "libllvm": """### Why only X86 and AMDGPU

Undefined-symbol analysis of mesa's `libgallium` finds `LLVMInitializeX86*`
(the llvmpipe / lavapipe JIT) and 27 AMDGPU symbols (radeonsi's shader
compiler). Intel (iris/ANV) and NVIDIA-open (nouveau/NVK) go through NIR
backends and never reach LLVM. The distro build ships every target and costs
137 MB; this one is 121 MB unpacked with the same coverage.

### Why gcc 15.1.0 and not the subos default, and not clang

* gcc 16.1.0 — the subos default — ICEs with a segfault on
  `AMDGPUAsmParser.cpp` at 2212/2218. AMDGPU cannot be dropped to dodge it.
* clang builds it and produces a payload that is wrong in a way nothing
  reports: the xlings `llvm` package's clang defaults to **libc++**, so
  libLLVM would need libc++/libc++abi/libunwind while mesa is built against
  **libstdc++**. `libgallium` references 97 mangled `llvm::` symbols; across
  two C++ runtimes those names match and the object layouts do not. Forcing
  `-stdlib=libstdc++` then fails to link.
* gcc 15.1.0 is the compiler whose runtime the ecosystem ships
  (`gcc-runtime@15.1.0`), so the C++ ABI is consistent by construction.

### This is not the `llvm` package

`llvm` is a self-contained clang/lld toolchain whose acceptance gate forbids a
shared libLLVM (`.agents/skills/llvm-subpackaging`). Different consumer,
different axis — the same split the index makes between `gcc` and
`gcc-runtime`.

### The payload is lib-only, deliberately

Consumers need `libLLVM.so` and nothing else. But a runtime-only tree **cannot
serve as a build dependency**: `llvm-config --shared-mode` verifies the
component archives it knows about are present, so against a `lib/` holding
only the `.so` it errors per component and mesa's
`dependency('llvm', method: 'config-tool')` concludes LLVM is absent. Building
mesa therefore needs a full `ninja install` staged into the build subos, which
is what `build-libllvm.sh` does. Same line distributions draw between
`libllvm20` and `llvm-dev`.
""",
    "mesa": """### Driver coverage in this build

`gallium-drivers=llvmpipe` only, and `vulkan-drivers` empty. That is staging,
not a scope decision:

* `iris` (Intel) pulls in **libclc** — `meson.build`: `with_gallium_iris` implies
  `with_clc` — which is a further package.
* The Vulkan drivers need **glslangValidator**, likewise.

The acceptance criterion exercises the GL path through llvmpipe, so the whole
chain is proven with one driver first. Adding a driver to a pipeline that
already renders is a small change; debugging a pipeline with five drivers at
once is not.

### Why `-Dglvnd=enabled` is load-bearing

It makes mesa build as a libglvnd **vendor** (`libGLX_mesa` / `libEGL_mesa`)
rather than as a `libGL` replacement. That is what allows the NVIDIA
proprietary vendor to sit beside it in one subos, selected per process through
the environment.

### Discovery protocols this payload needs

Neither PATH nor RPATH can supply these; the process that has to see them is
the user's own binary, which xlings never wraps:

    LIBGL_DRIVERS_PATH          ${pkgdir}/lib/dri
    __EGL_VENDOR_LIBRARY_DIRS   ${pkgdir}/share/glvnd/egl_vendor.d

The recipe declares them with `subos.env{}` (xlings ≥ 2026.8.5.1), so entering
the subos sets them and the user does nothing.
""",
    "libxcb": """### Build-time dependency on xcb-proto's Python module

`libxcb` generates its protocol bindings from the XML in `xcb-proto`, using
that package's `xcbgen` Python module. Both the module and the `.pc` that
locates the XML must be visible to the build.

The `.pc` records `prefix=/usr` — correct for a relocatable payload, wrong
during the build, where the files live under the subos. `build-in-subos.sh`
rewrites the prefix in the **staged** copy only; the shipped tarball keeps
`/usr`. Without that rewrite the build fails looking for `//usr/share/xcb/`,
a path on the host root.
""",
    "libX11": """### libtool archives are removed from the payload

A `.la` records the absolute libdir it was configured with, and the next
package's libtool reads that path literally. Keeping them made this build stop
with `'/usr/lib/libXau.la' is not a valid libtool archive` — it had gone
looking on the host root for a library sitting in the subos. Every payload in
this stack has its `.la` files deleted, which is what distributions settled on.
""",
}

TEMPLATE = """# {name}

xlings-res payload for **`{name}`** — part of the xlings graphics stack ({tier}).

Built from source **inside an xlings subos**, against that subos's glibc, so
the result depends on nothing from whatever host it is installed on. That is
the whole point: a payload linked against a build machine's glibc works there
and fails elsewhere, which is
[mcpp#352](https://github.com/mcpp-community/mcpp/issues/352).

| | |
|---|---|
| version | `{version}` |
| upstream | {upstream} |
| licence | {licence} |
| sha256 | `{sha}` |
| recipe | [`xim-pkgindex/pkgs/{initial}/{name}.lua`](https://github.com/openxlings/xim-pkgindex/blob/main/pkgs/{initial}/{name}.lua) |

## Build

```bash
git clone https://github.com/openxlings/xim-pkgindex && cd xim-pkgindex
xlings subos new gfxbuild
xlings subos use gfxbuild --global
xlings install gcc make ninja python cmake zlib expat -y

export XLINGS_GFX_SUBOS=gfxbuild
bash .agents/tools/graphics/tiers.sh {tier}     # or build-libllvm.sh for libllvm
```

{flags_section}
## What the harness guarantees

`build-in-subos.sh` refuses a payload that reaches back to the host, checking
for both kinds of leak before packaging:

* an RPATH naming anything outside the payload;
* an absolute host prefix baked into a `.pc`, `.la` or `*-config` file — which
  breaks nothing now and breaks the **next** package, by pointing its
  `configure` at `/usr`.

`PKG_CONFIG_LIBDIR` points only at the subos, so a dependency that is not
packaged yet fails `configure` loudly instead of being satisfied quietly by a
host copy.

{notes}
## Verifying the stack

```bash
bash .agents/tools/graphics/selfcontained-check.sh
```

Runs a GL client under bwrap with **no `/usr` and no `/lib`** — only the subos,
`/dev/dri` and a read-only `/sys` — and asserts it renders correct pixels and
that the renderer is *not* the host's driver. That last assertion is the only
thing separating a self-contained stack from one quietly using the host's:
both produce identical output.
"""


def flags_section(name):
    f = FLAGS.get(name)
    if not f:
        return ("Standard autotools/meson configuration; the harness supplies "
                "`--prefix=/usr --libdir=lib` and the subos toolchain.\n")
    return f"### Configuration\n\n```\n{f}\n```\n"


def upstream_url(name, version):
    """Upstream tarball for NAME at VERSION.

    mesa ships as `25.0.7.1`: the payload was rebuilt with a wider driver set
    while upstream stayed at 25.0.7, and a package whose contents changed has
    to be a different version — GitCode releases cannot be deleted, so the
    asset for a version is written once. The fourth component is ours; the
    upstream URL takes the first three.
    """
    tmpl = UPSTREAM.get(name)
    if not tmpl:
        return None
    v = version
    if name == "mesa" and version.count(".") == 3:
        v = version.rsplit(".", 1)[0]
    return tmpl.format(v=v)


def render(name, version, sha):
    return TEMPLATE.format(
        name=name, version=version, sha=sha, tier=TIERS.get(name, "T?"),
        initial=name[0].lower(),
        upstream=UPSTREAM.get(name, "(see recipe)").format(v=version),
        licence=LICENSES.get(name, DEFAULT_LICENSE),
        flags_section=flags_section(name),
        notes=(NOTES[name] + "\n") if name in NOTES else "",
    )


def main():
    manifest = pathlib.Path(sys.argv[1])
    push = "--push" in sys.argv
    for line in manifest.read_text().splitlines():
        if not line.strip():
            continue
        name, version, sha, *_ = line.split("|")
        body = render(name, version, sha)
        out = pathlib.Path(f"/tmp/xlings-res-readme/{name}")
        out.mkdir(parents=True, exist_ok=True)
        (out / "README.md").write_text(body)
        print(f"  {name}: README ({len(body)} bytes)")
        if push:
            repo = f"xlings-res/{name}"
            r = subprocess.run(
                ["gh", "api", f"repos/{repo}/contents/README.md",
                 "-X", "PUT", "-f", "message=docs: record how this payload is built",
                 "-f", f"content={__import__('base64').b64encode(body.encode()).decode()}"],
                capture_output=True, text=True)
            if r.returncode != 0 and "sha" in r.stderr:
                # already exists — needs the current blob sha to replace
                cur = subprocess.run(
                    ["gh", "api", f"repos/{repo}/contents/README.md", "-q", ".sha"],
                    capture_output=True, text=True)
                if cur.returncode == 0:
                    subprocess.run(
                        ["gh", "api", f"repos/{repo}/contents/README.md",
                         "-X", "PUT", "-f", "message=docs: record how this payload is built",
                         "-f", f"content={__import__('base64').b64encode(body.encode()).decode()}",
                         "-f", f"sha={cur.stdout.strip()}"],
                        capture_output=True, text=True)
            print(f"    → pushed to {repo}")


if __name__ == "__main__":
    main()
