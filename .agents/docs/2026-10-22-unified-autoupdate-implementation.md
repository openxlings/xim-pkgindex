# Unified autoupdate implementation evidence

Status: in progress; not ready for merge. Goal scope remains the complete design,
all conforming packages whose GitHub star count is greater than 50, green draft
PRs, and an automatically triggered real update with successful candidate tests.

## Current repositories

- Tool draft PR: https://github.com/openxlings/xpkgindex-update/pull/3
- Index worktree: branch `feat/unified-autoupdate`.
- Full inventory: `2026-10-22-autoupdate-package-audit.json`; 364 package files,
  152 GitHub upstream repositories queried through GitHub GraphQL. Star counts
  and recent release/tag evidence were collected on 2026-10-22. Each file has an
  enabled/manual decision and a reason for manual maintenance.

## Evidence collected

- Tool initial matrix and second matrix: all six Linux/macOS/Windows × Python
  3.11/3.13 test jobs and the composite Action passed.
- Tool local tests currently cover 81 cases, including complete architecture
  plans, keep/advance pointers, platform history divergence, plan tampering,
  failure atomicity, sidecar verification, retry budgets and runtime filtering.
- A real uv check found 0.12.7 → 0.13.5 and downloaded and hashed the three
  platform resources. The fixed plan is ready; this alone is not end-to-end proof.

## Implementation decisions

- The previous `XPKG_BOT_TOKEN` returned HTTP 401. Initially the organization
  also rejected built-in-token PR creation. The user has now explicitly enabled
  Actions PR creation; REST verification confirms `can_approve_pull_request_reviews:
  true` with default workflow permissions still read-only. The active mode is
  `XPKG_USE_GITHUB_TOKEN=true`, using the job's scoped token and explicit,
  head-verified, idempotent CI dispatch. No personal credential is copied into
  Actions secrets. Actual bot PR creation and all dispatched CI still need proof.
- A push to the explicitly named integration branch automatically scans uv and
  proposes a draft update against that branch. It uses the same fixed-plan
  updater as production, never targets main, and does not require merging the
  migration before obtaining real automation evidence.
- Duplicate-PR checks are scoped to the proposal base branch so the migration PR
  against main does not block a validation update against its integration branch.
- Existing installation CI uses the upstream tool's structural runtime diff to
  avoid re-installing unchanged payloads for declarations-only changes. Runtime
  URL/hash/hook changes remain selected; new version PRs have dedicated actual
  candidate installation checks. This is not a check bypass.
- 7zip needs explicit compact version expansion in artifact filenames. Numeric
  revision fields must parse as literal numbers. Existing package tests must
  inspect `xpm`, not confuse the new update URL matrix with runtime platform blocks.

## Remaining verification

Complete eligibility review, run the full static/isolation/index checks, create
and validate the index draft PR, run the automatically triggered uv draft update,
and inspect candidate evidence for every platform. Re-run CI at the final heads.
The tool stays a draft prerequisite; it will not be merged as part of a request
that asks for reviewable draft PRs. A released/pinned tool commit is needed before
production rollout. The design's seven daily production observations remain a
post-merge rollout gate; pre-merge branch validation does not claim to satisfy it.
