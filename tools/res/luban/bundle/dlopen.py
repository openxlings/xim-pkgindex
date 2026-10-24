#!/usr/bin/env python3
"""What a bundle loads by name at run time (xlings design 2026-10-24 §10.2).

ldd follows a program's links, not the libraries it opens with dlopen():
NSS's softokn and its trust module, the GL and Vulkan loaders, GIO's and
GStreamer's modules. A recipe declares those (`extensions.luban.bundle.dlopen`)
and the build collects them; this checks a tree:

  dlopen.py declared <recipe.lua>          the names the recipe declares, one a line
  dlopen.py check <libdir> <tree> [names]  every declared name is in <libdir>;
                                           a well-known name the tree's ELFs
                                           mention and nobody declared is said
"""
import os
import re
import sys

# Names a program opens by itself, by the library that does it.
KNOWN = {
    "libsoftokn3.so": "NSS", "libfreeblpriv3.so": "NSS", "libfreebl3.so": "NSS", "libnssckbi.so": "NSS",
    "libvulkan.so.1": "the Vulkan loader", "libEGL.so.1": "the EGL loader", "libGLX.so.0": "the GLX loader",
    "libgiognutls.so": "GIO", "libgstcoreelements.so": "GStreamer",
}


def declared(recipe):
    text = open(recipe, encoding="utf-8").read()
    m = re.search(r"dlopen\s*=\s*\{([^}]*)\}", text)
    return re.findall(r'"([^"]+)"', m.group(1)) if m else []


def mentions(tree):
    found = set()
    pattern = re.compile(rb"lib[A-Za-z0-9_+-]+\.so(?:\.[0-9]+)*")
    for root, _, files in os.walk(tree):
        for f in files:
            p = os.path.join(root, f)
            if os.path.islink(p) or not os.path.isfile(p):
                continue
            with open(p, "rb") as fh:
                if fh.read(4) != b"\x7fELF":
                    continue
                fh.seek(0)
                for name in pattern.findall(fh.read()):
                    found.add(name.decode())
    return found


def check(libdir, tree, names):
    missing = [n for n in names if not os.path.exists(os.path.join(libdir, n))]
    for n in missing:
        print(f"dlopen: {n} is declared but not in {libdir}", file=sys.stderr)
    have = set(os.listdir(libdir)) if os.path.isdir(libdir) else set()
    for n in sorted(mentions(tree)):
        if n in KNOWN and n not in names and n not in have:
            print(f"dlopen: warning: {n} ({KNOWN[n]}) is named in the tree and neither declared nor carried", file=sys.stderr)
    return 1 if missing else 0


if __name__ == "__main__":
    if len(sys.argv) >= 3 and sys.argv[1] == "declared":
        print("\n".join(declared(sys.argv[2])))
        sys.exit(0)
    if len(sys.argv) >= 4 and sys.argv[1] == "check":
        sys.exit(check(sys.argv[2], sys.argv[3], sys.argv[4:]))
    print(__doc__, file=sys.stderr)
    sys.exit(2)
