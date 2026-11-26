# aom

libaom, the AV1 video codec library of the Alliance for Open Media (`libaom.so.3`), `status = "stable"`. It exists so that `libavif` has the AV1 library it links against.

- Upstream: https://aomedia.googlesource.com/aom (BSD-2-Clause, with the AOM patent licence)
- Namespace: `xim`
- Platforms: `linux` (`x86_64`, `aarch64`). A library payload, no program.

## Source

- Tier: a repack of conda-forge's build (`aom-3.3.0-h27087fc_1` for linux-64, `aom-3.3.0-headf329_1` for linux-aarch64), with `.agents/tools/repack/repack.py`; each payload's `PROVENANCE.md` names the artefacts, their sha256 and the command.
- GLOBAL: `https://github.com/xlings-res/aom/releases/download/3.3.0/aom-3.3.0-linux-<arch>.tar.gz`
- CN: the same path on `https://gitcode.com/xlings-res/aom`.
- Checksums: conda-forge's published md5 equals the md5 of the downloaded archives, and the repack tool pins each source by sha256. After publishing, GitHub and GitCode were downloaded back and compared with the local tarball: identical.
- Auto-update: no. libavif 0.9.3 is built against aom 3.3.x; a newer libaom is a reviewed change.

## Linking

`libaom.so.3` names only `libc`, `libm` and `libpthread` (`readelf -d`); `deps = { "xim:glibc" }`. `selfcontain.seal` writes the RUNPATH against the dependency closure.

## What the hooks do

- install: moves the extracted `aom-3.3.0/` into place, seals the RUNPATH, rewrites the pkg-config prefix.
- config: registers a group root, declares the libraries, the `aom/` headers and the pkg-config file in the subos.
- uninstall: `xvm.remove`.
- System impact: none outside the subos.

## Verification

- Linux `x86_64`, isolated `XLINGS_HOME`: install, the payload holds `lib/libaom.so.3` with SONAME `libaom.so.3`, remove.
- Not run: `aarch64`.

## Revision log

- 2026-11-26 — added at 3.3.0, for libavif 0.9.3.
