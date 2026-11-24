# Troubleshooting: symptom, cause, local check, fix

Failures in this index have a small number of shapes. Find yours, run the **local check**
before changing anything, and fix the cause in the xpkg unless the cause is in xlings,
libxpkg or CI (then open an issue in that repository and say so in your PR).

## How to investigate (for you or a local AI)

1. **Reproduce in an isolated home**, never your own:
   `TMP_HOME="$(mktemp -d)"; XLINGS_HOME="$TMP_HOME" xlings ...`. Clear a stale install first:
   `rm -rf "$TMP_HOME"/data/xpkgs/{xim,local}-x-<pkg>/<version>`.
2. **Read the whole failure, not its last line.** The line that names the symptom is often
   several layers from the cause: a hook error appears in the outer install log.
3. **Inspect the result, not the exit code**: `ls` the install directory, `readelf -d` /
   `LD_TRACE_LOADED_OBJECTS=1` on an ELF, `xlings list`, the shims in the subos `bin/`.
4. **Get CI's logs** with the GitHub CLI and filter by platform and package:
   `gh pr checks <n>`, `gh run view <run-id> --log > ci.log`, then
   `grep "install (windows)" ci.log | grep -i <pkg>`. Compare the platform that fails with the
   one that passes: the difference is usually the answer.
5. **Check the three usual suspects first**: (a) a dependency not declared for *that* platform
   or for a library the payload names; (b) a change to what a hook installs without a
   `revision`; (c) something assumed to exist on the host (python3, tar, a compiler, a shell).
6. **Change one thing, rerun locally, push once.** CI is shared and slow; do not use it to
   experiment.

## Install

| Symptom | Likely cause | Check | Fix |
|---|---|---|---|
| `✓ installed`, but the install directory holds only `.xpkg.lua` | Same name and version already installed under another namespace: xlings skipped the hook | `ls $XLINGS_HOME/data/xpkgs/*-x-<pkg>/` | Remove both (`xim-x-`, `local-x-`) before testing |
| Install dir empty after a hook error | `install()` raised; the outer run still printed success | Re-run with the log visible; `ls` the dir | Assert the artifact at the end of `install()` |
| `attempt to call a nil value (field 'exists')` (or `curdir`, `execv`, `files`, `absolute`) | API not bound in the hook runtime | `grep -rn "<api>" pkgs/ \| wc -l` (0 = unavailable) | See `hook-pitfalls.md` section 1 |
| Windows: `'"C:\...' is not recognized` | Command line starts with a quote; libxpkg >= 0.0.67 runs it as written | Print the exact command | Prefix `call` |
| Windows: tar cannot read the `.zip` or says `Cannot connect to C:` | A bare `tar` resolved to GNU tar | Which `tar` is first on PATH | Use `%SystemRoot%\System32\tar.exe` |
| Windows: a program path fails with mixed `\` and `/` | `path.join` mixes separators | Print the argv | Normalize through `winpath()` |
| A payload contains another package's files (`lib/ollama/...`) | Flat archive moved out of the shared runtime dir (openxlings/xlings#736) | `ls` the payload against the archive's listing | Extract the archive again into the payload alone |
| macOS fails, Linux passes | A dependency declared only for Linux; the hook fell back to the host's tool (pip, python3) | Compare each platform's `deps` | Declare the dependency on every platform; remove the silent fallback |
| `os.arch()` is nil | Client before 2026.10.8.1 | Which xlings the user has | Detect from the payload's content |
| The command runs from the shim but breaks in a subos | `bindir` missing or a non-registered program | `xlings list`, the shim target | Set `bindir`; list the program in `programs` |

## Linking and dependencies

| Symptom | Likely cause | Check | Fix |
|---|---|---|---|
| Closure check (D1) says a `.so` has no provider | A library the payload names is not a declared dependency | `readelf -d <elf> \| grep NEEDED`, then compare with `deps` | Declare it (`xim:gcc-runtime` for libstdc++/libgcc_s, `xim:glibc`, X libraries...) |
| D1 names a library no file of this package contains | The payload holds files that are not the archive's (shared dir, leftover) | List the payload against the archive | Extract into the payload alone |
| Program fails: `libX.so.N: cannot open shared object file` | RPATH lacks a dependency, or elfpatch replaced an `$ORIGIN` RPATH | `readelf -d`; was `xim:glibc` declared on a self-contained payload? | Declare the library; or remove the loader dep for a self-contained payload |
| A `build` tool is not installed though declared | Mixed `deps` shape (`{ "a", build = {...} }`) dropped by older clients | `tests/test_deps_shape.py` | Use `{ runtime = {...}, build = {...} }` |
| `7zip`/`patchelf` ends on the user's PATH | Declared as runtime although only `install()` uses it | D3 advice in the install log | Move it to `build` |

## Xpkg and version

| Symptom | Likely cause | Check | Fix |
|---|---|---|---|
| `check-revision` fails | Changed a published entry or the payload under the same resource without a `revision` | Read the check's message; diff the entry | Raise `revision` (new asset: new tag `<ver>-r<N>`) |
| Installing on macOS/Windows gives version `ref` / "Only HTTPS is supported" | A platform section is `{ ref = "linux" }` | `tests/test_platform_table_reuse.py` | `local versions = {...}` named in each section |
| `latest` moved backwards or to an unverified version | Added an old version and re-pointed `latest` | Diff the `latest` ref | `latest` only advances, only to a version you verified |
| sha256 mismatch on a mirror | The mirror is stale or not the same bytes | Download GLOBAL and CN, `sha256sum` both | Drop CN, or wait for the mirror; do not edit the hash to match a mirror |
| A package is missing an architecture's checksum | `sha256` map lacks an arch you claim in `archs` | The updater `check` plan; `tests/` static | Add the hash, or remove the arch from `archs` |
| Local repo vanished (`package 'local:foo' not found`) | Two files with the same `package.name` in a local index | `grep -r 'name = "foo"'` | Delete the duplicate |
| Autoupdate `check` reports nothing / fails closed | A required platform or mirror asset is missing | `xpkgindex-update check --package xim:<name> --output plan.json` | Fix the declared templates; leave it manual and say why in a comment |

## Config packages and xvm

| Symptom | Likely cause | Check | Fix |
|---|---|---|---|
| `another package already owns this exact name and version` | Two packages register the same shared xvm name | The other xpkg's `xvm.add` | Register `<version>-<flavor>` (`hook-pitfalls.md` section 6) |
| After uninstall, lib nodes remain in `.xlings.json` | `xvm.remove` got a bare key for a namespaced install | `workspace` in `subos/<name>/.xlings.json` | Use the stored (namespaced) key |
| A shim `bin/<name> -> bin/xlings` that always fails | A binding root registered as a program | `xlings self doctor` | Register the root as `type = "group"` |
| User config lost or a token printed | A config hook overwrote or logged it | Read the hook | Back up, merge keys, never print secrets |

## CI

| Symptom | Likely cause | What to do |
|---|---|---|
| A huge matrix of jobs for a small change | You touched a package many others depend on (`glibc`, `gcc-runtime`, `libs/**`) | Confirm the change is needed; keep it minimal; expect a long run |
| A job fails on a package you did not touch | An xpkg in the reverse closure had its own latent bug the broader run exposed | Say so in the PR; do not "fix" unrelated xpkgs unless asked (a maintainer may split a fix PR) |
| A workflow or script is red | The problem is in `.github/**` | Do not edit it; report the log link and what you saw |
| A skipped job you expected | Path filter or planner; or the job needs a trigger | Ask a maintainer; do not dispatch workflows |
