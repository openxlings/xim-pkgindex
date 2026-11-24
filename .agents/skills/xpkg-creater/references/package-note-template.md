# Package note: `.agents/docs/<name>.md`

Every package gets one short note **when it is first added**. It is the place a later
maintainer (or agent) learns why the xpkg is the way it is, without reading the git history.

- File name is the package name: `.agents/docs/<name>.md` (for a namespaced package,
  `.agents/docs/<namespace>-<name>.md`). Dated names such as `2026-10-23-...md` are design
  records and keep that form.
- English or Chinese (either is fine here). Short: aim for under 80 lines. Facts you verified, not marketing.
- **A plain version bump adds no file and no entry.**
- A larger change appends **one dated entry** to the revision log of the existing note: a
  change of layout, dependencies, source or mirror, linking (static/dynamic), platform
  coverage, a `revision` raise, or a namespace move. Do not rewrite the history above the log.
- It is not published to users (`docs/` is). Do not link to it from `docs/` or the README.

## Template

```markdown
# <name>

<One or two sentences: what it is, the command(s) it provides, status (stable/dev/preview).>

- Upstream: <project URL> (<license>)
- Namespace: `xim` | `<handle>` (unofficial, see "Provenance")
- Platforms: <linux x86_64/aarch64, macosx aarch64, windows x86_64, ...> and what is not covered, with why

## Source

- Tier: upstream release | official repository release | well-known third-party release
- GLOBAL: <URL template>
- CN: <well-known mirror URL template> | xlings-res (GitCode, maintainer) | none yet (a maintainer will add it)
- Checksums: <where the sha256 came from; the second download that agreed>
- Auto-update: yes (`extensions.autoupdate`) | no (reason)

## Linking

<static / musl / dynamic glibc. Declared dependencies and why each is there (the DT_NEEDED
list that was measured). If a self-contained payload declares none, say that.>

## What the hooks do

- install: <what is unpacked and placed; anything relocated or patched>
- config: <commands registered with xvm, links, environment declared>
- uninstall: <what is removed>
- System impact: <none | what is touched outside the package's own directory>

## Provenance (unofficial packaging only)

<What it was built from (URL + hash), the exact reproducible process (commands, tool versions,
inputs), where the asset is hosted. A reviewer must be able to rebuild it and compare the sha256.>

## Verification

<The commands run, on which platforms/architectures, what was observed. What was not run.>

## Revision log

- 2026-11-25 — added at <version>: <anything non-obvious worth recording>.
```
