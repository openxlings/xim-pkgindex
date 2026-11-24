# Testing and acceptance

Two kinds of verification are required for every new or changed recipe:

1. **Direct commands** run against an isolated xlings home.
2. **The pytest suite**, the same levels CI runs (`docs/20-testing.md`).

Never run installs against your own `XLINGS_HOME`.

## A. Direct commands (local)

Let `<pkg>` be the package name and `<file>` the recipe path.

```bash
TMP_HOME="$(mktemp -d)"
export XLINGS_HOME="$TMP_HOME"

xlings config --add-xpkg <file>        # 1. register the recipe in the local overlay
xlings search <pkg>                    # 2. it is visible
xlings install <pkg>@<version> -y      # 3. install, for every version you changed
<pkg> --version                        # 4. run it (its real command), and `which <pkg>`
xlings list <pkg>                      # 5. the install list shows it
xlings install <pkg>@<version> -y      # 6. install again: must be a clean no-op
xlings remove <pkg> -y                 # 7. remove
xlings list <pkg>                      # 8. gone; no shim left in the subos bin/
xlings remove <pkg> -y                 # 9. remove again: must not fail badly
xlings config --remove-xpkg <pkg>      # 10. drop your recipe from the overlay
```

(`--remove-xpkg` needs xlings >= 2026.9.12.1. A forgotten copy that is byte-identical to the
index is cleaned at the next `xlings update`; a modified one keeps shadowing the index, and
`xlings config --list-xpkg` shows it.)

What acceptance means:

- it is found, installs, and the command **runs and does what it should** (not only `--version`:
  run the thing the package is for once);
- `ls` the install directory: the payload is there, not just `.xpkg.lua` (see
  `hook-pitfalls.md` section 2);
- after `config()` the xvm route works, and removal leaves no shim or registration behind;
- for several platforms, check them on each platform you can reach, and the resolution on
  x86_64 and aarch64 for the architectures you cannot run; for mirrors, fetch the real GLOBAL and
  CN responses and compare sha256s.

For a Linux dynamic payload also check its closure:

```bash
readelf -d <install_dir>/bin/<prog> | grep NEEDED
LD_TRACE_LOADED_OBJECTS=1 <install_dir>/bin/<prog>     # no "not found"
```

## B. The pytest levels

Every recipe has a mirror: `pkgs/n/mypackage.lua` -> `tests/n/test_mypackage.py` (`-` becomes
`_`). Model it on a neighbour's test module; `docs/20-testing.md` has a full example.

```bash
pytest tests/<letter>/test_<pkg>.py -m "static or isolation" -v   # always
pytest tests/<letter>/test_<pkg>.py -m index -v                   # needs xlings
XLINGS_HOME="$(mktemp -d)" pytest tests/<letter>/test_<pkg>.py -m "lifecycle or verify" -v
```

Before you open the pull request, also run the repository-wide static checks:

```bash
pytest tests/ -m "static or isolation" --tb=short -q
bash .github/scripts/check-revision.sh        # a hook/payload change needs a revision
bash .github/scripts/check-dep-namespace.sh   # dependencies carry the right namespace
```

They need a Lua 5.3+ interpreter and `origin/main` fetched as the base ref; a missing one is an
error, not a pass. They are maintainers' files: run them, do not edit them.

## C. What the pull request must say

1. The direct-command results above (add, search, install, run, remove), per platform.
2. The pytest commands and their results (at least `static or isolation`, and `index`).
3. What you did not run, why, and the risk that leaves.
4. Whether you expect CI to pass, and which checks are the ones that matter for this change.
