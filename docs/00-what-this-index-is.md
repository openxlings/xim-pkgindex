# What This Index Is

**English** | [简体中文](zh/00-what-this-index-is.md)

xim-pkgindex is the official package index of [xlings](https://github.com/openxlings/xlings):
the recipes `xlings install` reads, the resources they name, and the tests that
keep them installable. Browse it at [index.xlings.org](https://index.xlings.org).

## What is in it

| Path | What |
|---|---|
| `pkgs/<letter>/<name>.lua` | one recipe per package (an xpkg: metadata, a platform–version resource matrix, hooks) |
| `pkgs/luban/<name>.lua` | the packages that exist only for Luban: its editions, boot profiles, `luban-os`, `xdesk`, `labwc-desktop`, `luban-fonts` |
| `libs/` | Lua modules recipes share (`sysroot`, `relocate`, `graphics`, `luban`, ...) |
| `tests/` | pytest suites mirroring `pkgs/`, plus repository-wide checks |
| `tools/res/` | the build factory for resources this index builds itself |
| `xim-indexrepos.lua` | the default sub-indexes |
| `index-compat.json` | the oldest client this index needs |
| `.xpkgindex.json` | the site's configuration |

A recipe is data first: the resources it installs and their sha256s, the
programs it provides, its dependencies. Hooks do only what data cannot. The
format is [XPackage V2](specs/xpackage-v2.md).

## Namespaces

Every index is a namespace. This one is `xim`, and it is always present: a user's
own `index_repos` are added to it, never instead of it.

| Kind | Example | Comes from |
|---|---|---|
| the official index | `xim:gcc` | this repository |
| a default sub-index | `awesome:...`, `scode:...`, `d2x:...` | `xim-indexrepos.lua` here |
| a third-party or private index | `ros2:...` | the user's `index_repos` |

A bare name (`gcc`) is looked up in the main indexes first; only when none has it
are sub-indexes searched. An explicit namespace (`xim:gcc`) searches exactly that
index. Two main indexes answering the same bare name is an error asking for the
namespace.

A dependency a recipe here declares without a namespace means **this index's**
package of that name.

## How it reaches a machine

Users do not clone this repository. Each change to `main` is published as a
versioned artefact (a tarball and a pointer with its sha256, on GitHub and
GitCode), and `xlings update` fetches the newest snapshot its version may use.
How that works is xlings's
[index distribution](https://github.com/openxlings/xlings/blob/main/docs/specs/index-distribution.md);
which snapshot a client may use is the
[index version contract](https://github.com/openxlings/xlings/blob/main/docs/specs/index-version-contract.md).
This index declares its floor in `index-compat.json`.

## Other indexes

| Repository | Namespace | For |
|---|---|---|
| [xim-pkgindex-template](https://github.com/openxlings/xim-pkgindex-template) | your own | a self-hosted, mirrored or private index |
| [xim-pkgindex-fromsource](https://github.com/openxlings/xim-pkgindex-fromsource) | `fromsource` | packages built from source |
| [xim-pkgindex-d2x](https://github.com/d2learn/xim-pkgindex-d2x) | `d2x` | d2x course projects |
