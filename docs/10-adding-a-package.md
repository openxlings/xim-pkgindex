# Adding a Package

**English** | [简体中文](zh/10-adding-a-package.md)

From an xpkg to a merged pull request. The exact rules are
[XPackage V2](specs/xpackage-v2.md); this chapter is the path.

## The procedure

1. Open an [Add XPackage](https://github.com/openxlings/xim-pkgindex/issues/new/choose)
   issue: the name, one sentence, the home page, the license.
2. Copy [the template](specs/xpackage-template.lua) to `pkgs/<first letter>/<name>.lua`.
3. Fill in the `package` table and the hooks (below).
4. Add `tests/<first letter>/test_<name>.py` ([Testing](20-testing.md)).
5. Install it in an isolated home, on every platform and architecture it claims.
6. Open the pull request, and link it from the issue.

## The `package` table

```lua
package = {
    spec = "2",
    name = "demo",
    description = "One sentence on what it is",
    type = "package",
    licenses = {"MIT"},
    repo = "https://github.com/acme/demo",
    archs = {"x86_64", "aarch64"},
    status = "stable",
    programs = {"demo"},
    xvm_enable = true,

    xpm = {
        source = "https://github.com/acme/demo/releases/download/v${version}/demo-${os}-${arch_alias}.${ext}",
        linux = {
            ["latest"] = { ref = "1.0.0" },
            ["1.0.0"] = {
                arch_alias = { x86_64 = "amd64", aarch64 = "arm64" },
                sha256 = { x86_64 = "<amd64-sha256>", aarch64 = "<arm64-sha256>" },
            },
        },
    },
}
```

- `archs` is checked against the host and fails closed: claim only what you
  tested.
- `programs` names every command the package puts on PATH; the site and the
  routing table read it.
- `latest` is a `ref` to a real version, and only ever moves forward.
- A version without network resources (a script, a config) is an empty table:
  `["0.0.1"] = {}`.

### Choosing how a resource is written

Take the resource from the upstream's own release or its official repository first, then
from a well-known third-party release. Add a CN mirror (USTC, Tsinghua, ...) only when a
well-known one exists and you checked its path and bytes; otherwise declare GLOBAL alone. Without
write access to `xlings-res` you skip CN: a maintainer who has it adds the CN resource later, or
in the same pull request.
Prefer a static (musl) artifact from that official source, and never build from source while
installing.

Keep the `platform -> version` model and pick the first that fits:

| Case | Write |
|---|---|
| a release with regular URLs (the upstream's, or a well-known third party's) | `xpm.source = "<template with ${version}>"` and a per-architecture `sha256` |
| irregular URLs per architecture | a per-architecture map, each `{ url, sha256 }` |
| one special or historical version | an explicit `url` / mirror table in that entry, which overrides `source` |
| a resource the maintainers host on xlings-res | `xpm.source = "xlings-res"` and a per-architecture `sha256`; maintainers with access add it, so ask in an issue |
| an older xpkg | `"XLINGS_RES"`, `res = true`, a single URL, a single hash — still accepted |

A repack, a patched build or any packaging you maintain yourself sets
`namespace = "<your handle>"` in `package`, so its id is `<namespace>:<name>@<version>`; host
the asset yourself and give its reproducible process in the pull request.

Every architecture has its sha256. Without an authoritative hash, keep the old
form until the resource and its sidecar exist; never publish a new official
binary without one.

## Automatic updates for new packages

Copy the `package.extensions.autoupdate` template from
[CI: Mirror and Update](13-ci-mirror-and-update.md), then replace its source and
asset URLs with verified project paths and cover every supported platform/architecture.
We recommend this for upstream GitHub repositories with **at least 50 stars**;
this is guidance, not an enforced threshold. Packages can remain manually maintained.

The index scans every three days, selects the newest version satisfying all required
resources, and opens a PR for review. Existing version entries and hooks are preserved.
GLOBAL works alone; add a verified CN mirror as required by default, or explicitly
optional after review. Follow that chapter's local checks; CI generates coverage
from the xpkgs. Keep manual-maintenance reasons in an xpkg comment or the PR.

## The hooks

```lua
import("xim.libxpkg.pkginfo")
import("xim.libxpkg.xvm")

function install()
    os.tryrm(pkginfo.install_dir())
    os.mv(pkginfo.install_file():replace(".tar.gz", ""), pkginfo.install_dir())
    return true
end

function config()
    xvm.add("demo", { bindir = path.join(pkginfo.install_dir(), "bin") })
    return true
end

function uninstall()
    xvm.remove("demo")
    return true
end
```

- `install()` places the files; without one, the install directory holds exactly
  the archive's entries.
- `config()` registers commands, links into the sysroot, declares environment —
  once per scope, recorded by revision.
- Hooks use standard Lua and `xim.libxpkg.*` only: never a host package manager,
  never `.bashrc`, never `PATH` directly (the isolation tests fail them).
- Shared modules under `libs/` answer what several xpkgs would otherwise spell
  each its own way: `xim.pkgindex.winpath` (a path a Windows program accepts),
  `xim.pkgindex.payload` (landing the archive, then naming any file that did not
  land) and `xim.pkgindex.shortcut` (a Start Menu or Desktop entry, best-effort
  by contract). Import one instead of copying the code; the modules' headers are
  the reference. A prebuilt MSVC program whose import tables name the VC++
  runtime DLLs declares `xim:vcruntime` and copies its `bin/` beside the
  executables (app-local deployment) -- it never vendors the DLLs itself.
- A configuration package writes in `config()`, keeps what the user already has,
  and never prints a token.

## Dependencies

```lua
deps = {
    runtime = { "xim:glibc", "xim:gtk3" },
    build   = { "xim:7zip@26.02" },
}
```

- `runtime` is activated in the user's workspace and enters the RPATH closure;
  `build` exists only while `install()` runs and is not on PATH.
- A tool only `install()` uses (7zip, patchelf, cmake) is a `build` dependency;
  ask for it with `pkginfo.build_dep("7zip")` — the **bare** name.
- Ask for a runtime dependency with the coordinate you declared:
  `pkginfo.dep_install_dir("xim:glibc")`. Never rebuild a payload path yourself.
- Use the split form; do not mix a positional list with `build`
  (`tests/test_deps_shape.py`).
- A payload that carries its own libraries and finds them through
  `$ORIGIN` (xPack, some Electron and Bun apps) declares **no** loader
  dependency: declaring `xim:glibc` makes elfpatch replace its `DT_RPATH`, and
  its own libraries stop being found while the install reports success. Decide
  from the measured `DT_NEEDED` closure (`LD_TRACE_LOADED_OBJECTS=1 <bin>`), and
  run the program once in its test — `--version` does not show it.
- A library the payload loads with `dlopen()` is a runtime dependency too:
  xlings writes the payload's `DT_RUNPATH` from its runtime dependencies, and
  glibc resolves a `dlopen()` issued by an object that has `DT_RUNPATH` only
  there, in `LD_LIBRARY_PATH` and in the system directories — never in the
  `DT_RPATH` of the program that loaded it (`slint`).

## Versions

- A version key is the upstream version, as upstream writes it (`binutils`
  2.47, `linux-headers` 6.18.64).
- A repackaging of the same upstream version — a rebuild against other
  dependencies, a corrected archive, a changed layout — is a `revision` of that
  version entry with a new asset (`<version>-r<N>`), never a new version key
  ([XPackage V2](specs/xpackage-v2.md#revision--a-packaging-change-under-an-unchanged-version)).
- A build from another source tree — an upstream version with a correction
  upstream has not released — is a key of its own with a prerelease marker
  (`ninja` 1.13.2-mcpp.1).
- A published key is never renamed or removed. Keys made before this rule
  stay as they are (`binutils` 2.42.1, the 2.42 payload); later versions
  follow it.

## Rules that keep packages correct

- **A library payload does not carry the compiler's runtime.** On Windows that is
  `vcruntime140*.dll`, `msvcp140*.dll`, `concrt140.dll`, `vccorlib140.dll` and the
  `Microsoft.VC*.CRT` directory; only the toolset package (`msvc`) has them
  (`tests/test_no_compiler_runtime_in_payloads.py`).
- **A target sysroot is not a host library.** A cross or bare-metal sysroot
  (`picolibc-riscv`) never puts its headers into the SubOS's `usr/include`, uses
  one sha256 for every platform (its bytes do not depend on the host), and sets
  no `ci`.
- **What config does is versioned by `revision`.** A change to what `config()`
  registers, links, declares or writes raises the version entry's `revision`, or
  scopes that already configured it never see the change. `config()` never
  writes scope-specific data into the shared payload.
- **A prebuilt native program is fetched as it is, not picked by a script.** Prefer
  a platform archive taken directly (`esbuild`, `codex`); where a package manager
  is the only distribution, install with its install scripts off and choose the
  platform package in the xpkg (`bun`, `openclaw`). A script that runs the
  binary it downloads does so before xlings rewrites its loader: on a host without
  `/lib64/ld-linux-x86-64.so.2` (Alpine; the Luban host machine every Windows and
  macOS install goes through) that worked only since xlings 2026.11.22.1, and on a
  host whose glibc is older than the binary needs it never does.
  `native-binary-hosts.yml` installs these xpkgs where both assumptions fail.
- **Hard links in an archive are the client's to handle.** Android's app
  sandbox, FAT and exFAT refuse `link(2)`; from xlings 2026.10.10.2, this
  index's floor (`index-compat.json`), extraction copies a refused hard link.
  An upstream archive is mirrored as published. Payloads this index builds
  still pack with `tar --hard-dereference` (`tools/res/build.sh`).
- **A hook does not guess the architecture from its environment** on clients
  before 2026.10.8.1, where `os.arch()` is absent in hooks: detect from the
  payload's content (`os.isfile` on the loader it ships).

## Test it locally

```bash
xpkgindex-update inspect
pytest tests/<letter>/test_<name>.py -m "static or isolation"
```

Installs use an isolated home, never your own:

```bash
TMP_HOME="$(mktemp -d)"
XLINGS_HOME="$TMP_HOME" xlings config --add-xpkg pkgs/<letter>/<name>.lua
XLINGS_HOME="$TMP_HOME" xlings install <name>@<version> -y
XLINGS_HOME="$TMP_HOME" xlings remove <name> -y
```

For several architectures, check the resolution on x86_64 and aarch64; for
mirrors, the real GLOBAL and CN responses and their sha256s.

## The pull request

The description gives:

- what the package is, and its platforms and architectures;
- the resources: source, version, mirror release, sha256s;
- whether install, config or uninstall change the user's environment;
- what you ran: commands, pytest, the isolated install;
- when `latest` moves, the verified version it points to;
- optionally, which agent and model you used (the pull request template has the lines).

Labels are hints that a workflow adds; nothing checks them. Descriptions and logs are public and
an edit keeps the old text in the history, so remove local absolute paths, user names, host
names, e-mail addresses and tokens before you post.

Commits follow `<type>(<scope>): <description>` — `feat(pkg): add foo 1.2.0`,
`fix(index): add missing aarch64 checksums`. A pull request merges once Linux,
macOS, Windows and the index checks pass.

## Where the boundaries are

xlings and libxpkg are the only parser of an xpkg, its compatibility rules and
its resource resolution; this index declares data and hooks. An xpkg never
re-implements platform detection, resource-server URLs or template expansion.
