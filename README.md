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

1. Copy [the template](docs/specs/xpackage-template.lua) to `pkgs/<first letter>/<name>.lua`.
2. Add `tests/<first letter>/test_<name>.py`.
3. Open a pull request — [Adding a package](docs/10-adding-a-package.md) is the whole path.

The format is [XPackage V2](docs/specs/xpackage-v2.md); all documentation is in
[docs/](docs/README.md).

## Other indexes

| Repository | Namespace | For |
|---|---|---|
| [xim-pkgindex-template](https://github.com/openxlings/xim-pkgindex-template) | your own | a self-hosted, mirrored or private index |
| [xim-pkgindex-fromsource](https://github.com/openxlings/xim-pkgindex-fromsource) | `fromsource` | packages built from source |
| [xim-pkgindex-d2x](https://github.com/d2learn/xim-pkgindex-d2x) | `d2x` | d2x course projects |

## Community

[Forum](https://forum.d2learn.org/category/9/xlings) · QQ group 167535744 ·
[Issues](https://github.com/openxlings/xim-pkgindex/issues)
