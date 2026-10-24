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
cadence gate. A due run scans sequential batches and proposes from the same fixed plan. It never executes Lua,
rewrites published versions, repairs conflicting historical entries, builds payloads, or merges PRs.
A candidate must pass actual installation, verification and removal on its supported runners.
The central configuration is `.github/xpkgindex-update.yml`. `max_packages: 50` is the
scan batch size. A run scans up to 20 batches under a shared 500-request / 16 GiB
budget. Each package also has a 50-request / 8 GiB allowance: reaching that local
quota defers the package and advances the cursor, so it cannot starve the rest.
Global exhaustion leaves the interrupted package first in line for the next run.

Verified updates enter a persistent FIFO, independently of scan order.
`max_prs: 20` limits proposal attempts, including creates and refreshes, per run.
Remaining candidates stay queued without requiring rediscovery. A newer candidate
keeps its queue position; failures move behind other candidates with 1-hour to
24-hour backoff. Changed descriptors invalidate cached candidates, and proposal
creation rechecks source identity and resource bytes. Individual package failures
remain visible in the final result while other verified candidates can proceed.

The cursor and queue are stored on the operational `auto/update-state` branch.
The initial rollout can migrate the old Actions cache, but durable state takes
precedence thereafter. The final persistence job saves post-proposal state with
compare-and-swap; on proposal failure it preserves the latest available checkpoint.
A concurrent writer is rejected instead of overwriting newer progress. This state
branch publishes no package changes and is not automatically merged.

Candidate platform concurrency is four per workflow, and dispatch is capped at
20 new workflows per invocation. Successful or active CI for the same head,
including ordinary PR-triggered CI, is not duplicated. A refreshed head gets new
validation; obsolete runs are cancelled only after rechecking the PR head.
`autoupdate-dispatch.py --retry-failed` explicitly retries unchanged failed heads,
retaining bot/repository/base checks. Partial proposal failure still dispatches
successful proposals and remains a failure in the final gate.

A manual `xpkgindex-update.yml` run accepts `max_batches` (1..20), an optional
`package`, and `dry_run: true`. Dry runs scan real upstream resources and upload
`unified-update-plan`, but create no PRs and dispatch no candidate CI. Dry runs,
single-package scans and feature-branch scans neither restore nor save the
production cursor. Proposal creation remains restricted to the default branch.
For example, validate an integration branch before rollout:

```sh
gh workflow run xpkgindex-update.yml --ref fix/autoupdate-batching-ci -f dry_run=true -f max_batches=20
```

Candidate installers are fetched from the pinned xlings release tag, rather than
mutable `main`. Release support still matters: current xlings releases have no
macOS Intel or Windows ARM64 assets. Those native candidate jobs remain blocked;
a successful resource download or a scan does not count as native installation
validation. DPCPP's RUNPATH verification likewise remains a real upgrade gate.
These failures must be resolved before the affected package PRs merge.

Scan limits and a rotating cursor prevent request exhaustion without a multi-day failure throttle. Ordinary updates select the newest
stable release. Historical backfill is separate and is not enabled.

With the workflow's pinned tool installed:

```sh
xpkgindex-update inspect
xpkgindex-update check --package xim:foo --output plan.json
xpkgindex-update apply --plan plan.json --package xim:foo
```

`propose --plan plan.json` requires repository write credentials and creates per-package PRs.
Branches are fixed per package, for example `auto/bump-xim-nvim`. Newer verified
candidates update the same bot PR, including its title and resource evidence.
Ordinary fast-forward commits replace unpublished candidate changes while
preserving published versions. Manual edits and concurrent updates are rejected;
no force push is used. A legacy versioned bot PR is closed only after its fixed
branch replacement exists. Manual package PRs continue to block automation.
Failed PR creation after a push can be resumed. Plans are rejected when the base
commit, descriptor, tag commit or resource bytes change.

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
