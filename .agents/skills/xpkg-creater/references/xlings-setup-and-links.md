# xlings setup and links

## 1. Install xlings (needed before you develop an xpkg)

Goal: `xlings --version` runs, at the version CI uses (the default in
`.github/actions/setup-xlings/action.yml`).

- **Missing**: ask the user to install it from the repository README (install commands there).
  Do not pipe a remote install script into a shell yourself: xlings flags an unpinned
  `curl ... | bash` as a risk (xlings#713, #714).
- **Older than CI's pin, or a bug that may be fixed**: `xlings self update`. It changes the
  user's installed client, so ask first, unless they already agreed in this conversation or in
  your memory (`references/tooling-and-reporting.md`).
- **Matching CI exactly** is the installer with `XLINGS_VERSION=v<version>` set (see the setup
  action); leave running it to the user.

```bash
xlings --version
```

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
