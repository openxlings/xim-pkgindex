# Luban Packages

**English** | [简体中文](zh/12-luban-packages.md)

Luban's editions, policies and boot profiles are ordinary recipes in this index:
the xpkg format is unchanged, the data is in the recipe, and only
`libs/luban.lua` writes files. What Luban is, and how editions are used, is in
[xlings's Luban docs](https://github.com/openxlings/xlings/tree/main/docs/luban).

## The `luban:` namespace

What is official and made for Luban is published in the `luban` namespace:
editions (`luban:core`, `luban:desktop`), desktop components (`luban:labwc`,
`luban:lxqt`, `luban:kde`, `luban:xdesk`), the Qt runtime, the tool sets, and
the bundles built for them. General software stays in `xim` (fish, mesa, a
kernel), and so do the programs a user runs on a host (`xim:luban`,
`xim:luban-os`). Anyone may depend on a `luban:` package -- any SubOS, any
system: the namespace says who publishes it, not who may use it.

A short name in luban is a name in this namespace: `--edition desktop` is
`luban:desktop`, `--desktop kde` is `luban:kde`. Adding an official desktop is
adding its recipe here; nothing in luban or the Luban OS app lists them.

`xim`, `luban`, `subos` and `config` are **reserved**: `index-compat.json`
declares them (`namespaces.reserved`), and a client that knows the field takes
packages in them from this index only -- a recipe elsewhere that says
`namespace = "luban"` is refused, naming its index and file. The rule is the
client's and generic: any index may reserve its own namespaces the same way.

The published `subos:luban-*` editions and `xim:labwc-desktop` are frozen:
kept, resolved as before (instances and older editions name them), never
updated. Their successors declare `replaces = "<old name>"`, which a client
honours from the same index only.

## The kinds

| Kind | `type` | Namespace | Version | Written by |
|---|---|---|---|---|
| an edition | `subos` | `luban` (frozen ones: `subos`) | the release date, `YYYY.M.D.N` | `luban.edition({id, variant, versions, files})` |
| a desktop component (`luban:labwc`, `luban:foot`) | `package` | `luban` | upstream's, `-rN` for this index's build | the recipe; `luban_component` places it |
| a composite (`luban:compositor`, `luban:xdesk`) or a tool set (`luban:tools-dev`) | `package` | `luban` | the release date, or what it composes | its deps, its session and configuration |
| a policy | `subos-policy` | `xim` | the release date | `luban.policy(json)` |
| a boot profile | `package` | `xim` | the release date | `luban.boot(json)` |
| upstream software (kernels, limine, busybox, ...) | `package` | `xim` | upstream's, `-rN` when rebuilt | the recipe |

Each component says, in a comment, the form it takes and why (a bundle, a
runtime, a composite of atomic packages): the name and its conventions (a
session file, `X-Luban-Shell`, its checks, the default terminal) stay when the
form changes.

## An edition's manifest

A `luban:` edition writes its manifest from a table (`luban.manifest`): its
keys in a fixed order, `replaces` the frozen edition it succeeds, and a `luban`
object -- what a reader that knows Luban is told about it:

| Key | Meaning |
|---|---|
| `luban.settings` | what it presets (`mode`, `enter`, `desktop`, `login_shell`): below what the person sets; also written to the root's `usr/share/luban/settings.json`, which an older luban reads |
| `luban.os` | how it names itself (`name`, `version`): a distribution based on Luban says its own name |
| `luban.requires` | what it needs of whoever reads or runs it (opencaps names, `root-layout>=2`); a reader that lacks one says so before making it |

```lua
manifest = {
    subos_kind = "rootfs", min_client = "2026.10.18.1",
    from = "luban:core@2026.10.18.1", replaces = "subos:luban-desktop",
    abi = { kernel = "linux", libc = "gnu" },
    packages = { "luban:xdesk@2026.10.18.1", "luban:foot@1.27.0-r1" },
    luban = { settings = { mode = "machine", enter = "desktop", desktop = "xdesk-classic" } },
    workspace = {},
}
```

## What Luban shows of a package: `extensions.luban`

A recipe tells Luban how to present it in its package-level `extensions`
(the xpackage field, [`specs/xpackage-v2.md`](specs/xpackage-v2.md)): xlings
hands it on untouched; the Luban OS quick start and `luban search` read it
(xlings design 2026-10-19 §5.4, §20). Every key is optional; without one
Luban uses its own default.

| Key | Type | Meaning | Without it |
|---|---|---|---|
| `tier` | integer 1-4 | a desktop's weight: T1 Compositor (windows only), T2 labwc, T3 LXQt, T4 KDE Plasma; xdesk is off the axis | "not rated", listed last |
| `gpu` | `"better"` / `"needed"` | what it expects of the host's GPU | no note |
| `title` | `{ en = "...", zh = "..." }` | the card's name; technical names stay English in every language | the package name |
| `summary` | `{ en = "...", zh = "..." }` | the card's one line | `description` |
| `size` | integer (bytes) | what making it downloads | not shown |
| `highlights` | list of program names | a few programs the card names | the app's own text |

Values out of range read as absent (`luban search --desktops -v` says what was
ignored). `extensions` changes nothing installed: no `revision` is raised.

```lua
extensions = {
    luban = {
        tier = 3,
        title = { en = "LXQt", zh = "LXQt" },
        summary = { en = "Traditional: a panel, a desktop, a file manager and settings",
                    zh = "传统桌面：面板、桌面、文件管理器和设置" },
    },
},
```

## The rules

1. **A published version's output never changes.**
   `tests/fixtures/luban-published.json` records the sha256 and mode of every file
   each published version writes, and `tests/test_luban_published.py` compares.
   When a version merges to `main`, add it:
   `LUBAN_PUBLISHED_ADD=pkgs/l/<recipe>.lua@<version> pytest -k add_published`.
   The fixture only grows.
2. **An edition using a field newer clients read sets `min_client`.** A new field
   is designed so an older client ignoring it is still safe (an ignored
   `boot.profile` falls back to `boot.kernel`).
3. **Every edition `from`s an official layer** (except nano) and states its
   `abi`.
4. **A new edition names only `luban-init`**; `xlings-init` stays for published
   versions.
5. **Tools that move fast are not pinned** (an agent CLI): `subos new` installs
   the newest and records it in the instance, and `luban upgrade` moves it. Every
   other package is pinned exactly.
6. **A preview edition** (`status = "preview"`) has no short name in luban.
   A desktop is not an edition: an edition presets one, and `luban new --desktop`
   chooses another (`luban-desktop` in a package's `categories` offers it).
7. **An edition is built for the architectures it declares.** `archs` lists only
   what was booted and tested; each package it pins exists for each of them, and
   `scripts/test-luban-editions.sh` runs on x86_64 and aarch64.
8. **A layer above wins a program's name.** A package of an edition replaces a
   program of the same name from the edition it builds on: core's procps-ng `ps`
   is the system's `ps`, not tiny's BusyBox applet. Its self-check says so
   (`ps -C` works only with procps).
9. **What an architecture cannot have, its edition leaves out, and says so.**
   Core 2026.10.19.1 is tiny plus bash, fish, vim, nvim, git, gh, mcpp, ninja,
   coreutils, gcc, binutils, make, openssl, xz, zlib, yazi and procps-ng, and on
   x86_64 also cmake and xmake: upstream ships no linux aarch64 xmake, and
   cmake's GUI libraries are x86_64 only here.
10. **Every official desktop brings the pointer theme** (`luban:cursors`,
    through `luban:labwc` or `luban:xdesk`): any base with any official desktop
    has a default cursor theme (`tests/l/test_luban_desktop_extensions.py`).
