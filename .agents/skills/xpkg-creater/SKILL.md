---
name: xpkg-creater
description: Add or update a package (an xpkg recipe) in xim-pkgindex. For anyone, not only the upstream's author: pick an official or well-known source, write a spec-2 recipe from the template, verify it in an isolated home, add the package note, and open a minimal pull request. Use when creating a recipe, bumping a version, or fixing one.
---

# xpkg-creater

Adds or maintains one recipe under `pkgs/`. The hard rules are in `AGENTS.md`; this skill is
the procedure and the decisions behind them. The contributor may be anyone: the test is that
the information and resources are official or from a well-known mirror, and that you ran it.

References (read when the step says so):

- `references/source-selection.md`: which source and mirror, static vs dynamic, namespaces.
- `references/hook-pitfalls.md`: what the hook runtime lacks, `installed()`, shared xvm names.
- `references/testing-and-acceptance.md`: the commands, levels and what to put in the PR.
- `references/troubleshooting.md`: symptom → cause → how to check locally → fix.
- `references/package-note-template.md`: the `.agents/docs/<name>.md` format.
- `references/maintainer-publishing.md`: `xlings-res` and mirror publishing. Maintainers only.
- `references/xlings-setup-and-links.md`: installing xlings, links.

## 1. Decide before you write

1. **Is it already there?** `xlings search <name>` and `ls pkgs/*/<name>.lua`. A missing
   platform, a new version or a bug is an update, not a new package.
2. **Which source?** Walk the order in `references/source-selection.md`: the upstream's
   release, then its official repository, then a well-known third-party release. Note the
   URLs of every platform and architecture it publishes.
3. **Is it official?** If the thing is a repack, a patched build or your own packaging, it needs
   `namespace = "<your handle>"` and your own hosting (see the reference). If it is generally
   useful, open an issue asking maintainers to host it on `xlings-res` instead.
4. **Static or dynamic?** Prefer the official static or musl artifact. A dynamic glibc one is
   fine and declares its dependencies.
5. **Does it need compiling at install?** Then it is not a recipe for this index: open an issue.
6. **Luban?** Bug fixes only, locally verified; features go through an issue first.

## 2. Write the recipe

Copy `docs/specs/xpackage-template.lua` to `pkgs/<first letter>/<name>.lua`. Always
`spec = "2"`; the specification is `docs/specs/xpackage-v2.md`, the walk-through is
`docs/10-adding-a-package.md`. Do not copy the shape of an old neighbour: `spec = "1"`
recipes exist and are not to be imitated.

- **Required**: `spec`, `name`, `description`, `type`, `xpm`. Also set `licenses`, `repo`,
  `archs` (only what you tested), `status`, `programs`, `xvm_enable = true` when it puts a
  command on PATH.
- **Resources**: `xpm.source = "<template with ${version}...>"` and a per-architecture
  `sha256` for every version you list. If URLs are irregular, use a per-architecture map in the
  version entry. Take each hash from the upstream's own checksum file when it publishes one,
  and compute it yourself from the downloaded bytes; they must agree.
- **Several platforms, same versions**: one `local versions = {...}` above `package`, named in
  each platform section. `{ ref = "linux" }` (or `inherits`) as the whole body of the linux, macosx
  or windows section is forbidden: older clients read it as a version named `ref`.
- **Other recipes' code**: use `libs/` through `import("xim.pkgindex.<name>")` instead of copying.
- **Dependencies**: `deps = { runtime = {...}, build = {...} }`. Measure the payload's
  `DT_NEEDED` (`readelf -d`, `LD_TRACE_LOADED_OBJECTS=1`) and declare each library it names; a
  tool only `install()` uses is `build`. A payload that carries its own libraries via `$ORIGIN`
  declares no `xim:glibc`.
- **Hooks** (`install` / `config` / `uninstall`): read `references/hook-pitfalls.md` first.
  Unpack and place only; register commands with `xvm.add` in `config()`.
- **Automatic updates** (optional, upstream on GitHub or an official appcast): add
  `extensions.autoupdate` from `docs/13-ci-mirror-and-update.md`, GLOBAL first; add `CN` only when a
  mirror's real path and bytes are verified. Run `xpkgindex-update inspect` and a `check` on your
  package before the PR. Do not commit generated plans.
- **CN**: only a well-known institutional mirror you verified; otherwise leave it out. Without
  `xlings-res` access do not use `xlings-res` as `source`, `ci = { mirror = true }`, or publish
  releases: a maintainer adds the CN resource later (see AGENTS.md). A maintainer with access
  follows `references/maintainer-publishing.md`.

Minimal skeleton:

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

import("xim.libxpkg.pkginfo")
import("xim.libxpkg.xvm")

function install()
    os.tryrm(pkginfo.install_dir())
    os.mv(pkginfo.install_file():replace(".tar.gz", ""), pkginfo.install_dir())
    if not os.isfile(path.join(pkginfo.install_dir(), "demo")) then
        raise("demo: payload has no demo binary")
    end
    return true
end

function config()
    xvm.add("demo", { bindir = pkginfo.install_dir() })
    return true
end

function uninstall()
    xvm.remove("demo")
    return true
end
```

## 3. The test module

`tests/<first letter>/test_<name>.py` (a `-` in the name becomes `_`), written like its
neighbours (`docs/20-testing.md`). It locks the static and isolation levels and the
recipe-specific rules you rely on (a dependency, an `installed()` list, a template).

## 4. Verify locally

Isolated `XLINGS_HOME`, always. The commands, the levels and the checklist for the pull
request are in `references/testing-and-acceptance.md`. Install on every platform and
architecture you can reach, run the program, inspect the install directory, remove it.
Whatever you could not run goes into the PR as "not run, because ...".

## 5. The package note (first time only)

Create `.agents/docs/<name>.md` from `references/package-note-template.md`. A plain version bump
adds nothing. A larger change (layout, dependencies, source, a `revision`) appends one dated
entry to the existing note's revision log.

## 6. Updating an existing package

- A new version: add the version entry, move `latest` forward, change nothing else. If the
  recipe has `extensions.autoupdate`, the updater usually does this for you: check its
  pull request instead of writing a competing one.
- A fix to what a hook installs: raise that entry's `revision` (and `floor` only as the spec
  says); `.github/scripts/check-revision.sh` checks it.
- Do not migrate an old recipe's style, and do not touch other versions' entries.

## 7. Pull request

Follow `pr-workflow`. The description gives: what the package is and its platforms; source,
version, mirror and sha256s; whether install/config/uninstall change the user's environment;
the commands you ran and their results; what you did not run.

## 8. Stuck?

Open `references/troubleshooting.md` first; most failures here have a known shape. If the
cause is in xlings, libxpkg or the CI itself, say so in the pull request or open an issue in
the owning repository rather than working around it in the recipe.
