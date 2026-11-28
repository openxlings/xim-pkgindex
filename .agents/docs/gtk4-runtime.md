# gtk4-runtime

Private GTK 4.24.2 runtime closure for Linux GUI applications. This is a candidate
runtime package, not a replacement for the individual GTK/X11 development packages;
it registers no public command. Maintainer-owned infrastructure is pending #1521.

- Upstream: https://www.gtk.org / https://gitlab.gnome.org/GNOME/gtk
- Licenses: the recipe lists the component licenses; each archive preserves `licenses/`.
- Namespace: `xim` (proposed); the current archives are unofficial contributor repacks.
- Platforms: Linux x86_64 and aarch64 only; no macOS or Windows payload is declared.

## Source

- Tier: repacked conda-forge binary releases, with the data-only MIME input documented
  in `tools/res/gtk4-runtime-4.24.2.json`; not official upstream GTK binaries.
- GLOBAL: `https://github.com/FarnaHerry/xim-pkgindex/releases/download/gtk4-runtime-4.24.2/gtk4-runtime-4.24.2-linux-${arch}.tar.gz`.
- CN: none; these assets are not published as `xlings-res`.
- Checksums: archive SHA256s are pinned in the recipe; component URLs and SHA256s are
  pinned in the lock. This follow-up did not independently re-download both runtimes.
- Auto-update: no; rebuild and review the complete two-architecture closure together.

## Linking

Dynamic ELF closure: GTK, Pango, Cairo, GIO/TLS, image loaders and their bundled
providers remain private to the payload. `xim:glibc@>=2.38` supplies the declared
external C runtime; `xim:patchelf@>=0.19.3` is a build dependency for relocation.
The recipe exports `lib/` to runtime consumers, not public xvm library names.

## What the hooks do

- install: unpack the archive, require its file manifest, apply `RELOCATE.json`,
  and seal the private ELF closure with the shared `selfcontain` helper.
- config: compile schemas and GIO/image-loader/font caches after relocation, require
  the generated files, then register one xvm group. Cache environment overrides
  apply only to child commands, never to the user's shell or shared configuration.
- uninstall: remove only this namespace/version's group; xlings removes its payload.
- System impact: no host package-manager calls, profile edits or system-library replacement.

## Provenance

The lock records exact component URLs/hashes. The builder and repacker preserve
`BUILD-METADATA.json`, `PROVENANCE.md`, `RELOCATE.json` and component licenses.
From the repository root, rebuild each architecture with
`python3 tools/res/gtk4_runtime.py --arch x86_64 --output dist/` and
`python3 tools/res/gtk4_runtime.py --arch aarch64 --output dist/`.
Build metadata records the complete invocation and tool versions. Maintainers must
review these infrastructure pieces through #1521 before a package-only PR can land.

## Verification

Focused checks: `python3 -m pytest tests/g/test_gtk4_runtime.py -m 'static or isolation' -q`.
Native acceptance additionally requires an installed runtime, explicit glibc root,
compiler/headers and a display; it checks rendering, fonts, images, GIO TLS and a
real dbpp consumer. Static tests are not evidence of native ARM64 acceptance.
The consumer fixture uses its own local recipe and the real upstream dbpp 0.4.2
ARM64 asset `dbpp-aarch64.tar.gz`; it does not require #1505 to declare ARM64.
Both native CI legs and maintainer infrastructure triage remain merge prerequisites.

## Revision log

- 2026-11-28 — document the candidate 4.24.2 closure and maintainer handoff; correct
  the ARM64 consumer URL/SHA256 and remove retries around the permanently wrong URL.
