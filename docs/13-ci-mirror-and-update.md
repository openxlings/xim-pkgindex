# CI: Mirror and Update

**English** | [简体中文](zh/13-ci-mirror-and-update.md)

Automatic version updates use the pinned upstream [xpkgindex-update](https://github.com/openxlings/xpkgindex-update).
Declare updates only through `package.extensions.autoupdate`; `xpm.source` remains runtime configuration.

```lua
extensions = {
    autoupdate = {
        upstream = "acme/foo",
        tag = "v${version}",
        latest = "advance",
        url = {
            linux = "https://github.com/acme/foo/releases/download/${tag}/foo-linux-amd64.tar.gz",
            macosx = "https://github.com/acme/foo/releases/download/${tag}/foo-darwin-arm64.tar.gz",
        },
    },
},
```

`latest = "advance"` advances all declared platform pointers after verifying the complete matrix.
`keep` appends the candidate while retaining pointers. Explicit architecture maps use canonical keys
such as `x86_64` and `aarch64`; new multi-architecture entries use V2 resource maps.
Each resource can be an HTTPS URL or a GLOBAL/CN pair. Declared mirrors must already exist and
have identical SHA256. Resource-server consumers require `verify = "sha256-sidecar"`.

The daily workflow scans once and proposes from the same fixed plan. It never executes Lua,
rewrites published versions, repairs conflicting historical entries, builds payloads, or merges PRs.
A candidate must pass actual installation, verification and removal on its supported runners.
The central configuration is `.github/xpkgindex-update.yml`; scan limits and a rotating cursor
prevent request exhaustion without a multi-day failure throttle. Ordinary updates select the newest
stable release. Historical backfill is separate and is not enabled.

With the workflow's pinned tool installed:

```sh
xpkgindex-update inspect
xpkgindex-update check --package xim:foo --output plan.json
xpkgindex-update apply --plan plan.json --package xim:foo
```

`propose --plan plan.json` requires repository write credentials and creates per-package PRs.
Existing manual package PRs block duplicate proposals. Failed PR creation after a push can be resumed.
Plans are rejected when the base commit, descriptor, tag commit or resource bytes change.

## Mirror publication

`ci = { mirror = true }` remains an independent request to mirror already declared resources.
`tools/xpkg_ci.py` provides `inspect`, `materialize`, `verify`, `ensure-repo` and `mirror`.
It has no version discovery or proposal command. Mirror publication runs separately and cannot
produce the resources a proposal is waiting for only after that same proposal is merged.

Self-built/repacked payloads need their own resource production workflow. The updater can consume
those assets once available; it does not create them. Published resource changes require the existing
reviewed revision procedure, not an updater refresh.

The old update fields and workflows have been removed. There is no legacy update fallback.
The migration PR records the complete package inventory and each eligibility decision.
