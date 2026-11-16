# openkal Programs

**English** | [简体中文](zh/14-openkal-programs.md)

A program built for an ok-image target (`x86_64-openkal`, `aarch64-openkal`) is
one image per architecture, and the same image runs on Linux, macOS and Windows
through a loader, `okrun`. Its recipe states that once: one asset for every
system. The recipes `pkgs/o/okrun.lua` (the loader) and `pkgs/m/mcpp-ide.lua`
(a program) are the reference.

## What the asset is

`mcpp pack --target <arch>-openkal` over openkal-platform writes a **universal
package** ([mcpp SPEC-014](https://github.com/mcpp-community/mcpp/blob/main/docs/specs/packaging.md)):
one archive with one top-level directory holding

| Path | What |
|---|---|
| `lib/<arch>/<name>.oke` | the image of each architecture |
| `bin/<name>`, `bin/<name>.cmd` | launchers: they pick this machine's architecture and start `okrun` |
| `libexec/okrun/<os>-<arch>/` | the loader of each system, only in a `--mode self-contained` package |
| `mcpp-package.json` | the package's description: legs, systems, how it starts, every file with its sha256 |

The archive is the same file for every system, so its sha256 is one value.

## The recipe

- `archs` names the architectures whose images the package holds.
- `linux`, `macosx` and `windows` each name the same URL and the same sha256.
- A package that does not carry its loader depends on it in each table:
  `deps = { "xim:okrun" }`. A `--mode self-contained` package carries the loader
  of each system it names and depends on nothing.
- `install()` moves the archive's one top-level directory to the install
  directory; `config()` registers the launcher with xvm: `bindir` is `bin/`,
  and on Windows the command is the `.cmd` launcher (`alias = "<name>.cmd"`).

`mcpp emit xpkg --package <archive> --url <release prefix>` writes these parts
from `mcpp-package.json`; the recipe adds what an index states and a package
does not (authors, licenses, the CN mirror, the version history).

## The loader

`okrun` is the loader as a program of each system and architecture, built
by openkal-image's `release binaries` workflow over openkal-platform's hosted
arrangement (static on Linux, no SDK on macOS, no MSVC run-time on Windows);
`okld`, the linker and bundler of ok images, is built and described the same
way. Each recipe is per system, one asset and one sha256 per architecture of
the rows the workflow builds (`linux-x86_64`, `linux-aarch64`,
`macos-aarch64`, `windows-x86_64`), and is written by
`mcpp emit xpkg --package` from the four archives.

A program whose package is not universal (one archive per system, such as
`mcppls`, whose payload carries a system's clangd) keeps a recipe per system.

## Resources

GLOBAL is the upstream release; CN is the same bytes on
`gitcode.com/xlings-res/<package>` (uploaded with `gtc release upload` and
verified by download), so one sha256 serves both regions.
