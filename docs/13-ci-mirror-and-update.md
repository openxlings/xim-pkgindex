# CI: Mirror and Update

**English** | [简体中文](zh/13-ci-mirror-and-update.md)

Automatic version updates use the pinned upstream [xpkgindex-update](https://github.com/openxlings/xpkgindex-update).
Declare updates only through `package.extensions.autoupdate`; `xpm.source` remains runtime configuration.

```lua
extensions = {
    autoupdate = {
        source = "https://github.com/acme/foo/releases",
        resources = {
            GLOBAL = "https://github.com/acme/foo/releases/download/${tag}/foo-${version}.zip",
            -- When a verified mirror exists, both targets are required by default:
            -- CN = "https://verified-mirror.example/foo/${tag}/foo-${version}.zip",
        },
    },
},
```

New packages can opt in using the template above, inside the `package` table.
We recommend automatic updates for projects whose upstream GitHub repository has
**at least 50 stars**. This is contributor guidance, not a CI or tool threshold;
stars alone do not establish resource integrity or mirror availability.
Replace the example owner, project and asset paths with verified values. If all
platforms share one artifact, use the string form; otherwise use an explicit
platform/architecture URL matrix matching the package's full supported matrix.
`${tag}` is the original release tag and `${version}` is the extracted version;
ordinary numeric and `v`-prefixed tags need no extra tag template. These templates
are independent of `xpm.source` and do not implicitly expand runtime placeholders
such as `${os}`, `${arch_alias}` or `${ext}`.

Without a verified mirror, declare only GLOBAL. Add CN only after checking the
actual project path, complete candidate assets and identical SHA256s. Targets are
required by default; set `required = false` explicitly for an optional mirror after
review. At least one target must remain required. Use `latest = "keep"` for an LTS
or pinned default. Before opening the PR, run `inspect` and a package-specific
`check` with the pinned tool below, review the plan, and update the repository's
coverage inventory with the declaration (or a reason for staying manual).

`latest = "advance"` and each resource target's `required = true` are defaults.
Use `latest = "keep"` for a pinned/LTS default. A target can expand to
`{ required = true, url = { linux = { x86_64 = "..." } } }`.
Source URLs currently recognize GitHub releases/tags; download templates can use
any public HTTPS source. Select the newest candidate satisfying every required
region across the complete platform/architecture matrix, using a true intersection.
Targets can explicitly opt into optional availability after package/inventory review.
This migration configures every reviewed target as required by default.
Existing xlings-res pairs are consumed; institutional mirrors replace them only
when their paths and artifact identity match. CN redirects to GitHub do not count
as available CN assets. Historical resources, manual entries and hooks stay intact.

The workflow scans every three days at 02:17 UTC / 11:17 JST. A lightweight daily
trigger checks UTC days from 2026-10-23 and skips scheduled scans between due dates,
including across month/year boundaries. PR checks and manual triggers bypass this
cadence gate. A due run scans once and proposes from the same fixed plan. It never executes Lua,
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
