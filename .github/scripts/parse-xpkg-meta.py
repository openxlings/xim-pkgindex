"""Emit a small JSON meta object for a single .lua xpkg file.

Used by the per-platform install/uninstall CI jobs (linux-test,
macos-test, windows-test) to decide whether to install/test a changed
package and what programs to look for afterwards.

Fields in the output:
  name         package name (string)
  type         package type (e.g. package, app, lib, script, bugfix)
  namespace    package namespace (defaults to "local" when not declared);
               install/remove specs must use "<namespace>:<name>"
  programs     list of program names declared by the package
  is_ref       true if this file is a thin ref to another package
  has_linux    true if the package declares a linux branch in xpm
  has_macosx   true if the package declares a macosx branch in xpm
  has_windows  true if the package declares a windows branch in xpm
"""
import json
import sys
from pathlib import Path

repo_root = Path(__file__).resolve().parents[2]
sys.path.insert(0, str(repo_root))

from tests.lib.xpkg_parser import parse_xpkg


def main() -> int:
    if len(sys.argv) != 2:
        print("usage: parse-xpkg-meta.py <path-to-lua>", file=sys.stderr)
        return 2
    meta = parse_xpkg(sys.argv[1])
    print(json.dumps({
        "name": meta.name,
        "type": meta.pkg_type,
        "namespace": meta.namespace or "local",
        "programs": list(meta.programs),
        "is_ref": bool(meta.is_ref),
        "has_linux": bool(meta.platforms.get("linux")),
        "has_macosx": bool(meta.platforms.get("macosx")),
        "has_windows": bool(meta.platforms.get("windows")),
    }))
    return 0


if __name__ == "__main__":
    sys.exit(main())
