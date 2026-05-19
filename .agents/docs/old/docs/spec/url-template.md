# `url_template`: opt-in package version auto-update

A small contract between an xpkg description and the in-repo version
checker (`.github/scripts/version-check.py`). Adding it lets the
weekly cron find new upstream releases and (eventually) open auto-bump
PRs. Without it, the package is maintained by hand, same as today.

## The contract

A package opts in by placing a single string field
`xpm.<platform>.url_template` next to that platform's version table:

```lua
xpm = {
    linux = {
        url_template = "https://github.com/astral-sh/uv/releases/download/{version}/uv-x86_64-unknown-linux-gnu.tar.gz",

        ["latest"] = { ref = "0.11.7" },
        ["0.11.7"] = { url = "...", sha256 = "..." },
    },
    macosx = {
        url_template = "https://github.com/astral-sh/uv/releases/download/{version}/uv-aarch64-apple-darwin.tar.gz",
        ...
    },
    windows = {
        url_template = "https://github.com/astral-sh/uv/releases/download/{version}/uv-x86_64-pc-windows-msvc.zip",
        ...
    },
}
```

The placeholder `{version}` is the only token recognised today.

## Resolution rules (v1)

1. Updater scans every `pkgs/**/*.lua`.
2. Any package whose `xpm` has at least one platform with a
   `url_template` field is considered opt-in.
3. The updater treats `package.repo` as a GitHub URL and extracts
   `<owner>/<name>` from it.
4. It calls `GET https://api.github.com/repos/<owner>/<name>/releases/latest`
   and reads the `tag_name`. A leading `v` (if present) is stripped
   to produce `<version>`.
5. The current "latest" is read from `xpm.linux["latest"].ref`
   (whichever platform's `latest` is checked first; they are required
   to agree).
6. If the upstream `<version>` is not the same as the current one, the
   updater computes per-platform URLs by substituting `{version}` in
   each `url_template`, downloads each artifact, and records the
   sha256 sum.

In v1 only `source = github-release` is supported (implicitly — there
is no `source` field; the contract assumes GitHub). Packages whose
upstream is not a GitHub Release simply leave `url_template`
unset and continue to be maintained by hand.

## What is NOT in scope (v1)

- **The xlings package manager does not consume `url_template`.** It
  is a private convention between the package description and the
  in-repo updater. xpm version entries continue to record an explicit
  `url + sha256` so xlings install behaves exactly as before.
- **Any tag/version syntax beyond "leading-v stripped".** Date-based
  tags, monorepo tags, prefixed tags, and similar variants are out;
  packages that need them stay on manual maintenance for now.
- **Pre-releases.** The updater always pulls `releases/latest` (which
  excludes drafts and pre-releases by GitHub's own definition). No
  knob to opt in.
- **Multi-arch.** The current xpm shape is one platform → one URL,
  so this spec inherits the same shape. If a package needs distinct
  URLs per arch within the same platform, it stays on manual
  maintenance.

## Behaviour when fields are missing or inconsistent

- No `url_template` on any platform → package is skipped (manual mode).
- `url_template` on some platforms only → only those platforms are
  refreshed; other platforms are left alone.
- `package.repo` missing or not a GitHub URL → the package is
  skipped and a warning is emitted.
- The string `{version}` not present in the template → the
  template is rejected (lint failure) and the package is skipped.

## Phase 1 vs Phase 2

Both phases now ship in the same script (`.github/scripts/version-check.py`)
behind the `--apply` flag and as separate scheduled workflows.

**Phase 1 — `version-check.yml` (default, dry-run):** runs daily at
01:00 UTC. Reads `url_template`s, queries upstream, prints a JSON
report of "<pkg>: <current> → <available>", uploads it as a workflow
artifact, and does not modify any file or open any PR.

**Phase 2 — `version-bump.yml` (`--apply`):** runs weekly (Mondays
02:00 UTC) or on manual dispatch. For every package the dry-run flags
as `update-available`, the script:

1. Downloads the new artifact for each opted-in platform and computes
   its sha256.
2. Bumps `["latest"].ref` to the upstream version on every opted-in
   platform.
3. **Appends** a new `["<upstream>"] = { url, sha256 }` block right
   after `["latest"]` on the same platform. Existing version blocks
   are left untouched, so consumers pinned to an older version keep
   working unchanged.

The workflow then commits the modified lua to a per-package branch
named `auto/bump-<pkg>-<upstream>` and opens a PR via `gh`. If that
branch already exists on origin (i.e. an open PR is already pending
for the same target version) the package is skipped — the run is
idempotent.

Manual one-shot:

```bash
# preview only — no file changes
python3 .github/scripts/version-check.py --workspace .

# apply (modifies pkgs/**/*.lua in place)
python3 .github/scripts/version-check.py --workspace . --apply [--only <pkg>]
```

## Example: `pkgs/u/uv.lua`

`uv` is the reference implementation of this spec. See its `xpm`
block for the canonical shape; copy from there when adding
`url_template` to other packages.
