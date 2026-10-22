# Unified autoupdate implementation and review

> 2026-10-23 更新：本文旧的 upstream/url 和 GitHub-only 描述已被 [source/resources 当前设计](2026-10-23-xpkgindex-update-multi-mode-design.md) 取代；以当前设计、覆盖审计和 PR 最新提交为准。

Implements `2026-10-22-xpkgindex-update-unified-design.md` with the user's latest
rollout constraints: **every three days, GitHub only, exclude packages using CN**.
Final-head CI results are authoritative at these draft PRs:

- Upstream tool: https://github.com/openxlings/xpkgindex-update/pull/3
- Index migration: https://github.com/openxlings/xim-pkgindex/pull/1027
- Actual Actions-created uv validation update: https://github.com/openxlings/xim-pkgindex/pull/1028
- Package inventory: generated from current recipes by the CI audit command as `coverage.json`; raw migration snapshots remain local.

## Scope and schedule

The inventory covers all 364 package files and 152 queried GitHub upstream
repositories. Star counts were collected on 2026-10-22. **24 packages** meet the
static metadata, baseline, version mapping and native execution requirements,
have GitHub stars > 50, and satisfy the GitHub-only policy. The other **340** have
explicit maintenance reasons.

- A daily `17 2 * * *` trigger evaluates a lightweight UTC cadence gate. Actual
  scan/propose runs every three days from 2026-10-23 (23, 26, 29 October,
  1 November, etc.), at 02:17 UTC / 11:17 JST. Other scheduled runs skip
  scan/propose/candidate jobs. This remains three days across month/year boundaries.
  PR checks and manual triggers bypass the cadence gate.
- Candidate resources must use HTTPS `github.com` URLs. GitHub's normal asset
  redirects are handled by the upstream downloader.
- A CN resource anywhere in the recipe's runtime declarations excludes the
  entire package. `XLINGS_RES` and `source = "xlings-res"` also exclude it because
  they imply multiple mirrors. External registries and vendor download providers
  are outside this rollout. Existing historical resources remain unchanged.
- The policy is enforced in `tools/autoupdate_policy.py` and the declaration audit,
  with tests for direct and implicit CN sources, external URLs and GitHub archives.
- The temporary integration-branch push proposal trigger has been removed.
  Production proposals run only on the default branch's scheduled/manual workflow.
  PR CI and explicit read-only candidate validation remain available.

## Delivered behavior

One pinned upstream tool implements real adapter dispatch, fixed format-2 plans,
complete architecture matrices, atomic append, keep/advance latest policy and
immutable historical blocks/hooks. The sole update declaration is
`extensions.autoupdate`; the old scripts, schedules, update policy and active
`ci.update`/template markers are removed. Runtime sources, dependencies and
independent `ci.mirror` publication are preserved.

The workflow scans once and proposes from that fixed plan. Limits are 500 API
requests, 50 packages, 4 GiB/resource, 16 GiB/run and three PRs. A persistent fair
cursor, bounded retries and explicit error/deferred/waiting states keep results
observable. Waiting assets become errors after seven days; failed packages are
retried at the next three-day scheduled run. The removed Go vendor provider is not part of
this GitHub-only implementation.

Candidate CI verifies only versions added by the diff, including all resource
hashes, without discovering future releases. Native jobs install the checkout's
exact candidate, verify payload and registered programs, run package verification
tests and uninstall it. Reports record architecture, checkout SHA, normalized
recipe digest, version output and removal. Structural runtime comparison avoids
redundant installs for declaration-only changes, while retaining actual runtime
changes in existing installation checks.

## Permissions and actual automation

The user enabled Actions PR creation. REST verification confirmed
`can_approve_pull_request_reviews: true`, with default workflow permissions still
read-only. Proposals use only the scoped built-in `GITHUB_TOKEN` with explicit,
head-verified, idempotent CI dispatch. The failed legacy secret is not used.

The controlled integration push below automatically discovered uv 0.13.5 from
0.12.7, consumed the fixed plan and created draft #1028 as `github-actions[bot]`:
https://github.com/openxlings/xim-pkgindex/actions/runs/39759405164

Subsequent exact-head validation passed the complete resource gate and actual
installation/version verification/removal on Linux x64, macOS ARM64 and Windows
x64. Downloadable Actions artifacts are available here:
https://github.com/openxlings/xim-pkgindex/actions/runs/39763672914

That pre-merge proof does not depend on retaining a push-based update schedule.
Working evidence files remain local; the evidence directory is excluded from the
PR. The PR bodies link final-head verification and downloadable Actions artifacts.

## Validation and handoff

- Upstream local tests: 90 passed; Ruff and distribution build verified.
- CI includes Linux/macOS/Windows × Python 3.11/3.13 and the Action job.
- Index static/isolation, isolated index registration, complete declaration audit,
  workflow YAML validation, runtime diff and historical guard are rechecked after
  the scope change; final CI is linked above.
- The guard preserves all 364 historical descriptors; the migration selects no
  runtime payload changes.
- All 13 automatic update branches were audited. No legacy automatic PR remains
  open; branches are retained unchanged. Human xlings PR #1023 is retained.
  Open PR checks and dismissed-candidate history are scoped to their target base.

Review and merge the upstream tool first, then pin its accepted immutable commit
for the index rollout. All delivered PRs remain drafts. Seven production schedule
observations remain a post-merge rollout gate, now measured on the three-day cadence.
No automatic merge, old-scanner restoration or historical version deletion is used.
