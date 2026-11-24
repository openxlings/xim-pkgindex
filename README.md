# xim-pkgindex

**English** | [简体中文](README.zh.md)

The official package index of [xlings](https://github.com/openxlings/xlings):
xpkgs for compilers, runtimes, tools and environments, on Linux, macOS and
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

The easiest way is to let an AI agent do it, to this repository's rules
([AGENTS.md](AGENTS.md)). You do not have to be the upstream's author. Give it:

```
Follow the contribution rules of https://github.com/openxlings/xim-pkgindex
(AGENTS.md; skip this if you already have them in context).
Task: <the package, version or fix, with its upstream URL>. If I did not name
a package, ask me what to add before you start.
```

It writes the xpkg (xpackage: a package's Lua file) and its test, verifies them in an
isolated `XLINGS_HOME`, opens a pull request that says what it ran and what it could not,
and stays with it until CI is green. A bug it finds in xlings or in this index is filed as
an issue titled `[xpkg-report]:`. Review its pull request as you would anyone's: the
source, the sha256s, and whether the program was run.

### By hand

1. Copy [the template](docs/specs/xpackage-template.lua) to `pkgs/<first letter>/<name>.lua`
   and add `tests/<first letter>/test_<name>.py`.
2. Verify it in an isolated `XLINGS_HOME`.
3. Open a pull request.

[Adding a package](docs/10-adding-a-package.md) is the whole path, the format is
[XPackage V2](docs/specs/xpackage-v2.md), and all documentation is in [docs/](docs/README.md).
Not ready to write an xpkg? Open an
[issue](https://github.com/openxlings/xim-pkgindex/issues/new/choose).

## Other indexes

| Repository | Namespace | For |
|---|---|---|
| [xim-pkgindex-template](https://github.com/openxlings/xim-pkgindex-template) | your own | a self-hosted, mirrored or private index |
| [xim-pkgindex-fromsource](https://github.com/openxlings/xim-pkgindex-fromsource) | `fromsource` | packages built from source |
| [xim-pkgindex-d2x](https://github.com/d2learn/xim-pkgindex-d2x) | `d2x` | d2x course projects |

## Community

[Forum](https://forum.d2learn.org/category/9/xlings) · QQ group 167535744 ·
[Issues](https://github.com/openxlings/xim-pkgindex/issues)
