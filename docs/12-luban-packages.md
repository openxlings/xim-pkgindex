# Luban Packages

**English** | [简体中文](zh/12-luban-packages.md)

Luban's editions, policies and boot profiles are ordinary recipes in this index:
the xpkg format is unchanged, the data is in the recipe, and only
`libs/luban.lua` writes files. What Luban is, and how editions are used, is in
[xlings's Luban docs](https://github.com/openxlings/xlings/tree/main/docs/luban).

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
