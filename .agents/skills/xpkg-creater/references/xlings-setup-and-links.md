# xlings setup and links

## 1. Install xlings (needed before you develop a recipe)

Goal: `xlings --version` runs. Commands used by this repository's CI and workflows:

```bash
# A: quick_install (GitHub)
export XLINGS_NON_INTERACTIVE=1
curl -fsSL https://raw.githubusercontent.com/openxlings/xlings/main/tools/other/quick_install.sh | bash
```

```bash
# B: d2learn installer
export XLINGS_NON_INTERACTIVE=1
curl -fsSL https://d2learn.org/xlings-install.sh | bash
```

```bash
xlings --version
```

Install a specific version when you need to match CI: set `XLINGS_VERSION=v<version>` before the
installer (see `.github/actions/setup-xlings`).

## 2. Links

- xlings: <https://github.com/openxlings/xlings>
- the openxlings organisation: <https://github.com/openxlings>
- xlings docs: <https://xlings.d2learn.org>
- forum: <https://forum.d2learn.org>
- this index: <https://github.com/openxlings/xim-pkgindex>, browsable at <https://index.xlings.org>
- how an index reaches a machine: xlings `docs/specs/index-distribution.md` and
  `docs/specs/index-version-contract.md`; this repository's namespaces and official resources:
  `docs/00-what-this-index-is.md`, `docs/11-official-resources.md`

## 3. Notes

- If an install command changes, the xlings repository's README is the authority.
- This file keeps only the common commands; the platform matrix is in the xlings docs.
