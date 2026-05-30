# mcpp Ecosystem Package Follow-up

> Date: 2026-05-31 | Status: tracking note

## Context

The xlings mcpp validation path now depends on a growing set of packages that
should eventually live in stable package indexes rather than ad-hoc local
manifests.

Current xlings mcpp dependencies include:

- `mcpplibs.cmdline`
- `mcpplibs.capi.lua`
- `mcpplibs.tinyhttps`
- `mcpplibs.xpkg`
- `compat.libarchive`
- compression backends used by libarchive

## Why This Belongs Here

`xim-pkgindex` remains the xlings package-index surface. Even when a dependency
is consumed through mcpp's own index, xlings release/bootstrap work must keep a
clear record of which packages are official, which are compatibility packages,
and which still rely on local or transitional metadata.

## Tasks

- [ ] Keep xlings package-index entries aligned with the mcpp validation story.
- [ ] Avoid duplicating packages that are already stable in the mcpp official
      index unless xlings needs different runtime semantics.
- [ ] Track whether `compat.libarchive` and its compression backends should
      stay in mcpp's index, move to an xlings-owned compatibility namespace, or
      be mirrored in both places.
- [ ] After the mcpp fix lands, update xlings package-index documentation if
      a released mcpp version becomes part of the bootstrap path.

## Current Decision

Do not add new package entries in this repo as part of the mcpp quiet-refresh
fix. The immediate fix belongs in mcpp; this note keeps the package-index
ecosystem follow-up visible.
