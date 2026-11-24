# xim-pkgindex

**English** | [简体中文](README.zh.md)

The official package index of [xlings](https://github.com/openxlings/xlings):
recipes for compilers, runtimes, tools and environments, on Linux, macOS and
Windows, x86_64 and aarch64.

[![xpkg test](https://github.com/openxlings/xim-pkgindex/actions/workflows/ci-xpkg-test.yml/badge.svg?branch=main)](https://github.com/openxlings/xim-pkgindex/actions/workflows/ci-xpkg-test.yml)
[![site](https://github.com/openxlings/xim-pkgindex/actions/workflows/pkgindex-deloy.yml/badge.svg)](https://index.xlings.org)

## Install xlings

```bash
curl -fsSL https://d2learn.org/xlings-install.sh | bash
```

```powershell
irm https://d2learn.org/xlings-install.ps1.txt | iex
```

## Use this index

```bash
xlings search gcc
xlings install gcc -y
xlings update
```

Browse every package, its versions and commands at
[index.xlings.org](https://index.xlings.org).

## Contribute a package

You do not have to be the upstream's author. A package needs official information and
resources (or a well-known mirror), and an install you have actually run.

1. Copy [the template](docs/specs/xpackage-template.lua) to `pkgs/<first letter>/<name>.lua`.
2. Add `tests/<first letter>/test_<name>.py`.
3. Verify it in an isolated `XLINGS_HOME`, then open a pull request —
   [Adding a package](docs/10-adding-a-package.md) is the whole path.

A few rules of thumb:

- **Source**: the upstream's own release first, then a well-known third-party one. Add a CN
  mirror only where a well-known one exists; otherwise skip CN and a maintainer with
  `xlings-res` access adds it later.
- **Binaries**: prefer a static (musl) build from the official source, and never compile while
  installing.
- **Your own repack or patched build** goes under your own namespace (`<you>:<name>`), hosted
  by you, with its reproducible process in the pull request.
- **Luban OS** packages take bug fixes only for now; a new feature starts as an issue.
- Change only what the task needs; leave `.github/`, `libs/` and `tools/` to maintainers.

New packages can opt into [automatic updates](docs/13-ci-mirror-and-update.md)
with a fixed declaration template. We recommend upstream GitHub repositories with
at least 50 stars; this is guidance, not a required threshold.

The format is [XPackage V2](docs/specs/xpackage-v2.md); all documentation is in
[docs/](docs/README.md).

### With an AI agent

An agent (Claude Code, Cursor, Copilot, ...) can do the whole path. It reads
[AGENTS.md](AGENTS.md), which holds the rules and points to the skills for the rest. Give it:

```
Read AGENTS.md of https://github.com/openxlings/xim-pkgindex and follow it,
with the skills it points to. Task: add the package <name> (upstream: <url>)
for every platform and architecture its official source publishes. Verify it
in an isolated XLINGS_HOME, then open a pull request that says what you ran
and what you could not.
```

For other work keep the same lead-in and change the task: *bump `<name>` to `<version>`*, or
*fix `<name>`: `<symptom>`*. One package, the smallest change.

Review its pull request as you would anyone's: the source and its tier, the sha256s,
whether the program was run, and what it says it could not.

### Not ready to write a recipe?

Open an [issue](https://github.com/openxlings/xim-pkgindex/issues/new/choose): propose a
package, report a bug, ask for a new version, request that a resource be hosted on
`xlings-res`, or discuss a Luban feature before writing it.

## Other indexes

| Repository | Namespace | For |
|---|---|---|
| [xim-pkgindex-template](https://github.com/openxlings/xim-pkgindex-template) | your own | a self-hosted, mirrored or private index |
| [xim-pkgindex-fromsource](https://github.com/openxlings/xim-pkgindex-fromsource) | `fromsource` | packages built from source |
| [xim-pkgindex-d2x](https://github.com/d2learn/xim-pkgindex-d2x) | `d2x` | d2x course projects |

## Community

[Forum](https://forum.d2learn.org/category/9/xlings) · QQ group 167535744 ·
[Issues](https://github.com/openxlings/xim-pkgindex/issues)
