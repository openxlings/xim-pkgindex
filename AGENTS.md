# AGENTS.md

This is `xim-pkgindex`, the official package index of [xlings](https://github.com/openxlings/xlings)
(the `xim:` namespace). A package is one Lua recipe. Whoever adds or updates one is
usually **not** the upstream project's author, and may be an agent working for them:
what matters is that the package's information and resources are official, or from a
well-known mirror, and that you have run what you submit.

This file holds the rules that apply to every change. The how-to is in the skills,
the reasons in `docs/`. When a rule here and an old recipe disagree, the rule wins:
recipes are history, not examples.

## Layout

- `pkgs/<first letter>/<name>.lua`: recipes (`pkgs/luban/` holds Luban OS packages).
- `tests/<first letter>/test_<name>.py`: one pytest module per recipe.
- `libs/`: Lua shared by recipes, imported as `xim.pkgindex.<name>`.
- `docs/`: human documentation (English, mirrored in `docs/zh/`); `docs/specs/` is the normative format.
- `.agents/skills/`: how-to for agents. `.agents/docs/`: per-package notes and dated design
  records (history, not rules). `.agents/tools/`, `tools/`, `.github/`: maintainers' machinery.

## Read next

| You are... | Read |
|---|---|
| adding or updating a package | `.agents/skills/xpkg-creater/SKILL.md` |
| opening a pull request | `.agents/skills/pr-workflow/SKILL.md` |
| touching `pkgs/luban/` or `libs/luban*.lua` | `.agents/skills/luban-packages/SKILL.md` |
| carving an LLVM sub-package | `.agents/skills/llvm-subpackaging/SKILL.md` |
| debugging a failure | `.agents/skills/xpkg-creater/references/troubleshooting.md` |

## Change only what the task needs

- Edit your own recipe and its test, plus the package note below. Do not reformat, migrate
  or "clean up" other recipes, or older entries of your own.
- **Do not edit** `.github/**` (workflows, CI profiles, updater config), `tools/**`,
  `.agents/tools/**`, `libs/**`, `index-compat.json`, `tests/lib/**`, `tests/fixtures/**`,
  `docs/specs/**`, or generated files (`.xpkgindex*`, `.xlings-index-cache.json`) unless you
  are a maintainer and the task is about them. If CI fails because of CI itself, say so in
  the pull request with the log link; do not patch the workflow.
- A published version entry (its url, sha256, hooks' output) never changes. A fix is a new
  `revision` or a new version, never an edit in place.

## Recipes

- **Use the latest spec.** New recipes are `spec = "2"` ([`docs/specs/xpackage-v2.md`](docs/specs/xpackage-v2.md)).
  Start from `docs/specs/xpackage-template.lua`, **not** from a neighbouring recipe: many are
  older. Keep an older spec only when maintaining that recipe, and do not convert it on the way.
- **Source order.** GLOBAL, in this order: (1) the upstream project's own release, or its
  official repository's release; (2) a well-known third-party release; (3) `xlings-res`, which
  only maintainers can write to. Use the URL-template form of `xpm.source` with a per-architecture `sha256`. Cover the platforms and
  architectures the source publishes that you can test, and claim in `archs` only those.
- **CN mirror.** A well-known institutional mirror (USTC, Tsinghua, ...) of the original files,
  whose path and bytes you checked; otherwise `xlings-res` on GitCode. **A contributor without
  `xlings-res` access skips CN**: declare GLOBAL only, and a maintainer adds the CN resource later.
- **`xlings-res` is written by maintainers.** A maintainer with access may publish the GitCode
  (CN) resource directly, in the same pull request, by the gates in
  `.agents/skills/xpkg-creater/references/maintainer-publishing.md`. Everyone else does not use
  `xpm.source = "xlings-res"` or `ci = { mirror = true }` and does not publish to
  `github.com/xlings-res` / `gitcode.com/xlings-res`; if a generally useful package needs a
  resource we host (a repack, a layout fix), open an issue and ask.
- **Linking.** Within the official source, prefer a fully static or musl artifact over a
  dynamic one; a dynamic glibc artifact declares `xim:glibc` (and the libraries it names)
  instead. Never swap an official dynamic build for a third-party musl build just to get musl.
- **No source builds while installing.** `install()` unpacks, places and fixes up a prebuilt
  payload. It does not run `configure`, `cmake`, `make`, `cargo build` or a compiler. A package that
  has no usable binary is built by the maintainers' resource factory (`tools/res/`), not on a
  user's machine.
- **Unofficial packaging needs a namespace.** A repack, a patched build, or anything a person
  maintains rather than the upstream project or this index's maintainers sets
  `namespace = "<your handle>"` in `package`, so its id is `<ns>:<name>@<version>` and never
  collides with the upstream-based one. Host its assets in your own repository or release;
  explain the source and a reproducible process in the pull request and the package note.
  `xim`, `luban`, `subos` and `config` are reserved. Official `xim:` packages carry no prefix.
- **Hooks** use standard Lua and `xim.libxpkg.*` only: no host package manager, no `sudo`,
  no shell-profile or `PATH` edits, no `xvm` shell-outs. `install()` ends by asserting the
  artifact exists; `installed()` checks files, not directories.
- **Several platforms with one set of versions**: define one `local versions = {...}` before
  `package` and name it in each section. Never write `macosx = { ref = "linux" }` for the
  three looked-up platforms (linux, macosx, windows). Share logic across recipes through
  `libs/`, not by copying.
- **Dependencies**: `deps = { runtime = {...}, build = {...} }`, never a positional list mixed
  with `build`. A tool only `install()` uses is `build`. Declare every library a payload's
  `DT_NEEDED` names; a payload that finds its own libraries via `$ORIGIN` declares no loader.
- **Versions**: `latest` is a `ref` to a real version and only moves forward. A change to
  what `install()` or `config()` produces under an unchanged resource raises `revision`.
  A rebuilt resource is a new tag `<version>-r<N>`.

## Luban

Luban OS packages (`pkgs/luban/`, `libs/luban*.lua`) accept **bug fixes only**, for now, each
verified locally. A new feature, edition, component or desktop starts as an issue, not a
pull request. Published Luban versions never change their output.

## Verify before you push

Use an isolated home, never your own. Run what the package claims, on every platform and
architecture you can reach, and say in the pull request what you could not run.

```bash
pytest tests/<letter>/test_<name>.py -m "static or isolation"
TMP_HOME="$(mktemp -d)"
XLINGS_HOME="$TMP_HOME" xlings config --add-xpkg pkgs/<letter>/<name>.lua
XLINGS_HOME="$TMP_HOME" xlings install <name>@<version> -y   # then run the program
XLINGS_HOME="$TMP_HOME" xlings remove <name> -y
```

"Installed" is not "works": run the program, look in the install directory, and check
that removal leaves nothing behind.

## CI is shared and costs real time

A change to something many recipes depend on (`glibc`, `gcc-runtime`, `libs/**`, a Luban
package) fans out to its whole reverse closure (about 190 recipes on Linux for glibc) and
to the Luban editions. Touch those only when the task is about them. Get it right locally,
then push once: no empty commits to re-run CI, no manually dispatched workflows.

## Pull requests

- Never push to `main`; one concern per pull request; branch `<type>/<scope>`; commits
  `<type>(<scope>): <description>` (`feat(pkg): add foo 1.2.0`). Contributors do not merge.
- Describe: what the package is and its platforms; the resources (source, version, mirror,
  sha256); whether install/config/uninstall touch the user's environment; the commands you
  ran and their result; what you did not run.
- **First time a package is added**, also add `.agents/docs/<name>.md` from
  `.agents/skills/xpkg-creater/references/package-note-template.md`. A plain version bump adds
  no file. A larger change (layout, dependencies, source, a `revision`) appends a dated entry
  to that package's existing note.
- Add the recipe's test module. When you are unsure of something, ask in an issue rather than
  guess.

## Language

`AGENTS.md` and `.agents/skills/**` are English only. `.agents/docs/**` may be in either
English or Chinese. `docs/` is English with a `docs/zh/` mirror (`tests/test_docs.py` keeps
them in step). Issue templates are bilingual.
