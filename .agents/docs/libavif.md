# libavif

libavif, the AVIF image library (`libavif.so.13`), `status = "stable"`. It exists because Playwright's WebKit build links against `libavif.so.13` (`libavif13` of Ubuntu 22.04) and the xlings ecosystem should not take it from the host.

- Upstream: https://github.com/AOMediaCodec/libavif (BSD-2-Clause)
- Namespace: `xim`
- Platforms: `linux` (`x86_64`, `aarch64`). A library payload, no program.

## Source

- Tier: a repack of conda-forge's build (`libavif-0.9.3-h166bdaf_1` for linux-64, `libavif-0.9.3-h4e544f5_1` for linux-aarch64), with `.agents/tools/repack/repack.py`; each payload's `PROVENANCE.md` names the artefacts, their sha256 and the command.
- GLOBAL: `https://github.com/xlings-res/libavif/releases/download/0.9.3/libavif-0.9.3-linux-<arch>.tar.gz`
- CN: the same path on `https://gitcode.com/xlings-res/libavif`.
- Checksums: conda-forge's published md5 equals the md5 of the downloaded archives, and the repack tool pins each source by sha256. After publishing, GitHub and GitCode were downloaded back and compared with the local tarball: identical.
- Auto-update: no. The SONAME `libavif.so.13` belongs to 0.9.x; a newer libavif has another SONAME.

## Linking

`libavif.so.13` names `libaom.so.3` and `libc` (`readelf -d`): `deps = { "xim:glibc", "xim:aom@3.3.0" }`. `selfcontain.seal` writes the RUNPATH against that closure.

## What the hooks do

- install: moves the extracted `libavif-0.9.3/` into place, seals the RUNPATH, rewrites the pkg-config prefix.
- config: registers a group root, declares the libraries, the `avif/` headers and the pkg-config file in the subos.
- uninstall: `xvm.remove`.
- System impact: none outside the subos.

## Verification

- Linux `x86_64`, isolated `XLINGS_HOME`: install, the payload holds `lib/libavif.so.13` with SONAME `libavif.so.13` and the sealed RUNPATH reaches libaom, remove.
- Not run: `aarch64`.

## Revision log

- 2026-11-26 — added at 0.9.3, for Playwright's WebKit.
