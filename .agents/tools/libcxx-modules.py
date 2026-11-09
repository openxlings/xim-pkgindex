#!/usr/bin/env python3
"""Generate libc++'s module sources (std.cppm, std.compat.cppm, std/, std.compat/)
from an official libcxx-<version>.src tree, exactly as libc++'s own
modules/CMakeLists.txt does with configure_file: each @..._INCLUDE_SOURCES@
becomes one `#include "<file>"` line per entry of the list it names.

usage: libcxx-modules.py <libcxx-src-dir> <out-dir>
"""
import re, shutil, sys
from pathlib import Path

src, out = Path(sys.argv[1]) / "modules", Path(sys.argv[2])
cmake = (src / "CMakeLists.txt").read_text()

def listed(var):
    m = re.search(r"set\(%s\n(.*?)\)" % re.escape(var), cmake, re.S)
    if not m: raise SystemExit(f"{var} not found in modules/CMakeLists.txt")
    return [l.strip() for l in m.group(1).splitlines() if l.strip()]

out.mkdir(parents=True, exist_ok=True)
for name, var, placeholder in (("std", "LIBCXX_MODULE_STD_SOURCES", "@LIBCXX_MODULE_STD_INCLUDE_SOURCES@"),
                               ("std.compat", "LIBCXX_MODULE_STD_COMPAT_SOURCES", "@LIBCXX_MODULE_STD_COMPAT_INCLUDE_SOURCES@")):
    text = (src / f"{name}.cppm.in").read_text()
    assert placeholder in text, (name, placeholder)
    includes = "".join(f'#include "{f}"\n' for f in listed(var))
    (out / f"{name}.cppm").write_text(text.replace(placeholder, includes))
    if (out / name).exists(): shutil.rmtree(out / name)
    shutil.copytree(src / name, out / name)
print("generated", sorted(p.name for p in out.iterdir()))
