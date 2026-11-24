---
name: xlings-res-maintainer
description: Maintainer procedure for the xlings-res mirror of xim-pkgindex. Use when a mirror run failed, when the tracking issue (label mirror-failed) lists packages, when a package must be mirrored by hand or retried, when a mirror is refused, or when a CN leg must be added after publication. Not for contributors: they only declare ci = { mirror = true } in their pull request.
---

# xlings-res mirror: maintainer procedure

The mirror copies a package's declared GLOBAL resources to the `xlings-res` organisation
(GitHub and GitCode). Read `docs/13-ci-mirror-and-update.md` for the policy; this file is
what you do when it needs you.

## How it runs

- `.github/workflows/xpkg-mirror.yml` runs after a successful CI on `main`. It plans the
  packages changed since the newest successful run plus the packages still failing, publishes
  them in one job (two at a time), and records the result.
- A failure does not fail the run. It is written to **one** tracking issue: label `mirror-failed`,
  title "xlings-res mirror: packages that did not publish". The body holds a state block; the
  workflow reads it on every run. The issue closes itself when nothing is pending.
- `.github/workflows/mirror-precheck.yml` materializes and verifies, on a pull request, every
  changed package that declares `ci = { mirror = true }`. It publishes nothing.
- Merging a pull request is the approval. The `xlings-res-publish` environment has no reviewer
  gate.

## Look first

```bash
gh issue list --label mirror-failed --state all --limit 3 --json number,state,title,updatedAt
gh run list --workflow xpkg-mirror.yml --limit 5
```

Read the tracking issue's table: package, step (`materialize`, `verify`, `mirror`, `internal`,
`unknown`) and the last error line. Read the run's log only for the package you act on.

## Triage by step

| Step | Usual cause | What to do |
|---|---|---|
| `materialize` | upstream URL or template wrong, or a package the tool cannot read (e.g. `URL/template missing`) | Fix the xpkg in a pull request; the package is retried after the merge |
| `verify` | sha256 mismatch, a missing architecture, or a download that changed | Compare the upstream bytes yourself (`sha256sum`) before changing any hash |
| `mirror` | `GitCode asset upload failed ... timed out` | Transient. The next run retries it; nothing to do |
| `mirror` | `immutable GitHub release ... exists with different assets` | Stop. An asset of that tag is not what the manifest says. Decide with the author; never overwrite |
| `mirror` | token or permission error | Ask the owner of the secret; never print a token |
| `internal` / `unknown` | the batch crashed or did not finish | Re-run the workflow for that package (below) |

A package that keeps failing is attempted on every run. Fix it, or remove `ci = { mirror = true }`
in a pull request, so it stops costing runner time.

## Retry one package

Run it on `main` with `package` set (needs a maintainer account with write access):

```bash
gh workflow run xpkg-mirror.yml --ref main -f package=<name>
```

The package must still declare `ci = { mirror = true }`. A dispatched run does not move the
baseline, so it cannot skip another package's change.

## Check a package before it reaches main

```bash
TMP_WORK="$(mktemp -d)"
python3 tools/xpkg_ci.py --workspace . materialize <name> --output "$TMP_WORK/<name>"
python3 tools/xpkg_ci.py --workspace . verify "$TMP_WORK/<name>/manifest.json"
python3 tools/xpkg_ci.py --workspace . mirror "$TMP_WORK/<name>/manifest.json"   # dry run: prints the gh and gtc commands
```

Without `--execute` nothing is published. Do not add `--execute` locally: publication belongs to the workflow,
which runs with the `xlings-res-publish` environment.

## Keep one issue

There must be one open tracking issue at a time. If you find two, keep the one with the most
recent state block, close the other with a comment that links to it. Never create an issue by hand
for a package failure; the workflow owns it.

## Add the CN leg after publication

A published mirror does not change the package. When both GitHub and GitCode assets are verified:

1. Edit the xpkg in a pull request: add `CN` beside `GLOBAL` in the `url` map, pointing at the
   GitCode release asset. Keep the sha256 unchanged.
2. Follow the published-entry rule: a changed resource needs a new `revision`.
3. Run `tests/test_docs.py` and the package's own tests; the mirror does not run them for you.

## Never

- Edit the state block by hand, or delete the tracking issue to clear it. Fix the cause and re-run.
- Publish from a laptop, or add `--execute` to a local command.
- Put a token, a local path or a user name in an issue, a comment or a log you paste.
- Overwrite an immutable release. If its assets are wrong, the fix is a new tag or revision.
