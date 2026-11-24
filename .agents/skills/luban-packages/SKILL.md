---
name: luban-packages
description: Rules for pkgs/luban/ and libs/luban*.lua in xim-pkgindex (Luban OS editions, desktop components, policies, boot profiles). Bug fixes only for now, each verified locally; features go through an issue first. Covers the luban namespace, which dependencies are allowed, published-version immutability, min_client, archs and the cost of Luban CI. Use before touching any Luban xpkg.
---

# Luban packages

Luban's editions, policies and boot profiles are ordinary xpkgs in this index; the xpkg
format is unchanged and only `libs/luban.lua` writes files. What Luban is: xlings's Luban docs.
The full reference for this index is `docs/12-luban-packages.md`; this skill is the working
rules.

## Current policy (early stage)

- **Only bug fixes** are accepted for Luban packages, and each must be **verified locally** (below).
- **New features** (an edition, a desktop, a component, a new `extensions.luban` key, a new boot
  profile) **start as an issue**. Describe the need and the design; wait for a maintainer before
  writing the xpkg.
- Keep a fix to the smallest change that fixes it. Do not bump unrelated versions, rename, or
  re-organise.

## The namespaces

- `luban:` holds what is official and made for Luban: editions (`luban:core`, `luban:desktop`),
  desktop components (`luban:labwc`, `luban:lxqt`, `luban:kde`, `luban:xdesk`), the Qt runtime,
  tool sets, and bundles built for them. Anyone may depend on a `luban:` package.
- General software stays in `xim` (fish, mesa, a kernel), and so do the programs a user runs on a
  host (`xim:luban`, `xim:luban-os`).
- `xim`, `luban`, `subos` and `config` are reserved by `index-compat.json`: a client takes packages
  in them from this index only. Do not use them as a personal namespace.
- The published `subos:luban-*` editions and `xim:labwc-desktop` are frozen: kept, resolved as
  before, never updated. Their successors declare `replaces = "<old name>"`.

## Dependencies: what a Luban xpkg may depend on

- **Editions** (`type = "subos"`) pin exactly: every package they list has an exact version
  (`luban:foot@1.27.0-r1`), and each `from`s an official layer (except nano) and states its `abi`.
  The one exception is a fast-moving tool (an agent CLI), which `subos new` installs at the newest
  version and records in the instance.
- **Components and composites** may depend on `luban:` and `xim:` packages. Today no xpkg
  outside `pkgs/luban/` depends on a `luban:` package, and only Luban's own programs
  (`xim:luban-os` -> `luban:cursors`) cross from `xim:` into `luban:`. Keep it that way: general
  software must work without Luban, so if you think one needs a `luban:` dependency, open an issue.
- **Every official desktop brings the pointer theme** (`luban:cursors`, through `luban:labwc` or
  `luban:xdesk`).
- Declare runtime and build dependencies as `{ runtime = {...}, build = {...} }`, exactly as
  elsewhere; a Luban closure is checked (`tests/test_luban_build_closure.py`): the ELF relocation
  tools (`xim:patchelf@0.18.0`) are explicit build deps for the packages that need them.
- An edition is built only for the architectures it declares: `archs` lists what was booted and
  tested, and each package it pins must exist for each of them. What an architecture cannot
  have is left out of that edition, and the xpkg says so (no aarch64 xmake upstream, cmake's GUI
  libraries x86_64 only).
- A layer above wins a program's name: core's procps-ng `ps` replaces BusyBox's applet from tiny.
  Its self-check says so (`ps -C` works only with procps).

## Rules that must hold

1. **A published version's output never changes.** `tests/fixtures/luban-published.json` records
   the sha256 and mode of every file each published version writes; `tests/test_luban_published.py`
   compares. When a version merges to `main` a maintainer adds it
   (`LUBAN_PUBLISHED_ADD=pkgs/l/<name>.lua@<version> pytest -k add_published`). The fixture
   only grows. A fix to what a published version writes is a **new version**, not an edit.
2. **A change a user's installed machine must pick up raises the `revision`** of that entry
   (the same rule as every xpkg; see `docs/specs/xpackage-v2.md`).
3. **An edition using a field newer clients read sets `min_client`**; a new field is designed so
   an older client ignoring it is still safe.
4. **A new edition names only `luban-init`**; `xlings-init` remains for published versions.
5. **Tools that move fast are not pinned** (an agent CLI); every other package is pinned exactly.
6. **A preview edition** (`status = "preview"`) has no short name in luban. A desktop is not an
   edition: an edition presets one, and `luban new --desktop` chooses another.
7. Each component says in a comment the form it takes and why (a bundle, a runtime, a composite);
   the name and its conventions (a session file, `X-Luban-Shell`, the checks) stay when the form
   changes.

## Verify a fix locally

1. `pytest tests/test_luban_*.py tests/l/test_luban*.py -m "static or isolation"`, plus the test
   module of the xpkg you touched (`tests/<first letter>/test_<name>.py`).
2. Install the changed xpkg and its dependents in an isolated `XLINGS_HOME` (see
   `xpkg-creater/references/testing-and-acceptance.md`) and run what the fix is about.
3. For an edition, run `scripts/test-luban-editions.sh <home>` on a machine with the xlings/luban
   build under test (x86_64 and, where the edition claims it, aarch64). If you cannot, say that in
   the pull request instead of leaving it out.
4. State in the pull request: what was broken, how you reproduced it, what you ran after, and
   which published versions the change does or does not touch.

## CI cost

Luban xpkgs are in many reverse closures, and a change to `pkgs/luban/` or `libs/luban*.lua`
runs the Luban editions, which are slow and shared. So: verify locally first, push once, no empty
commits to re-run, no manually dispatched workflows. If a Luban job fails for a reason outside your
change, report the log link and leave `.github/**` alone.
