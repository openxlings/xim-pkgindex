# repack — upstream binaries into xlings payloads

`repack.py` turns conda-forge (`.conda`, `.tar.bz2`) and Debian (`.deb`)
artefacts into the payload shape every library recipe here installs:

```
<name>-<version>-linux-<arch>.tar.gz          top level <name>-<version>/
  lib/ include/ share/ licenses/
  PROVENANCE.md                               sources, sha256, the exact command, the audit
  RELOCATE.json                               only when a file must learn its install path
<name>-<version>-linux-<arch>.tar.gz.sha256
```

Nothing in a hook parses conda or deb. The recipe is the specification: its
header comment names the upstream artefacts and any placeholder decision, and
PROVENANCE.md inside the payload carries the command that rebuilds it.

## Use

```bash
python3 .agents/tools/repack/repack.py \
    --name gtk3 --version 3.24.43 --arch x86_64 \
    --src 'https://conda.anaconda.org/conda-forge/linux-64/gtk3-3.24.43-h0359ba6_0.conda#493d416b…' \
    --relocate 'lib/libgtk-3.so*' --relocate 'lib/gtk-3.0/*' \
    --require lib/libgtk-3.so.0 --out dist/
```

Repeat `--src` to merge several artefacts into one payload (tpm2-tss merges
four Debian packages). Debian sources must be `snapshot.debian.org` URLs: the
regular pool deletes a version as soon as its suite moves on.

Conda metadata under `info/` is pruned per input before merging, after its
provenance and licenses have been captured. Distinct inputs can therefore have
their own `info/index.json` and `info/paths.json`; conflicting actual payload
files still fail the merge.

The locked private GTK runtime uses `tools/res/gtk4_runtime.py --arch aarch64
--output dist/` (or `--arch x86_64`). It supplies `build(args, prepare=...)` to
generate MIME data before the placeholder audit and final packaging. The
resource's `BUILD-METADATA.json` records the complete builder command and tool
versions; the bare repacker command alone does not reproduce generated data.

Then publish both mirrors and verify them byte for byte:

```bash
XLINGS_GFX_README_DIR=<dir with <name>/README.md> \
XLINGS_RES_NOTES="Repacked from upstream … by .agents/tools/repack/repack.py" \
    .agents/tools/graphics/publish.sh dist/
```

`dist/RECIPE-DATA.txt` then holds the GLOBAL/CN url and sha256 per asset.

## Placeholders

conda-forge builds in a 255-byte padded prefix. Every file that still carries
one after the layout step is classified, and an unclassified one fails the run
(exit 1) with its path:

| class | flag | what happens |
|---|---|---|
| pkg-config | automatic | `prefix=/usr`, other occurrences `${prefix}`; `sysroot.relocate_pkgconfig` finishes it at install |
| payload data | `--relocate GLOB` | left in place, listed in `RELOCATE.json`; the recipe's `install()` calls `relocate.apply(dir)` (`libs/relocate.lua`) |
| host-owned | `--host GLOB` | rewritten now by the FHS mapping `<ph>/etc → /etc`, `<ph>/var → /var`, `<ph>/… → /usr/…` (NUL-padded in binaries): a daemon socket, `/etc` config, the udev hwdb |
| harmless | `--inert GLOB` | left in place; say why in the recipe |

ELF files are not modified here — `selfcontain.seal` in `install()` writes the
RUNPATH against the dependency closure the resolver chose.

## What is not shipped

`bin/`, `sbin/`, `libexec/`, static and libtool archives, cmake/GIR/aclocal/
gettext build data, man/doc/info, conda metadata. `--keep GLOB` ships one of
those; `--drop GLOB` removes more.

Exit codes follow `../README.md`: 0 produced, 1 broken (sha256 mismatch,
unclassified placeholder, conflicting files, missing `--require`), 3 could not
run (missing tool, download failure).
