# Maintainers only: `xlings-res` and mirror publishing

Contributors do **not** do anything in this file (AGENTS.md). It records the gates for a
maintainer who adds a resource to the official servers, so the same rules are applied the same
way. Public documentation: `docs/11-official-resources.md` and `docs/13-ci-mirror-and-update.md`.

Contributors who need a resource hosted open an issue with: the package, why it is generally
useful, the source asset and its hash, and the process that produced it if it is a repack.

## Who may write to `xlings-res`

Only maintainers with write access to the `xlings-res` organisation (GitHub) and the GitCode
group. A maintainer may publish a CN (GitCode) resource directly, in the same pull request that
adds the version, instead of leaving CN out; a contributor without access skips CN and the
maintainer supplements it later. The gates below apply to either route.

## When `xlings-res` is used

- A generally useful package whose official source cannot be used directly (needs a layout fix,
  hard-link removal, a musl or static build the upstream does not publish, a split payload).
- Resources built by the resource factory (`tools/res/`, `res-build.yml`).
- The CN side of a package whose upstream has no well-known institutional mirror.
- Later, as a fallback for an upstream that disappears or rate-limits.

It is not the default source of a new package: the xpkg points at the upstream
(`AGENTS.md`, "Source order").

## What `xpm.source = "xlings-res"` promises

`xpm.source = "xlings-res"` (historically `"XLINGS_RES"`) resolves to one organisation on two
hosts with byte-identical content: GLOBAL `https://github.com/xlings-res`, CN
`https://gitcode.com/xlings-res`. A resource is `xlings-res/<package>`, a release per version, assets
named `<name>-<version>-<os>-<arch>.<ext>` with a `.sha256` sidecar. This is the resource server
for package binaries; the index's own artefacts (`xlings-res/xim-index`) are a different kind.

## Gates before an xpkg names a version on `xlings-res`

1. A release with the same tag exists on both hosts, with every asset for every platform and
   architecture the version declares, with the same names.
2. Both come from one authoritative upstream release or one build. After publishing, download from
   GitHub RES, GitCode RES and the authoritative upstream and compare sha256: the bytes are
   identical. (GitCode: verify with GET, not HEAD; it answers HEAD with 401.)
3. Every archive has a same-named `.sha256` sidecar (`sha256sum` format), and the xpkg's
   per-architecture hashes equal the sidecars.
4. `xpkgindex-update apply --plan plan.json` fails closed, changing nothing, when a platform,
   architecture, asset or sidecar is missing.
5. `latest` moves only to a verified version, never backwards when an older version is added;
   check that `latest` on both hosts still points at the right one.
6. A published resource never changes. A rebuild is a new tag and asset name `<version>-r<N>`,
   with the entry's `revision` set to N. The old asset stays.
7. The pull request states the GitHub and GitCode release/tag and the sha256 results.

If either side lacks an asset or disagrees, the version does not go to `xlings-res`: complete
the mirrors first, then change the index.

## Publishing the CN side

With the maintainers' GitCode CLI (`gtc`, see `tools/gtc`):

```bash
gtc release create xlings-res/<pkg> --tag <version> --name "<pkg> <version>"
gtc release upload xlings-res/<pkg> --tag <version> <files...>
```

Upload the upstream bytes unchanged plus the `<file>.sha256` sidecar, then download each file back
from `https://gitcode.com/xlings-res/<pkg>/releases/download/<version>/<file>` and `cmp` it with the
upstream. The tag is the bare version (no `v`). Auto-update xpkgs require GLOBAL and CN to hold
identical bytes.

## Auto-update declarations (reviewed by maintainers)

`extensions.autoupdate` is the only declaration; the pinned `xpkgindex-update` scans and proposes.

- GLOBAL is the upstream; add CN only for a verified institutional mirror (path, complete assets,
  identical sha256). Each target is `required = true` by default; `required = false` is a reviewed
  choice, and at least one target stays required. `latest = "keep"` for an LTS/pinned default.
- A package that uses `xlings-res` may move to the real upstream and an institutional mirror for
  later versions; keep every old version block. Repacked or split payloads need their layout and
  hooks validated before such a move.
- Central policy: `.github/xpkgindex-update.yml`. A recommendation (not a gate): upstream GitHub
  repositories with at least 50 stars.
- The updater never executes Lua, rewrites published versions, builds payloads or merges. A
  candidate still needs real install, verification and removal on its runners.
