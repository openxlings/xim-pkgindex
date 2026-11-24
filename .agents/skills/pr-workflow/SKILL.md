---
name: pr-workflow
description: How a change reaches main in xim-pkgindex. Every change to pkgs/, tests/, libs/, docs/ or skills goes through a pull request with CI; no direct pushes. Covers branch and commit naming, the pull request description, what contributors may and may not touch, how to treat CI, and who merges. Use whenever you are about to commit or open a pull request.
---

# Pull request workflow

`main` is what xlings users pull as the package index, so a mistake lands on every user at
once. CI runs static analysis, isolation compliance, index registration and install/uninstall on
several platforms. Skipping it skips those protections. **No change goes to `main` except
through a pull request that CI has passed.** No exception for a new package, a version bump, a
fix, a test, a doc or a skill.

## Who does what

| | Contributor (anyone, incl. their agent) | Maintainer |
|---|---|---|
| Open a pull request | yes | yes |
| Edit `pkgs/<own>`, `tests/<own>`, own package note, relevant `docs/` | yes | yes |
| Edit `.github/**`, `libs/**`, `tools/**`, `index-compat.json`, `tests/lib/**`, `tests/fixtures/**`, `docs/specs/**` | no | when the task is about them |
| Declare `ci = { mirror = true }` (the default; see AGENTS.md, Source) | yes, unless they declare a well-known CN mirror | yes |
| Use `xpm.source = "xlings-res"`, or edit the mirror workflow or its tracking issue | no (ask in an issue) | yes, if they have `xlings-res` access |
| Merge | no | yes (squash) |

## Steps

### 1. Branch from the latest `main`

```bash
git fetch origin main
git checkout -b <type>/<scope> origin/main
```

`feat/<pkg>` (new package), `feat/<pkg>-<version>` (bump), `fix/<pkg>-<what>`,
`docs/<what>`, `feat/spec-<name>`. Use your fork if you do not have push access.

### 2. Do the work, minimal and verified

- Only the files the task needs. Do not reformat or migrate other xpkgs.
- Run the checks in `xpkg-creater/references/testing-and-acceptance.md` in an isolated
  `XLINGS_HOME`, on every platform you can reach.
- Do not push to find out: CI is slow and shared. Changes to widely depended-on packages
  (`glibc`, `gcc-runtime`, `libs/**`) or to `pkgs/luban/` fan out to a large reverse closure and
  to the Luban editions; keep those minimal and exact.

### 3. Commit

```bash
git add <specific files>        # never `git add .`
git commit -m "<type>(<scope>): <description>"
```

`feat(pkg): add foo 1.2.0`, `fix(slang): extract the flat archive into the payload alone`,
`docs(agents): add AGENTS.md`. One concern per pull request; split unrelated changes into
separate branches, each on the latest `main`.

### 4. Push and open the pull request

```bash
git push -u origin <branch>
gh pr create --base main --title "<commit-style title>" --body-file <description.md>
```

The description states:

- **what** the package or change is, and the platforms and architectures it covers;
- **resources**: the source and its tier, the version, the mirror (or "none"), the sha256s and how
  you checked them; for unofficial packaging the namespace and the reproducible process;
- **environment**: whether install, config or uninstall touch the user's system, shell profile,
  `PATH` or configuration;
- **what you ran**: commands, pytest, the isolated install per platform, with results;
- **what you did not run**, why, and the risk;
- when `latest` moves, the verified version it points to; the issue it closes, if any;
- **`Authorship:`**, one line: `by-ai` (an agent produced it from a task, a person directed and
  reviewed), `human-and-ai` (a person and an AI worked together; the person wrote or substantially
  reworked it) or `by-human`. The pull request template has it. An agent writes `by-ai`.
- optionally `Agent:` (the tool, e.g. Claude Code) and `Model:` (the model id): fill them when you
  know them, leave them blank otherwise, never guess.
- **nothing private**: see "Before you post" below.

Labels are hints, not checks: nothing fails without them. A workflow adds them from that line and
the changed files (`add-xpkg` for a new xpkg,
`update-xpkg` for a change to an existing one, `luban`, `bug` for a `fix` title). Do not pass
`--label`: a reporter without triage rights loses labels, and a label that does not exist can
make the command fail. If you cannot get a label, one line in the description saying what kind of
change this is (a new xpkg, a version update, a fix) is enough.

### Before you post (pull requests and issues)

Descriptions, logs and screenshots are public, and an edit keeps the old text in the history, so
clean them **before** posting. Remove or replace:

- local absolute paths and user names (`/home/<you>/...`, `/Users/<you>/...`,
  `C:\Users\<you>\...`): write `~`, `$HOME`, `$XLINGS_HOME`, `<user>` or `<tmp>`;
- host names, IP addresses, e-mail addresses;
- tokens, keys, and the contents of the user's configuration or shell profile.

`/home/runner` and `/Users/runner` of CI are not private. A quick pass over a log:

```bash
sed -e "s#$HOME#~#g" -e "s#$(id -un)#<user>#g" log.txt > log.clean.txt
```

Trim logs to the lines that show the problem. If something private was posted, tell a maintainer
at once: they can delete the edit history.

### 5. Watch CI

```bash
gh pr checks <number>
```

Expected: `plan`, `required`, the `ci_xpkg_test` jobs (static-and-isolation,
index-registration), `install` for each platform the xpkg claims, and the site check. A
skipped job is usually a path filter, not a pass.

If a job fails: read the failing job's log, find the cause (see
`xpkg-creater/references/troubleshooting.md`), fix it **locally**, push a new commit (do not
force-push a pull request that has been reviewed), and wait. Do not re-run by pushing empty
commits and do not dispatch workflows by hand.

If the failure is in CI itself (`.github/**`), or in a package you did not touch, say so in the
pull request with the log link and leave `.github/**` alone; a maintainer decides.

### 6. Merge (maintainers)

When CI is green and the review is done:

```bash
gh pr merge <number> --squash
```

Never merge with red CI. If CI is broken for a reason outside the change, record the evidence
(log links) in the pull request first.

## Never

| Action | Why |
|---|---|
| `git push origin main` | bypasses CI |
| merging with failing or unfinished CI | ships unverified changes |
| editing `.github/**`, `libs/**`, `tools/**` as a contributor | shared machinery, maintainers' review |
| one pull request mixing unrelated changes | hard to review and to revert |
| force-pushing a reviewed pull request | loses review context |
| `git add .`, committing generated files or your `XLINGS_HOME` | pollutes the diff |

## Emergencies

A hotfix is still a pull request: `git checkout -b hotfix/<what> origin/main`, fix, push, open,
wait for CI. If CI itself is the problem, a maintainer decides with the evidence in the pull
request.

## Related

- `xpkg-creater`: the procedure for the xpkg itself; its note, tests and checklist.
- `luban-packages`: the extra rules for `pkgs/luban/`.
- `AGENTS.md`: the rules every change follows.
