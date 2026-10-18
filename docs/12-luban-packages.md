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
| an edition | `subos` | `subos` | the release date, `YYYY.M.D.N` | `luban.edition({id, variant, versions, files})` |
| a policy | `subos-policy` | `xim` | the release date | `luban.policy(json)` |
| a boot profile | `package` | `xim` | the release date | `luban.boot(json)` |
| upstream software (kernels, limine, busybox, ...) | `package` | `xim` | upstream's, `-rN` when rebuilt | the recipe |

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
7. **An edition is built for the architectures it declares.** `archs` lists only
   what was booted and tested; each package it pins exists for each of them, and
   `scripts/test-luban-editions.sh` runs on x86_64 and aarch64.
