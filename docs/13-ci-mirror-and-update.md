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
`check` with the pinned tool below and review the plan. Keep configuration in the
recipe itself; document manual-maintenance reasons in a recipe comment or the PR.
Initial package versions use normal package CI; the updater candidate checks apply
to added versions in existing recipes. CI validates current recipes and generates `coverage.json`, uploaded as an
Actions artifact. Generated audit snapshots do not belong in the PR.

`latest = "advance"` and each resource target's `required = true` are defaults.
Use `latest = "keep"` for a pinned/LTS default. A target can expand to
`{ required = true, url = { linux = { x86_64 = "..." } } }`.
Source URLs recognize GitHub releases/tags and public HTTPS Sparkle RSS appcasts ending in `.xml`; download templates can use
any public HTTPS source. Select the newest candidate satisfying every required
region across the complete platform/architecture matrix, using a true intersection.
Targets can explicitly opt into optional availability through review of the package declaration.

For official appcasts, set `source = "https://vendor.example/appcast.xml"` and use
`${version}` download templates without a GitHub repository or `tag` declaration.
The numeric Sparkle short version identifies releases; delta and channel-marked
entries are excluded. A required template must match the full enclosure URL and
length. All required platforms must be ready before latest advances. ChatGPT uses
this mode for official Linux x86_64 DEB and macOS ARM64 ZIP resources: macOS-only
releases wait for Linux instead of changing the platform matrix. Historical helper
entries remain intact; new versions use explicit URL/SHA256 tables. Independent
per-platform advancement is not supported. Vendor sources do not need GitHub stars.
Plans pin the selected appcast item's metadata digest and artifact hashes; changes
to that item invalidate the plan, while unrelated new feed entries are allowed.
Sparkle signatures are not verified by the updater; ChatGPT retains its native
macOS bundle version and codesign checks during installation.

This migration configures every reviewed target as required by default.
Existing xlings-res pairs are consumed; institutional mirrors replace them only
when their paths and artifact identity match. CN redirects to GitHub do not count
as available CN assets. A package currently using xlings-res can use newer original
upstream assets and a verified institutional mirror for future versions. Point
`source` at the actual upstream version directory as well, so an old resource
repository does not cap discovery. Repacked/split payloads need layout and install
validation before such a migration. Historical resources, manual entries and hooks stay intact.

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
CI derives the complete package inventory from recipes on each run; it does not read a committed audit snapshot.
