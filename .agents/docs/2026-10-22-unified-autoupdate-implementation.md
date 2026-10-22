# Unified autoupdate implementation and review evidence

Implemented from `2026-10-22-xpkgindex-update-unified-design.md`. CI results for
final commits are authoritative at the PR links below. Nothing is merged or
automatically approved.

## Review artifacts

- Upstream tool draft: https://github.com/openxlings/xpkgindex-update/pull/3
- Index migration draft: https://github.com/openxlings/xim-pkgindex/pull/1027
- Actual bot-created uv update draft: https://github.com/openxlings/xim-pkgindex/pull/1028
- Full inventory: `2026-10-22-autoupdate-package-audit.json`.
- Committed local plan and native CI evidence: `2026-10-22-autoupdate-evidence/`.

The inventory covers all 364 package files and 152 queried GitHub upstream
repositories. Star counts and release/tag evidence were collected on 2026-10-22.
106 packages meet the declaration, static metadata, baseline, version mapping and
execution environment requirements and have upstream stars > 50. The other 258
have explicit maintenance reasons, including absent/low-star upstreams, dynamic
metadata, pinned or rolling versions, divergent platform pointers, hardcoded
version hooks, and missing verified resource baselines. esbuild, nasm and glew
include x86 hosts; the available xlings executables select their build architecture
and cannot prove x86 installation. Their complete matrices remain manual until a
verified x86 environment exists. No supported architecture is silently dropped.

## Delivered behavior

- One pinned upstream updater, real adapter dispatch, format-2 fixed plans,
  complete architecture and region matrices, atomic append, keep/advance latest
  policy, immutable historical blocks and hooks.
- Only `extensions.autoupdate` enables updating. Removed the old updater scripts,
  schedules, policy and active `ci.update`/template markers. Runtime sources,
  dependencies and `ci.mirror` remain independent.
- 500 API requests, 50 packages, 4 GiB per resource, 16 GiB per run and three PRs;
  persistent fair cursor, bounded retries, explicit deferred/error/waiting states.
  Waiting assets become errors after seven days. Failed packages do not throttle
  subsequent daily retries.
- Official Go discovery uses go.dev metadata and authoritative file SHA256.
  xlings-res consumers require both mirrors and sidecars. Missing producer assets
  yield waiting reports; the updater does not upload, repack or rewrite history.
- Candidate CI verifies every added version directly from the diff, including
  all resource regions and hashes, with no release rediscovery. Native jobs install
  the checkout recipe at the exact version, verify payload and registered programs,
  run existing verification tests and uninstall it. Host architecture is checked.
- Structural runtime filtering avoids redundant installs for declaration-only
  migration changes; URL/hash/hook/version changes remain selected. The strict
  automatic-update guard does not block ordinary human revision workflows.

## Authentication verification and actual update

The old `XPKG_BOT_TOKEN` returned HTTP 401. The user then enabled “Allow GitHub
Actions to create and approve pull requests”. REST verification returned
`can_approve_pull_request_reviews: true`, while default workflow permissions remain
read-only. The implementation now uses **only the scoped built-in GITHUB_TOKEN**
for proposals and explicit, head-verified, idempotent CI dispatch. No secret needs
to be replaced, and no personal credential was copied into Actions secrets.
This is the implemented authentication choice permitted by design section 8,
replacing its initially preferred App deployment assumption.

The push-triggered run below discovered uv 0.13.5 from baseline 0.12.7, consumed
the fixed scan plan and created draft #1028 as `github-actions[bot]`:
https://github.com/openxlings/xim-pkgindex/actions/runs/39759405164

The first explicit candidate dispatch exposed a branch-name resolution defect;
it failed closed before installation. The fix passes the immutable base SHA and
also resolves explicit branch inputs through origin. The candidate branch was
updated with that fix, and native verification passed:
https://github.com/openxlings/xim-pkgindex/actions/runs/39760502342

Its committed artifacts record `verified-and-removed: true` through status and
`removed: true`, actual uv/uvx 0.13.5 output on Linux x64, macOS ARM64 and Windows
x64, recipe hashes and exact local-namespace install directories. Windows checkout
line endings explain the raw hash difference in this first evidence set; current
reports use the updater's normalized descriptor digest and include checkout SHA.
Later runs at the final PR head revalidate the final helper and resource gate.

## Validation

- Upstream local tests: 92 passed; Ruff passed; wheel/sdist build passed at the final tool commit.
- Upstream CI includes Linux/macOS/Windows × Python 3.11/3.13 and the Action job.
- Index local static/isolation: 5,390 passed, 18 skipped, three existing xpasses.
  Index registration: 216 passed. Existing `meta` marker warnings are unchanged.
- Guard confirms historical descriptors preserved. Structural runtime diff
  against main selects no runtime changes for this metadata migration.
- Live rotating discovery covered all 102 initially enabled packages across three
  budgeted runs. Initial prerelease and 2,000-item listing failures were fixed;
  the third run completed successfully. Follow-up checks confirm the former
  cc-connect/dpcpp/vim failures are resolved (vim correctly waits for producer assets). Additional live checks cover the refined
  declarations and official Go provider. Their report is committed beside native
  evidence. Waiting mirrored assets remain visible and do not produce PRs.
- Local installation/index tests use a dedicated XLINGS_HOME. The initial shared
  home test overlays were backed up and only matching test-owned registrations
  were removed; existing installed payloads were retained.

## Existing PR and branch handoff

`legacy-update-pr-audit.json` records all 13 `auto/bump-*` branches. None of the
12 legacy branches has an open automatic PR; they are retained unchanged, with
no reopening or deletion. The thirteenth is validation draft #1028. Human xlings
PR #1023 remains open and blocks duplicate default-branch proposals for that
package. The new namespace-qualified branches do not overwrite legacy names. Open PR
checks and dismissed-candidate history are both scoped to their target base; the
validation draft cannot permanently suppress the same candidate on main.

## Merge and rollout

Review and merge the upstream tool first; the migration pins its tested immutable
commit, with no floating tool ref or private fork. Then review the index migration
and its bot-generated validation draft. The validation draft targets the integration
branch, preserving main. No automatic merge or approval is introduced.

The design's seven daily production observations are a **post-merge rollout gate**.
Pre-merge branch validation proves automation and candidate installation but cannot
substitute for those observations. Disable proposals if rollout fails, retain
reports and manual updates, and do not restore the retired scanner.
