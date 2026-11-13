# Disk-Image Assets and Naming

**English** | [简体中文](zh/12-disk-image-assets.md)

The asset class for "a system's official media, assembled into a bootable
image": what such a package is, how it is named, and what a recipe of the
class states. Nothing here is engine vocabulary — the engine knows none of
these names; the class serves any consumer that boots an image.

## The class

A disk-image package carries **the bytes of a system, prepared for an
emulator**: the publisher's official media, assembled into a bootable image
with a serial console, published on both resource servers with one sha for
both. It is an asset, not a mechanism: the emulator and the exit-code convention
belong to the runner that boots it, never to the package. What the image
itself answers --- its prompts, its shell's quoting, where a disk of files is
mounted --- is a fact of the image, and the package may carry it as the runner's
data: `dirun.toml` beside the image, the profile dirun boots it by
(`dirun --profile {pkg:<system>-disk-image}/dirun.toml -- {}`).

## Naming

| Rule | Statement |
|---|---|
| Package name | `<system>-disk-image` — the thing, not a mechanism, not a format |
| Asset names | carry the format (`*.qcow2`, `*.vfd`, …); the package name never does |
| Prefixes | none for generic assets; a tool whose contract is a build-system session carries that system's prefix |
| Attribution | the recipe names the publisher of the media it assembles |
| Provenance | repacked bytes are recorded, double-mirrored, sha-identical |

Why `disk-image` and not the alternatives: `disk` alone may read as
hardware, `image` alone is claimed by containers, an `iso` name lies the day
the media becomes a qcow2, and a `boot-` prefix says nothing a disk image
does not already say.

## What a recipe of the class states

```lua
-- <system>-disk-image.lua — an asset package: install only, nothing on PATH
package = {
    spec = "2",
    name = "<system>-disk-image",
    description = "The <Publisher> official <version> media, assembled into a bootable disk image with a serial console, for emulator runners",
    licenses = { "<publisher license>" },
    repo = "<publisher source>",
    type = "package",
    status = "dev",
    archs = { "x86_64", "aarch64" },
    xpm = {
        ["<os>"] = {
            source = {
                GLOBAL = "https://github.com/xlings-res/<system>-disk-image/releases/download/${version}/<system>-${version}.<arch>.qcow2",
                CN = "https://gitcode.com/xlings-res/<system>-disk-image/releases/download/${version}/<system>-${version}.<arch>.qcow2",
            },
            ["latest"] = { ref = "<version>" },
            ["<version>"] = { sha256 = { ["x86_64"] = "…", ["aarch64"] = "…" } },
        },
    },
}
-- install(): the image lands under the package root; config()/uninstall():
-- none. A consumer is a runner declaration that names the image's path.
```

## Corrective changes

| Change | Route |
|---|---|
| The image bytes must change, the version must not | same key, raised packaging revision; the updater channel enforces the raise is total |
| A format changes | the asset name carries it; the package name never does |
| The media's publisher changes | a new version entry with its own attribution |
